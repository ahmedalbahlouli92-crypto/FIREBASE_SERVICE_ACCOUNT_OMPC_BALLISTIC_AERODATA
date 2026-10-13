import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/services/test_result_extractor.dart';

void main() {
  group('Extraction Force Test Auto-Extraction Verification', () {
    const rawReportText = '''
Oman Munition Production Company
Extraction Force test - Cal 7.62

Specimen
BatchID       M80 Lot 01 OMPC 26
Notes         abdulsamad

Calculation   Extraction Force    Overall result
Units         N
Sample 1      550.8               PASS
Sample 2      324.4               PASS
Sample 3      558.8               PASS
Sample 4      968.7               PASS
Sample 5      624.7               PASS
Sample 6      457.7               PASS
Sample 7      304.2               PASS
Sample 8      579.8               PASS
Sample 9      638.3               PASS
Sample 10     518.4               PASS
Sample 11     668.9               PASS
Sample 12     435.3               PASS
Sample 13     618.8               PASS
Sample 14     388.0               PASS
Sample 15     506.5               PASS
Sample 16     314.8               PASS
Sample 17     455.6               PASS
Sample 18     390.4               PASS
Sample 19     345.3               PASS
Sample 20     504.9               PASS
Minimum       304.2
Maximum       968.7
Mean          507.7
SD            157
''';

    test('1. Parses Extraction Force test parameters accurately from raw report text', () {
      final res = TestResultExtractor.extract(content: rawReportText);
      final fields = res.fields;

      expect(res.detectedTest, equals('Extraction Force Test'));
      expect(fields['caliber'], equals('7.62x51 M80'));
      expect(fields['lotNo'], equals('001/OMPC/26'));
      expect(fields['lotDigits'], equals('001'));
      expect(fields['lotYear'], equals('26'));
      expect(fields['operators'], equals('abdulsamad'));

      expect(fields['accMinX'], equals('304.2'));
      expect(fields['accMaxX'], equals('968.7'));
      expect(fields['accMeanX'], equals('507.7'));
      expect(fields['accSDX'], equals('157'));
      expect(fields['accRangeX'], equals('664.5'));

      expect(fields['produced'], equals('20'));
      expect(fields['extractionForceType'], equals('Individual'));

      final rounds = (fields['roundForces'] as String).split(',');
      expect(rounds.length, equals(20));
      expect(rounds[0], equals('550.8'));
      expect(rounds[1], equals('324.4'));
      expect(rounds[2], equals('558.8'));
      expect(rounds[3], equals('968.7'));
      expect(rounds[4], equals('624.7'));
      expect(rounds[5], equals('457.7'));
      expect(rounds[6], equals('304.2'));
      expect(rounds[7], equals('579.8'));
      expect(rounds[8], equals('638.3'));
      expect(rounds[9], equals('518.4'));
      expect(rounds[10], equals('668.9'));
      expect(rounds[11], equals('435.3'));
      expect(rounds[12], equals('618.8'));
      expect(rounds[13], equals('388.0'));
      expect(rounds[14], equals('506.5'));
      expect(rounds[15], equals('314.8'));
      expect(rounds[16], equals('455.6'));
      expect(rounds[17], equals('390.4'));
      expect(rounds[18], equals('345.3'));
      expect(rounds[19], equals('504.9'));
    });

    test('2. PdfTextExtractor extracts text from BT/ET blocks and Tj/TJ operations', () {
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Length 200 >>
stream
BT
/F1 12 Tf
100 700 Td (Extraction Force test - Cal 7.62) Tj
0 -20 Td (BatchID M80 Lot 01 OMPC 26) Tj
0 -20 Td (Notes abdulsamad) Tj
0 -20 Td [(Sample 1 ) 20 (550.8) 20 ( PASS)] TJ
0 -20 Td (Minimum 304.2) Tj
0 -20 Td (Maximum 968.7) Tj
0 -20 Td (Mean 507.7) Tj
0 -20 Td (SD 157) Tj
ET
endstream
endobj
%%EOF
''';
      final bytes = latin1.encode(pdfContent);
      final extractedText = PdfTextExtractor.extractText(bytes);

      expect(extractedText.contains('Extraction Force test - Cal 7.62'), isTrue);
      expect(extractedText.contains('BatchID M80 Lot 01 OMPC 26'), isTrue);
      expect(extractedText.contains('Sample 1 550.8 PASS'), isTrue);
      expect(extractedText.contains('Minimum 304.2'), isTrue);
      expect(extractedText.contains('Maximum 968.7'), isTrue);

      final res = TestResultExtractor.extractFromBytes(bytes: bytes, filename: 'Extraction_Report.pdf');
      expect(res.fields['caliber'], equals('7.62x51 M80'));
      expect(res.fields['lotNo'], equals('001/OMPC/26'));
      expect(res.fields['operators'], equals('abdulsamad'));
      expect(res.fields['accMinX'], equals('304.2'));
      expect(res.fields['accMaxX'], equals('968.7'));
    });
  });
}
