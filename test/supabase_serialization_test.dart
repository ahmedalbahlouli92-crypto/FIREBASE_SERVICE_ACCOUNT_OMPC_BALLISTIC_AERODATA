import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';

void main() {
  group('Supabase Mapping Tests', () {
    test('Should accurately convert BallisticRecord to and from Supabase Map', () {
      final original = BallisticRecord(
        id: '123e4567-e89b-12d3-a456-426614174000',
        timestamp: '2026-09-16 14:00:00',
        operators: 'Inspector Khalid',
        shift: 'Day',
        caliber: '7.62x51 M80',
        lotNo: '101/OMPC/26',
        produced: 30,
        defects: 0,
        notes: 'Supabase test record',
        status: 'Approved',
        testName: 'EPVAT test',
        pressureBar: '3250',
        viscosity: 'N/A',
        testTime: '14:30',
        samplingLocation: 'Chamber 1',
        mouthSlow: 0,
        mouthFast: 0,
        primerSlow: 0,
        primerFast: 0,
        hopperNo: '5',
        boxNo: '12',
        requirement: 'NATO Spec',
        actionTimeMean: '3.4',
        primerHbar: '360.5',
      );

      final map = original.toSupabaseMap();
      expect(map['id'], '123e4567-e89b-12d3-a456-426614174000');
      expect(map['lot_no'], '101/OMPC/26');
      expect(map['test_name'], 'EPVAT test');
      expect(map['produced'], 30);
      expect(map['action_time_mean'], '3.4');
      expect(map['primer_hbar'], '360.5');

      final reconstructed = BallisticRecord.fromSupabaseMap(map);
      expect(reconstructed.id, original.id);
      expect(reconstructed.lotNo, original.lotNo);
      expect(reconstructed.testName, original.testName);
      expect(reconstructed.produced, original.produced);
      expect(reconstructed.actionTimeMean, original.actionTimeMean);
      expect(reconstructed.primerHbar, original.primerHbar);
    });
  });
}
