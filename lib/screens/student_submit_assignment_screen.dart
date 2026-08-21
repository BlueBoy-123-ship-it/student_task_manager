import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'student_submission_result_screen.dart';

class StudentSubmitAssignmentScreen extends StatefulWidget {
  final String assignmentId;

  const StudentSubmitAssignmentScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<StudentSubmitAssignmentScreen> createState() =>
      _StudentSubmitAssignmentScreenState();
}

class _StudentSubmitAssignmentScreenState
    extends State<StudentSubmitAssignmentScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _answerController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _assignment;
  String? _existingSubmissionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final assignment = await _service.getAssignment(widget.assignmentId);
      final existing = await _service.getStudentSubmission(widget.assignmentId);

      if (!mounted) return;
      setState(() {
        _assignment = assignment.exists ? assignment.data() as Map<String, dynamic> : null;
        if (existing.docs.isNotEmpty) {
          _existingSubmissionId = existing.docs.first.id;
          final data = existing.docs.first.data() as Map<String, dynamic>;
          _answerController.text = data['submissionText']?.toString() ?? '';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Unable to load submission page: $e', true);
    }
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return 'No due date';
    final d = value.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _confirmAndSubmit() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      _message('Please enter your answer before submitting.', true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text(
          'Are you sure you want to submit this assignment? You can update it later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Submission'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      final a = _assignment!;
      final submissionId = await _service.submitAssignment(
        assignmentId: widget.assignmentId,
        assignmentTitle: a['title']?.toString() ?? 'Assignment',
        courseId: a['courseId']?.toString() ?? '',
        courseName: a['courseName']?.toString() ?? 'Course',
        submissionText: answer,
      );

      if (!mounted) return;
      _existingSubmissionId = submissionId;
      _message('Assignment submitted successfully.');

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentSubmissionResultScreen(submissionId: submissionId),
        ),
      );
    } catch (e) {
      if (mounted) _message('Unable to submit assignment: $e', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, [bool error = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Submit Assignment')),
        body: const Center(child: Text('Assignment not found.')),
      );
    }

    final a = _assignment!;
    final title = a['title']?.toString() ?? 'Assignment';
    final course = a['courseName']?.toString() ?? 'Course';
    final marks = a['totalMarks'] is num ? (a['totalMarks'] as num).toInt() : 100;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Assignment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$course • $marks marks\nDue: ${_date(a['dueDate'])}'),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Your Answer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            minLines: 12,
            maxLines: 20,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Type your assignment answer here...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          if (_existingSubmissionId != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'You already have a submission. Confirming will update it.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          FilledButton.icon(
            onPressed: _saving ? null : _confirmAndSubmit,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Submitting...' : 'Confirm Submission'),
          ),
        ],
      ),
    );
  }
}
