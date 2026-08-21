import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'student_assignment_details_screen.dart';

class StudentAssignmentsScreen extends StatelessWidget {
  const StudentAssignmentsScreen({super.key});

  String _date(dynamic value) {
    if (value is! Timestamp) return 'No due date';

    final d = value.toDate();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');

    return '$day/$month/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
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
        stream: service.getMyEnrollments(),
        builder: (context, enrollmentSnapshot) {
          if (enrollmentSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your course enrollments.\n\n${enrollmentSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ),
            );
          }
          if (enrollmentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final enrolledIds = <String>{};
          for (final enrollment in enrollmentSnapshot.data?.docs ?? const []) {
            final data = enrollment.data() as Map<String, dynamic>;
            final courseId = data['courseId']?.toString();
            if (courseId != null && courseId.isNotEmpty) enrolledIds.add(courseId);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: service.getStudentAssignments(),
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

          final documents = snapshot.data?.docs ??
              <QueryDocumentSnapshot<Object?>>[];

          final docs = List<QueryDocumentSnapshot<Object?>>.from(documents).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final courseId = data['courseId']?.toString() ?? '';
            return courseId.isEmpty || enrolledIds.contains(courseId);
          }).toList();

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aDue = aData['dueDate'];
            final bDue = bData['dueDate'];

            final aDate =
                aDue is Timestamp ? aDue.toDate() : DateTime(9999);
            final bDate =
                bDue is Timestamp ? bDue.toDate() : DateTime(9999);

            return aDate.compareTo(bDate);
          });

          if (docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(30),
                children: [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.assignment_outlined,
                    size: 75,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No active assignments',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assignments published by lecturers will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final document = docs[index];
                final data =
                    document.data() as Map<String, dynamic>;

                final title =
                    data['title']?.toString() ?? 'Assignment';

                final course =
                    data['courseName']?.toString() ?? 'Course';

                final marks = data['totalMarks'] is num
                    ? (data['totalMarks'] as num).toInt()
                    : 100;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: CircleAvatar(
                      backgroundColor:
                          colors.primary.withValues(alpha: 0.10),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: colors.primary,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '$course\nDue: ${_date(data['dueDate'])} • $marks marks',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudentAssignmentDetailsScreen(
                            assignmentId: document.id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
            },
          );
        },
      ),
    );
  }
}
