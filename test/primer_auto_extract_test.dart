import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/services/test_result_extractor.dart';

void main() {
  group('Primer Sensitivity Test Auto-Extraction Tests', () {
    const primerReportText = '''
RECORD TYPE: Primer Sensitivity
DATE: 09.09.2025
Calibre: 5.56
Supplier: UG
Lot number: 5-25
Primer insertion depth(mm): 0.07 - 0.09
Temperature(C°): +21C
Operator: AbdulMajeed AlSabahi

H     F    M    PI
130.0 0    25   1.000
155.0 2    23   0.920
180.0 3    22   0.880
205.0 15   10   0.400
230.0 17   8    0.320
255.0 25   0    0.000

HM: 205.5
SD: 30.1
HM+5SD: 356
HM-2SD: 145.3
Alpha3: -6.331
Emax: 0.390
Emin: 0.159
''';

    test('Auto-detects Primer Sensitivity Test and extracts all required fields', () {
      final res = TestResultExtractor.extract(content: primerReportText);

      expect(res.detectedTest, equals('Primer Sensitivity Test'));

      // Caliber
      expect(res.fields['caliber'], equals('5.56x45 SS109'));

      // Supplier / Manufacturer
      expect(res.fields['primerSupplier'], equals('UG'));
      expect(res.fields['primer_supplier'], equals('UG'));

      // Lot number
      expect(res.fields['lotDigits'], equals('005'));
      expect(res.fields['lotYear'], equals('25'));
      expect(res.fields['primerLot'], equals('5-25'));
      expect(res.fields['primer_lot'], equals('5-25'));

      // Date of test
      expect(res.fields['testTime'], equals('09.09.2025'));
      expect(res.fields['testDate'], equals('09.09.2025'));
      expect(res.fields['test_date'], equals('09.09.2025'));

      // Room Temp / Temperature
      expect(res.fields['cartridgeTemp'], equals('+21'));
      expect(res.fields['roomTemp'], equals('+21'));
      expect(res.fields['room_temp'], equals('+21'));

      // Insertion depth average: (0.07 + 0.09) / 2 = 0.08 mm
      expect(res.fields['primerInsertionDepth'], equals('0.08'));
      expect(res.fields['primer_insertion_depth'], equals('0.08'));

      // Drop Table F & M quantity summation:
      // Fires: 0 + 2 + 3 + 15 + 17 + 25 = 62
      // Misfires: 25 + 23 + 22 + 10 + 8 + 0 = 88
      // Total Quantity Tested: 62 + 88 = 150
      expect(res.fields['primerTotalFires'], equals('62'));
      expect(res.fields['primerTotalMisfires'], equals('88'));
      expect(res.fields['misfires'], equals('88'));
      expect(res.fields['produced'], equals('150'));
      expect(res.fields['primerTotalTested'], equals('150'));

      // Statistical metrics
      expect(res.fields['primerHbar'], equals('205.5'));
      expect(res.fields['primer_hbar'], equals('205.5'));
      expect(res.fields['primerSD'], equals('30.1'));
      expect(res.fields['primer_sd'], equals('30.1'));
      expect(res.fields['primerAllFire'], equals('356'));
      expect(res.fields['primer_all_fire'], equals('356'));
      expect(res.fields['primerNoFire'], equals('145.3'));
      expect(res.fields['primer_no_fire'], equals('145.3'));

      // Advanced metrics
      expect(res.fields['primerAlpha3'], equals('-6.331'));
      expect(res.fields['primerEmax'], equals('0.390'));
      expect(res.fields['primerEmin'], equals('0.159'));

      // Inspector / Operator
      expect(res.fields['operators'], equals('AbdulMajeed AlSabahi'));
    });

    test('Auto-extracts exact media layout from media_1791792746357.png', () {
      const exactMediaText = '''
5.56 Primer UG Lot 05-25
OMPC
Oman Munition Production Company

RECORD TYPE:
DATE:           09.09.2025
Calibre:        5.56
Supplier:       UG
Lot number:     5-25
Primer insertion depth(mm): 0.07 - 0.09
Temperature(C°): +21C
Operator:       AbdulMajeed AlSabahi
Comments:
HM+5SD:         356
HM-2SD:         145.3
O Approved O Rejected
Test Supervisor:
Date:
Signature:

H     F    M    PI
130.0 0    25   1.000
155.0 2    23   0.920
180.0 3    22   0.880
205.0 15   10   0.400
230.0 17   8    0.320
255.0 25   0    0.000

HM 205.5
SD 30.1
Alpha3 -6.331
Emax 0.390
Emin 0.159
''';

      final res = TestResultExtractor.extract(content: exactMediaText);
      expect(res.detectedTest, equals('Primer Sensitivity Test'));
      expect(res.fields['primerHbar'], equals('205.5'));
      expect(res.fields['primerSD'], equals('30.1'));
      expect(res.fields['primerAllFire'], equals('356'));
      expect(res.fields['primerNoFire'], equals('145.3'));
      expect(res.fields['produced'], equals('150'));
      expect(res.fields['misfires'], equals('88'));
      expect(res.fields['primerInsertionDepth'], equals('0.08'));
      expect(res.fields['primerSupplier'], equals('UG'));
      expect(res.fields['lotDigits'], equals('005'));
      expect(res.fields['lotYear'], equals('25'));
    });

    test('Overrides mismatched preferredTestName (e.g. Accuracy Test) when document is Primer Sensitivity', () {
      const text = '''
5.56 Primer UG Lot 05-25
DATE: 09.09.2025
Calibre: 5.56
Supplier: UG
Lot number: 5-25
Primer insertion depth: 0.12
Temperature: +21C
H F M PI
130.0 0 25 1.000
155.0 25 0 0.000
HM 205.5
SD 30.1
''';

      final res = TestResultExtractor.extract(
        content: text,
        preferredTestName: 'Accuracy Test',
      );

      expect(res.detectedTest, equals('Primer Sensitivity Test'));
      expect(res.fields['primerHbar'], equals('205.5'));
      expect(res.fields['primerSD'], equals('30.1'));
      expect(res.fields['primerSupplier'], equals('UG'));
      expect(res.fields['primerInsertionDepth'], equals('0.12'));
      expect(res.fields['produced'], equals('50'));
      expect(res.fields['misfires'], equals('25'));
    });

    test('Total rounds is exactly the sum of fire and misfire from piped markdown drop table', () {
      const pipedText = '''
RECORD TYPE: Primer Sensitivity Test
Calibre: 5.56
Supplier: CBC
Lot number: CBC-26-01

| H | F | M | PI |
| 130.0 | 0 | 25 | 1.000 |
| 155.0 | 2 | 23 | 0.920 |
| 180.0 | 3 | 22 | 0.880 |
| 205.0 | 15 | 10 | 0.400 |
| 230.0 | 17 | 8 | 0.320 |
| 255.0 | 25 | 0 | 0.000 |

HM: 205.5
SD: 30.1
''';

      final res = TestResultExtractor.extract(content: pipedText);
      expect(res.detectedTest, equals('Primer Sensitivity Test'));
      // Total fires: 0 + 2 + 3 + 15 + 17 + 25 = 62
      // Total misfires: 25 + 23 + 22 + 10 + 8 + 0 = 88
      // Total rounds (sample size) = sum of fire and misfire = 62 + 88 = 150
      expect(res.fields['primerTotalFires'], equals('62'));
      expect(res.fields['primerTotalMisfires'], equals('88'));
      expect(res.fields['misfires'], equals('88'));
      expect(res.fields['produced'], equals('150'));
      expect(res.fields['primerTotalTested'], equals('150'));
      expect(res.fields['primerTotalRounds'], equals('150'));
    });

    test('Total rounds is sum of fire and misfire from column-oriented stream layout', () {
      const columnText = '''
RECORD TYPE: Primer Sensitivity
DATE: 12.10.2026
Calibre: 5.56
Supplier: UG
Lot number: 05-25

H
130.0
155.0
180.0
205.0
230.0
255.0

F
0
2
3
15
17
25

M
25
23
22
10
8
0

PI
1.000
0.920
0.880
0.400
0.320
0.000

HM 205.5
SD 30.1
''';

      final res = TestResultExtractor.extract(content: columnText);
      expect(res.detectedTest, equals('Primer Sensitivity Test'));
      expect(res.fields['primerTotalFires'], equals('62'));
      expect(res.fields['primerTotalMisfires'], equals('88'));
      expect(res.fields['misfires'], equals('88'));
      expect(res.fields['produced'], equals('150'));
      expect(res.fields['primerTotalTested'], equals('150'));
      expect(res.fields['primerTotalRounds'], equals('150'));
    });
  });
}

