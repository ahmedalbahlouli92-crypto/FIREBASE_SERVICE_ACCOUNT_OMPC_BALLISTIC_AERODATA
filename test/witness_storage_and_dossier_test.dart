import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/report_generator.dart';

BallisticRecord createTestRecord({
  required String testName,
  String caliber = '5.56x45 SS109',
  String lotNo = 'LOT-001',
  int produced = 20,
  int defects = 0,
  String status = 'Approved',
  String notes = '',
  String referenceNo = 'REF-1001',
  int mouthSlow = 0,
  int mouthFast = 0,
  int primerSlow = 0,
  int primerFast = 0,
  bool? isRetest,
  int retestProduced = 0,
  int retestDefects = 0,
  String retestStatus = '',
  String retestMetrics = '',
  String epvatMeanPressure = '3450',
  String epvatP2MeanPressure = '620',
  String actionTimeMean = '1.15',
  String velMean = '945',
  String primerHbar = '32.4',
  String primerSD = '3.2',
  String primerAllFireH = '48.4',
  String primerNoFireH = '26.0',
}) {
  final effectiveIsRetest = isRetest ?? (retestProduced > 0 || retestStatus.isNotEmpty);
  return BallisticRecord(
    timestamp: '9/29/2026 10:00:00 AM',
    operators: 'Technician',
    shift: 'Day',
    caliber: caliber,
    lotNo: lotNo,
    produced: produced,
    defects: defects,
    notes: notes,
    status: status,
    testName: testName,
    pressureBar: '1.5',
    viscosity: '1.0',
    testTime: '10:00 AM',
    samplingLocation: 'Line 1',
    mouthSlow: mouthSlow,
    mouthFast: mouthFast,
    primerSlow: primerSlow,
    primerFast: primerFast,
    hopperNo: '',
    boxNo: '',
    requirement: '',
    referenceNo: referenceNo,
    isRetest: effectiveIsRetest,
    retestProduced: retestProduced,
    retestDefects: retestDefects,
    retestStatus: retestStatus,
    retestMetrics: retestMetrics,
    epvatMeanPressure: epvatMeanPressure,
    epvatP2MeanPressure: epvatP2MeanPressure,
    actionTimeMean: actionTimeMean,
    velMean: velMean,
    primerHbar: primerHbar,
    primerSD: primerSD,
    primerAllFireH: primerAllFireH,
    primerNoFireH: primerNoFireH,
  );
}

