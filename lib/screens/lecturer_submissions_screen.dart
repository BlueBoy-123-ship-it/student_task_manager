import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'lecturer_grade_submission_screen.dart';
import 'pdf_viewer_screen.dart';

class LecturerSubmissionsScreen extends StatelessWidget {
  final String assignmentId;
  final String assignmentTitle;
  final String courseName;
  final int totalMarks;

  const LecturerSubmissionsScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.courseName,
    required this.totalMarks,
  });

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Not available';
    final d = value.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _openPdf(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          pdfUrl: url,
          title: title,
          allowDownload: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submissions'),
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
        stream: service.getAssignmentSubmissions(assignmentId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load submissions.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...(snapshot.data?.docs ?? [])];

          docs.sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['submittedAt'];
            final bd = (b.data() as Map<String, dynamic>)['submittedAt'];
            final at = ad is Timestamp ? ad.toDate() : DateTime(1970);
            final bt = bd is Timestamp ? bd.toDate() : DateTime(1970);
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'No students have submitted this assignment yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final student = data['studentName']?.toString() ?? 'Student';
              final matric = data['matricNumber']?.toString() ?? '';
              final status = data['status']?.toString() ?? 'submitted';
              final grade = data['grade'];
              final pdfUrl = data['pdfUrl']?.toString();
              final pdfName = data['pdfFileName']?.toString() ?? 'Submission PDF';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colors.primary.withValues(alpha: .10),
                            child: Icon(Icons.person_outline, color: colors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (matric.isNotEmpty) Text(matric),
                              ],
                            ),
                          ),
                          Chip(label: Text(status)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Submitted: ${_date(data['submittedAt'])}'),
                      if ((data['submissionText']?.toString() ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          data['submissionText'].toString(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (pdfUrl != null && pdfUrl.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openPdf(context, pdfUrl, pdfName),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(
                            'Open $pdfName',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (grade != null)
                            Text(
                              'Grade: $grade/$totalMarks',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LecturerGradeSubmissionScreen(
                                    submissionId: doc.id,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.grading_outlined),
                            label: Text(grade == null ? 'Grade' : 'Edit Grade'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
