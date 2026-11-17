import 'dart:convert';
import 'package:archive/archive.dart';

/// Lightweight, pure-Dart extractor for Microsoft Word documents (.docx)
/// Extracts paragraph text and table grids without external dependencies.
class DocxTextExtractor {
  static String extractText(List<int> bytes) {
    if (bytes.isEmpty) return '';

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.findFile('word/document.xml');
      if (documentFile == null) {
        // Fallback: search for any document XML or extract readable strings
        return _extractFallbackStrings(bytes);
      }

      final contentBytes = documentFile.content as List<int>;
      final xml = utf8.decode(contentBytes, allowMalformed: true);
      return parseWordXml(xml);
    } catch (_) {
      return _extractFallbackStrings(bytes);
    }
  }

  /// Parses Word document XML into plain text preserving tables (tabs/newlines) and paragraphs
  static String parseWordXml(String xml) {
    if (xml.isEmpty) return '';

    final sb = StringBuffer();

    // Clean up entities
    String cleanXml = xml
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    // Replace table row endings with newlines
    cleanXml = cleanXml.replaceAll(RegExp(r'<\/w:tr>', caseSensitive: false), '\n');

    // Replace table cell endings with tabs
    cleanXml = cleanXml.replaceAll(RegExp(r'<\/w:tc>', caseSensitive: false), '\t');

    // Replace paragraph endings with newlines
    cleanXml = cleanXml.replaceAll(RegExp(r'<\/w:p>', caseSensitive: false), '\n');

    // Replace line breaks with newlines
    cleanXml = cleanXml.replaceAll(RegExp(r'<w:br\s*\/?>', caseSensitive: false), '\n');

    // Match all text tags: <w:t ...>TEXT</w:t>
    final textPattern = RegExp(r'<w:t(?:\s+[^>]*)?>([^<]*)<\/w:t>', caseSensitive: false);
    
    // Split by newlines to rebuild lines cleanly
    final lines = cleanXml.split('\n');
    for (final rawLine in lines) {
      if (rawLine.trim().isEmpty) continue;
      
      // If line contains cell tabs
      if (rawLine.contains('\t')) {
        final cells = rawLine.split('\t');
        final cellTexts = <String>[];
        for (final cell in cells) {
          final cellText = textPattern
              .allMatches(cell)
              .map((m) => m.group(1) ?? '')
              .join('');
          cellTexts.add(cellText.trim());
        }
        final row = cellTexts.where((c) => c.isNotEmpty).join('\t');
        if (row.isNotEmpty) {
          sb.writeln(row);
        }
      } else {
        final lineText = textPattern
            .allMatches(rawLine)
            .map((m) => m.group(1) ?? '')
            .join('');
        if (lineText.trim().isNotEmpty) {
          sb.writeln(lineText.trim());
        }
      }
    }

    return sb.toString().trim();
  }

  /// Fallback string scanner for legacy or binary documents
  static String _extractFallbackStrings(List<int> bytes) {
    final sb = StringBuffer();
    final buffer = <int>[];

    for (int b in bytes) {
      if ((b >= 32 && b <= 126) || b == 9 || b == 10 || b == 13) {
        buffer.add(b);
      } else {
        if (buffer.length >= 4) {
          sb.writeln(String.fromCharCodes(buffer).trim());
        }
        buffer.clear();
      }
    }
    if (buffer.length >= 4) {
      sb.writeln(String.fromCharCodes(buffer).trim());
    }

    return sb.toString().trim();
  }
}
