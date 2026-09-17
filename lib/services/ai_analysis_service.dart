import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ballistic_record.dart';

class AiTestRecommendation {
  final String testName;
  final String status;
  final Color statusColor;
  final String summary;
  final List<String> findings;
  final List<String> recommendations;
  final Map<String, String> keyMetrics;

  AiTestRecommendation({
    required this.testName,
    required this.status,
    required this.statusColor,
    required this.summary,
    required this.findings,
    required this.recommendations,
    required this.keyMetrics,
  });
}

class WeeklyStabilityReport {
  final int totalTests;
  final int totalSampleRounds;
  final int stabilityScore; // 0 to 100
  final String stabilityRating;
  final Color ratingColor;
  final Map<String, int> dailyLeaks;
  final bool isLeaksIncreasing;
  final String leakTrendSummary;
  final Map<String, double> dailyMeanPressure;
  final Map<String, double> dailyPressureSD;
  final bool isPressureUnstable;
  final String pressureTrendSummary;
  final List<String> criticalAlerts;
  final List<String> actionableAdvice;

  WeeklyStabilityReport({
    required this.totalTests,
    required this.totalSampleRounds,
    required this.stabilityScore,
    required this.stabilityRating,
    required this.ratingColor,
    required this.dailyLeaks,
    required this.isLeaksIncreasing,
    required this.leakTrendSummary,
    required this.dailyMeanPressure,
    required this.dailyPressureSD,
    required this.isPressureUnstable,
    required this.pressureTrendSummary,
    required this.criticalAlerts,
    required this.actionableAdvice,
  });
}

class AiAnalysisService {
  AiAnalysisService._();
  static final AiAnalysisService instance = AiAnalysisService._();

