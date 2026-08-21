import 'package:flutter/material.dart';

import 'lecturer_submissions_screen.dart';

/// Compatibility wrapper for older screens that still use
/// AssignmentSubmissionsScreen.
class AssignmentSubmissionsScreen extends StatelessWidget {
  final String assignmentId;
  final String assignmentTitle;
  final String courseName;
  final int totalMarks;

  const AssignmentSubmissionsScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    this.courseName = 'Course',
    this.totalMarks = 100,
  });

  @override
  Widget build(BuildContext context) {
    return LecturerSubmissionsScreen(
      assignmentId: assignmentId,
      assignmentTitle: assignmentTitle,
      courseName: courseName,
      totalMarks: totalMarks,
    );
  }
}
