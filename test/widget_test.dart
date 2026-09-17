import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ompc_ballistic_aerodata/main.dart';
import 'package:ompc_ballistic_aerodata/screens/entry_tab.dart';
import 'package:ompc_ballistic_aerodata/screens/dashboard_tab.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OmpcBallisticAeroDataApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Sidebar navigation to Log Test Entry', (WidgetTester tester) async {
    // Set screen size to desktop
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      // Build app
      await tester.pumpWidget(const OmpcBallisticAeroDataApp());
      
      // Pump first frame (which shows loader)
      await tester.pump();

      // Wait for real-world File I/O to complete in runAsync
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Pump again to reflect the state change and rebuild the UI
      await tester.pump();
    });

    // Authenticate as Admin via Unified Login
    final usernameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.obscureText == false,
    );
    expect(usernameField, findsOneWidget);
    await tester.ensureVisible(usernameField);
    await tester.enterText(usernameField, 'admin');

    final passwordField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.obscureText == true,
    );
    expect(passwordField, findsOneWidget);
    await tester.ensureVisible(passwordField);
    await tester.enterText(passwordField, 'admin123');

    final authButton = find.text('Enter Laboratory Workspace');
    expect(authButton, findsOneWidget);
    await tester.ensureVisible(authButton);
    await tester.tap(authButton);
    await tester.pumpAndSettle();

    // Verify Dashboard tab is initially shown
    expect(find.byType(DashboardTab), findsOneWidget);

    // Tap on the 'Log Entry' text button in sub tab bar
    final logEntryButton = find.text('Log Entry');
    expect(logEntryButton, findsOneWidget);
    await tester.tap(logEntryButton);
    await tester.pumpAndSettle();

    // Verify EntryTab is now shown
    expect(find.byType(EntryTab), findsOneWidget);
  });

  group('BallisticRecord CSV Serialization Tests', () {
    test('Should parse old 40-column CSV row with default values for new fields', () {
      const oldRow = '"2026-07-11 20:30:15","Admin","Day","5.56x45 SS109","001/OMPC/26",20,0,"Notes","Approved","Accuracy Test","","","","","0","0","0","0","","","","B123","Heavy","25","10.0","12.0","8.0","4.0","1.5","9.0","11.0","7.0","4.0","1.2","800.0","790.0","810.0","20.0","5.0","45.0"\n';
      final record = BallisticRecord.fromCsvRow(oldRow);
      expect(record.barrelSN, 'B123');
      expect(record.extractionForceType, '');
      expect(record.epvatPressureType, '');
    });

    test('Should serialize and parse new 58-column CSV row with P2 and Velocity rounds', () {
      final record = BallisticRecord(
        timestamp: '2026-07-11 20:30:15',
        operators: 'Admin',
        shift: 'Day',
        caliber: '5.56x45 SS109',
        lotNo: '003 OMPC/26',
        produced: 20,
        defects: 0,
        notes: 'Remarks text',
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
        requirement: 'N/A',
        barrelSN: 'B999',
        barrelType: 'TestBarrel',
        velocityDistance: '25',
        extractionForceType: 'Individual',
        extractionForceRounds: '205,210,195',
        cartridgeTemp: '21.5',
        epvatPressureType: 'Individual',
        epvatPressureUnit: 'bar',
        epvatPressureRounds: '3200,3300,3100',
        epvatMeanPressure: '3200',
        epvatMaxPressure: '3300',
        epvatMinPressure: '3100',
        epvatRangePressure: '200',
        epvatSDPressure: '100',
        epvatP2MeanPressure: '2800',
        epvatP2MaxPressure: '2900',
        epvatP2MinPressure: '2700',
        epvatP2RangePressure: '200',
        epvatP2SDPressure: '100',
        epvatP2PressureRounds: '2800,2900,2700',
        epvatVelRounds: '900,910,890',
      );
      final csvRow = record.toCsvRow();
      final parsed = BallisticRecord.fromCsvRow(csvRow);

      expect(parsed.barrelSN, 'B999');
      expect(parsed.extractionForceType, 'Individual');
      expect(parsed.extractionForceRounds, '205,210,195');
      expect(parsed.cartridgeTemp, '21.5');
      expect(parsed.epvatPressureType, 'Individual');
      expect(parsed.epvatPressureUnit, 'bar');
      expect(parsed.epvatPressureRounds, '3200,3300,3100');
      expect(parsed.epvatMeanPressure, '3200');
      expect(parsed.epvatP2MeanPressure, '2800');
      expect(parsed.epvatP2MaxPressure, '2900');
      expect(parsed.epvatP2MinPressure, '2700');
      expect(parsed.epvatP2RangePressure, '200');
      expect(parsed.epvatP2SDPressure, '100');
      expect(parsed.epvatP2PressureRounds, '2800,2900,2700');
      expect(parsed.epvatVelRounds, '900,910,890');
    });

    test('Should serialize and parse new 67-column CSV row with Residual Stress parameters', () {
      final record = BallisticRecord(
        timestamp: '2026-07-13 11:00:00',
        operators: 'Inspector',
        shift: 'Night',
        caliber: '9x19 Para',
        lotNo: '004 OMPC/26',
        produced: 50,
        defects: 2,
        notes: 'Residual stress checks completed',
        status: 'Approved',
        testName: 'Residual Stress Test',
        pressureBar: '',
        viscosity: '',
        testTime: '15:30',
        samplingLocation: 'QC Lab',
        mouthSlow: 0,
        mouthFast: 0,
        primerSlow: 0,
        primerFast: 0,
        hopperNo: '',
        boxNo: '',
        requirement: 'No splits allowed',
        neckSlow: 2,
        neckFast: 1,
        shoulderSlow: 0,
        shoulderFast: 1,
        bodySlow: 0,
        bodyFast: 0,
        headSlow: 1,
        headFast: 0,
        roomTemp: '23.5',
      );
      final csvRow = record.toCsvRow();
      final parsed = BallisticRecord.fromCsvRow(csvRow);

      expect(parsed.neckSlow, 2);
      expect(parsed.neckFast, 1);
      expect(parsed.shoulderSlow, 0);
      expect(parsed.shoulderFast, 1);
      expect(parsed.bodySlow, 0);
      expect(parsed.bodyFast, 0);
      expect(parsed.headSlow, 1);
      expect(parsed.headFast, 0);
      expect(parsed.roomTemp, '23.5');
    });
  });
}

