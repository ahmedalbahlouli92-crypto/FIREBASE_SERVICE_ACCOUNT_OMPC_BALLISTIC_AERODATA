import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/services/test_result_extractor.dart';

void main() {
  group('EPVAT Auto Extract Tests', () {
    const rawEpvatReport = '''
Ballistic Measuring Machine Report
Name: M80 Lot 006 OMPC/26 +21 °C
Date: Aug 4, 2026 4:06:36 PM
Calibre: 7.62X51 NATO EPVAT AT20K263
Operator Name: Abdulmajeed AlSabahi & Said
Transducer 1: 6652
Transducer 2: 61393

Round Table:
No. P max_1 [kg/cm2] P max_2 [kg/cm2] t4 [ms] ta [ms] V24.00_2 [m/s]
1 3711.0 776.3 1.517 1.157 833.02
2 3869.3 775.4 1.516 1.159 834.79
3 3444.6 777.6 1.530 1.171 835.46
4 3848.1 788.6 1.520 1.163 835.83
5 3645.7 769.9 1.503 1.144 834.02
6 3590.2 772.3 1.515 1.155 838.25
7 3626.0 780.0 1.507 1.150 835.91
8 3686.2 769.1 1.515 1.154 831.64
9 3631.9 783.3 1.524 1.165 839.29
10 3644.2 759.5 1.547 1.189 832.74
11 3642.6 780.2 1.523 1.164 832.32
12 3664.8 767.1 1.513 1.153 834.88
13 3811.0 782.1 1.527 1.171 836.70
14 3642.5 766.1 1.537 1.178 833.56
15 3669.9 783.8 1.527 1.171 836.56
16 3711.4 769.8 1.524 1.166 834.52
17 3617.7 778.6 1.528 1.170 836.85
18 3671.3 763.5 1.554 1.196 828.60
19 3780.4 787.2 1.520 1.161 837.28
20 3755.9 785.4 1.512 1.154 834.48
21 3738.9 779.6 1.524 1.166 836.00
22 3725.1 773.8 1.523 1.164 831.06
23 3644.5 764.0 1.532 1.173 832.61
24 3433.7 758.8 1.513 1.154 834.87
25 3837.3 778.8 1.521 1.164 837.31
26 4116.0 829.3 1.451 1.087 848.79
27 3770.8 788.1 1.538 1.180 831.95
28 3819.2 780.7 1.525 1.169 831.92
29 3706.7 758.3 1.611 1.258 821.27
30 3749.1 747.5 1.579 1.226 828.84

Statistic only:
MEAN 3720.1 775.3 1.526 1.168 834.51
MAX 4116.0 829.3 1.611 1.258 848.79
MIN 3433.7 747.5 1.451 1.087 821.27
RANGE 682.3 81.8 0.160 0.171 27.52
STDEV 198.2 15.5 0.046 0.045 8.22
''';

    test('1. Accurately detects EPVAT test and extracts all header metadata', () {
      final res = TestResultExtractor.extract(content: rawEpvatReport);

      expect(res.detectedTest, equals('EPVAT test'));
      expect(res.fields['caliber'], equals('7.62x51 M80'));
      expect(res.fields['lotNo'], equals('006/OMPC/26'));
      expect(res.fields['lotDigits'], equals('006'));
      expect(res.fields['lotYear'], equals('26'));
      expect(res.fields['operators'], equals('Abdulmajeed AlSabahi & Said'));
      expect(res.fields['cartridgeTemp'], equals('+21'));
      expect(res.fields['epvatSensor1'], equals('6652'));
      expect(res.fields['epvatSensor2'], equals('61393'));
      expect(res.fields['distance'], equals('24.00'));
      expect(res.fields['epvatPressureUnit'], equals('kg/cm²'));
      expect(res.fields['produced'], equals('30'));
    });

    test('2. Accurately extracts 5-column Statistic only table parameters', () {
      final res = TestResultExtractor.extract(content: rawEpvatReport);
      final f = res.fields;

      // P1 Chamber Pressure
      expect(f['epvatMeanPressure'], equals('3720.1'));
      expect(f['epvatMaxPressure'], equals('4116.0'));
      expect(f['epvatMinPressure'], equals('3433.7'));
      expect(f['epvatRangePressure'], equals('682.3'));
      expect(f['epvatSDPressure'], equals('198.2'));

      // P2 Port Pressure
      expect(f['epvatP2MeanPressure'], equals('775.3'));
      expect(f['epvatP2MaxPressure'], equals('829.3'));
      expect(f['epvatP2MinPressure'], equals('747.5'));
      expect(f['epvatP2RangePressure'], equals('81.8'));
      expect(f['epvatP2SDPressure'], equals('15.5'));

      // Action Time ta
      expect(f['actionTimeMean'], equals('1.168'));
      expect(f['actionTimeMax'], equals('1.258'));
      expect(f['actionTimeMin'], equals('1.087'));
      expect(f['actionTimeRange'], equals('0.171'));
      expect(f['actionTimeSD'], equals('0.045'));

      // Velocity
      expect(f['velMean'], equals('834.51'));
      expect(f['velMax'], equals('848.79'));
      expect(f['velMin'], equals('821.27'));
      expect(f['velRange'], equals('27.52'));
      expect(f['velSD'], equals('8.22'));
    });

    test('3. Accurately extracts all 30 rounds from Round Table', () {
      final res = TestResultExtractor.extract(content: rawEpvatReport);
      final f = res.fields;

      final p1Rounds = (f['epvatPressureRounds'] as String).split(', ');
      final p2Rounds = (f['epvatP2PressureRounds'] as String).split(', ');
      final taRounds = (f['actionTimeRounds'] as String).split(', ');
      final velRounds = (f['epvatVelRounds'] as String).split(', ');

      expect(p1Rounds.length, equals(30));
      expect(p2Rounds.length, equals(30));
      expect(taRounds.length, equals(30));
      expect(velRounds.length, equals(30));

      expect(p1Rounds.first, equals('3711.0'));
      expect(p1Rounds.last, equals('3749.1'));

      expect(p2Rounds.first, equals('776.3'));
      expect(p2Rounds.last, equals('747.5'));

      expect(taRounds.first, equals('1.157'));
      expect(taRounds.last, equals('1.226'));

      expect(velRounds.first, equals('833.02'));
      expect(velRounds.last, equals('828.84'));
    });

    test('4. Correctly computes mathematical fallback when Statistic table is absent', () {
      const shotsOnlyReport = '''
EPVAT AT20K263
Calibre: 7.62X51 NATO
Name: M80 Lot 006 OMPC/26 +21 °C
Transducer 1: 6652
Transducer 2: 61393
No. P max_1 [kg/cm2] P max_2 [kg/cm2] t4 [ms] ta [ms] V24.00 [m/s]
1 3700.0 770.0 1.500 1.150 830.00
2 3800.0 780.0 1.510 1.160 840.00
3 3900.0 790.0 1.520 1.170 850.00
''';

      final res = TestResultExtractor.extract(content: shotsOnlyReport);
      final f = res.fields;

      expect(f['epvatMeanPressure'], equals('3800.0'));
      expect(f['epvatMinPressure'], equals('3700.0'));
      expect(f['epvatMaxPressure'], equals('3900.0'));
      expect(f['epvatRangePressure'], equals('200.0'));
      expect(f['epvatSDPressure'], equals('100.0'));

      expect(f['epvatP2MeanPressure'], equals('780.0'));
      expect(f['epvatP2MinPressure'], equals('770.0'));
      expect(f['epvatP2MaxPressure'], equals('790.0'));
      expect(f['epvatP2RangePressure'], equals('20.0'));
      expect(f['epvatP2SDPressure'], equals('10.0'));

      expect(f['actionTimeMean'], equals('1.160'));
      expect(f['velMean'], equals('840.00'));
      expect(f['velRange'], equals('20.00'));
    });

    test('5. Mirrors snake_case and camelCase parameters properly', () {
      final res = TestResultExtractor.extract(content: rawEpvatReport);
      final f = res.fields;

      expect(f['epvat_mean_pressure'], equals(f['epvatMeanPressure']));
      expect(f['epvat_p2_mean_pressure'], equals(f['epvatP2MeanPressure']));
      expect(f['action_time_mean'], equals(f['actionTimeMean']));
      expect(f['epvat_sensor1'], equals(f['epvatSensor1']));
      expect(f['epvat_sensor2'], equals(f['epvatSensor2']));
      expect(f['epvat_pressure_rounds'], equals(f['epvatPressureRounds']));
    });
  });
}
