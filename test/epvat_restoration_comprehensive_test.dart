import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/services/epvat_formula_helper.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';

void main() {
  group('EPVAT Calculation Restoration & Precision Tests', () {
    test('1. Resolves and evaluates NATO P1_MAX_INDIVIDUAL correctly', () {
      final item = {
        'name': 'P1 Max Individual (+21°C)',
        'formula': 'P1_MAX_INDIVIDUAL',
        'operator': '<=',
        'limit': '4200',
        'unit': 'bar',
      };
      final vars = {
        'p1_max_21': 3780.0,
      };
      final res = EpvatFormulaHelper.evaluateFormulaItem(item, vars, defaultTemp: '21');
      expect(res.isPassed, isTrue);
      expect(res.calculatedValue, equals(3780.0));
      expect(res.substitutedText, equals('3780'));
    });

    test('2. Resolves and evaluates P1_MEAN + 3 * P1_SD without zeroing out', () {
      final item = {
        'name': 'P1 3-Sigma (+21°C)',
        'formula': 'P1_MEAN + 3 * P1_SD',
        'operator': '<=',
        'limit': '3800',
        'unit': 'bar',
      };
      final vars = {
        'p1_mean_21': 3450.0,
        'p1_sd_21': 80.0,
      };
      final res = EpvatFormulaHelper.evaluateFormulaItem(item, vars, defaultTemp: '21');
      expect(res.isPassed, isTrue);
      expect(res.calculatedValue, equals(3450.0 + 3.0 * 80.0)); // 3690.0
      expect(res.substitutedText, contains('3450 + 3 * 80 = 3690'));
    });

    test('3. Resolves and evaluates P2_MEAN - 3 * P2_SD correctly', () {
      final item = {
        'name': 'P2 3-Sigma Lower Bound',
        'formula': 'P2_MEAN - 3 * P2_SD',
        'operator': '>=',
        'limit': '400',
        'unit': 'bar',
      };
      final vars = {
        'p2_mean_21': 650.0,
        'p2_sd_21': 35.0,
      };
      final res = EpvatFormulaHelper.evaluateFormulaItem(item, vars, defaultTemp: '21');
      expect(res.isPassed, isTrue);
      expect(res.calculatedValue, equals(650.0 - 3.0 * 35.0)); // 545.0
      expect(res.substitutedText, contains('650 - 3 * 35 = 545'));
    });

    test('4. Evaluates Action Time Mean and ACTION_TIME_MEAN correctly', () {
      final item1 = {
        'name': 'Action Time Limit',
        'formula': 'Action Time Mean',
        'operator': '<=',
        'limit': '4.0',
        'unit': 'ms',
      };
      final vars = {
        'action_time_mean_21': 2.35,
      };
      final res1 = EpvatFormulaHelper.evaluateFormulaItem(item1, vars, defaultTemp: '21');
      expect(res1.isPassed, isTrue);
      expect(res1.calculatedValue, equals(2.35));

      final item2 = {
        'name': 'Action Time Code Limit',
        'formula': 'ACTION_TIME_MEAN <= 4.0',
        'operator': '<=',
        'limit': '4.0',
        'unit': 'ms',
      };
      final res2 = EpvatFormulaHelper.evaluateFormulaItem(item2, vars, defaultTemp: '21');
      expect(res2.isPassed, isTrue);
      expect(res2.calculatedValue, equals(2.35));
    });

    test('5. Multi-temperature cross-delta formula abs(P1 Mean @ 21 - P1 Mean @ 52)', () {
      final item = {
        'name': 'P1 Temperature Shift Delta',
        'formula': 'abs(P1 Mean @ 21 - P1 Mean @ 52)',
        'operator': '<=',
        'limit': '450',
        'unit': 'bar',
      };
      final vars = {
        'p1_mean_21': 3450.0,
        'p1_mean_52': 3720.0,
      };
      final res = EpvatFormulaHelper.evaluateFormulaItem(item, vars);
      expect(res.isPassed, isTrue);
      expect(res.calculatedValue, equals(270.0));
      expect(res.substitutedText, contains('|3450 - 3720| = 270'));
    });

    test('6. extractVariablesFromRecords correctly parses rich notes string', () {
      final r = BallisticRecord(
        timestamp: '2026-09-27 12:00:00',
        operators: 'Inspector',
        shift: 'Day',
        caliber: '5.56x45 SS109',
        lotNo: '001/26',
        produced: 90,
        defects: 0,
        notes: 'Temps: +21°C (30 rds: P1=3450, Max=3620, Min=3310, SD=65, P2=640, P2Max=680, P2Min=610, P2SD=18, V=925, VMax=935, VMin=915, VSD=5.2, AT=2.30, ATSD=0.15); +52°C (30 rds: P1=3720, Max=3890, Min=3550, SD=72, P2=690, P2Max=720, P2Min=660, P2SD=15, V=940, VMax=950, VMin=930, VSD=5.0, AT=2.10, ATSD=0.12)',
        status: 'Approved',
        testName: 'EPVAT test',
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
        barrelSN: 'B1',
        barrelType: '',
        velocityDistance: '25',
        extractionForceType: '',
        extractionForceRounds: '',
        cartridgeTemp: '+21, +52',
        epvatPressureType: 'Overall',
        epvatPressureUnit: 'bar',
        epvatPressureRounds: '',
        epvatMeanPressure: '3450',
        epvatMaxPressure: '3620',
        epvatMinPressure: '3310',
        epvatRangePressure: '310',
        epvatSDPressure: '65',
        epvatP2MeanPressure: '640',
        epvatP2MaxPressure: '680',
        epvatP2MinPressure: '610',
        epvatP2RangePressure: '70',
        epvatP2SDPressure: '18',
        epvatP2PressureRounds: '',
        epvatVelRounds: '',
        velMean: '925',
        velMax: '935',
        velMin: '915',
        velRange: '20',
        velSD: '5.2',
        actionTimeMean: '2.30',
        actionTimeMax: '2.50',
        actionTimeMin: '2.10',
        actionTimeRange: '0.40',
        actionTimeSD: '0.15',
        actionTimeRounds: '',
      );

      final vars = EpvatFormulaHelper.extractVariablesFromRecords([r]);
      expect(vars['p1_mean_21'], equals(3450.0));
      expect(vars['p1_max_21'], equals(3620.0));
      expect(vars['p1_sd_21'], equals(65.0));
      expect(vars['p2_mean_21'], equals(640.0));
      expect(vars['vel_mean_21'], equals(925.0));
      expect(vars['action_time_mean_21'], equals(2.30));

      expect(vars['p1_mean_52'], equals(3720.0));
      expect(vars['p1_max_52'], equals(3890.0));
      expect(vars['p1_sd_52'], equals(72.0));
      expect(vars['p2_mean_52'], equals(690.0));
      expect(vars['vel_mean_52'], equals(940.0));
      expect(vars['action_time_mean_52'], equals(2.10));
    });

    test('7. Pressure unit conversion properly handles bar, MPa, and kg/cm²', () {
      expect(EpvatFormulaHelper.convertPressure(100.0, 'bar', 'MPa'), closeTo(10.0, 0.001));
      expect(EpvatFormulaHelper.convertPressure(10.0, 'MPa', 'bar'), closeTo(100.0, 0.001));
      expect(EpvatFormulaHelper.convertPressure(3800.0, 'bar', 'bar'), equals(3800.0));
    });

    test('8. Dynamic blank cartridge temperature extraction (-32°C instead of -54°C)', () {
      final r = BallisticRecord.empty().copyWith(
        testName: 'EPVAT test',
        cartridgeTemp: '-32',
        epvatMeanPressure: '2200',
        epvatMaxPressure: '2350',
        epvatSDPressure: '45',
      );
      final vars = EpvatFormulaHelper.extractVariablesFromRecords([r]);
      expect(vars['p1_mean_32'], equals(2200.0));
      expect(vars['p1_max_32'], equals(2350.0));
      expect(vars['p1_sd_32'], equals(45.0));
      // Baseline fallbacks populated
      expect(vars['p1_mean'], equals(2200.0));
      expect(vars['p1_max_individual'], equals(2350.0));
    });
  });
}
