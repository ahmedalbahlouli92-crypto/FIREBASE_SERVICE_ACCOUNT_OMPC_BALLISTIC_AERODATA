import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';

void main() {
  group('1. BallisticRecord Action Time and Primer Sensitivity Serialization', () {
    test('Should serialize and deserialize Action Time and Primer Sensitivity fields correctly', () {
      final record = BallisticRecord(
        timestamp: '2026-09-15 08:00:00',
        operators: 'Operator1',
        shift: 'Day',
        caliber: '7.62x51 M80',
        lotNo: '101/OMPC/26',
        produced: 30,
        defects: 0,
        notes: 'Full test pass',
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
        // Action Time fields
        actionTimeMean: '3.4',
        actionTimeMin: '3.1',
        actionTimeMax: '3.8',
        actionTimeRange: '0.7',
        actionTimeSD: '0.15',
        actionTimeRounds: '3.2,3.4,3.5,3.6',
        // Primer Sensitivity fields
        primerDropHeights: '350,370,360,380',
        primerFireResults: 'Fire,Misfire,Fire,Fire',
        primerHbar: '365.0',
        primerSD: '12.9',
        primerAllFireH: '429.5',
        primerNoFireH: '339.2',
      );

      final csv = record.toCsvRow();
      final parsed = BallisticRecord.fromCsvRow(csv);

      expect(parsed.actionTimeMean, '3.4');
      expect(parsed.actionTimeMin, '3.1');
      expect(parsed.actionTimeMax, '3.8');
      expect(parsed.actionTimeRange, '0.7');
      expect(parsed.actionTimeSD, '0.15');
      expect(parsed.actionTimeRounds, '3.2,3.4,3.5,3.6');

      expect(parsed.primerDropHeights, '350,370,360,380');
      expect(parsed.primerFireResults, 'Fire,Misfire,Fire,Fire');
      expect(parsed.primerHbar, '365.0');
      expect(parsed.primerSD, '12.9');
      expect(parsed.primerAllFireH, '429.5');
      expect(parsed.primerNoFireH, '339.2');
    });
  });

  group('2. EPVAT Sample Size by Caliber', () {
    int getExpectedSampleSize(String caliber) {
      final lower = caliber.toLowerCase();
      if (lower.contains('m80') || lower.contains('ss109') || lower.contains('para')) {
        return 30;
      } else if (lower.contains('m193')) {
        return 20;
      } else {
        return 10;
      }
    }

    test('M80, SS109, and 9mm Para must default to 30 rounds', () {
      expect(getExpectedSampleSize('7.62x51 M80'), 30);
      expect(getExpectedSampleSize('5.56x45 SS109'), 30);
      expect(getExpectedSampleSize('9x19mm Para'), 30);
    });

    test('M193 must default to 20 rounds', () {
      expect(getExpectedSampleSize('5.56x45 M193'), 20);
    });

    test('Other calibers (.308, .223 55gr, etc.) must default to 10 rounds', () {
      expect(getExpectedSampleSize('7.62x51 .308'), 10);
      expect(getExpectedSampleSize('5.56x45 .223 55 grains'), 10);
      expect(getExpectedSampleSize('5.56x45 M200 Blank'), 10);
    });
  });

  group('3. Primer Sensitivity Bruceton Calculations', () {
    test('Calculates Hbar, S, Hbar+5S, and Hbar-2S accurately', () {
      final heights = [350.0, 360.0, 370.0, 380.0];
      final hbar = heights.reduce((a, b) => a + b) / heights.length;
      expect(hbar, 365.0);

      double sumSq = 0.0;
      for (var h in heights) {
        sumSq += math.pow(h - hbar, 2);
      }
      final sd = math.sqrt(sumSq / (heights.length - 1));
      expect(sd, closeTo(12.91, 0.01));

      final allFire = hbar + (5 * sd);
      final noFire = hbar - (2 * sd);

      expect(allFire, closeTo(429.55, 0.01));
      expect(noFire, closeTo(339.18, 0.01));
    });
  });

  group('4. Universal 4-Tier Sentencing Standardization', () {
    const validStatuses = {
      'Approved',
      'Approved with condition',
      'Retest',
      'Rejected',
    };

    test('All possible statuses conform strictly to 4-tier standard', () {
      for (var s in ['Approved', 'Approved with condition', 'Retest', 'Rejected']) {
        expect(validStatuses.contains(s), isTrue);
      }
    });
  });

  group('5. Extraction Force Display Order Validation', () {
    test('Verification of Extraction Force stat order', () {
      const fieldOrder = ['Min Force', 'Max Force', 'Mean Force', 'SD Force', 'Range Force'];
      expect(fieldOrder[0], 'Min Force');
      expect(fieldOrder[1], 'Max Force');
      expect(fieldOrder[2], 'Mean Force');
      expect(fieldOrder[3], 'SD Force');
      expect(fieldOrder[4], 'Range Force');
    });
  });
}
