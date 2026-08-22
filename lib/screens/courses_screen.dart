import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'add_course_screen.dart';
import 'course_students_screen.dart';
import 'notifications_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  late Future<String> _roleFuture;
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _isSearchPending = false;
  Stream<QuerySnapshot>? _coursesStream;

  @override
  void initState() {
    super.initState();
    _roleFuture = _service.getCurrentUserRole();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _isSearchPending = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
        _isSearchPending = false;
      });
    });
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final code = data['code']?.toString().toLowerCase() ?? '';
    final name = data['name']?.toString().toLowerCase() ?? '';
    return code.contains(query) || name.contains(query);
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          labelText: 'Search by course code or name',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _isSearchPending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _openAddCourseScreen() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddCourseScreen()));
    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Course created successfully.')),
    );
  }

  Future<void> _enroll(String courseId, Map<String, dynamic> data) async {
    try {
      await _service.enrollInCourse(courseId, data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolled in ${data['code'] ?? 'course'}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unenroll(String courseId, Map<String, dynamic> data) async {
    try {
      await _service.unenrollFromCourse(courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course enrollment removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCourse(String courseId, String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text(
          'Delete $code? Assignments already published for it will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteCourse(courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Course deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roleSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Unable to determine account role.\n${roleSnapshot.error}',
              ),
            ),
          );
        }

        final isLecturer = roleSnapshot.data == 'lecturer';
        _coursesStream ??= isLecturer
          ? _service.getLecturerCourses()
          : _service.getAllCourses();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isLecturer ? 'My Courses' : 'Courses',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
              StreamBuilder<QuerySnapshot>(
                stream: _service.getUserNotifications(),
                builder: (context, snapshot) {
                  final unread = (snapshot.data?.docs ?? const []).where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['read'] != true;
                  }).length;

                  return Stack(
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 8,
                          top: 7,
                          child: IgnorePointer(
                            child: CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.red,
                              child: Text(
                                unread > 9 ? '9+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          floatingActionButton: isLecturer
              ? FloatingActionButton.extended(
                  onPressed: _openAddCourseScreen,
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Course'),
                )
              : null,
          body: Column(
            children: [
              _searchField(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _coursesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Unable to load courses.\n\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 80,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                isLecturer
                                    ? 'No courses yet'
                                    : 'No courses available',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isLecturer
                                    ? 'Create your first course so students can enroll in it.'
                                    : 'Courses created by lecturers will appear here.',
                                textAlign: TextAlign.center,
                              ),
                              if (isLecturer) ...[
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _openAddCourseScreen,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Course'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    if (isLecturer) {
                      final lecturerId = _service.currentUser?.uid;
                      final lecturerDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['lecturerId']?.toString() == lecturerId ||
                            data['userId']?.toString() == lecturerId;
                      }).toList();

                      if (lecturerDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 80,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'No courses yet',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Create your first course so students can enroll in it.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _openAddCourseScreen,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Course'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final filteredDocs = lecturerDocs.where((doc) {
                        return _matchesSearch(
                          doc.data() as Map<String, dynamic>,
                        );
                      }).toList();

                      return filteredDocs.isEmpty
                          ? const Center(
                              child: Text('No matching courses found.'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                100,
                              ),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final code =
                                    data['code']?.toString() ?? 'Course';
                                final name = data['name']?.toString() ?? '';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.school_outlined),
                                    ),
                                    title: Text(
                                      code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(name),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'View enrolled students',
                                          icon: const Icon(
                                            Icons.people_outline,
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CourseStudentsScreen(
                                                      courseId: doc.id,
                                                      courseCode: code,
                                                      courseName: name,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Delete course',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () =>
                                              _deleteCourse(doc.id, code),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: _service.getMyEnrollments(),
                      builder: (context, enrollmentSnapshot) {
                        if (enrollmentSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Unable to load enrollments.\n${enrollmentSnapshot.error}',
                            ),
                          );
                        }
                        if (enrollmentSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final enrolledIds = <String>{
                          for (final doc
                              in enrollmentSnapshot.data?.docs ?? const [])
                            (doc.data() as Map<String, dynamic>)['courseId']
                                    ?.toString() ??
                                doc.id.split('_').first,
                        };

                        final filteredDocs = docs.where((doc) {
                          return _matchesSearch(
                            doc.data() as Map<String, dynamic>,
                          );
                        }).toList();

                        return filteredDocs.isEmpty
                            ? const Center(
                                child: Text('No matching courses found.'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  30,
                                ),
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  final doc = filteredDocs[index];
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final code =
                                      data['code']?.toString() ?? 'Course';
                                  final name = data['name']?.toString() ?? '';
                                  final enrolled = enrolledIds.contains(doc.id);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        child: Icon(Icons.school_outlined),
                                      ),
                                      title: Text(
                                        code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(name),
                                      trailing: FilledButton(
                                        onPressed: () => enrolled
                                            ? _unenroll(doc.id, data)
                                            : _enroll(doc.id, data),
                                        child: Text(
                                          enrolled ? 'Enrolled' : 'Enroll',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
