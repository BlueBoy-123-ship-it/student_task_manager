import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({
    super.key,
  });

  @override
  State<AddCourseScreen> createState() =>
      _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final FirestoreService _firestoreService =
      FirestoreService();

  final TextEditingController _codeController =
      TextEditingController();

  final TextEditingController _nameController =
      TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();

    super.dispose();
  }

  // =========================================================
  // SAVE COURSE
  // =========================================================

  Future<void> _saveCourse() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();

    if (code.isEmpty) {
      _showMessage(
        'Please enter a course code.',
      );
      return;
    }

    if (name.isEmpty) {
      _showMessage(
        'Please enter a course name.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _firestoreService.addCourse(
        code,
        name,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Unable to create course: $e',
      );
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Course',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [
              const SizedBox(height: 20),

              // =================================================
              // ICON
              // =================================================

              Container(
                width: 90,
                height: 90,

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF7C3AED),
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(28),
                ),

                child: const Icon(
                  Icons.school_outlined,
                  size: 45,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              // =================================================
              // TITLE
              // =================================================

              Text(
                'Create a Course',
                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Create a course that students can join '
                'and receive assignments from.',
                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // =================================================
              // COURSE CODE
              // =================================================

              TextField(
                controller: _codeController,
                enabled: !_saving,

                textCapitalization:
                    TextCapitalization.characters,

                textInputAction:
                    TextInputAction.next,

                decoration: InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g. CSC 401',

                  prefixIcon: const Icon(
                    Icons.school_outlined,
                  ),

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
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
              ),

              const SizedBox(height: 18),

              // =================================================
              // COURSE NAME
              // =================================================

              TextField(
                controller: _nameController,
                enabled: !_saving,

                textCapitalization:
                    TextCapitalization.words,

                textInputAction:
                    TextInputAction.done,

                onSubmitted: (_) {
                  if (!_saving) {
                    _saveCourse();
                  }
                },

                decoration: InputDecoration(
                  labelText: 'Course Name',
                  hintText:
                      'e.g. Software Engineering',

                  prefixIcon: const Icon(
                    Icons.menu_book_outlined,
                  ),

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
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
              ),

              const SizedBox(height: 28),

              // =================================================
              // INFORMATION
              // =================================================

              Container(
                padding:
                    const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: colorScheme.primary
                      .withValues(alpha: 0.08),

                  borderRadius:
                      BorderRadius.circular(14),
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons.info_outline,
                      color:
                          colorScheme.primary,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'After creating this course, '
                        'students will be able to join it. '
                        'You can then create assignments '
                        'for students enrolled in the course.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // =================================================
              // CREATE BUTTON
              // =================================================

              SizedBox(
                height: 54,

                child: ElevatedButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _saveCourse,

                  icon: _saving
                      ? const SizedBox(
                          width: 21,
                          height: 21,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.add,
                        ),

                  label: Text(
                    _saving
                        ? 'Creating Course...'
                        : 'Create Course',

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        colorScheme.primary,

                    foregroundColor:
                        Colors.white,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}