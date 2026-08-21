import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:student_task_manager/services/firestore_service.dart';

class EditTaskDialog extends StatefulWidget {
  final String title;

  final String? courseId;
  final String? courseName;

  final String taskType;

  final DateTime? dueDate;

  final String priority;

  final DateTime? reminderDateTime;
  final int recurrenceWeeks;

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

  const EditTaskDialog({
    super.key,
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.taskType,
    required this.dueDate,
    required this.priority,
    required this.reminderDateTime,
    required this.onSave,
    this.recurrenceWeeks = 0,
  });

  @override
  State<EditTaskDialog> createState() =>
      _EditTaskDialogState();
}

class _EditTaskDialogState
    extends State<EditTaskDialog> {
  // =========================================================
  // CONTROLLERS / SERVICES
  // =========================================================

  late final TextEditingController _titleController;

  final FirestoreService _firestoreService =
      FirestoreService();

  // =========================================================
  // STATE
  // =========================================================

  late String _priority;

  late String _taskType;

  DateTime? _selectedDate;

  TimeOfDay? _selectedReminderTime;

  String? _selectedCourseId;

  String? _selectedCourseName;

  bool _saving = false;
  late bool _isRecurring;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.title,
    );

    _priority =
        ['Low', 'Medium', 'High'].contains(
      widget.priority,
    )
            ? widget.priority
            : 'Medium';

    // Existing task type
    const taskTypes = [
      'Assignment',
      'Quiz',
      'Exam',
      'Project',
      'Reading',
    ];

    _taskType =
        taskTypes.contains(widget.taskType)
            ? widget.taskType
            : 'Assignment';

    _selectedDate = widget.dueDate;

    _selectedCourseId = widget.courseId;

    _selectedCourseName = widget.courseName;
  _isRecurring = widget.recurrenceWeeks > 0;

    if (widget.reminderDateTime != null) {
      _selectedReminderTime = TimeOfDay(
        hour: widget.reminderDateTime!.hour,
        minute: widget.reminderDateTime!.minute,
      );
    }
  }

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

    final initialDate =
        _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isBefore(now)
              ? now
              : initialDate,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(
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
  // FORMAT DATE
  // =========================================================

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // =========================================================
  // FORMAT TIME
  // =========================================================

  String _formatTime(TimeOfDay time) {
    final hour =
        time.hourOfPeriod == 0
            ? 12
            : time.hourOfPeriod;

    final minute = time.minute
        .toString()
        .padLeft(2, '0');

    final period =
        time.period == DayPeriod.am
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
  // TASK TYPE ICON
  // =========================================================

  IconData _taskTypeIcon(String type) {
    switch (type) {
      case 'Assignment':
        return Icons.assignment_outlined;

      case 'Quiz':
        return Icons.quiz_outlined;

      case 'Exam':
        return Icons.school_outlined;

      case 'Project':
        return Icons.folder_outlined;

      case 'Reading':
        return Icons.menu_book_outlined;

      default:
        return Icons.task_outlined;
    }
  }

  // =========================================================
  // TASK TYPE COLOR
  // =========================================================

  Color _taskTypeColor(String type) {
    switch (type) {
      case 'Assignment':
        return Colors.blue;

      case 'Quiz':
        return Colors.purple;

      case 'Exam':
        return Colors.red;

      case 'Project':
        return Colors.orange;

      case 'Reading':
        return Colors.green;

      default:
        return Theme.of(context)
            .colorScheme
            .primary;
    }
  }

  // =========================================================
  // SELECT COURSE
  // =========================================================

  void _selectCourse(
    String courseId,
    String courseName,
  ) {
    setState(() {
      _selectedCourseId = courseId;
      _selectedCourseName = courseName;
    });
  }

  // =========================================================
  // REMOVE COURSE
  // =========================================================

  void _removeCourse() {
    setState(() {
      _selectedCourseId = null;
      _selectedCourseName = null;
    });
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _save() async {
    final title =
        _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Task title cannot be empty.',
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update task. Please try again.',
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
      title: const Text('Edit Task'),

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
              decoration:
                  const InputDecoration(
                labelText: 'Task title',
                hintText: 'Enter task title',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // TASK TYPE
            // =================================================

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Task Type',
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

            DropdownButtonFormField<String>(
              initialValue: _taskType,

              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.category_outlined,
                ),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Assignment',
                  child: Text('Assignment'),
                ),
                DropdownMenuItem(
                  value: 'Quiz',
                  child: Text('Quiz'),
                ),
                DropdownMenuItem(
                  value: 'Exam',
                  child: Text('Exam'),
                ),
                DropdownMenuItem(
                  value: 'Project',
                  child: Text('Project'),
                ),
                DropdownMenuItem(
                  value: 'Reading',
                  child: Text('Reading'),
                ),
              ],

              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _taskType = value;
                      });
                    },
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  _taskTypeIcon(_taskType),
                  size: 16,
                  color:
                      _taskTypeColor(_taskType),
                ),
                const SizedBox(width: 6),
                Text(
                  _taskType,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        _taskTypeColor(
                      _taskType,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =================================================
            // COURSE / SUBJECT
            // =================================================

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Course / Subject',
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

            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestoreService
                      .getCourses(),

              builder:
                  (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load courses.',
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox(
                    height: 55,
                    child: Center(
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final courses =
                    snapshot.data?.docs ?? [];

                final currentCourseExists =
                    _selectedCourseId !=
                            null &&
                        courses.any(
                          (doc) =>
                              doc.id ==
                              _selectedCourseId,
                        );

                final dropdownValue =
                    currentCourseExists
                        ? _selectedCourseId
                        : null;

                return Column(
                  children: [
                    DropdownButtonFormField<
                        String>(
                      isExpanded: true,

                      initialValue:
                          dropdownValue,

                      decoration:
                          const InputDecoration(
                        border:
                            OutlineInputBorder(),
                        prefixIcon:
                            Icon(
                          Icons.school_outlined,
                        ),
                      ),

                      hint: const Text(
                        'Select a course',
                      ),

                      items:
                          courses.map((doc) {
                        final data =
                            doc.data()
                                as Map<
                                    String,
                                    dynamic>;

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

                        return DropdownMenuItem<
                            String>(
                          value: doc.id,
                          child: Text(
                            displayName,
                            overflow:
                                TextOverflow
                                    .ellipsis,
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
                                    doc.id ==
                                    value,
                              );

                              final data =
                                  selected.data()
                                      as Map<
                                          String,
                                          dynamic>;

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

                              _selectCourse(
                                value,
                                displayName,
                              );
                            },
                    ),

                    if (_selectedCourseName !=
                            null &&
                        _selectedCourseName!
                            .isNotEmpty) ...[
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(
                            Icons
                                .school_outlined,
                            size: 16,
                            color:
                                colorScheme
                                    .primary,
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              'Current: $_selectedCourseName',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    colorScheme
                                        .primary,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),

                          TextButton(
                            onPressed:
                                _saving
                                    ? null
                                    : _removeCourse,
                            child:
                                const Text(
                              'Remove',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // =================================================
            // DUE DATE
            // =================================================

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Due Date',
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
                        : _pickDate,
                icon: const Icon(
                  Icons.calendar_today,
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
              const SizedBox(height: 5),

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
              const SizedBox(height: 10),

              Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  'Reminder',
                  style:
                      Theme.of(context)
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
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _pickReminderTime,

                  icon: Icon(
                    _selectedReminderTime ==
                            null
                        ? Icons
                            .notifications_off_outlined
                        : Icons
                            .notifications_active_outlined,
                  ),

                  label: Text(
                    _selectedReminderTime ==
                            null
                        ? 'No reminder'
                        : 'Remind me at '
                            '${_formatTime(
                            _selectedReminderTime!,
                          )}',
                  ),
                ),
              ),

              if (_selectedReminderTime !=
                  null) ...[
                const SizedBox(height: 4),

                TextButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _removeReminder,
                  icon: const Icon(
                    Icons
                        .notifications_off_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Remove Reminder',
                  ),
                ),
              ],

              const SizedBox(height: 4),

              Text(
                _selectedReminderTime == null
                    ? 'No notification will be scheduled.'
                    : 'You will receive a notification at this time on the due date.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme
                      .onSurfaceVariant,
                ),
              ),

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

            const SizedBox(height: 15),

            // =================================================
            // PRIORITY
            // =================================================

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Priority',
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

            DropdownButtonFormField<String>(
              initialValue: _priority,

              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Low',
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: Colors.green,
                      ),
                      SizedBox(width: 8),
                      Text('Low'),
                    ],
                  ),
                ),

                DropdownMenuItem(
                  value: 'Medium',
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Text('Medium'),
                    ],
                  ),
                ),

                DropdownMenuItem(
                  value: 'High',
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text('High'),
                    ],
                  ),
                ),
              ],

              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

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
                  size: 12,
                  color:
                      _priorityColor(
                    _priority,
                  ),
                ),

                const SizedBox(width: 6),

                Text(
                  '$_priority Priority',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme
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
          onPressed:
              _saving
                  ? null
                  : () {
                      Navigator.pop(
                        context,
                      );
                    },
          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed:
              _saving ? null : _save,
          child:
              _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                    ),
        ),
      ],
    );
  }
}