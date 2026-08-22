import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:student_task_manager/services/firestore_service.dart';
import 'package:student_task_manager/widgets/task_tile.dart';

class TaskFilterSection extends StatefulWidget {
  final List docs;
  final String taskType;

  const TaskFilterSection({
    super.key,
    required this.docs,
    this.taskType = '',
  });

  @override
  State<TaskFilterSection> createState() =>
      _TaskFilterSectionState();
}

class _TaskFilterSectionState
    extends State<TaskFilterSection> {
  String _selectedFilter = 'All';
  String _selectedPriority = 'All';
  String _selectedSort = 'Newest';

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  // =========================================================
  // OVERDUE
  // =========================================================

  bool _isOverdue(
    Map<String, dynamic> data,
  ) {
    final recurrenceWeeks =
        (data['recurrenceWeeks'] as num?)?.toInt() ?? 0;

    if (data['completed'] == true || recurrenceWeeks > 0) {
      return false;
    }

    final dueDate = data['dueDate'];

    if (dueDate is! Timestamp) {
      return false;
    }

    final date = dueDate.toDate();

    final endOfDueDate = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    );

    return DateTime.now().isAfter(endOfDueDate);
  }

  // =========================================================
  // FILTER + SEARCH + SORT
  // =========================================================

  List get filteredTasks {
    List tasks = List.from(widget.docs);

    // ---------------------------------------------------------
    // STATUS FILTER
    // ---------------------------------------------------------

    if (_selectedFilter == 'Pending') {
      tasks = tasks.where((doc) {
        final data =
            doc.data() as Map<String, dynamic>;

        return data['completed'] != true;
      }).toList();
    }

    if (_selectedFilter == 'Completed') {
      tasks = tasks.where((doc) {
        final data =
            doc.data() as Map<String, dynamic>;

        return data['completed'] == true;
      }).toList();
    }

    if (_selectedFilter == 'Overdue') {
      tasks = tasks.where((doc) {
        final data =
            doc.data() as Map<String, dynamic>;

        return _isOverdue(data);
      }).toList();
    }

    // ---------------------------------------------------------
    // PRIORITY FILTER
    // ---------------------------------------------------------

    if (_selectedPriority != 'All') {
      tasks = tasks.where((doc) {
        final data =
            doc.data() as Map<String, dynamic>;

        final priority =
            data['priority']?.toString() ?? 'Medium';

        return priority == _selectedPriority;
      }).toList();
    }

    // ---------------------------------------------------------
    // SEARCH
    // ---------------------------------------------------------

    if (_searchQuery.trim().isNotEmpty) {
      final query =
          _searchQuery.trim().toLowerCase();

      tasks = tasks.where((doc) {
        final data =
            doc.data() as Map<String, dynamic>;

        final title =
            data['title']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final courseName =
            data['courseName']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final taskType =
            data['taskType']
                    ?.toString()
                    .toLowerCase() ??
                '';

        return title.contains(query) ||
            courseName.contains(query) ||
            taskType.contains(query);
      }).toList();
    }

    // ---------------------------------------------------------
    // SORT
    // ---------------------------------------------------------

    tasks.sort((a, b) {
      final dataA =
          a.data() as Map<String, dynamic>;

      final dataB =
          b.data() as Map<String, dynamic>;

      // NEWEST
      if (_selectedSort == 'Newest') {
        final createdA =
            dataA['createdAt'] is Timestamp
                ? dataA['createdAt'] as Timestamp
                : null;

        final createdB =
            dataB['createdAt'] is Timestamp
                ? dataB['createdAt'] as Timestamp
                : null;

        if (createdA == null &&
            createdB == null) {
          return 0;
        }

        if (createdA == null) {
          return 1;
        }

        if (createdB == null) {
          return -1;
        }

        return createdB.compareTo(createdA);
      }

      // DUE DATE
      if (_selectedSort == 'Due date') {
        final dueA =
            dataA['dueDate'] is Timestamp
                ? dataA['dueDate'] as Timestamp
                : null;

        final dueB =
            dataB['dueDate'] is Timestamp
                ? dataB['dueDate'] as Timestamp
                : null;

        if (dueA == null &&
            dueB == null) {
          return 0;
        }

        if (dueA == null) {
          return 1;
        }

        if (dueB == null) {
          return -1;
        }

        return dueA.compareTo(dueB);
      }

      // PRIORITY
      if (_selectedSort == 'Priority') {
        final priorityA =
            dataA['priority']
                    ?.toString() ??
                'Medium';

        final priorityB =
            dataB['priority']
                    ?.toString() ??
                'Medium';

        const priorityOrder = {
          'High': 1,
          'Medium': 2,
          'Low': 3,
        };

        final valueA =
            priorityOrder[priorityA] ?? 2;

        final valueB =
            priorityOrder[priorityB] ?? 2;

        return valueA.compareTo(valueB);
      }

      // A-Z
      if (_selectedSort == 'A-Z') {
        final titleA =
            dataA['title']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final titleB =
            dataB['title']
                    ?.toString()
                    .toLowerCase() ??
                '';

        return titleA.compareTo(titleB);
      }

      return 0;
    });

    return tasks;
  }

  // =========================================================
  // FILTER BUTTON
  // =========================================================

  Widget filterButton(String filter) {
    final selected =
        _selectedFilter == filter;

    final colorScheme =
        Theme.of(context).colorScheme;

    Color selectedColor =
        colorScheme.primary;

    if (filter == 'Overdue') {
      selectedColor = Colors.red;
    }

    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Text(
            filter,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : colorScheme
                      .onSurfaceVariant,
              fontWeight: selected
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // PRIORITY BUTTON
  // =========================================================

  Widget priorityButton(
    String priority,
    Color color,
  ) {
    final selected =
        _selectedPriority == priority;

    final colorScheme =
        Theme.of(context).colorScheme;

    return InkWell(
      borderRadius:
          BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedPriority = priority;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color
              : color.withValues(
                  alpha: 0.10,
                ),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color
                : color.withValues(
                    alpha: 0.25,
                  ),
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            if (priority != 'All')
              Icon(
                Icons.circle,
                size: 9,
                color: selected
                    ? Colors.white
                    : color,
              ),
            if (priority != 'All')
              const SizedBox(width: 6),
            Text(
              priority,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : colorScheme.onSurface,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SORT BUTTON
  // =========================================================

  Widget sortButton() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      initialValue: _selectedSort,

      onSelected: (value) {
        setState(() {
          _selectedSort = value;
        });
      },

      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: 'Newest',
            child: Text('Newest first'),
          ),
          PopupMenuItem(
            value: 'Due date',
            child: Text('Due date'),
          ),
          PopupMenuItem(
            value: 'Priority',
            child: Text('Priority'),
          ),
          PopupMenuItem(
            value: 'A-Z',
            child: Text('A–Z'),
          ),
        ];
      },

      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: colorScheme
              .surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme
                .outline
                .withValues(
              alpha: 0.2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.sort,
              size: 19,
              color:
                  colorScheme.primary,
            ),
            const SizedBox(width: 7),
            Text(
              _selectedSort == 'Newest'
                  ? 'Newest first'
                  : _selectedSort,
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
                color:
                    colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SEARCH BAR
  // =========================================================

  Widget searchBar() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return TextField(
      controller:
          _searchController,

      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },

      decoration: InputDecoration(
        hintText: 'Search tasks...',

        hintStyle: TextStyle(
          color: colorScheme
              .onSurfaceVariant,
        ),

        prefixIcon: Icon(
          Icons.search,
          color: colorScheme
              .onSurfaceVariant,
        ),

        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip:
                        'Clear search',
                    icon:
                        const Icon(
                      Icons.clear,
                    ),
                    onPressed: () {
                      _searchController
                          .clear();

                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,

        filled: true,

        fillColor: colorScheme
            .surfaceContainerHighest,

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              BorderSide.none,
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
                colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // EMPTY MESSAGE
  // =========================================================

  Widget emptyMessage() {
    String title;
    String subtitle;
    IconData icon;

    if (_searchQuery
        .trim()
        .isNotEmpty) {
      title = 'No tasks found.';
      subtitle =
          'Try a different search term.';
      icon = Icons.search_off;
    } else if (_selectedFilter ==
        'Pending') {
      title = 'No pending tasks.';
      subtitle =
          'Great job! You have no pending tasks.';
      icon =
          Icons.check_circle_outline;
    } else if (_selectedFilter ==
        'Completed') {
      title = 'No completed tasks.';
      subtitle =
          'Completed tasks will appear here.';
      icon = Icons.task_alt;
    } else if (_selectedFilter ==
        'Overdue') {
      title = 'No overdue tasks.';
      subtitle =
          'Excellent! You are all caught up.';
      icon =
          Icons.check_circle_outline;
    } else if (_selectedPriority !=
        'All') {
      title =
          'No ${_selectedPriority.toLowerCase()} priority tasks.';
      subtitle =
          'Try another priority filter.';
      icon =
          Icons.flag_outlined;
    } else {
      title = 'No tasks yet.';
      subtitle =
          'Tap the + button to add your first task!';
      icon = Icons.task_alt;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 20,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 55,
            color: Colors.grey,
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final firestoreService =
        FirestoreService();

    final tasks = filteredTasks;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // =====================================================
        // SEARCH
        // =====================================================

        searchBar(),

        const SizedBox(height: 12),

        // =====================================================
        // STATUS
        // =====================================================

        Text(
          'Status',
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 6),

        Container(
          padding:
              const EdgeInsets.all(4),
          decoration:
              BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(
                alpha: 0.2,
              ),
            ),
          ),
          child: Row(
            children: [
              filterButton('All'),
              filterButton('Pending'),
              filterButton('Completed'),
              filterButton('Overdue'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // =====================================================
        // PRIORITY
        // =====================================================

        Text(
          'Priority',
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 6),

        SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: Row(
            children: [
              priorityButton(
                'All',
                Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(width: 8),
              priorityButton(
                'Low',
                Colors.green,
              ),
              const SizedBox(width: 8),
              priorityButton(
                'Medium',
                Colors.orange,
              ),
              const SizedBox(width: 8),
              priorityButton(
                'High',
                Colors.red,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // =====================================================
        // SORT
        // =====================================================

        Row(
          children: [
            Text(
              'Sort by',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const Spacer(),
            sortButton(),
          ],
        ),

        const SizedBox(height: 15),

        // =====================================================
// TASKS
// =====================================================

if (tasks.isEmpty)
  emptyMessage()
else
  ...tasks.map((doc) {
    final data =
        doc.data() as Map<String, dynamic>;

    // -------------------------------------------------
    // BASIC DATA
    // -------------------------------------------------

    final String title =
        data['title']?.toString() ?? '';

    final String taskType =
        data['taskType']?.toString() ??
            widget.taskType;

    final String priority =
        data['priority']?.toString() ??
            'Medium';

    // -------------------------------------------------
    // DATES
    // -------------------------------------------------

    final Timestamp? dueDate =
        data['dueDate'] is Timestamp
            ? data['dueDate'] as Timestamp
            : null;

    final Timestamp? reminderDateTime =
        data['reminderDateTime'] is Timestamp
            ? data['reminderDateTime']
                as Timestamp
            : null;

        final int recurrenceWeeks =
          (data['recurrenceWeeks'] as num?)?.toInt() ?? 0;

    // -------------------------------------------------
    // COURSE
    // -------------------------------------------------

    final String courseId =
        data['courseId']?.toString() ?? '';

    final String courseName =
        data['courseName']?.toString() ?? '';

    // -------------------------------------------------
    // TASK TILE
    // -------------------------------------------------

    return TaskTile(
  title: title,

  courseId: courseId,

  courseTitle: courseName,

  taskType: taskType,

  completed: data['completed'] == true,

  dueDate: dueDate,

  reminderDateTime: reminderDateTime,

  recurrenceWeeks: recurrenceWeeks,

  priority: priority,

  onDelete: () async {
    await firestoreService.deleteTask(doc.id);
  },

  onChanged: (value) async {
    await firestoreService.toggleTask(
      doc.id,
      value ?? false,
    );
  },

  onEdit: (
    newTitle,
    newDueDate,
    newPriority,
    newReminderDateTime,
    newCourseId,
    newCourseName,
    newTaskType,
    newRecurrenceWeeks,
  ) async {
    await firestoreService.updateTask(
      doc.id,
      newTitle,
      newDueDate,
      newPriority,
      newReminderDateTime,

      // IMPORTANT: pass the NEW task type
      taskType: newTaskType,

      courseId: newCourseId,
      courseName: newCourseName,
      recurrenceWeeks: newRecurrenceWeeks,
    );
  },
);
  }),
      ],
    );
  }
}
