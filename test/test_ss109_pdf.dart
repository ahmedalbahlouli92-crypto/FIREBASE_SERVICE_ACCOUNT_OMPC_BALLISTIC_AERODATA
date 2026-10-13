import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/services/test_result_extractor.dart';

void main() {
  test('Extract text from SS109 PDF', () {
    final file = File('C:/Users/user/Desktop/SS109 Lot 010 OMPC-26.pdf');
    if (!file.existsSync()) {
      print('File not found: ${file.path}');
      return;
    }
    final bytes = file.readAsBytesSync();
    final text = PdfTextExtractor.extractText(bytes);
    print('EXTRACTED LENGTH: ${text.length}');
    print('FIRST 1000 CHARS:\n$text');

    final extracted = TestResultExtractor.extract(content: text);
    print('DETECTED TEST: ${extracted.detectedTest}');
    print('EXTRACTED FIELDS: ${extracted.fields}');
  });
}
