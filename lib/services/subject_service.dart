import 'auth_helper.dart';

class SubjectServiceException implements Exception {
  final String message;
  SubjectServiceException(this.message);
  @override
  String toString() => message;
}

/// -----------------------------------------
/// FETCH ALL SUBJECTS
/// -----------------------------------------
Future<List<Map<String, dynamic>>> fetchSubjects() async {
  final rows = await supabase
      .from('subject')
      .select('id, subject_code, subject_name, credit_hours')
      .order('subject_code', ascending: true);

  return (rows as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// -----------------------------------------
/// FETCH ENROLLED SUBJECTS (status = ENROLLED)
/// -----------------------------------------
Future<List<Map<String, dynamic>>> fetchMyEnrolledSubjects() async {
  final user = supabase.auth.currentUser;
  if (user == null) throw SubjectServiceException("Not logged in");

  final rows = await supabase
      .from('subject_enrollments')
      .select('''
        id,
        status,
        subject_id,
        subject:subject_id (
          id,
          subject_code,
          subject_name,
          credit_hours
        )
      ''')
      .match({
        'student_user_id': user.id,
        'status': 'ENROLLED',
      })
      .order('created_at', ascending: false);

  return (rows as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// -----------------------------------------
/// INTERNAL: ENROLL / DROP FOR ANY STUDENT
/// (Used by HOD approvals)
/// -----------------------------------------
Future<void> _enrollSubjectForStudent({
  required String studentUserId,
  required String subjectId,
}) async {
  final sid = subjectId.trim();
  if (studentUserId.trim().isEmpty) {
    throw SubjectServiceException("studentUserId is empty");
  }
  if (sid.isEmpty) throw SubjectServiceException("subjectId is empty");

  final existing = await supabase
      .from('subject_enrollments')
      .select('id')
      .match({
        'student_user_id': studentUserId,
        'subject_id': sid,
      });

  if ((existing as List).isNotEmpty) {
    await supabase.from('subject_enrollments').update({
      'status': 'ENROLLED',
    }).match({
      'student_user_id': studentUserId,
      'subject_id': sid,
    });
  } else {
    await supabase.from('subject_enrollments').insert({
      'student_user_id': studentUserId,
      'subject_id': sid,
      'status': 'ENROLLED',
    });
  }
}

Future<void> _dropSubjectForStudent({
  required String studentUserId,
  required String subjectId,
}) async {
  final sid = subjectId.trim();
  if (studentUserId.trim().isEmpty) {
    throw SubjectServiceException("studentUserId is empty");
  }
  if (sid.isEmpty) throw SubjectServiceException("subjectId is empty");

  await supabase.from('subject_enrollments').update({
    'status': 'DROPPED',
  }).match({
    'student_user_id': studentUserId,
    'subject_id': sid,
  });
}

/// -----------------------------------------
/// ENROLL SUBJECT (current student)
/// NOTE: Call this ONLY when HOD approves ADD.
/// (Still kept for compatibility)
/// -----------------------------------------
Future<void> enrollSubject(String subjectId) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw SubjectServiceException("Not logged in");
  await _enrollSubjectForStudent(studentUserId: user.id, subjectId: subjectId);
}

/// -----------------------------------------
/// DROP SUBJECT (current student)
/// NOTE: Call this ONLY when HOD approves DROP.
/// (Still kept for compatibility)
/// -----------------------------------------
Future<void> dropSubject(String subjectId) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw SubjectServiceException("Not logged in");
  await _dropSubjectForStudent(studentUserId: user.id, subjectId: subjectId);
}

/// -----------------------------------------
/// INTERNAL: GET HOD USER ID FOR FACULTY
/// Uses your faculty_hods table
/// -----------------------------------------
Future<String> _getHodUserIdForFaculty(String faculty) async {
  final f = faculty.trim();
  if (f.isEmpty) throw SubjectServiceException("Your profile faculty is missing");

  // safer than .single() (won't crash if row missing)
  final hodRow = await supabase
      .from('faculty_hods')
      .select('hod_user_id')
      .eq('faculty', f)
      .maybeSingle();

  if (hodRow == null) {
    throw SubjectServiceException("No HOD assigned for faculty: $f");
  }

  final hodUserId = (hodRow['hod_user_id'] ?? '').toString().trim();
  if (hodUserId.isEmpty) {
    throw SubjectServiceException("faculty_hods.hod_user_id is empty for faculty: $f");
  }

  return hodUserId;
}

/// -----------------------------------------
/// SUBMIT ADD/DROP REQUEST
/// (Does NOT change enrollments yet — only HOD approval should)
/// -----------------------------------------
Future<void> submitSubjectRequest({
  required String subjectId,
  required String actionType, // ADD / DROP
  required String reason,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw SubjectServiceException("Not logged in");

  final sid = subjectId.trim();
  final action = actionType.trim().toUpperCase();
  final rsn = reason.trim();

  if (sid.isEmpty) throw SubjectServiceException("No subject selected");
  if (action != "ADD" && action != "DROP") {
    throw SubjectServiceException("Invalid action type (must be ADD or DROP)");
  }
  if (rsn.isEmpty) throw SubjectServiceException("Please enter a reason");

  // get faculty from profiles (safer to reuse helper)
  final profile = await getMyProfile();
  final faculty = (profile['faculty'] ?? '').toString().trim();
  if (faculty.isEmpty) throw SubjectServiceException("Your profile faculty is missing");

  // lookup HOD via faculty_hods
  final hodUserId = await _getHodUserIdForFaculty(faculty);

  // prevent spam: duplicate pending request for same subject+action
  final dup = await supabase
      .from('subject_requests')
      .select('id')
      .match({
        'student_user_id': user.id,
        'subject_id': sid,
        'action_type': action,
        'status': 'Pending',
      });

  if ((dup as List).isNotEmpty) {
    throw SubjectServiceException("You already have a Pending $action request for this subject.");
  }

  await supabase.from('subject_requests').insert({
    'student_user_id': user.id,
    'hod_user_id': hodUserId,
    'subject_id': sid,
    'action_type': action,
    'reason': rsn,
    'status': 'Pending',
    'hod_remark': null,
  });
}

/// -----------------------------------------
/// FETCH MY REQUEST HISTORY
/// -----------------------------------------
Future<List<Map<String, dynamic>>> fetchMySubjectRequests() async {
  final user = supabase.auth.currentUser;
  if (user == null) throw SubjectServiceException("Not logged in");

  final rows = await supabase
      .from('subject_requests')
      .select('''
        id,
        subject_id,
        action_type,
        reason,
        status,
        hod_remark,
        created_at,
        subject:subject_id (
          subject_code,
          subject_name,
          credit_hours
        )
      ''')
      .match({'student_user_id': user.id})
      .order('created_at', ascending: false);

  return (rows as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// -----------------------------------------
/// HOD DECISION (THE MISSING PIECE ✅)
/// - Updates subject_requests.status + hod_remark
/// - If Approved:
///     ADD  -> set ENROLLED
///     DROP -> set DROPPED
///
/// Call this from HodSubjectRequestsPage instead of direct update.
/// -----------------------------------------
Future<void> decideSubjectRequest({
  required String requestId,
  required String newStatus, // Approved / Rejected
  required String hodRemark,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw SubjectServiceException("Not logged in");

  final rid = requestId.trim();
  final status = newStatus.trim();
  final remark = hodRemark.trim();

  if (rid.isEmpty) throw SubjectServiceException("requestId is empty");
  if (status != "Approved" && status != "Rejected") {
    throw SubjectServiceException("Invalid decision (must be Approved or Rejected)");
  }

  // Load request info
  final req = await supabase
      .from('subject_requests')
      .select('id, student_user_id, subject_id, action_type, status, hod_user_id')
      .eq('id', rid)
      .single();

  final row = Map<String, dynamic>.from(req as Map);

  final requestHodId = (row['hod_user_id'] ?? '').toString().trim();
  if (requestHodId.isNotEmpty && requestHodId != user.id) {
    // extra safety; RLS should already protect this
    throw SubjectServiceException("You are not assigned to this request.");
  }

  final studentUserId = (row['student_user_id'] ?? '').toString().trim();
  final subjectId = (row['subject_id'] ?? '').toString().trim();
  final actionType = (row['action_type'] ?? '').toString().trim().toUpperCase();

  if (studentUserId.isEmpty || subjectId.isEmpty) {
    throw SubjectServiceException("Invalid request row (missing student/subject).");
  }

  // Update request
  await supabase.from('subject_requests').update({
    'status': status,
    'hod_remark': remark.isEmpty ? null : remark,
  }).match({'id': rid});

  // Apply enrollment only if Approved
  if (status == "Approved") {
    if (actionType == "ADD") {
      await _enrollSubjectForStudent(studentUserId: studentUserId, subjectId: subjectId);
    } else if (actionType == "DROP") {
      await _dropSubjectForStudent(studentUserId: studentUserId, subjectId: subjectId);
    }
  }
}
