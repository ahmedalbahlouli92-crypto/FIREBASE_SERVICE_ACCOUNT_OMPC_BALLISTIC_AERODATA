import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/storage_service.dart';
import 'package:ompc_ballistic_aerodata/main.dart';

BallisticRecord createTestRecord({
  required String timestamp,
  required String operators,
  required String shift,
  required String caliber,
  required String lotNo,
  required int produced,
  required String status,
  required String testName,
  String barrelSN = '',
  String gp6Serial = '',
  String cyclicRateWeaponType = '',
  String userRole = 'Operator',
}) {
  return BallisticRecord(
    timestamp: timestamp,
    operators: operators,
    shift: shift,
    caliber: caliber,
    lotNo: lotNo,
    produced: produced,
    defects: 0,
    notes: 'Test note',
    status: status,
    testName: testName,
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
    barrelSN: barrelSN,
    gp6Serial: gp6Serial,
    cyclicRateWeaponType: cyclicRateWeaponType,
    userRole: userRole,
  );
}

void main() {
  group('Asset Tracking & Cumulative Round Counting', () {
    final storage = StorageService();

    final List<BallisticRecord> testRecords = [
      createTestRecord(
        timestamp: '2026-09-17 08:30:00',
        operators: 'John Doe',
        shift: 'A',
        caliber: '7.62x51mm M80',
        lotNo: 'LOT-2026-01',
        produced: 30,
        status: 'Approved',
        testName: 'EPVAT Test',
        barrelSN: 'EPVAT-BRL-001',
        gp6Serial: 'GP6-SN-5501',
        cyclicRateWeaponType: 'M240 [WPN-SN-8821]',
        userRole: 'Technician',
      ),
      createTestRecord(
        timestamp: '2026-09-17 10:00:00',
        operators: 'Jane Smith',
        shift: 'A',
        caliber: '7.62x51mm M80',
        lotNo: 'LOT-2026-02',
        produced: 20,
        status: 'Approved',
        testName: 'EPVAT Test',
        barrelSN: 'EPVAT-BRL-001',
        gp6Serial: 'GP6-SN-7700',
        cyclicRateWeaponType: 'M240 [WPN-SN-8821]',
        userRole: 'Supervisor',
      ),
      createTestRecord(
        timestamp: '2026-09-17 11:15:00',
        operators: 'Bob Operator',
        shift: 'B',
        caliber: '5.56x45mm M193',
        lotNo: 'LOT-2026-03',
        produced: 50,
        status: 'Approved',
        testName: 'Accuracy Test',
        barrelSN: 'ACC-BRL-9902',
        gp6Serial: 'GP6-SN-5501',
        cyclicRateWeaponType: 'M16A4 [WPN-SN-1100]',
        userRole: 'Operator',
      ),
    ];

    test('calculateAssetRounds computes exact cumulative rounds for EPVAT Barrel', () {
      final rounds = storage.calculateAssetRounds(testRecords, 'EPVAT-BRL-001');
      expect(rounds, equals(50)); // 30 + 20
    });

    test('calculateAssetRounds computes exact cumulative rounds for Accuracy Barrel', () {
      final rounds = storage.calculateAssetRounds(testRecords, 'ACC-BRL-9902');
      expect(rounds, equals(50)); // 50
    });

    test('calculateAssetRounds computes exact cumulative rounds for GP6 Transducer', () {
      final rounds5501 = storage.calculateAssetRounds(testRecords, 'GP6-SN-5501');
      expect(rounds5501, equals(80)); // 30 + 50

      final rounds7700 = storage.calculateAssetRounds(testRecords, 'GP6-SN-7700');
      expect(rounds7700, equals(20)); // 20
    });

    test('calculateAssetRounds matches weapon serial within cyclicRateWeaponType string', () {
      final roundsWpn8821 = storage.calculateAssetRounds(testRecords, 'WPN-SN-8821');
      expect(roundsWpn8821, equals(50)); // 30 + 20

      final roundsWpn1100 = storage.calculateAssetRounds(testRecords, 'WPN-SN-1100');
      expect(roundsWpn1100, equals(50)); // 50
    });

    test('getAssetRoundCounts returns complete map of round counts for asset fleet', () {
      final fleet = [
        'EPVAT-BRL-001',
        'ACC-BRL-9902',
        'GP6-SN-5501',
        'GP6-SN-7700',
        'WPN-SN-8821',
        'UNUSED-SERIAL-999'
      ];
      final counts = storage.getAssetRoundCounts(testRecords, fleet);
      expect(counts['EPVAT-BRL-001'], equals(50));
      expect(counts['ACC-BRL-9902'], equals(50));
      expect(counts['GP6-SN-5501'], equals(80));
      expect(counts['GP6-SN-7700'], equals(20));
      expect(counts['WPN-SN-8821'], equals(50));
      expect(counts['UNUSED-SERIAL-999'], equals(0));
    });
  });

  group('4-Tier User Role Management & Parsing', () {
    test('parseUserRole handles all 4 tiers and admin correctly', () {
      expect(parseUserRole('manager'), equals(UserRole.manager));
      expect(parseUserRole('supervisor'), equals(UserRole.supervisor));
      expect(parseUserRole('technician'), equals(UserRole.technician));
      expect(parseUserRole('operator'), equals(UserRole.operator));
      expect(parseUserRole('admin'), equals(UserRole.admin));
    });

    test('parseUserRole is case-insensitive and falls back to operator', () {
      expect(parseUserRole('MANAGER'), equals(UserRole.manager));
      expect(parseUserRole('Supervisor'), equals(UserRole.supervisor));
      expect(parseUserRole('TECHNICIAN'), equals(UserRole.technician));
      expect(parseUserRole('unknown_role'), equals(UserRole.operator));
      expect(parseUserRole(null), equals(UserRole.operator));
    });

    test('UserRole extension provides distinct labels', () {
      expect(UserRole.manager.label, equals('Manager'));
      expect(UserRole.supervisor.label, equals('Supervisor'));
      expect(UserRole.technician.label, equals('Technician'));
      expect(UserRole.operator.label, equals('Operator'));
    });
  });

  group('BallisticRecord Serialization of new fields', () {
    test('gp6Serial and userRole survive Map and Supabase roundtrip', () {
      final record = createTestRecord(
        timestamp: '2026-09-17 14:22:10',
        operators: 'Sarah Connor',
        shift: 'B',
        caliber: '9x19mm Parabellum',
        lotNo: 'LOT-9MM-44',
        produced: 30,
        status: 'Approved',
        testName: 'Action Time Test',
        gp6Serial: 'GP6-TRANS-900',
        userRole: 'Technician',
      );

      // Supabase serialization
      final map = record.toSupabaseMap();
      expect(map['gp6_serial'], equals('GP6-TRANS-900'));
      expect(map['user_role'], equals('Technician'));

      final restored = BallisticRecord.fromSupabaseMap(map);
      expect(restored.gp6Serial, equals('GP6-TRANS-900'));
      expect(restored.userRole, equals('Technician'));
    });

    test('module field defaults to Lot Acceptance Test and persists correctly across Supabase and CSV', () {
      final defaultRecord = createTestRecord(
        timestamp: '2026-09-17 14:30:00',
        operators: 'Inspector Jane',
        shift: 'Day',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-SS109-01',
        produced: 20,
        status: 'Approved',
        testName: 'Waterproof Test',
      );
      expect(defaultRecord.module, equals('Lot Acceptance Test'));

      final dailyRecord = defaultRecord.copyWith(module: 'Daily Test');
      expect(dailyRecord.module, equals('Daily Test'));

      // CSV roundtrip
      final csv = dailyRecord.toCsvRow();
      final fromCsv = BallisticRecord.fromCsvRow(csv);
      expect(fromCsv.module, equals('Daily Test'));

      // Supabase roundtrip
      final map = dailyRecord.toSupabaseMap();
      expect(map['module'], equals('Daily Test'));
      final fromMap = BallisticRecord.fromSupabaseMap(map);
      expect(fromMap.module, equals('Daily Test'));
    });

    test('Role Permissions default matrix allows supervisor to edit records and export reports', () {
      final defaultRolePerms = {
        'manager': {
          'can_edit_records': true,
          'can_delete_records': false,
          'can_clear_logs': false,
          'can_export_reports': true,
          'can_manage_rules': true,
        },
        'supervisor': {
          'can_edit_records': true,
          'can_delete_records': false,
          'can_clear_logs': false,
          'can_export_reports': true,
          'can_manage_rules': false,
        },
        'technician': {
          'can_edit_records': false,
          'can_delete_records': false,
          'can_clear_logs': false,
          'can_export_reports': true,
          'can_manage_rules': false,
        },
        'operator': {
          'can_edit_records': false,
          'can_delete_records': false,
          'can_clear_logs': false,
          'can_export_reports': true,
          'can_manage_rules': false,
        },
      };

      // Supervisor has edit permissions
      expect(defaultRolePerms['supervisor']!['can_edit_records'], isTrue);
      expect(defaultRolePerms['supervisor']!['can_export_reports'], isTrue);
      expect(defaultRolePerms['supervisor']!['can_delete_records'], isFalse);

      // Manager has edit and rules permissions
      expect(defaultRolePerms['manager']!['can_edit_records'], isTrue);
      expect(defaultRolePerms['manager']!['can_manage_rules'], isTrue);

      // Operator and Technician are read-only for editing logs by default
      expect(defaultRolePerms['operator']!['can_edit_records'], isFalse);
      expect(defaultRolePerms['technician']!['can_edit_records'], isFalse);
    });

    test('BallisticRecord update/edit preserves primary attributes and modifies corrected fields', () {
      final original = createTestRecord(
        timestamp: '2026-09-17 11:00:00',
        operators: 'Technician Ali',
        shift: 'Day',
        caliber: '5.56x45 SS109',
        lotNo: 'LOT-ORIG-01',
        produced: 100,
        status: 'Rejected',
        testName: 'Waterproof Test',
      );

      // Supervisor corrects typo in produced quantity and defects
      final updated = original.copyWith(
        produced: 150,
        defects: 0,
        status: 'Approved',
        notes: 'Corrected sample size and defect count by Supervisor',
      );

      expect(updated.timestamp, equals(original.timestamp));
      expect(updated.lotNo, equals(original.lotNo));
      expect(updated.produced, equals(150));
      expect(updated.defects, equals(0));
      expect(updated.status, equals('Approved'));
      expect(updated.notes, contains('Supervisor'));
    });
  });
}
