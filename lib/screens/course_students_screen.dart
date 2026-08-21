import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class CourseStudentsScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseName;

  const CourseStudentsScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
  });

  @override
  State<CourseStudentsScreen> createState() => _CourseStudentsScreenState();
}

class _CourseStudentsScreenState extends State<CourseStudentsScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<List<Map<String, dynamic>>> _loadStudents(
    List<QueryDocumentSnapshot> documents,
  ) async {
    final students = <Map<String, dynamic>>[];

    for (final document in documents) {
      final enrollment = document.data() as Map<String, dynamic>;
      if (enrollment['courseId']?.toString() != widget.courseId) continue;

      final studentId = enrollment['studentId']?.toString() ?? '';
      final profile = studentId.isEmpty
          ? null
          : await _service.getUserProfile(studentId);
      students.add({
        ...enrollment,
        if (profile != null) ...{
          'studentName':
              profile['name']?.toString() ?? enrollment['studentName'],
          'matricNumber':
              profile['matricNumber']?.toString() ?? enrollment['matricNumber'],
        },
      });
    }

    return students;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseCode} Students'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getLecturerEnrollments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load enrolled students.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadStudents(snapshot.data?.docs ?? const []),
            builder: (context, studentsSnapshot) {
              if (studentsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (studentsSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load student profiles.\n${studentsSnapshot.error}',
                  ),
                );
              }

              final query = _searchQuery.trim().toLowerCase();
              final students = (studentsSnapshot.data ?? []).where((data) {
                final name =
                    data['studentName']?.toString().toLowerCase() ?? '';
                final matric =
                    data['matricNumber']?.toString().toLowerCase() ?? '';
                return query.isEmpty ||
                    name.contains(query) ||
                    matric.contains(query);
              }).toList();

              students.sort(
                (a, b) => (a['studentName']?.toString() ?? '')
                    .toLowerCase()
                    .compareTo(
                      (b['studentName']?.toString() ?? '').toLowerCase(),
                    ),
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Search by name or matric number',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${students.length} enrolled student${students.length == 1 ? '' : 's'}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                  Expanded(
                    child: students.isEmpty
                        ? const Center(
                            child: Text('No enrolled students found.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final data = students[index];
                              final name = data['studentName']
                                  ?.toString()
                                  .trim();
                              final matric = data['matricNumber']
                                  ?.toString()
                                  .trim();
                              final studentId =
                                  data['studentId']?.toString() ?? '';
                              final displayName = name == null || name.isEmpty
                                  ? 'Student'
                                  : name;
                              final identity = matric == null || matric.isEmpty
                                  ? 'Student ID: $studentId'
                                  : matric;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: colors.primary.withValues(
                                      alpha: .10,
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: colors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(identity),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
