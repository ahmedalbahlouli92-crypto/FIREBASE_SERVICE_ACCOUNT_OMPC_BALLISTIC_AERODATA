import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/ai_analysis_service.dart';
import 'package:ompc_ballistic_aerodata/services/epvat_formula_helper.dart';
import 'package:ompc_ballistic_aerodata/services/storage_service.dart';

BallisticRecord createTestRecord({
  required String timestamp,
  required String testName,
  required String caliber,
  required String lotNo,
  required int produced,
  int defects = 0,
  String status = 'Approved',
  String notes = '',
  int mouthSlow = 0,
  int mouthFast = 0,
  int primerSlow = 0,
  int primerFast = 0,
  String cartridgeTemp = '',
  String epvatMeanPressure = '',
  String epvatMaxPressure = '',
  String epvatMinPressure = '',
  String epvatSDPressure = '',
  String velMean = '',
  String velSD = '',
  String epvatSensor1 = '',
  String epvatSensor2 = '',
}) {
  return BallisticRecord(
    timestamp: timestamp,
    operators: 'Inspector Tech',
    shift: 'A (06:00 - 14:00)',
    caliber: caliber,
    lotNo: lotNo,
    produced: produced,
    defects: defects,
    notes: notes,
    status: status,
    testName: testName,
    pressureBar: '',
    viscosity: '',
    testTime: '10:00',
    samplingLocation: 'Range A',
    mouthSlow: mouthSlow,
    mouthFast: mouthFast,
    primerSlow: primerSlow,
    primerFast: primerFast,
    hopperNo: '',
    boxNo: '',
    requirement: '',
    cartridgeTemp: cartridgeTemp,
    epvatMeanPressure: epvatMeanPressure,
    epvatMaxPressure: epvatMaxPressure,
    epvatMinPressure: epvatMinPressure,
    epvatSDPressure: epvatSDPressure,
    velMean: velMean,
    velSD: velSD,
    epvatSensor1: epvatSensor1,
    epvatSensor2: epvatSensor2,
  );
}