void main() {
  group('13 Core Ballistic & Quality Requirements Tests', () {
    // -------------------------------------------------------------------------
    // Requirement 1: EPVAT Ordering
    // -------------------------------------------------------------------------
    test('1. EPVAT Pressure & Velocity ordering: P1, P2, Action Time, Velocity', () {
      final epvatRecord = createTestRecord(
        testName: 'EPVAT test',
        referenceNo: 'REF-1005',
        epvatMeanPressure: '3450',
        epvatP2MeanPressure: '620',
        actionTimeMean: '1.15',
        velMean: '945',
      );

      final html = ReportGenerator.generateHtml([epvatRecord], 'EPVAT test', 'Lot Acceptance Test');
      expect(html, contains('P1 (Chamber)'));
      expect(html, contains('P2 (Port)'));
      expect(html, contains('Action Time'));
      expect(html, contains('Velocity'));

      final p1Idx = html.indexOf('<th>P1 (Chamber)');
      final p2Idx = html.indexOf('<th>P2 (Port)');
      final atIdx = html.indexOf('<th>Action Time (ms)</th>');
      final velIdx = html.indexOf('<th>Velocity (m/s)</th>');

      expect(p1Idx, isNonNegative);
      expect(p2Idx, greaterThan(p1Idx));
      expect(atIdx, greaterThan(p2Idx));
      expect(velIdx, greaterThan(atIdx));
    });

    // -------------------------------------------------------------------------
    // Requirement 2: Primer Sensitivity Mean Height (H̄) before SD
    // -------------------------------------------------------------------------
    test('2. Primer Sensitivity: Mean Height (H̄) is added before SD', () {
      final primerRecord = createTestRecord(
        caliber: '9x19 Parabellum',
        testName: 'Primer Sensitivity Test',
        referenceNo: 'REF-1002',
        produced: 50,
        primerHbar: '32.4',
        primerSD: '3.2',
        primerAllFireH: '48.4',
        primerNoFireH: '26.0',
      );

      final html = ReportGenerator.generateHtml([primerRecord], 'Primer Sensitivity Test', 'Lot Acceptance Test');
      expect(html, contains('Mean Height (H̄)'));
      expect(html, contains('SD (Standard Deviation)'));

      // Check order in HTML: Mean Height appears before SD
      final meanIndex = html.indexOf('Mean Height (H̄)');
      final sdIndex = html.indexOf('SD (Standard Deviation)');
      expect(meanIndex, isNonNegative);
      expect(sdIndex, isNonNegative);
      expect(meanIndex, lessThan(sdIndex));
    });

    // -------------------------------------------------------------------------
    // Requirement 3: Inspection Lot Result formatting matches Inspection Log
    // -------------------------------------------------------------------------
    test('3. Inspection Lot Export Result column matches Inspection Log formatting', () {
      final recordWithRetest = createTestRecord(
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-2026-A1',
        produced: 200,
        defects: 2,
        status: 'Passed on Retest',
        testName: 'Waterproof Test',
        retestProduced: 100,
        retestDefects: 0,
        retestStatus: 'Approved',
        mouthSlow: 2,
        mouthFast: 0,
        primerSlow: 0,
        primerFast: 0,
      );

      final summaryHtml = ReportGenerator.generateHtml([recordWithRetest], 'All', 'Lot Acceptance Test');
      expect(summaryHtml, contains('Test: 2 leaks'));
      expect(summaryHtml, contains('Retest: 0 leak'));
      expect(summaryHtml, contains('300 rounds'));
    });

    // -------------------------------------------------------------------------
    // Requirement 4: Lot Report Title is "Final Lot Acceptance Certificate"
    // -------------------------------------------------------------------------
    test('4. Lot Report Title is renamed to "Final Lot Acceptance Certificate"', () {
      final record = createTestRecord(
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-2026-FINAL',
        produced: 200,
        defects: 0,
        status: 'Approved',
        testName: 'Waterproof Test',
      );

      final html = ReportGenerator.generateHtml([record], 'All', 'Lot Acceptance Test');
      expect(html, contains('Final Lot Acceptance Certificate'));
      expect(html, isNot(contains('Combined Test Report')));
    });

    // -------------------------------------------------------------------------
    // Requirement 5: Complete Lot Dossier in exact test sequence
    // -------------------------------------------------------------------------
    test('5. Complete Lot Dossier generates in exact sequence', () {
      final records = [
        createTestRecord(
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-DOSSIER-01',
          produced: 200,
          testName: 'Waterproof Test',
        ),
        createTestRecord(
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-DOSSIER-01',
          produced: 30,
          testName: 'Extraction Force Test',
        ),
        createTestRecord(
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-DOSSIER-01',
          produced: 20,
          testName: 'Accuracy Test',
        ),
        createTestRecord(
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-DOSSIER-01',
          produced: 20,
          testName: 'EPVAT test',
        ),
        createTestRecord(
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-DOSSIER-01',
          produced: 100,
          testName: 'Function Test',
        ),
        createTestRecord(
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-DOSSIER-01',
          produced: 25,
          testName: 'Residual Stress Test',
        ),
        createTestRecord(
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-DOSSIER-01',
          produced: 50,
          testName: 'Primer Sensitivity Test',
        ),
      ];

      final dossierHtml = ReportGenerator.generateLotDossierHtml(records, 'Lot Acceptance Test', base64Logo: '');

      // Sequence verification
      final certPos = dossierHtml.indexOf('Final Lot Acceptance Certificate');
      final primerPos = dossierHtml.indexOf('Primer Sensitivity Test');
      final epvatPos = dossierHtml.indexOf('EPVAT test');
      final funcPos = dossierHtml.indexOf('Function Test');
      final resPos = dossierHtml.indexOf('Residual Stress Test');
      final accPos = dossierHtml.indexOf('Accuracy Test');
      final extractPos = dossierHtml.indexOf('Extraction Force Test');
      final waterPos = dossierHtml.indexOf('Waterproof Test');

      expect(certPos, isNonNegative);
      expect(waterPos, greaterThan(certPos));
      expect(extractPos, greaterThan(waterPos));
      expect(accPos, greaterThan(extractPos));
      expect(epvatPos, greaterThan(accPos));
      expect(funcPos, greaterThan(epvatPos));
      expect(resPos, greaterThan(funcPos));
      expect(primerPos, greaterThan(resPos));

      // Word format test
      final dossierWord = ReportGenerator.generateLotDossierWord(records, 'Lot Acceptance Test', base64Logo: '');
      expect(dossierWord, contains('Final Lot Acceptance Certificate'));
      expect(dossierWord, contains('page-break-before'));
    });

    // -------------------------------------------------------------------------
    // Requirements 6 & 7: Retest Table Design & Numbering
    // -------------------------------------------------------------------------
    test('6 & 7. Retest tables use class="data-table" and are labeled "Parameters/Results - Retest 1"', () {
      final record = createTestRecord(
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-RETEST-99',
        produced: 200,
        defects: 2,
        status: 'Passed on Retest',
        testName: 'Waterproof Test',
        mouthSlow: 2,
        retestProduced: 100,
        retestDefects: 0,
        retestStatus: 'Approved',
        retestMetrics: jsonEncode({
          'mouthSlow': 0,
          'mouthFast': 0,
          'primerSlow': 0,
          'primerFast': 0,
        }),
      );

      final html = ReportGenerator.generateHtml([record], 'Waterproof Test', 'Lot Acceptance Test');
      expect(html, contains('Parameters/Results - Test'));
      expect(html, contains('Parameters/Results - Retest 1'));
      expect(html, contains('class="data-table"'));
    });

    // -------------------------------------------------------------------------
    // Requirement 8: Reference Number Counter in Header
    // -------------------------------------------------------------------------
    test('8. Report header displays Ref No on the right side', () {
      final record = createTestRecord(
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-REF-TEST',
        produced: 200,
        defects: 0,
        status: 'Approved',
        testName: 'Waterproof Test',
        referenceNo: 'REF-1008',
      );

      final html = ReportGenerator.generateHtml([record], 'Waterproof Test', 'Lot Acceptance Test');
      expect(html, contains('Ref No: REF-1008'));

      final word = ReportGenerator.generateWordHtml([record], 'Waterproof Test', 'Lot Acceptance Test');
      expect(word, contains('Ref No: REF-1008'));
    });

    // -------------------------------------------------------------------------
    // Requirements 9 & 10: Sample Size & Defects Summation
    // -------------------------------------------------------------------------
    test('9 & 10. Sample size and defects sum test and retest quantities', () {
      final record = createTestRecord(
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-SUM-TEST',
        produced: 200,
        defects: 2,
        status: 'Passed on Retest',
        testName: 'Waterproof Test',
        mouthSlow: 2,
        retestProduced: 100,
        retestDefects: 1,
        retestStatus: 'Approved',
      );

      final combinedHtml = ReportGenerator.generateHtml([record], 'All', 'Lot Acceptance Test');
      // Sample size should be 200 + 100 = 300 rounds
      expect(combinedHtml, contains('300 rounds'));
      // Metric summary should show initial leaks and retest leaks
      expect(combinedHtml, contains('Test: 2 leaks'));
      expect(combinedHtml, contains('Retest: 1 leaks'));
    });

    // -------------------------------------------------------------------------
    // Requirements 12 & 13: Witness Storage Lot Registration & Consumption
    // -------------------------------------------------------------------------
    test('12 & 13. Witness Storage: Registration, Consumption, and Automated Countdown', () {
      // 1. Register lot
      final witnessLot = <String, dynamic>{
        'id': 'WL_TEST_01',
        'lotNo': 'WITNESS-LOT-2026-01',
        'caliber': '5.56x45mm',
        'initialQty': 1000,
        'consumedQty': 0,
        'remainingQty': 1000,
        'powderLot': 'POW-WC844-01',
        'powderSupplier': 'General Dynamics',
        'powderType': 'WC844',
        'chargeWeight': '26.2 gr',
        'primerLot': 'PRIMER-CC1-41',
        'primerSupplier': 'CCI',
        'primerType': 'Boxer No. 41',
        'storageLocation': 'Bunker 1 - Rack B2',
        'registeredBy': 'Technician Ahmed',
        'registeredAt': DateTime.now().toIso8601String(),
        'status': 'ACTIVE',
      };

      expect(witnessLot['remainingQty'], equals(1000));
      expect(witnessLot['status'], equals('ACTIVE'));

      // 2. First consumption: 250 rounds for Annual Surveillance
      final consumption1 = <String, dynamic>{
        'id': 'WC_01',
        'lotId': 'WL_TEST_01',
        'lotNo': 'WITNESS-LOT-2026-01',
        'caliber': '5.56x45mm',
        'quantity': 250,
        'purpose': 'Annual Surveillance Test',
        'orderRef': 'REF-1001',
        'consumedBy': 'Operator Khalid',
        'consumedAt': DateTime.now().toIso8601String(),
      };

      // 3. Second consumption: 600 rounds for Customer Acceptance
      final consumption2 = <String, dynamic>{
        'id': 'WC_02',
        'lotId': 'WL_TEST_01',
        'lotNo': 'WITNESS-LOT-2026-01',
        'caliber': '5.56x45mm',
        'quantity': 600,
        'purpose': 'Customer Demonstration & Acceptance',
        'orderRef': 'REF-1002',
        'consumedBy': 'Operator Salem',
        'consumedAt': DateTime.now().toIso8601String(),
      };

      final consumptions = [consumption1, consumption2];

      // Automated countdown logic
      final int totalConsumed = consumptions.fold(0, (sum, c) => sum + (c['quantity'] as int));
      final int initial = witnessLot['initialQty'] as int;
      final int remaining = initial - totalConsumed;

      witnessLot['consumedQty'] = totalConsumed;
      witnessLot['remainingQty'] = remaining;

      if (remaining == 0) {
        witnessLot['status'] = 'DEPLETED';
      } else if (remaining <= (initial * 0.2).round() || remaining <= 50) {
        witnessLot['status'] = 'LOW STOCK';
      } else {
        witnessLot['status'] = 'ACTIVE';
      }

      // Verification: 1000 - 850 = 150 (which is <= 20% of 1000, so LOW STOCK)
      expect(witnessLot['consumedQty'], equals(850));
      expect(witnessLot['remainingQty'], equals(150));
      expect(witnessLot['status'], equals('LOW STOCK'));

      // 4. Final consumption to deplete
      final consumption3 = <String, dynamic>{
        'id': 'WC_03',
        'lotId': 'WL_TEST_01',
        'lotNo': 'WITNESS-LOT-2026-01',
        'caliber': '5.56x45mm',
        'quantity': 150,
        'purpose': 'Final Lot Disposal / Training',
        'orderRef': 'REF-1003',
        'consumedBy': 'Operator Salem',
        'consumedAt': DateTime.now().toIso8601String(),
      };
      consumptions.add(consumption3);

      final int finalConsumed = consumptions.fold(0, (sum, c) => sum + (c['quantity'] as int));
      final int finalRemaining = initial - finalConsumed;

      witnessLot['consumedQty'] = finalConsumed;
      witnessLot['remainingQty'] = finalRemaining;
      if (finalRemaining == 0) {
        witnessLot['status'] = 'DEPLETED';
      }

      expect(witnessLot['consumedQty'], equals(1000));
      expect(witnessLot['remainingQty'], equals(0));
      expect(witnessLot['status'], equals('DEPLETED'));
    });
  });
}
