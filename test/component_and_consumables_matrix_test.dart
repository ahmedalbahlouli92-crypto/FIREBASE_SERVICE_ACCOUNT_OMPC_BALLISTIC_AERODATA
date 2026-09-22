import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/models/default_consumables.dart';

void main() {
  group('1. BallisticRecord Component Fields Serialization', () {
    test('Should properly serialize and deserialize Primer & Propellant fields to/from Supabase Map & CSV', () {
      final record = BallisticRecord(
        timestamp: '2026-09-22 14:00:00',
        operators: 'Operator A',
        shift: 'Day',
        caliber: 'SS109',
        lotNo: 'LOT-2026-001',
        produced: 90,
        defects: 0,
        notes: 'Component verification',
        status: 'Approved',
        testName: 'Primer Sensitivity Test',
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
        module: 'Component Test',
        primerLot: 'PRIMER-LOT-88',
        primerSupplier: 'UNIS "GINIX"',
        primerInsertionDepth: '0.18',
        propellantSupplier: 'Explosia',
        propellantCode: 'D-073.4',
        propellantLot: 'PROP-LOT-55',
        propellantCharge: '1.62',
      );

      // Verify toSupabaseMap and fromSupabaseMap
      final map = record.toSupabaseMap();
      expect(map['primer_lot'], 'PRIMER-LOT-88');
      expect(map['primer_supplier'], 'UNIS "GINIX"');
      expect(map['primer_insertion_depth'], '0.18');
      expect(map['propellant_supplier'], 'Explosia');
      expect(map['propellant_code'], 'D-073.4');
      expect(map['propellant_lot'], 'PROP-LOT-55');
      expect(map['propellant_charge'], '1.62');

      final reconstructed = BallisticRecord.fromSupabaseMap(map);
      expect(reconstructed.primerLot, 'PRIMER-LOT-88');
      expect(reconstructed.primerSupplier, 'UNIS "GINIX"');
      expect(reconstructed.primerInsertionDepth, '0.18');
      expect(reconstructed.propellantSupplier, 'Explosia');
      expect(reconstructed.propellantCode, 'D-073.4');
      expect(reconstructed.propellantLot, 'PROP-LOT-55');
      expect(reconstructed.propellantCharge, '1.62');

      // Verify CSV serialization
      final csvLine = record.toCsvRow();
      final fromCsv = BallisticRecord.fromCsvRow(csvLine);
      expect(fromCsv.primerLot, 'PRIMER-LOT-88');
      expect(fromCsv.primerSupplier, 'UNIS GINIX'); // double quotes stripped in CSV parser
      expect(fromCsv.primerInsertionDepth, '0.18');
      expect(fromCsv.propellantSupplier, 'Explosia');
      expect(fromCsv.propellantCode, 'D-073.4');
      expect(fromCsv.propellantLot, 'PROP-LOT-55');
      expect(fromCsv.propellantCharge, '1.62');
    });
  });

  group('2. Default Consumables Catalog Verification', () {
    test('Should contain 214 items categorized across the 8 specified categories', () {
      final items = getDefaultConsumablesCatalog();
      expect(items.length, 214);

      final categories = items.map((i) => i['category'] as String).toSet();
      expect(categories, contains('Shooting system'));
      expect(categories, contains('closed Vessel and Calibration Unit'));
      expect(categories, contains('Manual loading tools'));
      expect(categories, contains('Primer Equipment'));
      expect(categories, contains('Weapon cleaning item'));
      expect(categories, contains('Styer rifle spare Part'));
      expect(categories, contains('M16 & M4 Spare Part'));

      // Check specific items from user prompt
      expect(items.any((i) => (i['name'] as String).contains('Firing Pin Diameter 1..52mm') && i['serial'] == '290105U'), isTrue);
      expect(items.any((i) => (i['name'] as String).contains('Spare parts B180.1 Adapter')), isTrue);
      expect(items.any((i) => (i['name'] as String).contains('5,56 Percutor pin')), isTrue);
      expect(items.any((i) => (i['name'] as String).contains('Dropping Ball weight 55 g')), isTrue);
      expect(items.any((i) => (i['name'] as String).contains('Competition powder measure')), isTrue);
      expect(items.any((i) => (i['name'] as String).contains('Ultra Sonic Cleaner')), isTrue);
      expect(items.any((i) => (i['name'] as String).contains('Barrel 508mm') && i['serial'] == '1240010401E'), isTrue);
    });
  });
}
