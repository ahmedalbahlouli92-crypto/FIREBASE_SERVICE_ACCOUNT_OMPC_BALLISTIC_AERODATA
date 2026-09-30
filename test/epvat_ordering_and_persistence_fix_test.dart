import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/epvat_formula_helper.dart';

void main() {
  group('EPVAT Parameter Order, Formulas & Quality Sentencing Tests', () {
    test('1. 9x19mm Para with zero P2 passes when P1 formulas pass', () {
      // 9mm record with no P2 (pistol ammo)
      final record = BallisticRecord.empty().copyWith(
        timestamp: '2026-09-30 10:00:00',
        operators: 'Test Operator',
        shift: 'Day',
        caliber: '9x19mm Para',
        lotNo: 'LOT-9MM-001',
        produced: 30,
        defects: 0,
        notes: '',
        status: 'Approved',
        testName: 'EPVAT test',
        cartridgeTemp: '+21',
        epvatMeanPressure: '2350',
        epvatMaxPressure: '2500',
        epvatMinPressure: '2200',
        epvatRangePressure: '300',
        epvatSDPressure: '45',
        // P2 is 0 or empty for 9mm
        epvatP2MeanPressure: '',
        epvatP2MaxPressure: '',
        epvatP2MinPressure: '',
        epvatP2RangePressure: '',
        epvatP2SDPressure: '',
        velMean: '385',
        velMax: '395',
        velMin: '375',
        velRange: '20',
        velSD: '3.5',
        actionTimeMean: '1.25',
        actionTimeMax: '1.35',
        actionTimeMin: '1.15',
        actionTimeRange: '0.20',
        actionTimeSD: '0.04',
      );

      final vars = EpvatFormulaHelper.extractVariablesFromRecords([record]);

      // Formulas map for 9x19mm Para (from default rules)
      final formulas = EpvatFormulaHelper.getFormulasForCaliber({
        '9x19mm Para': [
          {
            'name': 'P1 Max Individual (+21°C)',
            'formula': 'P1_MAX_INDIVIDUAL',
            'operator': '<=',
            'limit': '2650',
            'unit': 'bar',
          },
          {
            'name': 'P1 Mean + 3SD (+21°C)',
            'formula': 'P1_MEAN + 3 * P1_SD',
            'operator': '<=',
            'limit': '2650',
            'unit': 'bar',
          }
        ]
      }, '9x19mm Para');

      expect(formulas.length, 2);

      for (final f in formulas) {
        final res = EpvatFormulaHelper.evaluateFormulaItem(f, vars, defaultTemp: '+21');
        expect(res.isPassed, isTrue, reason: '${res.name} should pass: ${res.substitutedText} vs ${res.limitValue}');
      }
    });

    test('2. Formula requiring P2 is marked not applicable when caliber does not measure P2', () {
      final record = BallisticRecord.empty().copyWith(
        timestamp: '2026-09-30 10:00:00',
        operators: 'Test Operator',
        shift: 'Day',
        caliber: '9x19mm Para',
        lotNo: 'LOT-9MM-002',
        produced: 30,
        defects: 0,
        notes: '',
        status: 'Approved',
        testName: 'EPVAT test',
        cartridgeTemp: '+21',
        epvatMeanPressure: '2350',
        epvatMaxPressure: '2500',
        epvatMinPressure: '2200',
        epvatRangePressure: '300',
        epvatSDPressure: '45',
        epvatP2MeanPressure: '0',
        epvatP2MaxPressure: '0',
        velMean: '385',
      );

      final vars = EpvatFormulaHelper.extractVariablesFromRecords([record]);

      // If a formula requiring P2 is tested against a 0-P2 record:
      final p2Formula = {
        'name': 'P2 Port Mean - 3SD (+21°C)',
        'formula': 'P2_MEAN - 3 * P2_SD',
        'operator': '>=',
        'limit': '180',
        'unit': 'bar',
      };

      final res = EpvatFormulaHelper.evaluateFormulaItem(p2Formula, vars, defaultTemp: '+21');
      expect(res.isApplicable, isFalse);
      expect(res.isPassed, isTrue); // Inapplicable formula should not cause rejection
      expect(res.substitutedText, contains('No P2'));
    });

    test('3. 5.56x45 SS109 3-sigma passes with NATO standard 4200 bar limit', () {
      // 5.56 SS109 record with Mean = 3750, SD = 60 => Mean + 3SD = 3930 bar (exceeds 3800, but <= 4200)
      final record = BallisticRecord.empty().copyWith(
        timestamp: '2026-09-30 10:00:00',
        operators: 'Test Operator',
        shift: 'Day',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-SS109-001',
        produced: 30,
        defects: 0,
        notes: '',
        status: 'Approved',
        testName: 'EPVAT test',
        cartridgeTemp: '+21',
        epvatMeanPressure: '3750',
        epvatMaxPressure: '3950',
        epvatMinPressure: '3600',
        epvatRangePressure: '350',
        epvatSDPressure: '60',
        epvatP2MeanPressure: '650',
        epvatP2MaxPressure: '720',
        epvatP2MinPressure: '580',
        epvatP2RangePressure: '140',
        epvatP2SDPressure: '25',
        velMean: '920',
        actionTimeMean: '1.20',
      );

      final vars = EpvatFormulaHelper.extractVariablesFromRecords([record]);
      final defaultFormulas = EpvatFormulaHelper.getDefaultFormulas(isThreeTemp: false);
      
      final threeSigmaRule = defaultFormulas.firstWhere((f) => f['name'].toString().contains('3-Sigma'));
      final res = EpvatFormulaHelper.evaluateFormulaItem(threeSigmaRule, vars, defaultTemp: '+21');

      // Mean (3750) + 3*SD (180) = 3930 bar. Limit is 4200 bar, so this MUST pass!
      expect(res.calculatedValue, closeTo(3930, 0.1));
      expect(res.limitValue, closeTo(4200, 0.1));
      expect(res.isPassed, isTrue);
    });
  });
}
