import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/services/test_result_extractor.dart';

void main() {
  test('Test new extractor on OMPC Ballistic AeroData.pdf', () {
    final file = File('C:/Users/user/Desktop/OMPC Ballistic AeroData.pdf');
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    final text = PdfTextExtractor.extractText(bytes);
    print('EXTRACTED LENGTH: ${text.length}');
    print('FIRST 1000 CHARS:\n$text');

    final extracted = TestResultExtractor.extract(content: text);
    print('DETECTED TEST: ${extracted.detectedTest}');
    print('EXTRACTED FIELDS: ${extracted.fields}');

    expect(extracted.detectedTest, equals('Function Test'));
    expect(extracted.fields['caliber'], equals('5.56x45 SS109'));
    expect(extracted.fields['lotNo'], equals('001/OMPC/26'));
    expect(extracted.fields['lotDigits'], equals('001'));
    expect(extracted.fields['lotYear'], equals('26'));
    expect(extracted.fields['testDate'], equals('9/29/2026'));
    expect(extracted.fields['operators'], equals('System Administrator'));
    expect(extracted.fields['cartridgeTemp'], equals('+21'));
  });
}
