import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// ==============================
/// ID -> EMAIL MAPPING
/// ==============================
/// If user types "stu001" -> "stu001@campusapp.com"
/// If user types already an email -> use as-is.
String _toEmail(String input) {
  final v = input.trim();
  if (v.contains('@')) return v;
  return '$v@campusapp.com';
}

class AuthHelperException implements Exception {
  final String message;
  AuthHelperException(this.message);
  @override
  String toString() => message;
}

/// ==============================
/// AUTH
/// ==============================

Future<void> loginStudent({
  required String studentId,
  required String password,
}) async {
  final id = studentId.trim();
  final pw = password.trim();

  if (id.isEmpty || pw.isEmpty) {
    throw AuthHelperException("Please enter Student ID and Password");
  }

  await supabase.auth.signInWithPassword(
    email: _toEmail(id),
    password: pw,
  );

  // ✅ Enforce role: if not student, logout to avoid bad session
  try {
    final role = await getUserRole();
    if (role != 'student') {
      await logout();
      throw AuthHelperException("Not a student account");
    }
  } catch (e) {
    // if profile fetch fails etc, logout for safety
    await logout();
    rethrow;
  }
}

Future<void> loginFaculty({
  required String staffId,
  required String password,
}) async {
  final id = staffId.trim();
  final pw = password.trim();

  if (id.isEmpty || pw.isEmpty) {
    throw AuthHelperException("Please enter Staff ID and Password");
  }

  await supabase.auth.signInWithPassword(
    email: _toEmail(id),
    password: pw,
  );

  // ✅ Enforce role: if not hod, logout to avoid bad session
  try {
    final role = await getUserRole();
    if (role != 'hod') {
      await logout();
      throw AuthHelperException("Not a faculty/HOD account");
    }
  } catch (e) {
    await logout();
    rethrow;
  }
}

Future<void> logout() async {
  await supabase.auth.signOut();
}

/// ==============================
/// PROFILE + ROLE
/// ==============================

Future<Map<String, dynamic>> getMyProfile() async {
  final user = supabase.auth.currentUser;
  if (user == null) throw AuthHelperException("Not logged in");

  final res = await supabase
      .from('profiles')
      .select(
        'id, role, full_name, student_id, staff_id, faculty, course, semester, batch',
      )
      .eq('id', user.id)
      .maybeSingle();

  if (res == null) {
    throw AuthHelperException(
      "Profile not found for current user (profiles.id must match auth.user.id).",
    );
  }

  return Map<String, dynamic>.from(res as Map);
}

Future<String> getUserRole() async {
  final profile = await getMyProfile();
  final role = (profile['role'] ?? '').toString().trim();

  // ✅ safer: do NOT default to "student"
  // If role is empty, treat as invalid setup
  if (role.isEmpty) {
    throw AuthHelperException("Role not set in profiles table for this user.");
  }

  return role;
}

/// ==============================
/// HOD LOOKUP (handles multiple rows)
/// ==============================
/// If multiple HODs exist for a faculty, pick the first deterministically.
Future<String> getHodUserIdForFaculty(String faculty) async {
  final facultyTrim = faculty.trim();
  if (facultyTrim.isEmpty) {
    throw AuthHelperException(
      "Your profile faculty is empty. Please set faculty in profiles table.",
    );
  }

  final rows = await supabase
      .from('profiles')
      .select('id, staff_id')
      .eq('role', 'hod')
      .eq('faculty', facultyTrim)
      .order('staff_id', ascending: true)
      .limit(1);

  final list =
      (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();

  if (list.isEmpty) {
    throw AuthHelperException(
      "No HOD found for faculty: $facultyTrim. Ensure profiles has role='hod' and faculty='$facultyTrim'.",
    );
  }

  final hodId = (list.first['id'] ?? '').toString().trim();
  if (hodId.isEmpty) {
    throw AuthHelperException("HOD profile found but id is empty (invalid row).");
  }

  return hodId;
}

/// ==============================
/// LEAVE SUBMISSION
/// ==============================
/// attachmentUrl = newline-separated public URLs (or empty string)
Future<void> submitLeaveApplication({
  required String leaveType,
  required DateTime startDate,
  required DateTime endDate,
  required int totalDays,
  required String reason,
  required String attachmentUrl,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw AuthHelperException("Not logged in");

  if (endDate.isBefore(startDate)) {
    throw AuthHelperException("End date cannot be before start date");
  }

  final profile = await getMyProfile();
  final faculty = (profile['faculty'] ?? '').toString().trim();

  final hodUserId = await getHodUserIdForFaculty(faculty);

  final payload = <String, dynamic>{
    'student_user_id': user.id,
    'hod_user_id': hodUserId,
    'leave_type': leaveType,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'total_days': totalDays,
    'reason': reason.trim(),
    'status': 'Pending',
    'hod_remark': null,
    'attachment_url': attachmentUrl.trim().isEmpty ? null : attachmentUrl.trim(),
    'faculty': faculty, // you said you added this column
  };

  await supabase.from('leave_applications').insert(payload);
}
