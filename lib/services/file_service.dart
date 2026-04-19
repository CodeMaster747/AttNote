// services/file_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class FileService {
  final _storage = FirebaseStorage.instance;

  Future<String?> uploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
        final ref = _storage.ref().child('images/$fileName');

        await ref.putFile(file);
        return await ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
    return null;
  }

  Future<Map<String, String>?> uploadPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final ref = _storage.ref().child('pdfs/$fileName');

        await ref.putFile(file);
        final downloadUrl = await ref.getDownloadURL();

        return {'url': downloadUrl, 'fileName': result.files.single.name};
      }
    } catch (e) {
      debugPrint('Error uploading PDF: $e');
    }
    return null;
  }

  Future<Map<String, String>?> uploadTextFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final ref = _storage.ref().child('text_files/$fileName');

        await ref.putFile(file);
        final downloadUrl = await ref.getDownloadURL();

        return {'url': downloadUrl, 'fileName': result.files.single.name};
      }
    } catch (e) {
      debugPrint('Error uploading text file: $e');
    }
    return null;
  }

  Future<String?> readTextFileContent(String fileUrl) async {
    try {
      // For local text files, you can read the content
      // For remote files, you might need to download and read
      // This is a simplified example
      return "File content would be loaded here";
    } catch (e) {
      debugPrint('Error reading text file: $e');
      return null;
    }
  }
}
