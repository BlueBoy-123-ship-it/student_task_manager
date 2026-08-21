import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PdfStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _safeName(String fileName) {
    final name = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (!name.toLowerCase().endsWith('.pdf')) {
      throw Exception('Only PDF files are allowed.');
    }
    return name;
  }

  void _validateFile(String filePath, String fileName) {
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      throw Exception('Only PDF files are allowed.');
    }
    final file = File(filePath);
    if (!file.existsSync()) throw Exception('The selected PDF could not be found.');
    final size = file.lengthSync();
    if (size > 10 * 1024 * 1024) throw Exception('PDF must be 10 MB or smaller.');
  }

  Future<Map<String, String>> uploadAssignmentPdf({
    required String assignmentId,
    required String filePath,
    required String fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');
    _validateFile(filePath, fileName);

    final safeName = _safeName(fileName);
    final ref = _storage.ref().child(
      'assignments/${user.uid}/$assignmentId/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'application/pdf'),
    );

    return {
      'url': await ref.getDownloadURL(),
      'path': ref.fullPath,
      'name': safeName,
    };
  }

  Future<Map<String, String>> uploadSubmissionPdf({
    required String assignmentId,
    required String filePath,
    required String fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently signed in.');
    _validateFile(filePath, fileName);

    final safeName = _safeName(fileName);
    final ref = _storage.ref().child(
      'submissions/${user.uid}/$assignmentId/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'application/pdf'),
    );

    return {
      'url': await ref.getDownloadURL(),
      'path': ref.fullPath,
      'name': safeName,
    };
  }

  Future<void> deleteFile(String path) async {
    if (path.trim().isEmpty) return;
    try {
      await _storage.ref().child(path).delete();
    } catch (_) {}
  }
}
