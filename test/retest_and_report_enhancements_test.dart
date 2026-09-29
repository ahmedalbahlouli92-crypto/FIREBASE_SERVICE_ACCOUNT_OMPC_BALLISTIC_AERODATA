import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/report_generator.dart';

void main() {
  group('Quality Enhancements & Retest Separation Tests', () {
    test('1. Default PDF Filename format follows Caliber_Test Name_Lot number', () {
      final record = BallisticRecord(
        timestamp: '9/29/2026 10:00:00 AM',
        operators: 'Inspector Ahmed',
        shift: 'Day',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC26',
        produced: 200,
        defects: 0,
        notes: '',
        status: 'Approved',
        testName: 'Waterproof Test',
        pressureBar: '1.5',
        viscosity: '1.0',
        testTime: '10:00 AM',
        samplingLocation: 'Hopper 1',
        mouthSlow: 0,
        mouthFast: 0,
        primerSlow: 0,
        primerFast: 0,
        hopperNo: '1',
        boxNo: '',
        requirement: '',
      );

      final repCaliber = record.caliber.replaceAll(';', ' ').trim();
      final repTestName = record.testName;
      final repLotNo = record.lotNo;
      final exportFilename = '${repCaliber}_${repTestName}_$repLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      expect(exportFilename, equals('5.56x45 SS109_Waterproof Test_001 OMPC26'));
    });

    test('2. Empty remarks are kept empty and "No remarks recorded." is removed', () {
      expect(ReportGenerator.cleanRemarks(''), equals(''));
      expect(ReportGenerator.cleanRemarks('   '), equals(''));
      expect(ReportGenerator.cleanRemarks('No remarks recorded.'), equals(''));
      expect(ReportGenerator.cleanRemarks('Temps: +21°C (P1=3200)'), equals(''));
      expect(ReportGenerator.cleanRemarks('Batch passed | Temps: +21°C (P1=3200)'), equals('Batch passed'));
    });

    test('3. Exported HTML and Word reports have matching remarks and defect guide box dimensions and no placeholder text', () {
      final record = BallisticRecord(
        timestamp: '9/29/2026 10:00:00 AM',
        operators: 'Inspector Ahmed',
        shift: 'Day',
        caliber: '9x19 Parabellum',
        lotNo: '002 OMPC26',
        produced: 100,
        defects: 0,
        notes: '', // No remarks recorded
        status: 'Approved',
        testName: 'Function Test',
        pressureBar: '',
        viscosity: '',
        testTime: '',
        samplingLocation: '',
        mouthSlow: 0,
        mouthFast: 0,
        primerSlow: 0,
        primerFast: 0,
        hopperNo: '',
        boxNo: '',
        requirement: '',
      );

      final html = ReportGenerator.generateHtml([record], 'Function Test', 'Lot Acceptance Test');
      final word = ReportGenerator.generateWordHtml([record], 'Function Test', 'Lot Acceptance Test');

      // Does not contain placeholder
      expect(html.contains('No remarks recorded.'), isFalse);
      expect(word.contains('No remarks recorded.'), isFalse);

      // Contains matching sizing tokens
      expect(html.contains('height: 210px'), isTrue);
      expect(word.contains('height: 210px'), isTrue);
    });

    test('4. Retest results are preserved separately and rendered in separated table', () {
      final initialRecord = BallisticRecord(
        timestamp: '9/29/2026 09:00:00 AM',
        operators: 'Inspector Ali',
        shift: 'Day',
        caliber: '7.62x51 M80',
        lotNo: '003 OMPC26',
        produced: 200,
        defects: 4, // 4 leaks initially
        notes: 'Initial test failed due to leaks',
        status: 'Retest',
        testName: 'Waterproof Test',
        pressureBar: '1.5',
        viscosity: '1.0',
        testTime: '09:00 AM',
        samplingLocation: 'Line 2',
        mouthSlow: 2,
        mouthFast: 2,
        primerSlow: 0,
        primerFast: 0,
        hopperNo: '',
        boxNo: '',
        requirement: '',
      );

      // Perform non-destructive retest
      final retestMetrics = {
        'mouthSlow': 0,
        'mouthFast': 0,
        'primerSlow': 0,
        'primerFast': 0,
      };

      final retestedRecord = initialRecord.copyWith(
        status: 'Approved',
        isRetest: true,
        retestTimestamp: '9/29/2026 11:30:00 AM',
        retestOperator: 'Admin Omar',
        retestNotes: 'Retest completely conforming',
        retestStatus: 'Approved',
        originalStatus: 'Retest',
        retestProduced: 400,
        retestDefects: 0,
        retestMetrics: jsonEncode(retestMetrics),
      );

      // Initial test values MUST remain untouched
      expect(retestedRecord.produced, equals(200));
      expect(retestedRecord.defects, equals(4));
      expect(retestedRecord.mouthSlow, equals(2));
      expect(retestedRecord.mouthFast, equals(2));

      // Retest values are stored in retest fields
      expect(retestedRecord.isRetest, isTrue);
      expect(retestedRecord.retestProduced, equals(400));
      expect(retestedRecord.retestDefects, equals(0));
      expect(retestedRecord.parsedRetestMetrics['mouthSlow'], equals(0));
      expect(retestedRecord.parsedRetestMetrics['mouthFast'], equals(0));

      // Verify separated retest table generated in report
      final html = ReportGenerator.generateHtml([retestedRecord], 'Waterproof Test', 'Lot Acceptance Test');
      expect(html.contains('Retest Verification Inspection Results'), isTrue);
      expect(html.contains('Retest Mouth Leaks'), isTrue);
      expect(html.contains('Retest Primer Leaks'), isTrue);

      final word = ReportGenerator.generateWordHtml([retestedRecord], 'Waterproof Test', 'Lot Acceptance Test');
      expect(word.contains('Retest Verification Inspection Results'), isTrue);
    });
  });
}
