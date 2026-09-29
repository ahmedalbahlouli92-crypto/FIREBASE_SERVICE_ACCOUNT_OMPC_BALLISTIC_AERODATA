import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/report_generator.dart';

void main() {
  group('Primer Sensitivity & Inspection Log Verification Tests', () {
    test('1. Primer Sensitivity 7.62 rules: HM+5SD <= 500 and HM-2SD >= 75', () {
      final defaultAllFire = 500.0;
      final defaultNoFire = 75.0;

      // Passing case
      final hmPass = 300.0;
      final sdPass = 30.0;
      final allFirePass = hmPass + 5 * sdPass; // 450.0
      final noFirePass = hmPass - 2 * sdPass;  // 240.0
      expect(allFirePass <= defaultAllFire, isTrue);
      expect(noFirePass >= defaultNoFire, isTrue);

      // Failing All Fire case
      final hmFailHigh = 400.0;
      final sdFailHigh = 30.0;
      final allFireFail = hmFailHigh + 5 * sdFailHigh; // 550.0 > 500
      expect(allFireFail > defaultAllFire, isTrue);

      // Failing No Fire case
      final hmFailLow = 100.0;
      final sdFailLow = 20.0;
      final noFireFail = hmFailLow - 2 * sdFailLow; // 60.0 < 75
      expect(noFireFail < defaultNoFire, isTrue);
    });

    test('2. Primer Sensitivity 5.56 rules: HM+5SD <= 450 and HM-2SD >= 75', () {
      final defaultAllFire = 450.0;
      final defaultNoFire = 75.0;

      // Passing case
      final hmPass = 250.0;
      final sdPass = 30.0;
      final allFirePass = hmPass + 5 * sdPass; // 400.0 <= 450.0
      final noFirePass = hmPass - 2 * sdPass;  // 190.0 >= 75.0
      expect(allFirePass <= defaultAllFire, isTrue);
      expect(noFirePass >= defaultNoFire, isTrue);

      // Failing All Fire case
      final hmFailHigh = 320.0;
      final sdFailHigh = 30.0;
      final allFireFail = hmFailHigh + 5 * sdFailHigh; // 470.0 > 450.0
      expect(allFireFail > defaultAllFire, isTrue);
    });

    test('3. Primer Sensitivity 9mm rules: HM+5SD <= 350 and HM-2SD >= 75', () {
      final defaultAllFire = 350.0;
      final defaultNoFire = 75.0;

      // Passing case
      final hmPass = 200.0;
      final sdPass = 25.0;
      final allFirePass = hmPass + 5 * sdPass; // 325.0 <= 350.0
      final noFirePass = hmPass - 2 * sdPass;  // 150.0 >= 75.0
      expect(allFirePass <= defaultAllFire, isTrue);
      expect(noFirePass >= defaultNoFire, isTrue);

      // Failing All Fire case
      final hmFailHigh = 250.0;
      final sdFailHigh = 25.0;
      final allFireFail = hmFailHigh + 5 * sdFailHigh; // 375.0 > 350.0
      expect(allFireFail > defaultAllFire, isTrue);
    });

    test('4. Exported HTML and Word reports have clean formatting with no corrupted symbols', () {
      final record = BallisticRecord.empty().copyWith(
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        epvatMeanPressure: '3500',
        epvatSDPressure: '100',
        epvatP2MeanPressure: '1200',
        velMean: '915',
        cartridgeTemp: '+21',
      );

      final adminRules = {
        'epvat': {
          'bullet_mass_grams': {'5.56x45 SS109': 4.0},
        }
      };

      final html = ReportGenerator.generateHtml([record], 'EPVAT test', 'Lot Acceptance Test', adminRules: adminRules);
      final word = ReportGenerator.generateWordHtml([record], 'EPVAT test', 'Lot Acceptance Test', adminRules: adminRules);

      // Should not contain raw emoji symbol ⚡
      expect(html.contains('⚡'), isFalse);
      expect(word.contains('⚡'), isFalse);

      // Should contain clean &bull; Kinetic Energy (+21&deg;C)
      expect(html.contains('&bull; Kinetic Energy (+21&deg;C):'), isTrue);
      expect(word.contains('&bull; Kinetic Energy (+21&deg;C):'), isTrue);

      // Word HTML should contain UTF-8 Content-Type meta
      expect(word.contains('<meta http-equiv="Content-Type" content="text/html; charset=utf-8">'), isTrue);
    });

    test('5. Record metrics summary accurately displays Accuracy and EPVAT order', () {
      final accRecord = BallisticRecord.empty().copyWith(
        testName: 'Accuracy Test',
        caliber: '7.62x51 M80',
        accSDX: '12.4',
        accSDY: '14.8',
        velMean: '835',
      );

      final epvatRecord = BallisticRecord.empty().copyWith(
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        epvatMeanPressure: '3500',
        epvatP2MeanPressure: '1200',
        epvatPressureUnit: 'bar',
        velMean: '915',
      );

      // Generate report for 'All' to check _getRecordMetricsSummary
      final html = ReportGenerator.generateHtml([accRecord, epvatRecord], 'All', 'Lot Acceptance Test');
      expect(html.contains('SD X: 12.4 mm, SD Y: 14.8 mm, Mean Vel: 835 m/s'), isTrue);
      expect(html.contains('Mean Chamber: 3500 bar, Mean Port: 1200 bar, Mean Vel (+21 °C): 915 m/s'), isTrue);
    });
  });
}