void main() {
  group('AI Analysis & Recommendation Engine Tests', () {
    test('1. AiAnalysisService analyzes Waterproof Test and detects leaks', () {
      final r = createTestRecord(
        timestamp: '2026-09-17 10:00:00',
        testName: 'Waterproof Test',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-WP-01',
        produced: 50,
        defects: 5,
        status: 'Retest',
        mouthSlow: 2,
        mouthFast: 1,
        primerSlow: 1,
        primerFast: 1,
      );

      final rec = AiAnalysisService.instance.analyzeRecord(r);
      expect(rec.testName, equals('Waterproof Test'));
      expect(rec.findings.isNotEmpty, isTrue);
      expect(rec.recommendations.isNotEmpty, isTrue);
      expect(rec.keyMetrics['Total Leaks'], equals('5'));
      expect(rec.keyMetrics['Sample Size'], equals('50 rounds'));
    });

    test('2. AiAnalysisService analyzes EPVAT Test and computes kinetic energy & 3-Sigma', () {
      final r = createTestRecord(
        timestamp: '2026-09-17 10:30:00',
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-EPV-01',
        produced: 30,
        cartridgeTemp: '+21°C',
        epvatMeanPressure: '360.5',
        epvatMaxPressure: '375.0',
        epvatMinPressure: '348.0',
        epvatSDPressure: '7.2',
        velMean: '942.0',
        velSD: '3.5',
      );

      final rec = AiAnalysisService.instance.analyzeRecord(r);
      expect(rec.testName, contains('EPVAT'));
      expect(rec.keyMetrics.containsKey('P1 Max'), isTrue);
      expect(rec.keyMetrics.containsKey('Velocity Mean'), isTrue);
      expect(rec.findings.any((f) => f.contains('P1 Chamber Pressure')), isTrue);
    });

    test('3. AiAnalysisService analyzes 1-Week Stability and detects rising leaks trend', () {
      final records = <BallisticRecord>[
        createTestRecord(
          timestamp: '2026-09-11 10:00:00',
          testName: 'Waterproof Test',
          caliber: '5.56x45 SS109',
          lotNo: 'L1',
          produced: 50,
          mouthSlow: 0,
          mouthFast: 0,
        ),
        createTestRecord(
          timestamp: '2026-09-12 10:00:00',
          testName: 'Waterproof Test',
          caliber: '5.56x45 SS109',
          lotNo: 'L2',
          produced: 50,
          mouthSlow: 1,
          mouthFast: 0,
        ),
        createTestRecord(
          timestamp: '2026-09-13 10:00:00',
          testName: 'Waterproof Test',
          caliber: '5.56x45 SS109',
          lotNo: 'L3',
          produced: 50,
          mouthSlow: 1,
          mouthFast: 1,
        ),
        createTestRecord(
          timestamp: '2026-09-14 10:00:00',
          testName: 'Waterproof Test',
          caliber: '5.56x45 SS109',
          lotNo: 'L4',
          produced: 50,
          status: 'Retest',
          mouthSlow: 2,
          mouthFast: 2,
        ),
      ];

      final weekly = AiAnalysisService.instance.analyzeWeeklyStability(records);
      expect(weekly.dailyLeaks.isNotEmpty, isTrue);
      expect(weekly.isLeaksIncreasing, isTrue);
      expect(weekly.criticalAlerts.any((a) => a.toLowerCase().contains('leak')), isTrue);
      expect(weekly.actionableAdvice.isNotEmpty, isTrue);
    });

    test('4. BallisticRecord.consolidateRecords unifies multiple temperature rows into one test record with sum of sample sizes', () {
      final splitRecords = <BallisticRecord>[
        createTestRecord(
          timestamp: '2026-09-17 11:00:00',
          testName: 'EPVAT test',
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-MULTI-01',
          produced: 30,
          notes: 'Amb Temp',
          cartridgeTemp: '+21°C',
          epvatMeanPressure: '360.0',
        ),
        createTestRecord(
          timestamp: '2026-09-17 11:01:00',
          testName: 'EPVAT test',
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-MULTI-01',
          produced: 30,
          notes: 'Cold Temp',
          cartridgeTemp: '-54°C',
          epvatMeanPressure: '340.0',
        ),
        createTestRecord(
          timestamp: '2026-09-17 11:02:00',
          testName: 'EPVAT test',
          caliber: '5.56x45 SS109',
          lotNo: 'LOT-MULTI-01',
          produced: 30,
          notes: 'Hot Temp',
          cartridgeTemp: '+52°C',
          epvatMeanPressure: '380.0',
        ),
      ];

      final consolidated = BallisticRecord.consolidateRecords(splitRecords);
      expect(consolidated.length, equals(1));
      expect(consolidated.first.produced, equals(90)); // 30 + 30 + 30 = 90 rounds
      expect(consolidated.first.cartridgeTemp, contains('+21°C'));
      expect(consolidated.first.cartridgeTemp, contains('-54°C'));
      expect(consolidated.first.cartridgeTemp, contains('+52°C'));
    });

    test('5. EpvatFormulaHelper resolves SS109 formulas seamlessly whether queried as 5.56x45 SS109 or SS109', () {
      final customFormulas = {
        '5.56x45 SS109': [
          {
            'name': 'P1 Max Individual (+21°C)',
            'formula': 'P1_MAX_INDIVIDUAL',
            'operator': '<=',
            'limit': '4200',
            'unit': 'bar',
          },
          {
            'name': 'P1 Mean + 3SD (+21°C)',
            'formula': 'P1_MEAN + 3 * P1_SD',
            'operator': '<=',
            'limit': '4200',
            'unit': 'bar',
          },
        ]
      };

      // Query with full name
      final formulasFull = EpvatFormulaHelper.getFormulasForCaliber(customFormulas, '5.56x45 SS109');
      expect(formulasFull.length, equals(2));
      expect(formulasFull.first['name'], equals('P1 Max Individual (+21°C)'));

      // Query with short name
      final formulasShort = EpvatFormulaHelper.getFormulasForCaliber(customFormulas, 'SS109');
      expect(formulasShort.length, equals(2));
      expect(formulasShort.first['name'], equals('P1 Max Individual (+21°C)'));

      // Evaluate formula
      final vars = {
        'P1_MAX_INDIVIDUAL': 4150.0,
        'P1_MEAN': 3800.0,
        'P1_SD': 80.0,
      };
      final eval = EpvatFormulaHelper.evaluateFormulaItem(formulasFull.first, vars);
      expect(eval.isPassed, isTrue);
      expect(eval.calculatedValue, equals(4150.0));
    });

    test('6. Unified GP6 transducer tracks cumulative rounds whether mounted as GP6 (1) Chamber or GP6 (2) Port', () {
      final r1 = createTestRecord(
        timestamp: '2026-09-20 10:00:00',
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-01',
        produced: 30,
        epvatSensor1: 'GP6-Kistler-8801', // Mounted in Chamber (GP6-1)
        epvatSensor2: 'GP6-PCB-9901',     // Mounted in Port (GP6-2)
      );

      final r2 = createTestRecord(
        timestamp: '2026-09-21 10:00:00',
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-02',
        produced: 20,
        epvatSensor1: 'GP6-PCB-9901',     // Mounted in Chamber (GP6-1)
        epvatSensor2: 'GP6-Kistler-8801', // Mounted in Port (GP6-2)
      );

      final List<BallisticRecord> records = [r1, r2];
      final storage = StorageService();

      // GP6-Kistler-8801 was used in r1 (30 rounds) and r2 (20 rounds) = 50 rounds total
      expect(storage.calculateAssetRounds(records, 'GP6-Kistler-8801'), equals(50));
      // GP6-PCB-9901 was used in r1 (30 rounds) and r2 (20 rounds) = 50 rounds total
      expect(storage.calculateAssetRounds(records, 'GP6-PCB-9901'), equals(50));
    });
  });
}
