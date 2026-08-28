import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'courses_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'student_assignments_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/progress_card.dart';
import '../widgets/task_filter_section.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _firestoreService.rescheduleActiveTaskReminders().catchError((error) {
      debugPrint('Task reminder resynchronization failed: $error');
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _userName() {
    final name = _auth.currentUser?.displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'there';
  }

  int _getCompletedTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      return doc.data()['completed'] == true;
    }).length;
  }

  int _getDueTodayTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();

    return docs.where((doc) {
      final rawDueDate = doc.data()['dueDate'];

      if (rawDueDate is! Timestamp) return false;

      final dueDate = rawDueDate.toDate();

      return dueDate.year == now.year &&
          dueDate.month == now.month &&
          dueDate.day == now.day;
    }).length;
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

  Future<void> _showAddTaskDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AddTaskDialog(
          onSave: (
            String title,
            DateTime? dueDate,
            String priority,
            DateTime? reminderDateTime,
            String? courseId,
            String? courseName,
            String taskType,
            int recurrenceWeeks,
          ) async {
            await _firestoreService.addTask(
              title,
              dueDate,
              priority,
              reminderDateTime,
              courseId,
              courseName,
              taskType,
              recurrenceWeeks,
            );
          },
        );
      },
    );
  }

  void _openCourses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CoursesScreen(),
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

  void _openAssignments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentAssignmentsScreen(),
      ),
    );
  }

  Widget _buildDashboard(
    int total,
    int completed,
    int pending,
    int dueToday,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                title: 'Total',
                value: '$total',
                icon: Icons.task,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardCard(
                title: 'Done',
                value: '$completed',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                title: 'Pending',
                value: '$pending',
                icon: Icons.schedule,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardCard(
                title: 'Today',
                value: '$dueToday',
                icon: Icons.today,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Ergobug',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Courses',
            icon: const Icon(Icons.school_outlined),
            onPressed: _openCourses,
          ),
          IconButton(
            tooltip: 'Assignments',
            icon: const Icon(Icons.assignment_outlined),
            onPressed: _openAssignments,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: _openProfile,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getTasks(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 50,
                        color: colors.error,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load your tasks.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              (snapshot.data?.docs ?? const []).map(
                (doc) => doc as QueryDocumentSnapshot<Map<String, dynamic>>,
              ),
            );

            final total = docs.length;
            final completed = _getCompletedTasks(docs);
            final pending = total - completed;
            final dueToday = _getDueTodayTasks(docs);
            final progress =
                total == 0 ? 0.0 : completed / total;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                100,
              ),
              children: [
                Text(
                  '${_greeting()}, ${_userName()}!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Stay productive today 🚀',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 18),
                _buildDashboard(
                  total,
                  completed,
                  pending,
                  dueToday,
                ),
                const SizedBox(height: 18),
                ProgressCard(progress: progress),
                const SizedBox(height: 22),
                Text(
                  "Today's Tasks",
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TaskFilterSection(
                  key: const PageStorageKey(
                    'task-filter-section',
                  ),
                  docs: docs,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
