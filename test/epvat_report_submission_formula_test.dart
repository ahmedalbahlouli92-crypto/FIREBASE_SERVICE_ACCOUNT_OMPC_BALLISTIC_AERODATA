import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/epvat_formula_helper.dart';
import 'package:ompc_ballistic_aerodata/services/report_generator.dart';

void main() {
  group('EPVAT Multi-Temp Submission and Report Formula Evaluation Tests', () {
    test('1. Normalizes all 11 user attachment formulas including Action Time', () {
      final formulas = [
        'Mean P1 @21 + 5*SD P1 @21',
        'Mean P1 @52',
        'Mean P1 @54',
        'Mean P2 @21 - 3*SD P2 @21',
        'Mean P2 @52 - 3*SD P2 @52',
        'Mean P2 @ 54',
        'Mean P2 @52 - Mean P2 @21',
        'Mean P2 @54 - Mean P2 @21',
        'Mean Vel @52 - Mean Vel @21',
        'Mean Vel @54 - Mean Vel @21',
        'Mean Action Time @-54 + 5* SD Action Time @-54',
      ];

      final expected = [
        'p1_mean_21 + 5*p1_sd_21',
        'p1_mean_52',
        'p1_mean_54',
        'p2_mean_21 - 3*p2_sd_21',
        'p2_mean_52 - 3*p2_sd_52',
        'p2_mean_54',
        'p2_mean_52 - p2_mean_21',
        'p2_mean_54 - p2_mean_21',
        'vel_mean_52 - vel_mean_21',
        'vel_mean_54 - vel_mean_21',
        'action_time_mean_54 + 5* action_time_sd_54',
      ];

      for (int i = 0; i < formulas.length; i++) {
        final norm = EpvatFormulaHelper.normalizeFormula(formulas[i], defaultTemp: '21');
        expect(norm, expected[i], reason: 'Failed for formula: ${formulas[i]}');
      }
    });

    test('2. Correctly extracts variables from a submitted multi-temperature EPVAT record', () {
      final record = BallisticRecord.empty().copyWith(
        cartridgeTemp: '+21°C, +52°C, -54°C',
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        epvatMeanPressure: '3500',
        epvatSDPressure: '100',
        epvatP2MeanPressure: '1200',
        epvatP2SDPressure: '10',
        velMean: '915',
        notes: 'Temps: '
            '+21°C (30 rds: P1=3500, Max=3700, P1Min=3400, SD=100, P2=1200, P2Max=1250, P2Min=1150, P2SD=10, V=915, VMax=925, VMin=905, VSD=5, AT=0.35, ATSD=0.04); '
            '+52°C (30 rds: P1=3800, Max=4100, P1Min=3600, SD=90, P2=1350, P2Max=1400, P2Min=1300, P2SD=11, V=925, VMax=935, VMin=915, VSD=6, AT=0.36, ATSD=0.03); '
            '-54°C (30 rds: P1=3300, Max=3500, P1Min=3200, SD=85, P2=1070, P2Max=1100, P2Min=1040, P2SD=9, V=895, VMax=905, VMin=885, VSD=7, AT=0.38, ATSD=0.05)',
      );

      final vars = EpvatFormulaHelper.extractVariablesFromRecords([record]);

      // Check baseline +21 values
      expect(vars['p1_mean_21'], 3500.0);
      expect(vars['p1_sd_21'], 100.0);
      expect(vars['p2_mean_21'], 1200.0);
      expect(vars['p2_sd_21'], 10.0);
      expect(vars['vel_mean_21'], 915.0);

      // Check +52 values
      expect(vars['p1_mean_52'], 3800.0);
      expect(vars['p1_sd_52'], 90.0);
      expect(vars['p2_mean_52'], 1350.0);
      expect(vars['p2_sd_52'], 11.0);
      expect(vars['vel_mean_52'], 925.0);

      // Check -54 values
      expect(vars['p1_mean_54'], 3300.0);
      expect(vars['p1_sd_54'], 85.0);
      expect(vars['p2_mean_54'], 1070.0);
      expect(vars['p2_sd_54'], 9.0);
      expect(vars['vel_mean_54'], 895.0);
      expect(vars['action_time_mean_54'], 0.38);
      expect(vars['action_time_sd_54'], 0.05);
    });

    test('3. Generates substituted calculations without 0 or 52 54 leakage', () {
      final record = BallisticRecord.empty().copyWith(
        cartridgeTemp: '+21°C, +52°C, -54°C',
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        epvatMeanPressure: '3500',
        epvatSDPressure: '100',
        epvatP2MeanPressure: '1200',
        epvatP2SDPressure: '10',
        velMean: '915',
        notes: 'Temps: '
            '+21°C (30 rds: P1=3500, Max=3700, P1Min=3400, SD=100, P2=1200, P2Max=1250, P2Min=1150, P2SD=10, V=915, VMax=925, VMin=905, VSD=5, AT=0.35, ATSD=0.04); '
            '+52°C (30 rds: P1=3800, Max=4100, P1Min=3600, SD=90, P2=1350, P2Max=1400, P2Min=1300, P2SD=11, V=925, VMax=935, VMin=915, VSD=6, AT=0.36, ATSD=0.03); '
            '-54°C (30 rds: P1=3300, Max=3500, P1Min=3200, SD=85, P2=1070, P2Max=1100, P2Min=1040, P2SD=9, V=895, VMax=905, VMin=885, VSD=7, AT=0.38, ATSD=0.05)',
      );

      final vars = EpvatFormulaHelper.extractVariablesFromRecords([record]);

      final subP1_21 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P1 @21 + 5*SD P1 @21', vars, defaultTemp: '21');
      expect(subP1_21, '3500 + 5 * 100 = 4000');

      final subP1_52 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P1 @52', vars, defaultTemp: '21');
      expect(subP1_52, '3800 = 3800');

      final subP1_54 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P1 @54', vars, defaultTemp: '21');
      expect(subP1_54, '3300 = 3300');

      final subP2_21 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P2 @21 - 3*SD P2 @21', vars, defaultTemp: '21');
      expect(subP2_21, '1200 - 3 * 10 = 1170');

      final subP2_52 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P2 @52 - 3*SD P2 @52', vars, defaultTemp: '21');
      expect(subP2_52, '1350 - 3 * 11 = 1317');

      final subP2_54 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P2 @ 54', vars, defaultTemp: '21');
      expect(subP2_54, '1070 = 1070');

      final subP2Diff52 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P2 @52 - Mean P2 @21', vars, defaultTemp: '21');
      expect(subP2Diff52, '1350 - 1200 = 150');

      final subP2Diff54 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean P2 @54 - Mean P2 @21', vars, defaultTemp: '21');
      expect(subP2Diff54, '1070 - 1200 = -130');

      final subVelDiff52 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean Vel @52 - Mean Vel @21', vars, defaultTemp: '21');
      expect(subVelDiff52, '925 - 915 = 10');

      final subVelDiff54 = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean Vel @54 - Mean Vel @21', vars, defaultTemp: '21');
      expect(subVelDiff54, '895 - 915 = -20');

      final subActionTime = EpvatFormulaHelper.buildSubstitutedArithmetic('Mean Action Time @-54 + 5* SD Action Time @-54', vars, defaultTemp: '21');
      expect(subActionTime, '0.38 + 5 * 0.05 = 0.63');
      expect(subActionTime.contains('52 54'), isFalse);
      expect(subActionTime.contains('Action Time'), isFalse);
    });

    test('4. Full HTML report generation renders correct EPVAT section', () {
      final record = BallisticRecord.empty().copyWith(
        cartridgeTemp: '+21°C, +52°C, -54°C',
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        epvatMeanPressure: '3500',
        epvatSDPressure: '100',
        epvatP2MeanPressure: '1200',
        epvatP2SDPressure: '10',
        velMean: '915',
        notes: 'Temps: '
            '+21°C (30 rds: P1=3500, Max=3700, P1Min=3400, SD=100, P2=1200, P2Max=1250, P2Min=1150, P2SD=10, V=915, VMax=925, VMin=905, VSD=5, AT=0.35, ATSD=0.04); '
            '+52°C (30 rds: P1=3800, Max=4100, P1Min=3600, SD=90, P2=1350, P2Max=1400, P2Min=1300, P2SD=11, V=925, VMax=935, VMin=915, VSD=6, AT=0.36, ATSD=0.03); '
            '-54°C (30 rds: P1=3300, Max=3500, P1Min=3200, SD=85, P2=1070, P2Max=1100, P2Min=1040, P2SD=9, V=895, VMax=905, VMin=885, VSD=7, AT=0.38, ATSD=0.05)',
      );

      final adminRules = {
        'epvat': {
          'custom_formulas': {
            'SS109': [
              {
                'name': 'Chmaber Pressure +21',
                'formula': 'Mean P1 @21 + 5*SD P1 @21',
                'operator': '<=',
                'limit': '4450.0',
                'unit': 'bar',
              },
              {
                'name': 'chamber Pressure +52',
                'formula': 'Mean P1 @52',
                'operator': '<=',
                'limit': '4550.0',
                'unit': 'bar',
              },
              {
                'name': 'Chmaber Pressure -54',
                'formula': 'Mean P1 @54',
                'operator': '<=',
                'limit': '4550.0',
                'unit': 'bar',
              },
              {
                'name': 'Port Pressure +21',
                'formula': 'Mean P2 @21 - 3*SD P2 @21',
                'operator': '>=',
                'limit': '1030.0',
                'unit': 'bar',
              },
              {
                'name': 'Port Pressure +52',
                'formula': 'Mean P2 @52 - 3*SD P2 @52',
                'operator': '>=',
                'limit': '1030.0',
                'unit': 'bar',
              },
              {
                'name': 'Port Pressure -54',
                'formula': 'Mean P2 @ 54',
                'operator': '>=',
                'limit': '1030.0',
                'unit': 'bar',
              },
              {
                'name': 'Port Pressure diff +52/+21',
                'formula': 'Mean P2 @52 - Mean P2 @21',
                'operator': '<=',
                'limit': '150.0',
                'unit': 'bar',
              },
              {
                'name': 'Port Pressure diff -54/+21',
                'formula': 'Mean P2 @54 - Mean P2 @21',
                'operator': '<=',
                'limit': '150.0',
                'unit': 'bar',
              },
              {
                'name': 'Speed Diff +52/+21',
                'formula': 'Mean Vel @52 - Mean Vel @21',
                'operator': '<=',
                'limit': '50.0',
                'unit': 'm/s',
              },
              {
                'name': 'Speed diff -54/+21',
                'formula': 'Mean Vel @54 - Mean Vel @21',
                'operator': '<=',
                'limit': '-80.0',
                'unit': 'm/s',
              },
              {
                'name': 'Action time',
                'formula': 'Mean Action Time @-54 + 5* SD Action Time @-54',
                'operator': '<=',
                'limit': '3.0',
                'unit': 'ms',
              },
            ],
          },
        },
      };

      final html = ReportGenerator.generateHtml(
        [record],
        'EPVAT test',
        'Lot Acceptance Test',
        adminRules: adminRules,
      );

      expect(html.contains('4000.0 bar'), isTrue);
      expect(html.contains('3800.0 bar'), isTrue);
      expect(html.contains('3300.0 bar'), isTrue);
      expect(html.contains('1170.0 bar'), isTrue);
      expect(html.contains('1317.0 bar'), isTrue);
      expect(html.contains('1070.0 bar'), isTrue);
      expect(html.contains('150.0 bar'), isTrue);
      expect(html.contains('-130.0 bar'), isTrue);
      expect(html.contains('10.0 m/s'), isTrue);
      expect(html.contains('-20.0 m/s'), isTrue);
      expect(html.contains('0.6 ms'), isTrue);
      expect(html.contains('0 52 54 Action Time'), isFalse);
    });
  });
}
