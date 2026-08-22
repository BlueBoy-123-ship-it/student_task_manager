import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _firestore.collection('users').doc(user.uid).get();
    return snap.exists ? snap.data() : null;
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final snap = await _firestore.collection('users').doc(userId).get();
    return snap.exists ? snap.data() : null;
  }

  Future<String> getCurrentUserRole() async {
    final profile = await getCurrentUserProfile();
    return profile?['role']?.toString().toLowerCase() == 'lecturer'
        ? 'lecturer'
        : 'student';
  }

  // ========================= COURSES =========================

  Future<void> addCourse(String code, String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role']?.toString().toLowerCase();
    if (role != 'lecturer') {
      throw Exception('Only lecturers can create courses.');
    }

    final lecturerName =
        profile.data()?['name']?.toString() ?? user.displayName ?? 'Lecturer';

    await _firestore.collection('courses').add({
      'code': code.trim(),
      'name': name.trim(),
      'lecturerId': user.uid,
      'userId': user.uid, // legacy compatibility with older course documents
      'lecturerName': lecturerName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getCourses() => getLecturerCourses();

  Stream<QuerySnapshot> getLecturerCourses() {
    // We read the course collection and filter locally so older courses that
    // used the legacy `userId` field remain visible to their lecturer.
    if (_auth.currentUser == null) return const Stream<QuerySnapshot>.empty();
    return _firestore.collection('courses').snapshots();
  }

  Stream<QuerySnapshot> getAllCourses() {
    if (_auth.currentUser == null) return const Stream<QuerySnapshot>.empty();
    return _firestore.collection('courses').snapshots();
  }

  Stream<QuerySnapshot> getMyEnrollments() {
    final user = _auth.currentUser;
    if (user == null) return const Stream<QuerySnapshot>.empty();
    return _firestore
        .collection('course_enrollments')
        .where('studentId', isEqualTo: user.uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getLecturerEnrollments() {
    final user = _auth.currentUser;
    if (user == null) return const Stream<QuerySnapshot>.empty();
    return _firestore
        .collection('course_enrollments')
        .where('lecturerId', isEqualTo: user.uid)
        .snapshots();
  }

  Future<void> enrollInCourse(
    String courseId,
    Map<String, dynamic> course,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');

    final profile = await _firestore.collection('users').doc(user.uid).get();
    if (profile.data()?['role']?.toString().toLowerCase() != 'student') {
      throw Exception('Only students can enroll in courses.');
    }

    final studentData = profile.data() ?? {};

    final enrollmentId = '${courseId}_${user.uid}';
    await _firestore.collection('course_enrollments').doc(enrollmentId).set({
      'courseId': courseId,
      'studentId': user.uid,
      'studentName':
          studentData['name']?.toString() ?? user.displayName ?? 'Student',
      'matricNumber': studentData['matricNumber']?.toString() ?? '',
      'courseCode': course['code']?.toString() ?? '',
      'courseName': course['name']?.toString() ?? '',
      'lecturerId': course['lecturerId']?.toString() ?? '',
      'enrolledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unenrollFromCourse(String courseId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');
    await _firestore
        .collection('course_enrollments')
        .doc('${courseId}_${user.uid}')
        .delete();
  }

  Future<void> deleteCourse(String courseId) async {
    await _firestore.collection('courses').doc(courseId).delete();
  }

  Future<void> attachAssignmentPdf({
    required String assignmentId,
    required String pdfUrl,
    required String pdfPath,
    required String pdfFileName,
  }) async {
    await _firestore.collection('assignments').doc(assignmentId).update({
      'attachmentUrl': pdfUrl,
      'attachmentPath': pdfPath,
      'attachmentName': pdfFileName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ========================= TASKS =========================

  Future<void> addTask(
    String title,
    DateTime? dueDate,
    String priority,
    DateTime? reminderDateTime,
    String? courseId,
    String? courseName,
    String taskType,
    int recurrenceWeeks,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');

    final ref = await _firestore.collection('tasks').add({
      'title': title.trim(),
      'completed': false,
      'priority': priority,
      'taskType': taskType.trim().isEmpty ? 'Assignment' : taskType.trim(),
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'courseId': courseId,
      'courseName': courseName,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'reminderDateTime': reminderDateTime == null
          ? null
          : Timestamp.fromDate(reminderDateTime),
      'recurrenceWeeks': recurrenceWeeks,
    });

    if (reminderDateTime != null) {
      await _safeScheduleReminder(
        notificationId: _notificationId(ref.id),
        taskTitle: title,
        reminderDateTime: reminderDateTime,
        weekly: recurrenceWeeks > 0,
      );
    }
  }

  Stream<QuerySnapshot> getTasks() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  Future<void> rescheduleActiveTaskReminders() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('tasks')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['completed'] == true) continue;

      final reminder = data['reminderDateTime'];
      if (reminder is! Timestamp) continue;

      final recurrenceWeeks = (data['recurrenceWeeks'] as num?)?.toInt() ?? 0;
      final reminderDateTime = reminder.toDate();
      if (recurrenceWeeks == 0 && !reminderDateTime.isAfter(DateTime.now())) {
        continue;
      }

      await _safeScheduleReminder(
        notificationId: _notificationId(doc.id),
        taskTitle: data['title']?.toString() ?? 'Task',
        reminderDateTime: reminderDateTime,
        weekly: recurrenceWeeks > 0,
      );
    }
  }

  Future<void> toggleTask(String docId, bool completed) async {
    final ref = _firestore.collection('tasks').doc(docId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final reminder = data['reminderDateTime'] is Timestamp
        ? (data['reminderDateTime'] as Timestamp).toDate()
        : null;
    await ref.update({'completed': completed});

    if (completed) {
      await _safeCancelReminder(_notificationId(docId));
    } else if (reminder != null && reminder.isAfter(DateTime.now())) {
      await _safeScheduleReminder(
        notificationId: _notificationId(docId),
        taskTitle: data['title']?.toString() ?? 'Task',
        reminderDateTime: reminder,
      );
    }
  }

  Future<void> deleteTask(String docId) async {
    await _safeCancelReminder(_notificationId(docId));
    await _firestore.collection('tasks').doc(docId).delete();
  }

  Future<void> updateTask(
    String docId,
    String title,
    DateTime? dueDate,
    String priority,
    DateTime? reminderDateTime, {
    String? taskType,
    String? courseId,
    String? courseName,
    int recurrenceWeeks = 0,
  }) async {
    await _safeCancelReminder(_notificationId(docId));

    await _firestore.collection('tasks').doc(docId).update({
      'title': title.trim(),
      'priority': priority,
      'courseId': courseId,
      'courseName': courseName,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'reminderDateTime': reminderDateTime == null
          ? null
          : Timestamp.fromDate(reminderDateTime),
      'recurrenceWeeks': recurrenceWeeks,
      if (taskType != null && taskType.trim().isNotEmpty)
        'taskType': taskType.trim(),
    });

    if (reminderDateTime != null && reminderDateTime.isAfter(DateTime.now())) {
      final snap = await _firestore.collection('tasks').doc(docId).get();
      if (snap.exists && snap.data()?['completed'] != true) {
        await _safeScheduleReminder(
          notificationId: _notificationId(docId),
          taskTitle: title,
          reminderDateTime: reminderDateTime,
          weekly: recurrenceWeeks > 0,
        );
      }
    }
  }

  // ========================= ASSIGNMENTS =========================

  Future<String> createAssignment({
    required String title,
    required String description,
    required String courseId,
    required String courseName,
    required DateTime dueDate,
    DateTime? reminderDateTime,
    int totalMarks = 100,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');

    if (totalMarks <= 0) {
      throw Exception('Total marks must be greater than zero.');
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final lecturerData = profile.data() ?? {};

    final ref = await _firestore.collection('assignments').add({
      'title': title.trim(),
      'description': description.trim(),
      'courseId': courseId,
      'courseName': courseName.trim(),
      'lecturerId': user.uid,
      'lecturerName':
          lecturerData['name']?.toString() ?? user.displayName ?? 'Lecturer',
      'dueDate': Timestamp.fromDate(dueDate),
      'reminderDateTime': reminderDateTime == null
          ? null
          : Timestamp.fromDate(reminderDateTime),
      'totalMarks': totalMarks,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    if (reminderDateTime != null) {
      await _safeScheduleReminder(
        notificationId: _notificationId(ref.id),
        taskTitle: 'Assignment: ${title.trim()}',
        reminderDateTime: reminderDateTime,
      );
    }

    try {
      final enrollments = await _firestore
          .collection('course_enrollments')
          .where('lecturerId', isEqualTo: user.uid)
          .where('courseId', isEqualTo: courseId)
          .get();

      final notificationWrites = enrollments.docs.map((enrollment) {
        final studentId = (enrollment.data()['studentId'] ?? '').toString();
        return _createUserNotification(
          recipientId: studentId,
          title: 'New assignment published',
          body: '${title.trim()} was published in ${courseName.trim()}.',
          type: 'assignment_published',
          data: {'assignmentId': ref.id, 'courseId': courseId},
        );
      });
      await Future.wait(notificationWrites);
    } catch (e) {
      debugPrint('Assignment publication notifications failed: $e');
    }

    return ref.id;
  }

  Stream<QuerySnapshot> getLecturerAssignments() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _firestore
        .collection('assignments')
        .where('lecturerId', isEqualTo: user.uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getStudentAssignments() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _firestore
        .collection('assignments')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Future<DocumentSnapshot> getAssignment(String assignmentId) {
    return _firestore.collection('assignments').doc(assignmentId).get();
  }

  Future<void> updateAssignment({
    required String assignmentId,
    required String title,
    required String description,
    required DateTime dueDate,
    int totalMarks = 100,
  }) async {
    await _firestore.collection('assignments').doc(assignmentId).update({
      'title': title.trim(),
      'description': description.trim(),
      'dueDate': Timestamp.fromDate(dueDate),
      'totalMarks': totalMarks,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAssignmentStatus({
    required String assignmentId,
    required String status,
  }) async {
    if (status != 'active' && status != 'completed') {
      throw Exception('Invalid assignment status.');
    }

    await _firestore.collection('assignments').doc(assignmentId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _safeCancelReminder(_notificationId(assignmentId));
    await _firestore.collection('assignments').doc(assignmentId).delete();
  }

  // ========================= SUBMISSIONS =========================

  Future<String> submitAssignment({
    required String assignmentId,
    required String assignmentTitle,
    required String courseId,
    required String courseName,
    required String submissionText,
    String? pdfUrl,
    String? pdfPath,
    String? pdfFileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');

    final assignmentSnap = await _firestore
        .collection('assignments')
        .doc(assignmentId)
        .get();

    if (!assignmentSnap.exists) {
      throw Exception('Assignment not found.');
    }

    final assignmentData = assignmentSnap.data() ?? {};
    final totalMarks = (assignmentData['totalMarks'] as num?)?.toInt() ?? 100;

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final studentData = profile.data() ?? {};

    final studentName =
        studentData['name']?.toString() ?? user.displayName ?? 'Student';
    final matricNumber = studentData['matricNumber']?.toString() ?? '';

    final existing = await _firestore
        .collection('submissions')
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: user.uid)
        .limit(1)
        .get();

    final data = {
      'assignmentId': assignmentId,
      'assignmentTitle': assignmentTitle,
      'courseId': courseId,
      'courseName': courseName,
      'studentId': user.uid,
      'studentName': studentName,
      'matricNumber': matricNumber,
      'submissionText': submissionText.trim(),
      'totalMarks': totalMarks,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'submitted',
      'grade': null,
      'feedback': null,
      'gradedAt': null,
      'gradedBy': null,
      'returnedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      if (pdfPath != null) 'pdfPath': pdfPath,
      if (pdfFileName != null) 'pdfFileName': pdfFileName,
    };

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(data);
      try {
        await _notifyLecturerOfSubmission(
          assignmentId: assignmentId,
          assignmentData: assignmentData,
          assignmentTitle: assignmentTitle,
          studentName: studentName,
          submissionId: existing.docs.first.id,
        );
      } catch (e) {
        debugPrint('Submission notification failed: $e');
      }
      return existing.docs.first.id;
    }

    final ref = await _firestore.collection('submissions').add(data);
    try {
      await _notifyLecturerOfSubmission(
        assignmentId: assignmentId,
        assignmentData: assignmentData,
        assignmentTitle: assignmentTitle,
        studentName: studentName,
        submissionId: ref.id,
      );
    } catch (e) {
      debugPrint('Submission notification failed: $e');
    }
    return ref.id;
  }

  Stream<QuerySnapshot> getStudentSubmissions() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _firestore
        .collection('submissions')
        .where('studentId', isEqualTo: user.uid)
        .snapshots();
  }

  Future<QuerySnapshot> getStudentSubmission(String assignmentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');

    return _firestore
        .collection('submissions')
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: user.uid)
        .limit(1)
        .get();
  }

  Stream<QuerySnapshot> getAssignmentSubmissions(String assignmentId) {
    return _firestore
        .collection('submissions')
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots();
  }

  Future<DocumentSnapshot> getSubmission(String submissionId) {
    return _firestore.collection('submissions').doc(submissionId).get();
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required int grade,
    required String feedback,
  }) async {
    final lecturer = _auth.currentUser;
    if (lecturer == null) {
      throw Exception('No lecturer is currently signed in.');
    }

    final ref = _firestore.collection('submissions').doc(submissionId);
    final snap = await ref.get();

    if (!snap.exists) throw Exception('Submission not found.');

    final data = snap.data() ?? {};
    final totalMarks = (data['totalMarks'] as num?)?.toInt() ?? 100;

    if (grade < 0 || grade > totalMarks) {
      throw Exception('Grade must be between 0 and $totalMarks.');
    }

    await ref.update({
      'grade': grade,
      'feedback': feedback.trim(),
      'status': 'graded',
      'gradedAt': FieldValue.serverTimestamp(),
      'gradedBy': lecturer.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> returnSubmission(String submissionId) async {
    await _firestore.collection('submissions').doc(submissionId).update({
      'status': 'returned',
      'returnedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ========================= NOTIFICATIONS =========================

  Stream<QuerySnapshot> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return const Stream<QuerySnapshot>.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .snapshots();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> _createUserNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    if (recipientId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(recipientId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'type': type,
          'senderId': _auth.currentUser?.uid,
          'data': data,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _notifyLecturerOfSubmission({
    required String assignmentId,
    required Map<String, dynamic> assignmentData,
    required String assignmentTitle,
    required String studentName,
    required String submissionId,
  }) async {
    await _createUserNotification(
      recipientId: assignmentData['lecturerId']?.toString() ?? '',
      title: 'Assignment submitted',
      body: '$studentName submitted $assignmentTitle.',
      type: 'assignment_submitted',
      data: {'assignmentId': assignmentId, 'submissionId': submissionId},
    );
  }

  Future<void> _safeScheduleReminder({
    required int notificationId,
    required String taskTitle,
    required DateTime reminderDateTime,
    bool weekly = false,
  }) async {
    try {
      final scheduled = await NotificationService.instance.scheduleTaskReminder(
        notificationId: notificationId,
        taskTitle: taskTitle,
        reminderDateTime: reminderDateTime,
        weekly: weekly,
      );
      if (!scheduled) {
        debugPrint('Reminder was not scheduled for task: $taskTitle');
      }
    } catch (e) {
      // Notifications should never prevent assignment/task creation.
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  Future<void> _safeCancelReminder(int notificationId) async {
    try {
      await NotificationService.instance.cancelTaskReminder(notificationId);
    } catch (e) {
      debugPrint('Reminder cancellation failed: $e');
    }
  }

  int _notificationId(String id) {
    // String.hashCode is not guaranteed to stay the same between app runs.
    // FNV-1a keeps scheduled reminders cancellable after a restart.
    var hash = 2166136261;
    for (final codeUnit in id.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
