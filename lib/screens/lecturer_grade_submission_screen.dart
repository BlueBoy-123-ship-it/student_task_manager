import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'pdf_viewer_screen.dart';

class LecturerGradeSubmissionScreen extends StatefulWidget {
  final String submissionId;

  const LecturerGradeSubmissionScreen({
    super.key,
    required this.submissionId,
  });

  @override
  State<LecturerGradeSubmissionScreen> createState() => _LecturerGradeSubmissionScreenState();
}

class _LecturerGradeSubmissionScreenState extends State<LecturerGradeSubmissionScreen> {
  final FirestoreService _service = FirestoreService();
  final _grade = TextEditingController();
  final _feedback = TextEditingController();

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _service.getSubmission(widget.submissionId);
      if (!mounted) return;
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        _data = d;
        if (d['grade'] != null) _grade.text = d['grade'].toString();
        if (d['feedback'] != null) _feedback.text = d['feedback'].toString();
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _msg('Unable to load submission: $e', true);
    }
  }

  int get _totalMarks => (_data?['totalMarks'] as num?)?.toInt() ?? 100;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final grade = int.tryParse(_grade.text.trim());

    if (grade == null) {
      _msg('Enter a valid whole-number grade.', true);
      return;
    }
    if (grade < 0 || grade > _totalMarks) {
      _msg('Grade must be between 0 and $_totalMarks.', true);
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.gradeSubmission(
        submissionId: widget.submissionId,
        grade: grade,
        feedback: _feedback.text.trim(),
      );
      if (!mounted) return;
      _msg('Grade and feedback saved.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _msg('Unable to save grade: $e', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _return() async {
    if (_data?['grade'] == null) {
      _msg('Save a grade before returning the submission.', true);
      return;
    }

    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Return to student?'),
        content: const Text('The student will see the grade and feedback.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Return')),
        ],
      ),
    );

    if (yes != true) return;

    try {
      await _service.returnSubmission(widget.submissionId);
      if (!mounted) return;
      _msg('Submission returned to student.');
      Navigator.pop(context, true);
    } catch (e) {
      _msg('Unable to return submission: $e', true);
    }
  }

  void _msg(String text, [bool error = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ));
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Unknown';
    final d = value.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grade Submission')),
        body: const Center(child: Text('Submission not found.')),
      );
    }

    final d = _data!;
    final name = d['studentName']?.toString() ?? 'Student';
    final matric = d['matricNumber']?.toString() ?? '';
    final title = d['assignmentTitle']?.toString() ?? 'Assignment';
    final course = d['courseName']?.toString() ?? 'Course';
    final answer = d['submissionText']?.toString() ?? '';
    final pdfUrl = d['pdfUrl']?.toString();
    final pdfName = d['pdfFileName']?.toString() ?? 'Submission PDF';

    return Scaffold(
      appBar: AppBar(title: const Text('Grade Submission')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(matric.isEmpty ? course : '$matric\n$course'),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          Text('Submitted: ${_date(d['submittedAt'])}'),
          const SizedBox(height: 20),
          const Text('Student Submission', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                answer.trim().isEmpty ? 'No written submission provided.' : answer,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ),
          if (pdfUrl != null && pdfUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(
                      pdfUrl: pdfUrl,
                      title: pdfName,
                      allowDownload: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(
                'Open $pdfName',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text('Grade', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _grade,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Grade',
              suffixText: '/ $_totalMarks',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _feedback,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Feedback',
              hintText: 'Write feedback for the student...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Grade & Feedback'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _return,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Return to Student'),
          ),
        ],
      ),
    );
  }
}
