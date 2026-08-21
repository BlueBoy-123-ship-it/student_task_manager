import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AddTaskDialog extends StatefulWidget {
  final Future<void> Function(
    String title,
    DateTime? dueDate,
    String priority,
    DateTime? reminderDateTime,
    String? courseId,
    String? courseName,
    String taskType,
    int recurrenceWeeks,
  ) onSave;

  const AddTaskDialog({
    super.key,
    required this.onSave,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _titleController =
      TextEditingController();

  final FirestoreService _firestoreService =
      FirestoreService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedReminderTime;

  String _priority = 'Medium';
  String _taskType = 'Assignment';
  bool _isRecurring = false;

  String? _selectedCourseId;
  String? _selectedCourseName;

  bool _saving = false;

  // =========================================================
  // TASK TYPES
  // =========================================================

  static const List<String> _taskTypes = [
    'Assignment',
    'Quiz',
    'Exam',
    'Project',
    'Reading',
    'Other',
  ];

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // =========================================================
  // PICK DUE DATE
  // =========================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final initialDate = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: DateTime(2035),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // =========================================================
  // PICK REMINDER TIME
  // =========================================================

  Future<void> _pickReminderTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a due date before setting a reminder.',
          ),
        ),
      );

      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime:
          _selectedReminderTime ??
          const TimeOfDay(
            hour: 8,
            minute: 0,
          ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedReminderTime = picked;
      });
    }
  }

  // =========================================================
  // COMBINE DATE + TIME
  // =========================================================

  DateTime? _getReminderDateTime() {
    if (_selectedDate == null ||
        _selectedReminderTime == null) {
      return null;
    }

    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedReminderTime!.hour,
      _selectedReminderTime!.minute,
    );
  }

  // =========================================================
  // REMOVE DUE DATE
  // =========================================================

  void _removeDueDate() {
    setState(() {
      _selectedDate = null;
      _selectedReminderTime = null;
    });
  }

  // =========================================================
  // REMOVE REMINDER
  // =========================================================

  void _removeReminder() {
    setState(() {
      _selectedReminderTime = null;
    });
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // =========================================================
  // FORMAT TIME
  // =========================================================

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;

    final minute = time.minute
        .toString()
        .padLeft(2, '0');

    final period = time.period == DayPeriod.am
        ? 'AM'
        : 'PM';

    return '$hour:$minute $period';
  }

  // =========================================================
  // PRIORITY COLOR
  // =========================================================

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Low':
        return Colors.green;

      case 'High':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _save() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a task title.',
          ),
        ),
      );
      return;
    }

    final reminderDateTime = _getReminderDateTime();
    if (_isRecurring && reminderDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a reminder time for a weekly task.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (reminderDateTime != null && !reminderDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reminder time must be in the future.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(
        title,
        _selectedDate,
        _priority,
        reminderDateTime,
        _selectedCourseId,
        _selectedCourseName,
        _taskType,
        _isRecurring ? 1 : 0,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to add task. Please try again.',
          ),
        ),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Add New Task'),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // =================================================
            // TASK TITLE
            // =================================================

            TextField(
              controller: _titleController,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Task title',
                hintText: 'Enter task title',
                prefixIcon: Icon(
                  Icons.task_alt_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 18),

            // =================================================
            // TASK TYPE
            // =================================================

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Task Type',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _taskType,

              isExpanded: true,

              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.label_outline,
                ),
              ),

              items: _taskTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),

              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _taskType = value;
                      });
                    },
            ),

            const SizedBox(height: 18),

            // =================================================
            // COURSE
            // =================================================

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Course / Subject',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getCourses(),

              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load courses.',
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox(
                    height: 50,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final courses =
                    snapshot.data?.docs ?? [];

                final selectedCourseExists =
                    _selectedCourseId != null &&
                    courses.any(
                      (doc) =>
                          doc.id ==
                          _selectedCourseId,
                    );

                return DropdownButtonFormField<String>(
                  initialValue:
                      selectedCourseExists
                          ? _selectedCourseId
                          : null,

                  isExpanded: true,

                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.school_outlined,
                    ),
                  ),

                  hint: const Text(
                    'Select a course',
                  ),

                  items: courses.map((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final code =
                        data['code']
                                ?.toString() ??
                            '';

                    final name =
                        data['name']
                                ?.toString() ??
                            '';

                    final displayName =
                        code.isEmpty
                            ? name
                            : '$code — $name';

                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(
                        displayName,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),

                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          final selected =
                              courses.firstWhere(
                            (doc) =>
                                doc.id == value,
                          );

                          final data =
                              selected.data()
                                  as Map<String, dynamic>;

                          final code =
                              data['code']
                                      ?.toString() ??
                                  '';

                          final name =
                              data['name']
                                      ?.toString() ??
                                  '';

                          final displayName =
                              code.isEmpty
                                  ? name
                                  : '$code — $name';

                          setState(() {
                            _selectedCourseId =
                                value;

                            _selectedCourseName =
                                displayName;
                          });
                        },
                );
              },
            ),

            // Current course indicator
            if (_selectedCourseName != null &&
                _selectedCourseName!.isNotEmpty) ...[
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      'Selected: $_selectedCourseName',
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            colorScheme.primary,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() {
                              _selectedCourseId =
                                  null;
                              _selectedCourseName =
                                  null;
                            });
                          },
                    child: const Text(
                      'Remove',
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            // =================================================
            // DUE DATE
            // =================================================

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Due Date',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _saving ? null : _pickDate,

                icon: const Icon(
                  Icons.calendar_today_outlined,
                ),

                label: Text(
                  _selectedDate == null
                      ? 'Choose Due Date'
                      : _formatDate(
                          _selectedDate!,
                        ),
                ),
              ),
            ),

            if (_selectedDate != null) ...[
              const SizedBox(height: 4),

              TextButton(
                onPressed:
                    _saving
                        ? null
                        : _removeDueDate,
                child: const Text(
                  'Remove Due Date',
                ),
              ),
            ],

            // =================================================
            // REMINDER
            // =================================================

            if (_selectedDate != null) ...[
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reminder',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _pickReminderTime,

                  icon: Icon(
                    _selectedReminderTime == null
                        ? Icons
                            .notifications_none_outlined
                        : Icons
                            .notifications_active_outlined,
                  ),

                  label: Text(
                    _selectedReminderTime == null
                        ? 'No reminder'
                        : 'Remind me at '
                            '${_formatTime(
                            _selectedReminderTime!,
                          )}',
                  ),
                ),
              ),

              if (_selectedReminderTime != null) ...[
                const SizedBox(height: 4),

                TextButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _removeReminder,

                  icon: const Icon(
                    Icons.notifications_off_outlined,
                    size: 18,
                  ),

                  label: const Text(
                    'Remove Reminder',
                  ),
                ),
              ],

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat weekly'),
                subtitle: const Text('Continue until this task is completed'),
                value: _isRecurring,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isRecurring = value),
              ),
            ],

            const SizedBox(height: 14),

            // =================================================
            // PRIORITY
            // =================================================

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Priority',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _priority,

              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.flag_outlined,
                ),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Low',
                  child: Text('Low'),
                ),
                DropdownMenuItem(
                  value: 'Medium',
                  child: Text('Medium'),
                ),
                DropdownMenuItem(
                  value: 'High',
                  child: Text('High'),
                ),
              ],

              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _priority = value;
                      });
                    },
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 11,
                  color: _priorityColor(
                    _priority,
                  ),
                ),

                const SizedBox(width: 6),

                Text(
                  '$_priority Priority',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        colorScheme
                            .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // =======================================================
      // ACTIONS
      // =======================================================

      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.pop(context);
                },

          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed:
              _saving ? null : _save,

          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Add Task',
                ),
        ),
      ],
    );
  }
}