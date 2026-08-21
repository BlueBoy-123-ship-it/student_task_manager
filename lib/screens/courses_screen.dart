import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'add_course_screen.dart';
import 'course_students_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final FirestoreService _service = FirestoreService();
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _service.getCurrentUserRole();
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
        final coursesStream = isLecturer
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
          body: StreamBuilder<QuerySnapshot>(
            stream: coursesStream,
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

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: lecturerDocs.length,
                  itemBuilder: (context, index) {
                    final doc = lecturerDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final code = data['code']?.toString() ?? 'Course';
                    final name = data['name']?.toString() ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.school_outlined),
                        ),
                        title: Text(
                          code,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View enrolled students',
                              icon: const Icon(Icons.people_outline),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CourseStudentsScreen(
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
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteCourse(doc.id, code),
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  final enrolledIds = <String>{
                    for (final doc in enrollmentSnapshot.data?.docs ?? const [])
                      (doc.data() as Map<String, dynamic>)['courseId']
                              ?.toString() ??
                          doc.id.split('_').first,
                  };

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final code = data['code']?.toString() ?? 'Course';
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(name),
                          trailing: FilledButton(
                            onPressed: () => enrolled
                                ? _unenroll(doc.id, data)
                                : _enroll(doc.id, data),
                            child: Text(enrolled ? 'Enrolled' : 'Enroll'),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
