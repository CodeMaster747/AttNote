// services/document_text_service.dart
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// Extracts plain text from an uploaded syllabus/holiday document so it can be
/// fed to the AI. PDF and DOCX are supported; anything else (e.g. legacy .doc
/// or scanned/image PDFs) returns null so the UI can fall back to manual entry.
class DocumentTextService {
  Future<String?> extractFromUrl(String url, String fileName) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      return extractFromBytes(response.bodyBytes, fileName);
    } catch (e) {
      debugPrint('Document download failed: $e');
      return null;
    }
  }

  String? extractFromBytes(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    try {
      if (lower.endsWith('.pdf')) return _extractPdf(bytes);
      if (lower.endsWith('.docx')) return _extractDocx(bytes);
      return null; // .doc and others: manual fallback
    } catch (e) {
      debugPrint('Document extraction failed: $e');
      return null;
    }
  }

  String? _extractPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText();
      final cleaned = text.trim();
      return cleaned.isEmpty ? null : cleaned;
    } finally {
      document.dispose();
    }
  }

  String? _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.findFile('word/document.xml');
    if (doc == null) return null;
    final content = doc.content as List<int>;
    final xmlString = utf8.decode(content, allowMalformed: true);
    final document = XmlDocument.parse(xmlString);

    final buffer = StringBuffer();
    for (final node in document.descendants) {
      if (node is XmlElement) {
        final local = node.name.local;
        if (local == 't') {
          buffer.write(node.innerText);
        } else if (local == 'p' || local == 'br' || local == 'tab') {
          buffer.write('\n');
        }
      }
    }
    final cleaned = buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}
