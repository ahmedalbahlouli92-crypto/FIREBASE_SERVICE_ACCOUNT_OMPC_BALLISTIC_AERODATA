import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/services/test_result_extractor.dart';

void main() {
  group('Accuracy Test Auto-Extraction Verification', () {
    const rawReportText = '''
Results:

Round Table:
No.    x_1 [mm]    y_1 [mm]    V24.00_1 [m/s]
1      32.7        118.9       908.43
2      62.1         60.4       909.52
3      58.1         23.4       904.77
4      44.3        -33.3       901.92
5      79.6         46.3       898.23
6     -30.1         -7.9       897.36
7      29.8         41.5       899.42
8     -84.9         36.2       893.75
9       5.3        130.8       900.17
10     50.9         91.5       904.16
11      5.2        174.9       913.85
12    267.6        252.1       908.20
13      3.3         80.4       894.29
14     97.3        126.4       907.21
15    134.9          3.1       902.89
16     15.5         79.2       903.98
17     68.1        108.1       902.89
18    263.3         80.6       896.08
19     98.1        -32.8       896.56
20     70.4        -15.3       901.08
21     63.1          3.3       896.70
22     58.2        -56.0       909.42
23    103.1        198.1       903.00
24   -114.4        206.0       917.26
25    159.2         58.4       905.45
26      8.9         98.1       901.81
27    198.4       -161.0       890.87
28    127.5        184.7       903.79
29     43.9        -88.2       895.84
30     45.8        155.7       910.31

Statistic:
No.    x_1 [mm]    y_1 [mm]    V24.00_1 [m/s]
MEAN   65.5        65.5        902.64
MAX    267.6       252.1       917.26
MIN   -114.4      -161.0       890.87
RANGE  382.0       413.1        26.39
STDEV   83.8        93.6         6.19

Evaluation                     B590 Target System (1) [mm]
Impact Mean Point X            65.5
Impact Mean Point Y            65.5
Mean Radius                    104.3
Sum H+W                        795.1
Largest Distance               482.2
''';

    test('1. Parses complete Accuracy Test PDF report matching exact values from images', () {
      final res = TestResultExtractor.extract(content: rawReportText);
      final fields = res.fields;

      expect(res.detectedTest, equals('Accuracy Test'));

      // Velocity Statistics
      expect(fields['velMean'], equals('902.64'));
      expect(fields['velMax'], equals('917.26'));
      expect(fields['velMin'], equals('890.87'));
      expect(fields['velRange'], equals('26.39'));
      expect(fields['velSD'], equals('6.19'));

      // Coordinate X Statistics
      expect(fields['accMeanX'], equals('65.5'));
      expect(fields['accMaxX'], equals('267.6'));
      expect(fields['accMinX'], equals('-114.4'));
      expect(fields['accRangeX'], equals('382.0'));
      expect(fields['accSDX'], equals('83.8'));

      // Coordinate Y Statistics
      expect(fields['accMeanY'], equals('65.5'));
      expect(fields['accMaxY'], equals('252.1'));
      expect(fields['accMinY'], equals('-161.0'));
      expect(fields['accRangeY'], equals('413.1'));
      expect(fields['accSDY'], equals('93.6'));

      // Evaluation Metrics
      expect(fields['accMeanRadius'], equals('104.3'));
      expect(fields['accLargestDistance'], equals('482.2'));
      expect(fields['largest_distance'], equals('482.2'));
      expect(fields['accExtremeSpread'], equals('482.2'));
      expect(fields['accSumHW'], equals('795.1'));

      // Velocity Distance & Shot Count
      expect(fields['distance'], equals('24.00'));
      expect(fields['produced'], equals('30'));

      // Verify snake_case mirrors
      expect(fields['vel_mean'], equals('902.64'));
      expect(fields['acc_mean_x'], equals('65.5'));
      expect(fields['acc_mean_y'], equals('65.5'));
      expect(fields['acc_mean_radius'], equals('104.3'));
      expect(fields['acc_largest_distance'], equals('482.2'));
    });

    test('2. PdfTextExtractor extracts and parses Accuracy PDF stream', () {
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Length 300 >>
stream
BT
/F1 12 Tf
100 700 Td (Accuracy Test Results) Tj
0 -20 Td (V24.00_1 [m/s]) Tj
0 -20 Td (MEAN 65.5 65.5 902.64) Tj
0 -20 Td (MAX 267.6 252.1 917.26) Tj
0 -20 Td (MIN -114.4 -161.0 890.87) Tj
0 -20 Td (RANGE 382.0 413.1 26.39) Tj
0 -20 Td (STDEV 83.8 93.6 6.19) Tj
0 -20 Td (Mean Radius 104.3) Tj
0 -20 Td (Largest Distance 482.2) Tj
0 -20 Td (Sum H+W 795.1) Tj
ET
endstream
endobj
%%EOF
''';
      final bytes = latin1.encode(pdfContent);
      final extractedText = PdfTextExtractor.extractText(bytes);

      expect(extractedText.contains('MEAN 65.5 65.5 902.64'), isTrue);
      expect(extractedText.contains('Mean Radius 104.3'), isTrue);
      expect(extractedText.contains('Largest Distance 482.2'), isTrue);

      final res = TestResultExtractor.extractFromBytes(bytes: bytes, filename: 'Accuracy_Report.pdf');
      expect(res.detectedTest, equals('Accuracy Test'));
      expect(res.fields['accMeanRadius'], equals('104.3'));
      expect(res.fields['accLargestDistance'], equals('482.2'));
      expect(res.fields['velMean'], equals('902.64'));
      expect(res.fields['accMeanX'], equals('65.5'));
      expect(res.fields['accMeanY'], equals('65.5'));
      expect(res.fields['distance'], equals('24.00'));
    });

    test('3. Computes accurate ballistic statistics directly from Round Table shots when summary table is omitted', () {
      const roundsOnlyText = '''
Round Table:
No.    x_1 [mm]    y_1 [mm]    V24.00_1 [m/s]
1      32.7        118.9       908.43
2      62.1         60.4       909.52
3      58.1         23.4       904.77
4      44.3        -33.3       901.92
5      79.6         46.3       898.23
6     -30.1         -7.9       897.36
7      29.8         41.5       899.42
8     -84.9         36.2       893.75
9       5.3        130.8       900.17
10     50.9         91.5       904.16
11      5.2        174.9       913.85
12    267.6        252.1       908.20
13      3.3         80.4       894.29
14     97.3        126.4       907.21
15    134.9          3.1       902.89
16     15.5         79.2       903.98
17     68.1        108.1       902.89
18    263.3         80.6       896.08
19     98.1        -32.8       896.56
20     70.4        -15.3       901.08
21     63.1          3.3       896.70
22     58.2        -56.0       909.42
23    103.1        198.1       903.00
24   -114.4        206.0       917.26
25    159.2         58.4       905.45
26      8.9         98.1       901.81
27    198.4       -161.0       890.87
28    127.5        184.7       903.79
29     43.9        -88.2       895.84
30     45.8        155.7       910.31
''';
      final res = TestResultExtractor.extract(content: roundsOnlyText);
      final fields = res.fields;

      expect(res.detectedTest, equals('Accuracy Test'));
      expect(fields['produced'], equals('30'));
      expect(fields['accMeanX'], equals('65.5'));
      expect(fields['accMeanY'], equals('65.5'));
      expect(fields['velMean'], equals('902.64'));
      expect(fields['accMaxX'], equals('267.6'));
      expect(fields['accMinX'], equals('-114.4'));
      expect(fields['accRangeX'], equals('382.0'));
      expect(fields['accMaxY'], equals('252.1'));
      expect(fields['accMinY'], equals('-161.0'));
      expect(fields['accRangeY'], equals('413.1'));
      expect(fields['accSDX'], equals('83.8'));
      expect(fields['accSDY'], equals('93.6'));
      expect(fields['velSD'], equals('6.19'));
      expect(fields['accMeanRadius'], equals('104.3'));
      expect(fields['accLargestDistance'], equals('482.2'));
      expect(fields['accSumHW'], equals('795.1'));
    });
  });
}
