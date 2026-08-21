import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'pdf_viewer_screen.dart';

class StudentSubmissionResultScreen extends StatelessWidget {
  final String submissionId;

  const StudentSubmissionResultScreen({
    super.key,
    required this.submissionId,
  });

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Unknown';
    final d = value.toDate();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Result'),
        foregroundColor: Colors.white,
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: service
            .getSubmission(submissionId)
            .asStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load result.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Submission not found.'),
            );
          }

          final d =
              snapshot.data!.data() as Map<String, dynamic>;

          final title =
              d['assignmentTitle']?.toString() ?? 'Assignment';
          final course =
              d['courseName']?.toString() ?? 'Course';
          final grade = d['grade'];
          final total = d['totalMarks'] is num
              ? (d['totalMarks'] as num).toInt()
              : 100;
          final feedback =
              d['feedback']?.toString().trim() ?? '';
          final status =
              d['status']?.toString() ?? 'submitted';
          final answer =
              d['submissionText']?.toString() ?? '';
          final pdfUrl = d['pdfUrl']?.toString();
          final pdfName =
              d['pdfFileName']?.toString() ?? 'Submitted PDF';

          final isGraded = grade is num;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                course,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        isGraded
                            ? Icons.emoji_events_outlined
                            : Icons.hourglass_top,
                        size: 58,
                        color: isGraded
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isGraded
                            ? '$grade / $total'
                            : 'Awaiting Grading',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Status: ${status.toUpperCase()}',
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Submitted: ${_date(d['submittedAt'])}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (pdfUrl != null && pdfUrl.trim().isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      _openPdf(context, pdfUrl, pdfName),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(
                    'Open $pdfName',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              const Text(
                'Your Submission',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    answer.trim().isEmpty
                        ? 'No written submission.'
                        : answer,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
              if (isGraded) ...[
                const SizedBox(height: 20),
                const Text(
                  'Lecturer Feedback',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: cs.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      feedback.isEmpty
                          ? 'No feedback was provided.'
                          : feedback,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
