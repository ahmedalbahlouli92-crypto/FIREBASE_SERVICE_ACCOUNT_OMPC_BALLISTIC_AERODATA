import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/report_generator.dart';
import 'package:ompc_ballistic_aerodata/services/epvat_formula_helper.dart';

void main() {
  group('Admin Rules, Certificate Scoping & EPVAT Multi-Temperature Tests', () {
    test('1. Certificate generation for 7.62x51 M80 does NOT leak SS109 dummy data', () {
      final records = <BallisticRecord>[
        BallisticRecord.empty().copyWith(
          testName: 'Waterproof Test',
          lotNo: '010 OMPC/25',
          caliber: '7.62x51 M80',
          produced: 20,
          defects: 0,
          status: 'Approved',
          pressureBar: '1.0',
          viscosity: '20',
          samplingLocation: 'Line 1',
        ),
      ];

      final adminRules = <String, dynamic>{
        'supervisor_name': 'Test Supervisor',
        'manager_name': 'Test Manager',
      };

      final html = ReportGenerator.generateHtml(
        records,
        'All',
        'Lot Acceptance Test',
        adminRules: adminRules,
      );

      // Verify that M80 specs are applied, NOT SS109
      expect(html, contains('7.62X51 M80'));
      expect(html, contains('010 OMPC/25'));
      // M80 extraction requirement is 265 N, not 200 N
      expect(html, contains('265 N'));

      // Check that unperformed tests show '-' and NEVER dummy SS109 numbers
      expect(html, isNot(contains('474.2 N')));
      expect(html, isNot(contains('105.5 mm')));
      expect(html, isNot(contains('119.3 mm')));
      expect(html, isNot(contains('3424.0 Bar')));
      expect(html, isNot(contains('1201.5 Bar')));
      expect(html, isNot(contains('360.50 mm')));
      expect(html, isNot(contains('114.10 mm')));

      // Waterproof was provided and should show 0 leaks
      expect(html, contains('0 leaks'));
    });

    test('2. EpvatFormulaHelper extracts all 3 temperatures from composite record', () {
      final epvRec = BallisticRecord.empty().copyWith(
        testName: 'EPVAT test',
        lotNo: '010 OMPC/25',
        caliber: '7.62x51 M80',
        cartridgeTemp: '+21°C, +52°C, -54°C',
        epvatMeanPressure: '3500',
        epvatPressureRounds: 'mean=3500,max=3600,min=3400,sd=50;mean=3700,max=3800,min=3600,sd=60;mean=3300,max=3400,min=3200,sd=45',
        epvatP2PressureRounds: 'mean=300,max=320,min=280,sd=10;mean=310,max=330,min=290,sd=12;mean=290,max=310,min=270,sd=11',
        epvatVelRounds: 'mean=830,max=840,min=820,sd=5;mean=850,max=860,min=840,sd=6;mean=810,max=820,min=800,sd=5',
        actionTimeRounds: 'mean=1.2,sd=0.05;mean=1.1,sd=0.04;mean=1.3,sd=0.06',
      );

      final vars = EpvatFormulaHelper.extractVariablesFromRecords([epvRec]);

      // Check +21 °C vars
      expect(vars['p1_mean_21'], 3500.0);
      expect(vars['p2_mean_21'], 300.0);
      expect(vars['vel_mean_21'], 830.0);

      // Check +52 °C vars
      expect(vars['p1_mean_52'], 3700.0);
      expect(vars['p2_mean_52'], 310.0);
      expect(vars['vel_mean_52'], 850.0);

      // Check -54 °C vars
      expect(vars['p1_mean_54'], 3300.0);
      expect(vars['p2_mean_54'], 290.0);
      expect(vars['vel_mean_54'], 810.0);
    });

    test('3. Certificate filters strictly by lot and caliber without mixing', () {
      final m80Rec = BallisticRecord.empty().copyWith(
        testName: 'Waterproof Test',
        lotNo: '010 OMPC/25',
        caliber: '7.62x51 M80',
        produced: 20,
        defects: 0,
        status: 'Approved',
      );
      final ss109Rec = BallisticRecord.empty().copyWith(
        testName: 'Extraction Force Test',
        lotNo: '099 OMPC/25',
        caliber: '5.56x45 SS109',
        produced: 20,
        defects: 0,
        status: 'Approved',
        accMeanX: '488.5',
      );

      final html = ReportGenerator.generateHtml(
        [m80Rec, ss109Rec],
        'All',
        'Lot Acceptance Test',
      );

      // When m80 is the first record, the SS109 extraction test value must NOT leak into the M80 certificate
      expect(html, isNot(contains('488.5')));
      // Extraction for M80 should be '-'
      expect(html, contains('265 N'));
    });
  });
}
