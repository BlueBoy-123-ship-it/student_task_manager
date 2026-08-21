import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'create_assignment_screen.dart';
import 'courses_screen.dart';
import 'lecturer_submissions_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class LecturerHomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const LecturerHomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  final FirestoreService _service = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortOrder = 'Newest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤';
    return 'Good Evening 🌙';
  }

  String _lecturerName() {
    final name = _auth.currentUser?.displayName?.trim();
    return name == null || name.isEmpty ? 'Lecturer' : name;
  }

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
      (_) => false,
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  Future<void> _createAssignment() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()),
    );

    if (!mounted || created != true) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Assignment created successfully.'),
          backgroundColor: Colors.green,
        ),
      );
  }

  int _marks(Map<String, dynamic> data) {
    final value = data['totalMarks'];
    return value is num && value > 0 ? value.toInt() : 100;
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return 'No due date';

    final d = value.toDate();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _status(dynamic value) {
    if (value is! Timestamp) return 'No due date';

    final due = value.toDate();
    final now = DateTime.now();

    if (due.isBefore(now)) return 'Overdue';

    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  Color _statusColor(BuildContext context, String status) {
    final colors = Theme.of(context).colorScheme;

    if (status == 'Overdue') return colors.error;
    if (status == 'Due today') return Colors.orange;
    if (status == 'Due tomorrow') return Colors.deepOrange;

    return colors.primary;
  }

  Future<void> _toggleAssignmentStatus(
    String assignmentId,
    String currentStatus,
  ) async {
    final nextStatus = currentStatus == 'completed' ? 'active' : 'completed';
    try {
      await _service.updateAssignmentStatus(
        assignmentId: assignmentId,
        status: nextStatus,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openSubmissions(
    Map<String, dynamic> data,
    String assignmentId,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LecturerSubmissionsScreen(
          assignmentId: assignmentId,
          assignmentTitle: data['title']?.toString() ?? 'Assignment',
          courseName: data['courseName']?.toString() ?? 'Course',
          totalMarks: _marks(data),
        ),
      ),
    );
  }

  Future<void> _deleteAssignment(String assignmentId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: Text('Delete "$title"? Existing submissions will remain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteAssignment(assignmentId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assignmentCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final title = data['title']?.toString() ?? 'Untitled Assignment';
    final course = data['courseName']?.toString() ?? 'Course';
    final description = data['description']?.toString() ?? '';
    final marks = _marks(data);
    final assignmentStatus = data['status']?.toString() == 'completed'
        ? 'completed'
        : 'active';
    final status = assignmentStatus == 'completed'
        ? 'Completed'
        : _status(data['dueDate']);
    final statusColor = assignmentStatus == 'completed'
        ? Colors.green
        : _statusColor(context, status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    course,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                decoration: assignmentStatus == 'completed'
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16),
                    const SizedBox(width: 5),
                    Text(_date(data['dueDate'])),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grade_outlined, size: 17),
                    const SizedBox(width: 5),
                    Text('$marks marks'),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _openSubmissions(data, doc.id),
                  icon: const Icon(Icons.people_outline, size: 17),
                  label: const Text('View Submissions'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteAssignment(doc.id, title);
                    }
                    if (value == 'toggle-status') {
                      _toggleAssignmentStatus(doc.id, assignmentStatus);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle-status',
                      child: Text(
                        assignmentStatus == 'completed'
                            ? 'Mark as Active'
                            : 'Mark as Completed',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Assignment'),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
          'Ergobug',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'My Courses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoursesScreen()),
              );
            },
            icon: const Icon(Icons.school_outlined),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAssignment,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Assignment'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getLecturerAssignments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load assignments.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignments = (snapshot.data?.docs ?? const [])
              .map((doc) => doc as QueryDocumentSnapshot<Map<String, dynamic>>)
              .toList();

          assignments.sort((a, b) {
            final ad = a.data()['createdAt'];
            final bd = b.data()['createdAt'];

            final at = ad is Timestamp ? ad.toDate() : DateTime(1970);
            final bt = bd is Timestamp ? bd.toDate() : DateTime(1970);

            return bt.compareTo(at);
          });

          final active = assignments.where((doc) {
            return doc.data()['status'] == 'active';
          }).length;

          final visibleAssignments = assignments.where((doc) {
            final data = doc.data();
            final status = data['status']?.toString() == 'completed'
                ? 'completed'
                : 'active';
            final query = _searchQuery.trim().toLowerCase();
            final title = data['title']?.toString().toLowerCase() ?? '';
            final course = data['courseName']?.toString().toLowerCase() ?? '';
            return (_statusFilter == 'All' || status == _statusFilter) &&
                (query.isEmpty ||
                    title.contains(query) ||
                    course.contains(query));
          }).toList();

          visibleAssignments.sort((a, b) {
            final aData = a.data();
            final bData = b.data();
            if (_sortOrder == 'Title') {
              return (aData['title']?.toString() ?? '').toLowerCase().compareTo(
                (bData['title']?.toString() ?? '').toLowerCase(),
              );
            }
            final aValue = _sortOrder == 'Due date'
                ? aData['dueDate']
                : aData['createdAt'];
            final bValue = _sortOrder == 'Due date'
                ? bData['dueDate']
                : bData['createdAt'];
            final aDate = aValue is Timestamp
                ? aValue.toDate()
                : DateTime(1970);
            final bDate = bValue is Timestamp
                ? bValue.toDate()
                : DateTime(1970);
            return _sortOrder == 'Due date'
                ? aDate.compareTo(bDate)
                : bDate.compareTo(aDate);
          });

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
              children: [
                Text(
                  '${_greeting()}, ${_lecturerName()}!',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Create assignments, view submissions, grade students and return results.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _stat(
                      context,
                      'Assignments',
                      '${assignments.length}',
                      Icons.assignment_outlined,
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _stat(
                      context,
                      'Active',
                      '$active',
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'My Assignments',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    labelText: 'Search assignments',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value ?? 'All'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _sortOrder,
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Newest',
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: 'Due date',
                            child: Text('Due date'),
                          ),
                          DropdownMenuItem(
                            value: 'Title',
                            child: Text('Title'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _sortOrder = value ?? 'Newest'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visibleAssignments.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 60,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No matching assignments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            assignments.isEmpty
                                ? 'Tap "Create Assignment" below to publish your first assignment.'
                                : 'Try changing the search or status filter.',
                            textAlign: TextAlign.center,
                          ),
                          if (assignments.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _createAssignment,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Assignment'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                for (final doc in visibleAssignments)
                  _assignmentCard(context, doc),
              ],
            ),
          );
        },
      ),
    );
  }
}
