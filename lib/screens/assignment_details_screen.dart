import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'assignment_submissions_screen.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentDetailsScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<AssignmentDetailsScreen> createState() =>
      _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState
    extends State<AssignmentDetailsScreen> {
  final FirestoreService _service = FirestoreService();

  bool _loading = true;
  Map<String, dynamic>? _assignment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _service.getAssignment(widget.assignmentId);
      if (!mounted) return;
      setState(() {
        _assignment = snap.exists
            ? snap.data() as Map<String, dynamic>
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Unable to load assignment: $e', true);
    }
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Unknown';
    final d = value.toDate();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _message(String text, [bool error = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ));
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: const Text(
          'This will remove the assignment. Existing submissions are not automatically deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _service.deleteAssignment(widget.assignmentId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _message('Unable to delete assignment: $e', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment')),
        body: const Center(child: Text('Assignment not found.')),
      );
    }

    final a = _assignment!;
    final title = a['title']?.toString() ?? 'Assignment';
    final description = a['description']?.toString() ?? '';
    final course = a['courseName']?.toString() ?? 'Course';
    final marks = (a['totalMarks'] as num?)?.toInt() ?? 100;
    final status = a['status']?.toString() ?? 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Details'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(course, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  _info(Icons.grade_outlined, 'Total marks', '$marks'),
                  _info(Icons.schedule_outlined, 'Deadline', _date(a['dueDate'])),
                  _info(Icons.flag_outlined, 'Status', status.toUpperCase()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Instructions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                description.trim().isEmpty ? 'No instructions provided.' : description,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssignmentSubmissionsScreen(
                    assignmentId: widget.assignmentId,
                    assignmentTitle: title,
                    courseName: course,
                    totalMarks: marks,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.people_outline),
            label: const Text('View Student Submissions'),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
