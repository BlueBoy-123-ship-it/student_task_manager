import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'edit_task_dialog.dart';

class TaskTile extends StatelessWidget {
  final String title;
  final String courseId;
  final String courseTitle;
  final String taskType;

  final bool completed;
  final Timestamp? dueDate;
  final Timestamp? reminderDateTime;
  final int recurrenceWeeks;
  final String priority;

  final VoidCallback onDelete;
  final ValueChanged<bool?> onChanged;

  final Future<void> Function(
    String title,
    DateTime? dueDate,
    String priority,
    DateTime? reminderDateTime,
    String? courseId,
    String? courseName,
    String taskType,
    int recurrenceWeeks,
  ) onEdit;

  const TaskTile({
    super.key,
    required this.title,
    required this.courseId,
    required this.courseTitle,
    required this.taskType,
    required this.completed,
    required this.dueDate,
    required this.reminderDateTime,
    required this.recurrenceWeeks,
    required this.priority,
    required this.onDelete,
    required this.onChanged,
    required this.onEdit,
  });

  // =========================================================
  // DATE FORMAT
  // =========================================================

  String formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();

    return '${date.day}/${date.month}/${date.year}';
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

  Color _taskTypeColor(
    BuildContext context,
    String type,
  ) {
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
        return Theme.of(context).colorScheme.primary;
    }
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
  // OVERDUE
  // =========================================================

  bool get isOverdue {
    if (completed || dueDate == null) {
      return false;
    }

    final now = DateTime.now();
    final due = dueDate!.toDate();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dueDay = DateTime(
      due.year,
      due.month,
      due.day,
    );

    return dueDay.isBefore(today);
  }

  // =========================================================
  // DUE SOON
  // =========================================================

  bool get isDueSoon {
    if (completed ||
        dueDate == null ||
        isOverdue) {
      return false;
    }

    final now = DateTime.now();
    final due = dueDate!.toDate();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dueDay = DateTime(
      due.year,
      due.month,
      due.day,
    );

    if (dueDay == today) {
      return true;
    }

    final tomorrow =
        today.add(const Duration(days: 1));

    return dueDay == tomorrow;
  }

  // =========================================================
  // REMINDER STATUS
  // =========================================================

  bool get reminderScheduled {
    if (completed ||
        reminderDateTime == null) {
      return false;
    }

    return reminderDateTime!
        .toDate()
        .isAfter(DateTime.now());
  }

  // =========================================================
  // EDIT DIALOG
  // =========================================================

  Future<void> _showEditDialog(
    BuildContext context,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return EditTaskDialog(
          title: title,

          courseId:
              courseId.isEmpty
                  ? null
                  : courseId,

          courseName:
              courseTitle.isEmpty
                  ? null
                  : courseTitle,

          taskType: taskType,

          dueDate:
              dueDate?.toDate(),

          priority: priority,

          reminderDateTime:
              reminderDateTime?.toDate(),

            recurrenceWeeks: recurrenceWeeks,

          onSave: (
            newTitle,
            newDueDate,
            newPriority,
            newReminderDateTime,
            newCourseId,
            newCourseName,
            newTaskType,
            newRecurrenceWeeks,
          ) async {
            await onEdit(
              newTitle,
              newDueDate,
              newPriority,
              newReminderDateTime,
              newCourseId,
              newCourseName,
              newTaskType,
              newRecurrenceWeeks,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final priorityColor =
        _priorityColor(priority);

    final colorScheme =
        Theme.of(context).colorScheme;

    final typeColor =
        _taskTypeColor(
      context,
      taskType,
    );

    Color dueDateColor =
        colorScheme.onSurfaceVariant;

    if (isOverdue) {
      dueDateColor = Colors.red;
    } else if (isDueSoon) {
      dueDateColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // =================================================
            // CHECKBOX
            // =================================================

            Padding(
              padding:
                  const EdgeInsets.only(top: 2),
              child: Checkbox(
                value: completed,
                onChanged: onChanged,
                activeColor:
                    const Color(0xFF2563EB),
              ),
            ),

            const SizedBox(width: 6),

            // =================================================
            // TASK INFORMATION
            // =================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // COURSE
                  if (courseTitle.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color:
                              colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            courseTitle,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  colorScheme.primary,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),
                  ],

                  // TITLE
                  Text(
                    title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w600,
                      decoration: completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: completed
                          ? colorScheme
                              .onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // TASK TYPE
                  if (taskType.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color: typeColor
                            .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                          color: typeColor
                              .withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            _taskTypeIcon(
                              taskType,
                            ),
                            size: 14,
                            color: typeColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            taskType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (recurrenceWeeks > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 15,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Repeats weekly until completed',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // DUE DATE
                  if (dueDate != null) ...[
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Icon(
                          isOverdue
                              ? Icons
                                  .warning_amber_rounded
                              : isDueSoon
                                  ? Icons
                                      .schedule_outlined
                                  : Icons
                                      .calendar_today_outlined,
                          size: 14,
                          color: dueDateColor,
                        ),

                        const SizedBox(width: 5),

                        Flexible(
                          child: Text(
                            isOverdue
                                ? 'Overdue • Due: ${formatDate(dueDate!)}'
                                : isDueSoon
                                    ? 'Due soon • ${formatDate(dueDate!)}'
                                    : 'Due: ${formatDate(dueDate!)}',
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dueDateColor,
                              fontSize: 13,
                              fontWeight:
                                  isOverdue ||
                                          isDueSoon
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // PRIORITY
                  if (priority.isNotEmpty) ...[
                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: priorityColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$priority Priority',
                          style: TextStyle(
                            color:
                                priorityColor,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 5),

                  // REMINDER
                  Row(
                    children: [
                      Icon(
                        reminderScheduled
                            ? Icons
                                .notifications_active_outlined
                            : Icons
                                .notifications_off_outlined,
                        size: 14,
                        color: reminderScheduled
                            ? const Color(
                                0xFF2563EB,
                              )
                            : colorScheme
                                .onSurfaceVariant,
                      ),

                      const SizedBox(width: 5),

                      Flexible(
                        child: Text(
                          reminderScheduled
                              ? 'Reminder scheduled'
                              : 'No reminder',
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: reminderScheduled
                                ? const Color(
                                    0xFF2563EB,
                                  )
                                : colorScheme
                                    .onSurfaceVariant,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // =================================================
            // ACTION BUTTONS
            // =================================================

            Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit task',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color:
                        Color(0xFF2563EB),
                  ),
                  onPressed: () =>
                      _showEditDialog(context),
                ),

                IconButton(
                  tooltip: 'Delete task',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}