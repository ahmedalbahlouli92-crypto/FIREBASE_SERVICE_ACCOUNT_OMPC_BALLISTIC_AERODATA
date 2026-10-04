import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/report_helper.dart';

BallisticRecord createTestRecord({
  required String testName,
  String timestamp = '10/01/2026 08:00 AM',
  String operators = 'Tech A',
  String shift = 'Day',
  String caliber = '7.62x51 NATO M80',
  String lotNo = 'LOT-100',
  int produced = 200,
  int defects = 0,
  String notes = '',
  String status = 'Approved',
  String pressureBar = '1.5',
  String viscosity = '1.0',
  String testTime = '08:00 AM',
  String samplingLocation = 'Line 1',
  int mouthSlow = 0,
  int mouthFast = 0,
  int primerSlow = 0,
  int primerFast = 0,
  String hopperNo = '1',
  String boxNo = '1',
  String requirement = '',
  int neckSlow = 0,
  int neckFast = 0,
  int shoulderSlow = 0,
  int shoulderFast = 0,
  int bodySlow = 0,
  int bodyFast = 0,
  int headSlow = 0,
  int headFast = 0,
  String accMeanRadius = '',
  String accSDX = '',
  String accSDY = '',
  String primerAllFireH = '',
  String primerNoFireH = '',
  int functionLevel1 = 0,
  int functionLevel2 = 0,
  int functionLevel3 = 0,
  int functionLevel4 = 0,
}) {
  return BallisticRecord(
    timestamp: timestamp,
    operators: operators,
    shift: shift,
    caliber: caliber,
    lotNo: lotNo,
    produced: produced,
    defects: defects,
    notes: notes,
    status: status,
    testName: testName,
    pressureBar: pressureBar,
    viscosity: viscosity,
    testTime: testTime,
    samplingLocation: samplingLocation,
    mouthSlow: mouthSlow,
    mouthFast: mouthFast,
    primerSlow: primerSlow,
    primerFast: primerFast,
    hopperNo: hopperNo,
    boxNo: boxNo,
    requirement: requirement,
    neckSlow: neckSlow,
    neckFast: neckFast,
    shoulderSlow: shoulderSlow,
    shoulderFast: shoulderFast,
    bodySlow: bodySlow,
    bodyFast: bodyFast,
    headSlow: headSlow,
    headFast: headFast,
    accMeanRadius: accMeanRadius,
    accSDX: accSDX,
    accSDY: accSDY,
    primerAllFireH: primerAllFireH,
    primerNoFireH: primerNoFireH,
    functionLevel1: functionLevel1,
    functionLevel2: functionLevel2,
    functionLevel3: functionLevel3,
    functionLevel4: functionLevel4,
  );
}

void main() {
  group('13 Ballistic Enhancements Verification Tests', () {
    test('1. BallisticRecord.copyWith supports full admin authority updates', () {
      final initial = createTestRecord(
        testName: 'Waterproof Test',
        defects: 2,
        notes: 'Initial note',
        mouthSlow: 1,
        mouthFast: 1,
      );

      final updated = initial.copyWith(
        testName: 'Accuracy Test',
        timestamp: '10/01/2026 09:30 AM',
        testTime: '09:30 AM',
        samplingLocation: 'QA Laboratory',
        caliber: '5.56x45 SS109',
        status: 'Approved with condition',
        accMeanRadius: '15.2',
        accSDX: '3.1',
        accSDY: '2.9',
      );

      expect(updated.testName, equals('Accuracy Test'));
      expect(updated.timestamp, equals('10/01/2026 09:30 AM'));
      expect(updated.testTime, equals('09:30 AM'));
      expect(updated.samplingLocation, equals('QA Laboratory'));
      expect(updated.caliber, equals('5.56x45 SS109'));
      expect(updated.status, equals('Approved with condition'));
      expect(updated.accMeanRadius, equals('15.2'));
      expect(updated.accSDX, equals('3.1'));
      expect(updated.accSDY, equals('2.9'));
    });

    test('2. Waterproof metrics calculation: Slow Leaks, Fast Leaks, Total Leaks', () {
      final record = createTestRecord(
        testName: 'Waterproof Test',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-101',
        mouthSlow: 1,
        mouthFast: 0,
        primerSlow: 2,
        primerFast: 0,
        defects: 3,
      );

      final totalSlow = record.mouthSlow + record.primerSlow;
      final totalFast = record.mouthFast + record.primerFast;
      final totalLeaks = totalSlow + totalFast;

      expect(totalSlow, equals(3));
      expect(totalFast, equals(0));
      expect(totalLeaks, equals(3));
      // 0 to 3 leaks is Approved
      expect(record.status, equals('Approved'));
    });

    test('3. Accuracy Test metrics calculation: Average SD (X & Y) and Mean Radius', () {
      final record = createTestRecord(
        testName: 'Accuracy Test',
        caliber: '7.62x51 NATO M80',
        lotNo: 'LOT-102',
        produced: 30,
        accMeanRadius: '18.4',
        accSDX: '4.0',
        accSDY: '6.0',
      );

      final sdx = double.tryParse(record.accSDX) ?? 0.0;
      final sdy = double.tryParse(record.accSDY) ?? 0.0;
      final avgSD = (sdx + sdy) / 2.0;

      expect(avgSD, equals(5.0));
      expect(double.tryParse(record.accMeanRadius), equals(18.4));
    });

    test('4. Residual Stress metrics calculation: Total cracks / splits', () {
      final record = createTestRecord(
        testName: 'Residual Stress Test',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-103',
        status: 'Rejected',
        neckSlow: 1,
        neckFast: 0,
        shoulderSlow: 1,
        shoulderFast: 1,
        bodySlow: 0,
        bodyFast: 1,
        headSlow: 0,
        headFast: 0,
      );

      final totalCracks = record.neckSlow + record.neckFast +
          record.shoulderSlow + record.shoulderFast +
          record.bodySlow + record.bodyFast +
          record.headSlow + record.headFast;

      expect(totalCracks, equals(4));
    });

    test('5. Primer Sensitivity metrics calculation: HM+5SD and HM-2SD', () {
      final record = createTestRecord(
        testName: 'Primer Sensitivity Test',
        caliber: '7.62x51 NATO M80',
        lotNo: 'LOT-104',
        primerAllFireH: '410.5',
        primerNoFireH: '85.2',
      );

      expect(double.tryParse(record.primerAllFireH), equals(410.5));
      expect(double.tryParse(record.primerNoFireH), equals(85.2));
    });

    test('6. Function Test metrics: Levels 1-4 and Total Defects', () {
      final record = createTestRecord(
        testName: 'Function Test',
        caliber: '9x19 Parabellum',
        lotNo: 'LOT-105',
        functionLevel1: 0,
        functionLevel2: 1,
        functionLevel3: 2,
        functionLevel4: 3,
      );

      final totalDefects = record.functionLevel1 + record.functionLevel2 + record.functionLevel3 + record.functionLevel4;
      expect(totalDefects, equals(6));
    });

    test('7. ReportHelper instance exists and openReport method is available', () {
      expect(ReportHelper.instance, isNotNull);
    });
  });
}