  /// Generates intelligent engineering analysis and actionable recommendation for an individual ballistic test record
  AiTestRecommendation analyzeRecord(BallisticRecord r, {Map<String, dynamic> adminRules = const {}}) {
    final testName = r.testName.trim();
    final lowerName = testName.toLowerCase();

    if (lowerName.contains('waterproof')) {
      return _analyzeWaterproof(r, adminRules);
    } else if (lowerName.contains('residual stress')) {
      return _analyzeResidualStress(r, adminRules);
    } else if (lowerName.contains('epvat')) {
      return _analyzeEpvat(r, adminRules);
    } else if (lowerName.contains('function')) {
      return _analyzeFunction(r, adminRules);
    } else if (lowerName.contains('accuracy')) {
      return _analyzeAccuracy(r, adminRules);
    } else if (lowerName.contains('extraction')) {
      return _analyzeExtraction(r, adminRules);
    } else if (lowerName.contains('primer')) {
      return _analyzePrimerSensitivity(r, adminRules);
    }

    // Generic fallback analysis
    final isApproved = r.status.toLowerCase().contains('approved');
    return AiTestRecommendation(
      testName: testName,
      status: isApproved ? 'Compliant' : 'Requires Review',
      statusColor: isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      summary: isApproved
          ? 'Trial meets designated acceptance bounds with zero unhandled defects.'
          : 'Trial status marked as ${r.status}. Further inspection needed.',
      findings: [
        'Inspector: ${r.operators} on Shift ${r.shift}',
        'Lot Number: ${r.lotNo}, Caliber: ${r.caliber}',
        'Sample Size Tested: ${r.produced} rounds, Defects: ${r.defects}',
      ],
      recommendations: [
        isApproved
            ? 'Proceed with standard lot release documentation.'
            : 'Hold lot pending supervisory review and disposition verification.',
      ],
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'Defects': '${r.defects}',
        'Status': r.status,
      },
    );
  }

  AiTestRecommendation _analyzeWaterproof(BallisticRecord r, Map<String, dynamic> adminRules) {
    final totalLeaks = r.defects;
    final mouthTotal = r.mouthSlow + r.mouthFast;
    final primerTotal = r.primerSlow + r.primerFast;

    final findings = <String>[];
    final recommendations = <String>[];

    findings.add('Total Tested Quantity: ${r.produced} rounds.');
    findings.add('Mouth Leaks: $mouthTotal (Slow: ${r.mouthSlow}, Fast: ${r.mouthFast}).');
    findings.add('Primer Leaks: $primerTotal (Slow: ${r.primerSlow}, Fast: ${r.primerFast}).');

    String status = 'Fully Compliant';
    Color statusColor = const Color(0xFF10B981);

    if (totalLeaks == 0) {
      status = 'Optimal Seal Integrity';
      statusColor = const Color(0xFF10B981);
      recommendations.add('Mouth and primer hermetic seals are completely impervious to water penetration under pressure.');
      recommendations.add('Maintain current crimp diameter tooling and sealant viscosity levels (nominal 35-45 cPs).');
    } else if (totalLeaks <= 4) {
      status = 'Advisory - Retest Watch';
      statusColor = const Color(0xFFF59E0B);
      if (mouthTotal > primerTotal) {
        recommendations.add('Mouth seal variance detected ($mouthTotal leaks). Inspect bullet seating depth and case mouth chamfer.');
        recommendations.add('Verify bullet cannelure crimping force: ensure crimp enters cannelure groove uniformly without brass wall distortion.');
      } else {
        recommendations.add('Primer pocket seal variance detected ($primerTotal leaks). Inspect primer pocket depth and sealant lacquer volume.');
        recommendations.add('Check primer anvil seating depth (nominal 0.05 - 0.12 mm below case head).');
      }
      recommendations.add('Subject sample to verification retest per caliber quality guidelines before lot release.');
    } else {
      status = 'Critical Seal Failure';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('Unacceptable leak count ($totalLeaks defects). Immediate quarantine of ammunition lot is advised.');
      recommendations.add('Perform calibration of pneumatic sealant injection needles for nozzle clogging or air bubbles.');
      recommendations.add('Audit brass annealing at case mouth to ensure proper ductility for secure crimp bite.');
    }

    return AiTestRecommendation(
      testName: 'Waterproof Test',
      status: status,
      statusColor: statusColor,
      summary: totalLeaks == 0
          ? '100% waterproof compliance achieved with zero leakage.'
          : '$totalLeaks leaks observed across ${r.produced} tested rounds.',
      findings: findings,
      recommendations: recommendations,
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'Total Leaks': '$totalLeaks',
        'Mouth Leaks': '$mouthTotal',
        'Primer Leaks': '$primerTotal',
        'Test Pressure': '${r.pressureBar} bar',
      },
    );
  }

  AiTestRecommendation _analyzeResidualStress(BallisticRecord r, Map<String, dynamic> adminRules) {
    final totalSplits = r.defects;
    final neckSplits = r.neckSlow + r.neckFast;
    final shoulderSplits = r.shoulderSlow + r.shoulderFast;
    final bodySplits = r.bodySlow + r.bodyFast;
    final headSplits = r.headSlow + r.headFast;

    final findings = <String>[];
    final recommendations = <String>[];

    findings.add('Sample Size: ${r.produced} rounds inspected after chemical exposure.');
    findings.add('Neck Splits: $neckSplits | Shoulder Splits: $shoulderSplits');
    findings.add('Body Splits: $bodySplits | Head Splits: $headSplits');

    String status = 'Optimal Metallurgical Relief';
    Color statusColor = const Color(0xFF10B981);

    if (totalSplits == 0) {
      recommendations.add('Case brass displays zero residual drawing stress. Annealing profile is optimal.');
      recommendations.add('Grain structure is stable. Safe for long-term storage and tropical climatic conditions.');
    } else if (bodySplits > 0 || headSplits > 0) {
      status = 'Critical Structural Stress';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('High-severity split found on Case Body/Head. Risk of catastrophic case rupture during firing.');
      recommendations.add('Audit brass cup drawing reduction stages; check for excessive work-hardening or die lubrication failure.');
      recommendations.add('Quarantine lot and review brass metallurgy certificate (70/30 cartridge brass hardness Rockwell B).');
    } else {
      status = 'Moderate Neck Stress';
      statusColor = const Color(0xFFF59E0B);
      recommendations.add('Neck/Shoulder splitting detected ($neckSplits neck, $shoulderSplits shoulder).');
      recommendations.add('Adjust induction neck annealing temperature upwards by +15°C to +20°C or increase flame dwell time.');
      recommendations.add('Verify mercurous nitrate / ammonia immersion duration does not exceed specified specification window.');
    }

    return AiTestRecommendation(
      testName: 'Residual Stress Test',
      status: status,
      statusColor: statusColor,
      summary: totalSplits == 0
          ? 'Zero splits detected. Excellent stress-relief annealing.'
          : '$totalSplits brass splits detected after immersion.',
      findings: findings,
      recommendations: recommendations,
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'Total Splits': '$totalSplits',
        'Neck / Shoulder': '${neckSplits + shoulderSplits}',
        'Body / Head': '${bodySplits + headSplits}',
      },
    );
  }

  AiTestRecommendation _analyzeEpvat(BallisticRecord r, Map<String, dynamic> adminRules) {
    final findings = <String>[];
    final recommendations = <String>[];

    final p1Mean = double.tryParse(r.epvatMeanPressure) ?? 0.0;
    final p1Max = double.tryParse(r.epvatMaxPressure) ?? 0.0;
    final p1SD = double.tryParse(r.epvatSDPressure) ?? 0.0;
    final p2Min = double.tryParse(r.epvatP2MinPressure) ?? 0.0;
    final velMean = double.tryParse(r.velMean) ?? 0.0;
    final velSD = double.tryParse(r.velSD) ?? 0.0;

    findings.add('Total Rounds Tested: ${r.produced} rounds.');
    if (r.cartridgeTemp.isNotEmpty) findings.add('Conditioning Temperatures: ${r.cartridgeTemp}');
    if (p1Mean > 0) findings.add('P1 Chamber Pressure: Mean = ${p1Mean.toStringAsFixed(1)} bar, Max = ${p1Max.toStringAsFixed(1)} bar, SD = ${p1SD.toStringAsFixed(1)} bar.');
    if (p2Min > 0) findings.add('P2 Port Pressure: Min = ${p2Min.toStringAsFixed(1)} bar.');
    if (velMean > 0) findings.add('Muzzle Velocity: Mean = ${velMean.toStringAsFixed(1)} m/s, SD = ${velSD.toStringAsFixed(1)} m/s.');

    String status = 'Compliant Ballistic Profile';
    Color statusColor = const Color(0xFF10B981);

    // Evaluate P1
    if (p1Max > 3900.0) {
      status = 'P1 Pressure Limit Exceeded';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('P1 Peak Pressure ($p1Max bar) exceeds safe NATO proofing limit. Immediate charge weight reduction required (-0.3 grains).');
      recommendations.add('Inspect propellant lot burn rate and check bullet seating depth (excessive bullet intrusion reduces combustion chamber volume).');
    } else if (p1Max > 3750.0) {
      status = 'P1 Approaching Upper Limit';
      statusColor = const Color(0xFFF59E0B);
      recommendations.add('P1 Max ($p1Max bar) is trending close to threshold. Recommend reducing powder thrower nominal charge by -0.1 grains.');
    }

    // Evaluate P1 SD
    if (p1SD > 120.0) {
      recommendations.add('Elevated chamber pressure variation (SD = $p1SD bar). Indicates inconsistent propellant ignition or powder grain variance.');
      recommendations.add('Inspect propellant gravimetric feeder tolerance and primer flame flash hole cleanliness.');
    }

    // Evaluate P2 Port Pressure
    if (p2Min > 0 && p2Min < 200.0) {
      recommendations.add('P2 Port Pressure drops below 200 bar ($p2Min bar). Weapon automatic cycling, extraction, or bolt hold-open may suffer.');
      recommendations.add('Adjust propellant formulation to ensure sufficient gas impulse volume at the gas block port.');
    }

    // Evaluate Velocity SD
    if (velSD > 15.0) {
      recommendations.add('Velocity Standard Deviation ($velSD m/s) is high. Recommend tightening bullet weight sorting to within ±0.05 grains.');
    } else if (velMean > 0) {
      recommendations.add('Velocity curve is stable with clean interior ballistic repeatability.');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Interior ballistic curve, gas volume, and velocities are within design limits.');
    }

    return AiTestRecommendation(
      testName: 'EPVAT Test',
      status: status,
      statusColor: statusColor,
      summary: 'Overall EPVAT trial evaluated across ${r.produced} rounds with P1 max at $p1Max bar.',
      findings: findings,
      recommendations: recommendations,
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'P1 Max': p1Max > 0 ? '$p1Max bar' : 'N/A',
        'P1 SD': p1SD > 0 ? '$p1SD bar' : 'N/A',
        'Velocity Mean': velMean > 0 ? '$velMean m/s' : 'N/A',
        'Velocity SD': velSD > 0 ? '$velSD m/s' : 'N/A',
      },
    );
  }

  AiTestRecommendation _analyzeFunction(BallisticRecord r, Map<String, dynamic> adminRules) {
    final findings = <String>[];
    final recommendations = <String>[];

    final l1 = r.functionLevel1;
    final l2 = r.functionLevel2;
    final l3 = r.functionLevel3;
    final l4 = r.functionLevel4;
    final totalDefects = r.defects;

    findings.add('Total Rounds Fired: ${r.produced} rounds.');
    findings.add('Level 1 (Critical): $l1 defects (Blown primer, Case rupture, Bore obstruction).');
    findings.add('Level 2 (Major): $l2 defects (Extraction failure, Ejection failure, Misfeed).');
    findings.add('Level 3 (Minor): $l3 defects (Case dent, Extractor burr).');
    findings.add('Level 4 (Incidental): $l4 defects (Minor cosmetic markings).');

    String status = 'Functionally Conforming';
    Color statusColor = const Color(0xFF10B981);

    if (l1 > 0) {
      status = 'Critical Firing Incident (L1)';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('Critical Level 1 defect ($l1 count) observed. Mandate immediate production halt on ammunition packaging line.');
      recommendations.add('Inspect weapon bolt face and barrel chamber for gas erosion, headspace compliance, and excessive peak pressure.');
      recommendations.add('Quarantine corresponding case and primer sub-lots.');
    } else if (l2 > 0) {
      status = 'Major Cycling Stoppage (L2)';
      statusColor = const Color(0xFFF59E0B);
      recommendations.add('Major stoppage encountered ($l2 count). Review case rim thickness and extractor groove angle.');
      recommendations.add('Inspect weapon gas regulator setting and test weapon clean/lubrication state.');
    } else if (l3 > 2) {
      status = 'Minor Defects Elevated (L3)';
      statusColor = const Color(0xFFF59E0B);
      recommendations.add('Level 3 defects ($l3 count) exceed nominal threshold. Inspect feeding ramp geometry and magazine spring tension.');
    } else {
      recommendations.add('Weapon feeding, chambering, firing, extraction, and ejection functioned without operational stoppages.');
      recommendations.add('Cycling rate and mechanical action within standard weapon specifications.');
    }

    return AiTestRecommendation(
      testName: 'Function & Casualties Test',
      status: status,
      statusColor: statusColor,
      summary: totalDefects == 0
          ? 'Zero mechanical stoppages across ${r.produced} rounds fired.'
          : '$totalDefects defects recorded (L1: $l1, L2: $l2, L3: $l3, L4: $l4).',
      findings: findings,
      recommendations: recommendations,
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'Total Defects': '$totalDefects',
        'Level 1 (Critical)': '$l1',
        'Level 2 (Major)': '$l2',
        'Level 3 (Minor)': '$l3',
      },
    );
  }

  AiTestRecommendation _analyzeAccuracy(BallisticRecord r, Map<String, dynamic> adminRules) {
    final findings = <String>[];
    final recommendations = <String>[];

    final meanRadius = double.tryParse(r.accMeanRadius) ?? 0.0;
    final velSD = double.tryParse(r.velSD) ?? 0.0;
    final rangeX = double.tryParse(r.accRangeX) ?? 0.0;
    final rangeY = double.tryParse(r.accRangeY) ?? 0.0;

    findings.add('Sample Size: ${r.produced} rounds at target range (${r.velocityDistance.isNotEmpty ? r.velocityDistance : "100m"}).');
    if (meanRadius > 0) findings.add('Mean Radius: ${meanRadius.toStringAsFixed(1)} mm.');
    if (rangeX > 0 || rangeY > 0) findings.add('Extreme Spread: Horizontal = ${rangeX.toStringAsFixed(1)} mm, Vertical = ${rangeY.toStringAsFixed(1)} mm.');
    if (velSD > 0) findings.add('Velocity Standard Deviation: ${velSD.toStringAsFixed(1)} m/s.');

    String status = 'Match Grade Accuracy';
    Color statusColor = const Color(0xFF10B981);

    if (meanRadius > 50.0) {
      status = 'Grouping Exceeds Limit';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('Mean radius ($meanRadius mm) exceeds acceptance limit. Check bullet concentricity (runout > 0.002 in).');
      recommendations.add('Inspect barrel muzzle crown for microscopic burrs or asymmetry.');
      recommendations.add('Verify test barrel round count: throat erosion may be degrading bullet gyroscopic stabilization.');
    } else if (meanRadius > 38.0) {
      status = 'Moderate Dispersion';
      statusColor = const Color(0xFFF59E0B);
      recommendations.add('Dispersion is approaching outer tolerance. Inspect propellant charge consistency and case neck tension.');
    } else {
      recommendations.add('Tight group dispersion achieved. Aerodynamic stability and projectile balance are optimal.');
    }

    return AiTestRecommendation(
      testName: 'Accuracy Test',
      status: status,
      statusColor: statusColor,
      summary: 'Mean radius measured at ${meanRadius.toStringAsFixed(1)} mm across ${r.produced} rounds.',
      findings: findings,
      recommendations: recommendations,
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'Mean Radius': '$meanRadius mm',
        'Vel SD': '$velSD m/s',
        'Barrel S.N.': r.barrelSN.isNotEmpty ? r.barrelSN : 'Default',
      },
    );
  }

  AiTestRecommendation _analyzeExtraction(BallisticRecord r, Map<String, dynamic> adminRules) {
    final findings = <String>[];
    final recommendations = <String>[];

    final pullRounds = r.extractionForceRounds.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).where((v) => v > 0).toList();
    double minF = 9999.0;
    double maxF = 0.0;
    double sumF = 0.0;

    for (var f in pullRounds) {
      if (f < minF) minF = f;
      if (f > maxF) maxF = f;
      sumF += f;
    }
    final avgF = pullRounds.isNotEmpty ? sumF / pullRounds.length : 0.0;
    if (minF == 9999.0) minF = 0.0;

    findings.add('Sample Size: ${r.produced} rounds.');
    if (pullRounds.isNotEmpty) {
      findings.add('Peak Extraction Force: Min = ${minF.toStringAsFixed(0)} N, Max = ${maxF.toStringAsFixed(0)} N, Mean = ${avgF.toStringAsFixed(0)} N.');
    }

    String status = 'Secure Bullet Retention';
    Color statusColor = const Color(0xFF10B981);

    if (minF > 0 && minF < 200.0) {
      status = 'Low Extraction Force';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('Minimum pull-out force ($minF N) is below the standard 200 N threshold.');
      recommendations.add('Risk of bullet setback during weapon auto-chambering, which can cause extreme chamber pressure spikes.');
      recommendations.add('Action: Tighten case neck sizing bushing and increase roll crimping depth.');
    } else {
      recommendations.add('Bullet retention withstands rough handling, cyclic feed recoil, and magazine shocks.');
    }

    return AiTestRecommendation(
      testName: 'Extraction Force Test',
      status: status,
      statusColor: statusColor,
      summary: pullRounds.isNotEmpty
          ? 'Mean bullet extraction force measured at ${avgF.toStringAsFixed(0)} N.'
          : 'Extraction test completed for ${r.produced} rounds.',
      findings: findings,
      recommendations: recommendations,
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'Mean Force': '${avgF.toStringAsFixed(0)} N',
        'Min Force': '${minF.toStringAsFixed(0)} N',
        'Max Force': '${maxF.toStringAsFixed(0)} N',
      },
    );
  }

  AiTestRecommendation _analyzePrimerSensitivity(BallisticRecord r, Map<String, dynamic> adminRules) {
    final findings = <String>[];
    final recommendations = <String>[];

    final hbar = double.tryParse(r.primerHbar) ?? 0.0;
    final s = double.tryParse(r.primerSD) ?? 0.0;
    final allFire = double.tryParse(r.primerAllFireH) ?? (hbar + 5 * s);
    final noFire = double.tryParse(r.primerNoFireH) ?? (hbar - 2 * s);

    findings.add('Tested Sample Size: ${r.produced} primers via Bruceton staircase methodology.');
    findings.add('Mean Drop Height (H̄): ${hbar.toStringAsFixed(1)} mm, Std Deviation (S): ${s.toStringAsFixed(1)} mm.');
    findings.add('All-Fire Limit (H̄ + 5S): ${allFire.toStringAsFixed(1)} mm (Max allowable: 380 mm).');
    findings.add('No-Fire Limit (H̄ - 2S): ${noFire.toStringAsFixed(1)} mm (Min allowable: 75 mm).');

    String status = 'STANAG Compliant';
    Color statusColor = const Color(0xFF10B981);

    if (allFire > 380.0) {
      status = 'All-Fire Limit Exceeded (Insensitive)';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('All-Fire height ($allFire mm) exceeds 380 mm limit. Risk of light primer strikes and hangfires/misfires in field rifles.');
      recommendations.add('Action: Audit primer mix pellet weight, cup brass hardness, and anvil leg angle.');
    } else if (noFire < 75.0) {
      status = 'No-Fire Limit Violated (Over-Sensitive)';
      statusColor = const Color(0xFFEF4444);
      recommendations.add('No-Fire height ($noFire mm) is below 75 mm safety floor. Ammunition is dangerously sensitive to drops and mechanical shocks.');
      recommendations.add('Action: Adjust priming compound desensitizing additives and foil paper thickness.');
    } else {
      recommendations.add('Bruceton sensitivity curve conforms strictly to NATO AC/225 standard.');
    }

    return AiTestRecommendation(
      testName: 'Primer Sensitivity Test',
      status: status,
      statusColor: statusColor,
      summary: 'Bruceton H̄ = ${hbar.toStringAsFixed(1)} mm, S = ${s.toStringAsFixed(1)} mm.',
      findings: findings,
      recommendations: recommendations,
      keyMetrics: {
        'Sample Size': '${r.produced} rounds',
        'H̄ (Mean)': '$hbar mm',
        'H̄ + 5S': '$allFire mm',
        'H̄ - 2S': '$noFire mm',
      },
    );
  }

  /// Conducts a comprehensive 1-week stability & trend analysis across historical inspection logs
  WeeklyStabilityReport analyzeWeeklyStability(List<BallisticRecord> records) {
    if (records.isEmpty) {
      return WeeklyStabilityReport(
        totalTests: 0,
        totalSampleRounds: 0,
        stabilityScore: 100,
        stabilityRating: 'No Records In Range',
        ratingColor: const Color(0xFF94A3B8),
        dailyLeaks: {},
        isLeaksIncreasing: false,
        leakTrendSummary: 'No recent waterproof test logs available to analyze.',
        dailyMeanPressure: {},
        dailyPressureSD: {},
        isPressureUnstable: false,
        pressureTrendSummary: 'No recent EPVAT chamber pressure logs available.',
        criticalAlerts: ['No ballistic test records found in the active workspace.'],
        actionableAdvice: ['Log quality inspection trials to generate automated AI trend diagnostics.'],
      );
    }

    int totalRounds = 0;
    final Map<String, List<int>> leaksByDay = {};
    final Map<String, List<double>> p1ByDay = {};
    final criticalAlerts = <String>[];
    final actionableAdvice = <String>[];

    // Group records by day key (YYYY-MM-DD or readable date)
    for (var r in records) {
      totalRounds += r.produced;
      final dateKey = _extractDateKey(r.timestamp);

      // Leaks tracking
      if (r.testName.toLowerCase().contains('waterproof')) {
        final leaks = (r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast) > 0
            ? (r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast)
            : r.defects;
        leaksByDay.putIfAbsent(dateKey, () => []).add(leaks);
      }

      // EPVAT pressure tracking
      if (r.testName.toLowerCase().contains('epvat')) {
        final p1 = double.tryParse(r.epvatMeanPressure) ?? 0.0;
        if (p1 > 0) {
          p1ByDay.putIfAbsent(dateKey, () => []).add(p1);
        }
      }
    }

    // Process daily leaks
    final Map<String, int> dailyLeaksSum = {};
    leaksByDay.forEach((day, list) {
      dailyLeaksSum[day] = list.reduce((a, b) => a + b);
    });

    // Check if daily leaks are increasing over consecutive days
    bool leaksIncreasing = false;
    final leakDaysSorted = dailyLeaksSum.keys.toList()..sort();
    if (leakDaysSorted.length >= 3) {
      final last3 = leakDaysSorted.sublist(leakDaysSorted.length - 3);
      final v0 = dailyLeaksSum[last3[0]] ?? 0;
      final v1 = dailyLeaksSum[last3[1]] ?? 0;
      final v2 = dailyLeaksSum[last3[2]] ?? 0;
      if (v2 > v1 && v1 >= v0 && v2 > 0) {
        leaksIncreasing = true;
      }
    }

    // Process daily pressures
    final Map<String, double> dailyP1Mean = {};
    final Map<String, double> dailyP1SD = {};
    p1ByDay.forEach((day, list) {
      if (list.isNotEmpty) {
        final mean = list.reduce((a, b) => a + b) / list.length;
        double variance = 0.0;
        for (var p in list) {
          variance += pow(p - mean, 2);
        }
        final sd = list.length > 1 ? sqrt(variance / (list.length - 1)) : 15.0;
        dailyP1Mean[day] = mean;
        dailyP1SD[day] = sd;
      }
    });

    // Check pressure instability or upward drift
    bool pressureUnstable = false;
    final pressureDaysSorted = dailyP1Mean.keys.toList()..sort();
    if (pressureDaysSorted.length >= 2) {
      // Check high standard deviation or drift > 100 bar
      final latestDay = pressureDaysSorted.last;
      final latestSD = dailyP1SD[latestDay] ?? 0.0;
      if (latestSD > 90.0) {
        pressureUnstable = true;
      }

      final firstDay = pressureDaysSorted.first;
      final diff = (dailyP1Mean[latestDay] ?? 0) - (dailyP1Mean[firstDay] ?? 0);
      if (diff > 80.0) {
        pressureUnstable = true;
        criticalAlerts.add('Pressure Drift: Mean chamber pressure increased by +${diff.toStringAsFixed(1)} bar across recent production days.');
      }
    }

    // Formulate alerts and advice
    if (leaksIncreasing) {
      criticalAlerts.add('Leak Frequency Rising: Daily waterproof seal failures show an upward trend across the last 3 test sessions.');
      actionableAdvice.add('Inspect mouth sealant dispensing needle nozzles for partial blockage or sealant batch viscosity changes.');
      actionableAdvice.add('Verify bullet crimp die collet wear on loading machines.');
    }

    if (pressureUnstable) {
      criticalAlerts.add('Chamber Pressure Instability: Daily standard deviation indicates inconsistent interior ballistics.');
      actionableAdvice.add('Audit propellant loading room relative humidity (maintain 45-55% RH).');
      actionableAdvice.add('Verify powder measure volumetric check weights every 2 hours.');
    }

    // Calculate stability score
    int score = 100;
    if (leaksIncreasing) score -= 25;
    if (pressureUnstable) score -= 25;

    final hasRejects = records.any((r) => r.status.toLowerCase().contains('reject'));
    if (hasRejects) score -= 15;

    if (score < 40) score = 40;

    String rating = 'Optimal Ballistic Stability';
    Color ratingColor = const Color(0xFF10B981);
    if (score < 65) {
      rating = 'Process Instability Warning';
      ratingColor = const Color(0xFFEF4444);
    } else if (score < 85) {
      rating = 'Moderate Drift - Monitor Closely';
      ratingColor = const Color(0xFFF59E0B);
    }

    if (criticalAlerts.isEmpty) {
      criticalAlerts.add('No critical drift or systematic anomalies detected in active 7-day trials.');
      actionableAdvice.add('Continue standard quality acceptance sampling plan.');
    }

    final leakSummary = leaksIncreasing
        ? 'Daily leak count is trending upwards across consecutive production days. Seal degradation likely.'
        : 'Daily waterproof leak rates remain stable and within nominal acceptance boundaries.';

    final pressureSummary = pressureUnstable
        ? 'Chamber pressure displays noticeable variance or upward drift across daily batches.'
        : 'EPVAT mean chamber pressures and standard deviations are stable across test days.';

    return WeeklyStabilityReport(
      totalTests: records.length,
      totalSampleRounds: totalRounds,
      stabilityScore: score,
      stabilityRating: rating,
      ratingColor: ratingColor,
      dailyLeaks: dailyLeaksSum,
      isLeaksIncreasing: leaksIncreasing,
      leakTrendSummary: leakSummary,
      dailyMeanPressure: dailyP1Mean,
      dailyPressureSD: dailyP1SD,
      isPressureUnstable: pressureUnstable,
      pressureTrendSummary: pressureSummary,
      criticalAlerts: criticalAlerts,
      actionableAdvice: actionableAdvice,
    );
  }

  String _extractDateKey(String timestamp) {
    if (timestamp.contains(' ')) {
      final parts = timestamp.split(' ');
      return parts[0];
    }
    return timestamp;
  }
}
