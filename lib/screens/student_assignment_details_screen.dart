import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/pdf_storage_service.dart';
import 'pdf_viewer_screen.dart';
import 'student_submission_result_screen.dart';

class StudentAssignmentDetailsScreen extends StatefulWidget {
  final String assignmentId;

  const StudentAssignmentDetailsScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<StudentAssignmentDetailsScreen> createState() =>
      _StudentAssignmentDetailsScreenState();
}

class _StudentAssignmentDetailsScreenState
    extends State<StudentAssignmentDetailsScreen> {
  final FirestoreService _service = FirestoreService();
  final PdfStorageService _pdfStorage = PdfStorageService();
  final TextEditingController _submissionController = TextEditingController();

  bool _loading = false;
  PlatformFile? _selectedPdf;

  @override
  void dispose() {
    _submissionController.dispose();
    super.dispose();
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Unknown';
    final d = value.toDate();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    if (file.path == null) {
      _message('Unable to access the selected PDF.', true);
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      _message('PDF must be 10 MB or smaller.', true);
      return;
    }

    setState(() => _selectedPdf = file);
  }

  void _openPdf(String url, String title) {
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

  Future<void> _submit(Map<String, dynamic> assignment) async {
    if (_loading) return;

    final text = _submissionController.text.trim();

    if (text.isEmpty && _selectedPdf == null) {
      _message('Write a submission or attach a PDF.', true);
      return;
    }

    setState(() => _loading = true);

    String? uploadedPath;

    try {
      Map<String, String>? upload;

      if (_selectedPdf != null) {
        upload = await _pdfStorage.uploadSubmissionPdf(
          assignmentId: widget.assignmentId,
          filePath: _selectedPdf!.path!,
          fileName: _selectedPdf!.name,
        );

        uploadedPath = upload['path'];
      }

      final existing =
          await _service.getStudentSubmission(widget.assignmentId);

      final oldPath = existing.docs.isNotEmpty
          ? (existing.docs.first.data()
                  as Map<String, dynamic>)['pdfPath']
              ?.toString()
          : null;

      await _service.submitAssignment(
        assignmentId: widget.assignmentId,
        assignmentTitle:
            assignment['title']?.toString() ?? 'Assignment',
        courseId: assignment['courseId']?.toString() ?? '',
        courseName:
            assignment['courseName']?.toString() ?? 'Course',
        submissionText: text,
        pdfUrl: upload?['url'],
        pdfPath: upload?['path'],
        pdfFileName: upload?['name'],
      );

      if (upload != null &&
          oldPath != null &&
          oldPath.isNotEmpty &&
          oldPath != uploadedPath) {
        await _pdfStorage.deleteFile(oldPath);
      }

      if (!mounted) return;

      _submissionController.clear();

      setState(() {
        _selectedPdf = null;
      });

      _message('Assignment submitted successfully.');
    } catch (e) {
      if (mounted) {
        _message(
          e.toString().replaceFirst('Exception: ', ''),
          true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String text, [bool error = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  Widget _submissionStatusCard(
    BuildContext context,
    QueryDocumentSnapshot? submission,
  ) {
    final colors = Theme.of(context).colorScheme;

    if (submission == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.pending_actions, color: colors.onSurfaceVariant),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Not submitted yet',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = submission.data() as Map<String, dynamic>;
    final status = data['status']?.toString() ?? 'submitted';
    final grade = data['grade'];
    final totalMarks = data['totalMarks'] is num
        ? (data['totalMarks'] as num).toInt()
        : 100;
    final feedback = data['feedback']?.toString().trim() ?? '';
    final pdfUrl = data['pdfUrl']?.toString();
    final pdfName =
        data['pdfFileName']?.toString() ?? 'Submitted PDF';

    final isGraded = grade is num;
    final isReturned = status == 'returned';

    final Color statusColor;
    final IconData statusIcon;

    if (isReturned) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isGraded) {
      statusColor = Colors.green;
      statusIcon = Icons.grading;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isReturned
                        ? 'Returned by lecturer'
                        : isGraded
                            ? 'Graded'
                            : 'Submitted — awaiting grading',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Submission status: ${status.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Submitted: ${_date(data['submittedAt'])}'),
            if (isGraded) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR GRADE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${grade.toInt()} / $totalMarks',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Lecturer Feedback',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  feedback.isEmpty
                      ? 'No feedback was provided.'
                      : feedback,
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ],
            if (pdfUrl != null && pdfUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _openPdf(pdfUrl, pdfName),
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  'Open $pdfName',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (isGraded) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentSubmissionResultScreen(
                          submissionId: submission.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Full Result'),
                ),
              ),
            ],
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
        title: const Text('Assignment Details'),
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
      body: FutureBuilder<DocumentSnapshot>(
        future: _service.getAssignment(widget.assignmentId),
        builder: (context, assignmentSnapshot) {
          if (assignmentSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (assignmentSnapshot.hasError ||
              !assignmentSnapshot.hasData ||
              !assignmentSnapshot.data!.exists) {
            return Center(
              child: Text(
                'Unable to load this assignment.',
                style: TextStyle(color: colors.error),
              ),
            );
          }

          final assignment =
              assignmentSnapshot.data!.data()
                  as Map<String, dynamic>;

          final title =
              assignment['title']?.toString() ?? 'Assignment';
          final course =
              assignment['courseName']?.toString() ?? 'Course';
          final description =
              assignment['description']?.toString() ?? '';
          final marks = assignment['totalMarks'] is num
              ? (assignment['totalMarks'] as num).toInt()
              : 100;
          final attachmentUrl =
              assignment['attachmentUrl']?.toString();
          final attachmentName =
              assignment['attachmentName']?.toString() ??
                  'Assignment PDF';

          return StreamBuilder<QuerySnapshot>(
            stream: _service.getStudentSubmissions(),
            builder: (context, submissionSnapshot) {
              QueryDocumentSnapshot? submission;

              if (submissionSnapshot.hasData) {
                for (final doc in submissionSnapshot.data!.docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  if (d['assignmentId']?.toString() ==
                      widget.assignmentId) {
                    submission = doc;
                    break;
                  }
                }
              }

              final submissionData = submission?.data()
                  as Map<String, dynamic>?;
              final hasSubmission = submission != null;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  40,
                ),
                children: [
                  Text(
                    course,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Due: ${_date(assignment['dueDate'])}',
                          ),
                          const SizedBox(height: 6),
                          Text('Total marks: $marks'),
                          const SizedBox(height: 16),
                          const Text(
                            'Instructions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description.isEmpty
                                ? 'No additional instructions.'
                                : description,
                          ),
                          if (attachmentUrl != null &&
                              attachmentUrl.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openPdf(attachmentUrl, attachmentName),
                              icon: const Icon(
                                Icons.picture_as_pdf,
                              ),
                              label: Text(attachmentName),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // LIVE RESULT/STATUS SECTION
                  const Text(
                    'Submission Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _submissionStatusCard(
                    context,
                    submission,
                  ),

                  const SizedBox(height: 22),

                  // Do not ask students to submit again if their
                  // submission has already been graded/returned.
                  if (!hasSubmission ||
                      submissionData?['status'] == 'submitted') ...[
                    const Text(
                      'Your Submission',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _submissionController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Submission message',
                        hintText:
                            'Add a short note about your submission...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading:
                            const Icon(Icons.picture_as_pdf),
                        title: Text(
                          _selectedPdf?.name ??
                              'No PDF selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: _selectedPdf == null
                            ? const Text(
                                'Attach your completed assignment as PDF.',
                              )
                            : Text(
                                '${(_selectedPdf!.size / 1024).toStringAsFixed(1)} KB',
                              ),
                        trailing: IconButton(
                          onPressed:
                              _loading ? null : _pickPdf,
                          icon: const Icon(Icons.attach_file),
                          tooltip: 'Choose PDF',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            _loading ? null : () => _submit(assignment),
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _loading
                              ? 'Uploading & submitting...'
                              : hasSubmission
                                  ? 'Resubmit Assignment'
                                  : 'Submit Assignment',
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
