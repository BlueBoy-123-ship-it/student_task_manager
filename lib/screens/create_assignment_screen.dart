import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/pdf_storage_service.dart';

class CreateAssignmentScreen extends StatefulWidget {
  const CreateAssignmentScreen({super.key});

  @override
  State<CreateAssignmentScreen> createState() =>
      _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();
  final _pdfStorage = PdfStorageService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _marksController = TextEditingController(text: '100');

  String? _courseId;
  String _courseName = 'General';
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  DateTime? _reminderDateTime;
  PlatformFile? _selectedPdf;

  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: _dueDate ?? now.add(const Duration(days: 1)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _dueDate = picked;
      _dueTime ??= const TimeOfDay(hour: 23, minute: 59);
    });
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 23, minute: 59),
    );

    if (picked == null || !mounted) return;

    setState(() => _dueTime = picked);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: _reminderDateTime ?? now,
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _reminderDateTime != null
          ? TimeOfDay.fromDateTime(_reminderDateTime!)
          : TimeOfDay.now(),
    );

    if (time == null || !mounted) return;

    final reminder = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!reminder.isAfter(DateTime.now())) {
      _message('Reminder must be in the future.', true);
      return;
    }

    setState(() => _reminderDateTime = reminder);
  }

  DateTime? _combinedDueDate() {
    if (_dueDate == null) return null;

    final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);

    return DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      time.hour,
      time.minute,
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} • $hour:$minute';
  }

  String _formatDueDate() {
    final date = _combinedDueDate();
    if (date == null) return 'Select due date';

    return _formatDateTime(date);
  }

  void _message(String text, [bool error = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.path == null) {
      _message('Unable to access the selected PDF.', true);
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      _message('PDF must be 10 MB or smaller.', true);
      return;
    }
    setState(() => _selectedPdf = file);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final dueDate = _combinedDueDate();

    if (dueDate == null) {
      _message('Please select a due date.', true);
      return;
    }

    if (!dueDate.isAfter(DateTime.now())) {
      _message('Due date and time must be in the future.', true);
      return;
    }

    final marks = int.tryParse(_marksController.text.trim());

    if (marks == null || marks <= 0) {
      _message('Total marks must be greater than zero.', true);
      return;
    }

    setState(() => _saving = true);

    String? createdAssignmentId;
    try {
      final assignmentId = await _service.createAssignment(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        courseId: _courseId ?? '',
        courseName: _courseName.trim().isEmpty ? 'General' : _courseName.trim(),
        dueDate: dueDate,
        reminderDateTime: _reminderDateTime,
        totalMarks: marks,
      );

      createdAssignmentId = assignmentId;

      if (_selectedPdf != null) {
        final upload = await _pdfStorage.uploadAssignmentPdf(
          assignmentId: assignmentId,
          filePath: _selectedPdf!.path!,
          fileName: _selectedPdf!.name,
        );
        await _service.attachAssignmentPdf(
          assignmentId: assignmentId,
          pdfUrl: upload['url']!,
          pdfPath: upload['path']!,
          pdfFileName: upload['name']!,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (createdAssignmentId != null) {
        try {
          await _service.deleteAssignment(createdAssignmentId);
        } catch (_) {}
      }
      if (mounted) {
        _message('Unable to create assignment: $e', true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Assignment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF7C3AED),
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Assignment Information'),

                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Assignment title',
                        hintText: 'e.g. Database Design Assignment',
                        prefixIcon: Icon(Icons.assignment_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter an assignment title.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Instructions / description',
                        hintText: 'Tell students what they need to do...',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    StreamBuilder<QuerySnapshot>(
                      stream: _service.getCourses(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];

                        if (snapshot.hasError) {
                          return InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Course',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              'Could not load courses. Assignment will use General.',
                              style: TextStyle(color: colors.error),
                            ),
                          );
                        }

                        if (docs.isEmpty) {
                          return InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Course',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            child: const Text('General'),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _courseId,
                          isExpanded: true, // Prevents right pixel overflow
                          decoration: const InputDecoration(
                            labelText: 'Course',
                            prefixIcon: Icon(Icons.school_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: docs.map((doc) {
                            final data =
                                doc.data() as Map<String, dynamic>;

                            final code =
                                data['code']?.toString().trim() ?? '';
                            final name =
                                data['name']?.toString().trim() ?? '';

                            final label = code.isEmpty
                                ? name
                                : '$code — $name';

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                label.isEmpty ? 'General' : label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            final selected =
                                docs.firstWhere((doc) => doc.id == value);

                            final data =
                                selected.data() as Map<String, dynamic>;

                            final code =
                                data['code']?.toString().trim() ?? '';
                            final name =
                                data['name']?.toString().trim() ?? '';

                            setState(() {
                              _courseId = value;
                              _courseName = code.isEmpty
                                  ? (name.isEmpty ? 'General' : name)
                                  : '$code — $name';
                            });
                          },
                          validator: (_) => null,
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _marksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total marks',
                        hintText: '100',
                        prefixIcon: Icon(Icons.grade_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final marks = int.tryParse(value?.trim() ?? '');
                        if (marks == null || marks <= 0) {
                          return 'Enter a valid total mark.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Schedule'),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.calendar_today_outlined),
                      ),
                      title: const Text(
                        'Due date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_formatDueDate()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDueDate,
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.schedule_outlined),
                      ),
                      title: const Text(
                        'Due time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _dueTime == null
                            ? 'Default: 23:59'
                            : _dueTime!.format(context),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDueTime,
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.notifications_outlined),
                      ),
                      title: const Text(
                        'Reminder',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _reminderDateTime == null
                            ? 'No reminder selected'
                            : _formatDateTime(_reminderDateTime!),
                      ),
                      trailing: _reminderDateTime == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              tooltip: 'Remove reminder',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() => _reminderDateTime = null);
                              },
                            ),
                      onTap: _pickReminder,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(
                  _selectedPdf?.name ?? 'No assignment PDF selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: _selectedPdf == null
                    ? const Text('Optional: attach the assignment PDF for students.')
                    : Text('${(_selectedPdf!.size / 1024).toStringAsFixed(1)} KB'),
                trailing: IconButton(
                  tooltip: 'Choose PDF',
                  onPressed: _saving ? null : _pickPdf,
                  icon: const Icon(Icons.attach_file),
                ),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_outlined),
                label: Text(
                  _saving ? 'Publishing...' : 'Publish Assignment',
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Published assignments become visible to students immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}