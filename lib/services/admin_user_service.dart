import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserService {
  static SupabaseClient get _sb => Supabase.instance.client;

  /// If user types "stu001" -> "stu001@campusapp.com"
  /// If user types already an email -> use as-is.
  static String toEmail(String input) {
    final v = input.trim();
    if (v.contains('@')) return v;
    return '$v@campusapp.com';
  }

  /// Creates auth user + profile via Edge Function (service role inside function)
  static Future<Map<String, dynamic>> createUser({
    required String loginId,
    required String password,
    required String role, // student / hod / admin
    required String fullName,
    String faculty = "",
    String course = "",
    String semester = "",
    String batch = "",
  }) async {
    final r = role.trim().toLowerCase();
    if (r != "student" && r != "hod" && r != "admin") {
      throw "Invalid role: $role";
    }

    final profile = <String, dynamic>{
      'role': r,
      'full_name': fullName.trim().isEmpty ? null : fullName.trim(),
      'faculty': faculty.trim().isEmpty ? null : faculty.trim(),
      'course': course.trim().isEmpty ? null : course.trim(),
      'semester': semester.trim().isEmpty ? null : semester.trim(),
      'batch': batch.trim().isEmpty ? null : batch.trim(),
      'student_id': r == "student" ? loginId.trim() : null,
      'staff_id': (r == "hod" || r == "admin") ? loginId.trim() : null,
    };

    final res = await _sb.functions.invoke(
      'admin-create-user',
      body: {
        'id': loginId.trim(),
        'password': password,
        'profile': profile,
      },
    );

    if (res.data == null) {
      throw "Create user failed (no response data).";
    }

    if (res.data is Map && (res.data['error'] != null)) {
      throw res.data['error'].toString();
    }

    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Deletes auth user + profile (Edge Function)
  static Future<void> deleteUser({required String userId}) async {
    final res = await _sb.functions.invoke(
      'admin-delete-user',
      body: {'user_id': userId},
    );

    if (res.data is Map && (res.data['error'] != null)) {
      throw res.data['error'].toString();
    }
  }

  /// ✅ ADMIN sets a new password immediately (NO EMAIL)
  static Future<void> setPassword({
    required String userId,
    required String newPassword,
  }) async {
    final token = _sb.auth.currentSession?.accessToken;
    if (token == null) {
      throw "Not logged in (no access token).";
    }

    final res = await _sb.functions.invoke(
      'admin-set-password',
      body: {
        'user_id': userId,
        'new_password': newPassword,
      },
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.data is Map && (res.data['error'] != null)) {
      throw res.data['error'].toString();
    }
  }

  /// OPTIONAL helper: resolve userId from loginId using profiles table
  static Future<String> resolveUserIdFromLoginId(String loginId) async {
    final id = loginId.trim();
    if (id.isEmpty) throw "loginId is empty";

    final rows = await _sb
        .from('profiles')
        .select('id')
        .or('student_id.eq.$id,staff_id.eq.$id')
        .limit(1);

    final list = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (list.isEmpty) throw "No profile found for loginId: $id";

    return (list.first['id'] ?? '').toString();
  }
}