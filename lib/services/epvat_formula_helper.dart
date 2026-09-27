import 'dart:math' as math;
import '../models/ballistic_record.dart';

class EpvatFormulaResult {
  final String name;
  final String formula;
  final String substitutedText;
  final double calculatedValue;
  final String op;
  final double limitValue;
  final String unit;
  final bool isPassed;

  const EpvatFormulaResult({
    required this.name,
    required this.formula,
    required this.substitutedText,
    required this.calculatedValue,
    required this.op,
    required this.limitValue,
    required this.unit,
    required this.isPassed,
  });
}

class EpvatFormulaHelper {
  /// Returns a normalized map of variables for all temperatures.
  static Map<String, double> extractVariablesFromRecords(
    List<BallisticRecord> records, {
    String blankColdTemp = '-32',
  }) {
    final Map<String, double> vars = {};

    Map<String, double> computeStats(String commaString) {
      final nums = commaString
          .split(',')
          .map((s) => double.tryParse(s.trim()))
          .where((n) => n != null)
          .cast<double>()
          .toList();
      if (nums.isEmpty) {
        return {'mean': 0.0, 'max': 0.0, 'min': 0.0, 'range': 0.0, 'sd': 0.0};
      }
      final mean = nums.reduce((a, b) => a + b) / nums.length;
      final max = nums.reduce(math.max);
      final min = nums.reduce(math.min);
      final range = max - min;
      final variance = nums.length > 1
          ? nums.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / (nums.length - 1)
          : 0.0;
      final sd = math.sqrt(variance);
      return {'mean': mean, 'max': max, 'min': min, 'range': range, 'sd': sd};
    }

    for (final r in records) {
      if (r.testName != 'EPVAT test' && r.testName != 'Propellant Test') continue;
      final String t = r.cartridgeTemp.trim();

      // Determine baseline temperature suffix for record's primary fields
      String sfx = '21';
      if (!t.contains('21')) {
        if (t.contains('52')) sfx = '52';
        else if (t.contains('54')) sfx = '54';
        else if (t.contains('32')) sfx = '32';
      }

      final p1Mean = double.tryParse(r.epvatMeanPressure) ?? 0.0;
      final p1Max = double.tryParse(r.epvatMaxPressure) ?? 0.0;
      final p1Min = double.tryParse(r.epvatMinPressure) ?? 0.0;
      final p1Range = double.tryParse(r.epvatRangePressure) ?? 0.0;
      final p1Sd = double.tryParse(r.epvatSDPressure) ?? 0.0;

      final p2Mean = double.tryParse(r.epvatP2MeanPressure) ?? 0.0;
      final p2Max = double.tryParse(r.epvatP2MaxPressure) ?? 0.0;
      final p2Min = double.tryParse(r.epvatP2MinPressure) ?? 0.0;
      final p2Range = double.tryParse(r.epvatP2RangePressure) ?? 0.0;
      final p2Sd = double.tryParse(r.epvatP2SDPressure) ?? 0.0;

      final velMean = double.tryParse(r.velMean) ?? 0.0;
      final velMax = double.tryParse(r.velMax) ?? 0.0;
      final velMin = double.tryParse(r.velMin) ?? 0.0;
      final velRange = double.tryParse(r.velRange) ?? 0.0;
      final velSd = double.tryParse(r.velSD) ?? 0.0;

      final actMean = double.tryParse(r.actionTimeMean) ?? 0.0;
      final actMax = double.tryParse(r.actionTimeMax) ?? 0.0;
      final actMin = double.tryParse(r.actionTimeMin) ?? 0.0;
      final actRange = double.tryParse(r.actionTimeRange) ?? 0.0;
      final actSd = double.tryParse(r.actionTimeSD) ?? 0.0;

      // Assign suffixed variables
      vars['p1_mean_$sfx'] = p1Mean;
      vars['p1_max_$sfx'] = p1Max;
      vars['p1_max_individual_$sfx'] = p1Max;
      vars['p1_min_$sfx'] = p1Min;
      vars['p1_range_$sfx'] = p1Range;
      vars['p1_sd_$sfx'] = p1Sd;

      vars['p2_mean_$sfx'] = p2Mean;
      vars['p2_max_$sfx'] = p2Max;
      vars['p2_min_$sfx'] = p2Min;
      vars['p2_range_$sfx'] = p2Range;
      vars['p2_sd_$sfx'] = p2Sd;

      vars['vel_mean_$sfx'] = velMean;
      vars['vel_max_$sfx'] = velMax;
      vars['vel_min_$sfx'] = velMin;
      vars['vel_range_$sfx'] = velRange;
      vars['vel_sd_$sfx'] = velSd;

      vars['action_time_mean_$sfx'] = actMean;
      vars['action_time_max_$sfx'] = actMax;
      vars['action_time_min_$sfx'] = actMin;
      vars['action_time_range_$sfx'] = actRange;
      vars['action_time_sd_$sfx'] = actSd;

      // Also set default un-suffixed variables
      vars.putIfAbsent('p1_mean', () => p1Mean);
      vars.putIfAbsent('p1_max', () => p1Max);
      vars.putIfAbsent('p1_max_individual', () => p1Max);
      vars.putIfAbsent('p1_min', () => p1Min);
      vars.putIfAbsent('p1_range', () => p1Range);
      vars.putIfAbsent('p1_sd', () => p1Sd);
      vars.putIfAbsent('p2_mean', () => p2Mean);
      vars.putIfAbsent('p2_max', () => p2Max);
      vars.putIfAbsent('p2_min', () => p2Min);
      vars.putIfAbsent('p2_range', () => p2Range);
      vars.putIfAbsent('p2_sd', () => p2Sd);
      vars.putIfAbsent('vel_mean', () => velMean);
      vars.putIfAbsent('vel_max', () => velMax);
      vars.putIfAbsent('vel_min', () => velMin);
      vars.putIfAbsent('vel_range', () => velRange);
      vars.putIfAbsent('vel_sd', () => velSd);
      vars.putIfAbsent('action_time_mean', () => actMean);
      vars.putIfAbsent('action_time_max', () => actMax);
      vars.putIfAbsent('action_time_min', () => actMin);
      vars.putIfAbsent('action_time_range', () => actRange);
      vars.putIfAbsent('action_time_sd', () => actSd);

      // If semicolon-separated rounds exist for multiple temperatures, compute per-temp variables
      if (r.epvatPressureRounds.contains(';') || r.epvatVelRounds.contains(';') || r.actionTimeRounds.contains(';')) {
        final p1Secs = r.epvatPressureRounds.split(';');
        final p2Secs = r.epvatP2PressureRounds.split(';');
        final velSecs = r.epvatVelRounds.split(';');
        final actSecs = r.actionTimeRounds.split(';');

        List<String> tempKeys = ['21', '52', '54'];
        if (r.cartridgeTemp.isNotEmpty) {
          final extractedKeys = r.cartridgeTemp
              .split(',')
              .map((s) => s.replaceAll(RegExp(r'[^0-9]'), '').trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (extractedKeys.isNotEmpty) {
            tempKeys = extractedKeys;
          }
        }

        for (int i = 0; i < tempKeys.length; i++) {
          final curSfx = tempKeys[i];
          if (i < p1Secs.length && p1Secs[i].trim().isNotEmpty) {
            final st = computeStats(p1Secs[i]);
            vars['p1_mean_$curSfx'] = st['mean']!;
            vars['p1_max_$curSfx'] = st['max']!;
            vars['p1_max_individual_$curSfx'] = st['max']!;
            vars['p1_min_$curSfx'] = st['min']!;
            vars['p1_range_$curSfx'] = st['range']!;
            vars['p1_sd_$curSfx'] = st['sd']!;
          }
          if (i < p2Secs.length && p2Secs[i].trim().isNotEmpty) {
            final st = computeStats(p2Secs[i]);
            vars['p2_mean_$curSfx'] = st['mean']!;
            vars['p2_max_$curSfx'] = st['max']!;
            vars['p2_min_$curSfx'] = st['min']!;
            vars['p2_range_$curSfx'] = st['range']!;
            vars['p2_sd_$curSfx'] = st['sd']!;
          }
          if (i < velSecs.length && velSecs[i].trim().isNotEmpty) {
            final st = computeStats(velSecs[i]);
            vars['vel_mean_$curSfx'] = st['mean']!;
            vars['vel_max_$curSfx'] = st['max']!;
            vars['vel_min_$curSfx'] = st['min']!;
            vars['vel_range_$curSfx'] = st['range']!;
            vars['vel_sd_$curSfx'] = st['sd']!;
          }
          if (i < actSecs.length && actSecs[i].trim().isNotEmpty) {
            final st = computeStats(actSecs[i]);
            vars['action_time_mean_$curSfx'] = st['mean']!;
            vars['action_time_max_$curSfx'] = st['max']!;
            vars['action_time_min_$curSfx'] = st['min']!;
            vars['action_time_range_$curSfx'] = st['range']!;
            vars['action_time_sd_$curSfx'] = st['sd']!;
          }
        }
      }

      // Also parse notes for temperature metrics (both legacy and rich summary formats)
      if (r.notes.contains('Temps:')) {
        final matches = RegExp(r'([+-]?\d+)°C\s*\(([^)]+)\)').allMatches(r.notes);
        for (final m in matches) {
          final tRaw = m.group(1)?.replaceAll('+', '').replaceAll('-', '') ?? '21';
          final inner = m.group(2) ?? '';

          void extractMetric(String regexPattern, List<String> targetKeys) {
            final match = RegExp(regexPattern, caseSensitive: false).firstMatch(inner);
            if (match != null) {
              final val = double.tryParse(match.group(1) ?? '');
              if (val != null) {
                for (final tk in targetKeys) {
                  vars['${tk}_$tRaw'] = val;
                }
              }
            }
          }

          // P1 Chamber Pressure
          extractMetric(r'\bP1=([\d.]+)', ['p1_mean']);
          extractMetric(r'\b(?:P1Max|Max)=([\d.]+)', ['p1_max', 'p1_max_individual']);
          extractMetric(r'\b(?:P1Min|Min)=([\d.]+)', ['p1_min']);
          extractMetric(r'\b(?:P1SD|SD)=([\d.]+)', ['p1_sd']);

          // P2 Port Pressure
          extractMetric(r'\bP2=([\d.]+)', ['p2_mean']);
          extractMetric(r'\bP2Max=([\d.]+)', ['p2_max']);
          extractMetric(r'\bP2Min=([\d.]+)', ['p2_min']);
          extractMetric(r'\bP2SD=([\d.]+)', ['p2_sd']);

          // Velocity
          extractMetric(r'\b(?:V|Vel)=([\d.]+)', ['vel_mean']);
          extractMetric(r'\b(?:VMax|VelMax)=([\d.]+)', ['vel_max']);
          extractMetric(r'\b(?:VMin|VelMin)=([\d.]+)', ['vel_min']);
          extractMetric(r'\b(?:VSD|VelSD)=([\d.]+)', ['vel_sd']);

          // Action Time
          extractMetric(r'\b(?:AT|ActionTime)=([\d.]+)', ['action_time_mean']);
          extractMetric(r'\b(?:ATMax|ActionTimeMax)=([\d.]+)', ['action_time_max']);
          extractMetric(r'\b(?:ATMin|ActionTimeMin)=([\d.]+)', ['action_time_min']);
          extractMetric(r'\b(?:ATSD|ActionTimeSD)=([\d.]+)', ['action_time_sd']);
        }
      }
    }

    return vars;
  }

  /// Normalizes natural language formula into machine-parsable expression.
  /// Supports:
  /// - `3SD` -> `3 * sd`
  /// - `P1_MAX_INDIVIDUAL` -> `p1_max_$defaultTemp`
  /// - `P1_MEAN + 3 * P1_SD` -> `p1_mean_$defaultTemp + 3 * p1_sd_$defaultTemp`
  /// - `P1 Mean @ 21` -> `p1_mean_21`
  /// - `Mean P1 @ 21` -> `p1_mean_21`
  /// - `P1 Mean` (without temp) -> `p1_mean_$defaultTemp`
  /// - `|expr|` -> `abs(expr)`
  static String normalizeFormula(String input, {String defaultTemp = '21'}) {
    String expr = input.trim();
    String cleanDefaultTemp = defaultTemp.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDefaultTemp.isEmpty) cleanDefaultTemp = '21';

    // 1. Convert pipe absolute syntax |A - B| into abs(A - B)
    expr = expr.replaceAllMapped(RegExp(r'\|([^|]+)\|'), (m) => 'abs(${m[1]})');

    // 2. Pre-normalize NATO individual max expressions
    expr = expr.replaceAllMapped(
      RegExp(r'\b(p1|p2)[\s_]+max[\s_]+individual\b', caseSensitive: false),
      (m) => '${m[1]}_max',
    );

    // 3. Handle implicit multiplication specifically for standalone numbers before SD, Sigma, or parenthesis:
    // e.g. "3SD" or "3 SD" or "3sd" -> "3 * sd"
    // Use negative lookbehind so digits inside "P1" or "P2" do NOT trigger multiplication on following words!
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z0-9_])(\d+)\s*(sd|sigma)\b', caseSensitive: false),
      (m) => '${m[1]} * ${m[2]}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z0-9_])(\d+)\s*\('),
      (m) => '${m[1]} * (',
    );

    // 4. Normalise compound tokens (both space and underscore separated):
    // e.g. "P1_MEAN", "P1 Mean", "P1 Mean @ 21", "P1_MEAN_21", "P1 SD @ +21", "VEL_MEAN", "ACTION_TIME_MEAN", "Action Time Mean"
    expr = expr.replaceAllMapped(
      RegExp(r'\b(p1|p2|vel(?:ocity)?|v|action[\s_]+time|action_time|at)[\s_]+(mean|sd|sigma|max|min|range)(?:[\s_]*(?:@|at)?[\s_]*\+?(-?\d+))?\b', caseSensitive: false),
      (m) {
        final pRaw = m[1]!.toLowerCase();
        final param = (pRaw.startsWith('v')) ? 'vel' : ((pRaw == 'at' || pRaw.contains('action')) ? 'action_time' : pRaw);
        final mRaw = m[2]!.toLowerCase();
        final metric = (mRaw == 'sigma') ? 'sd' : mRaw;
        String temp = m[3] ?? cleanDefaultTemp;
        temp = temp.replaceAll('-', '').replaceAll('+', '');
        return '${param}_${metric}_$temp';
      },
    );

    // 5. Inverted order: "Mean P1 @ 21", "SD P1 @ 52", "Mean P1", "SD P2", "Mean Action Time"
    expr = expr.replaceAllMapped(
      RegExp(r'\b(mean|sd|sigma|max|min|range)[\s_]+(p1|p2|vel(?:ocity)?|v|action[\s_]+time|action_time|at)(?:[\s_]*(?:@|at)?[\s_]*\+?(-?\d+))?\b', caseSensitive: false),
      (m) {
        final mRaw = m[1]!.toLowerCase();
        final metric = (mRaw == 'sigma') ? 'sd' : mRaw;
        final pRaw = m[2]!.toLowerCase();
        final param = pRaw.startsWith('v') ? 'vel' : ((pRaw == 'at' || pRaw.contains('action')) ? 'action_time' : pRaw);
        String temp = m[3] ?? cleanDefaultTemp;
        temp = temp.replaceAll('-', '').replaceAll('+', '');
        return '${param}_${metric}_$temp';
      },
    );

    // 6. Standalone parameter mentions without metric (e.g. "P1 @ 21", "P1", "P2 @ 52")
    // Must NOT match already normalized tokens like p1_mean_21!
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_])(p1|p2)(?!\s*_[a-z0-9_])(?:\s*(?:@|at)\s*\+?(-?\d+))?(?![a-z0-9_])', caseSensitive: false),
      (m) {
        final param = m[1]!.toLowerCase();
        String temp = m[2] ?? cleanDefaultTemp;
        temp = temp.replaceAll('-', '').replaceAll('+', '');
        return '${param}_mean_$temp';
      },
    );

    // 7. Standalone "SD" or "Mean" or "Sigma" without parameter:
    // e.g. "3 * SD" -> "3 * p1_sd_21"
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_])(sd|mean|sigma)(?:\s*(?:@|at)\s*\+?(-?\d+))?(?![a-z0-9_])', caseSensitive: false),
      (m) {
        final mRaw = m[1]!.toLowerCase();
        final metric = (mRaw == 'sigma' || mRaw == 'sd') ? 'sd' : 'mean';
        String temp = m[2] ?? cleanDefaultTemp;
        temp = temp.replaceAll('-', '').replaceAll('+', '');
        return 'p1_${metric}_$temp';
      },
    );

    return expr.trim();
  }

  /// Evaluates an expression string using variables.
  static double evaluate(String expression, Map<String, double> variables, {String defaultTemp = '21'}) {
    final normalized = normalizeFormula(expression, defaultTemp: defaultTemp);
    return _parseAndCompute(normalized, variables);
  }

  /// Builds a human-readable arithmetic substitution string:
  /// e.g. "3500 + 3 * 100 = 3800.00"
  static String buildSubstitutedArithmetic(
    String originalFormula,
    Map<String, double> variables, {
    String defaultTemp = '21',
  }) {
    String cleanDefaultTemp = defaultTemp.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDefaultTemp.isEmpty) cleanDefaultTemp = '21';

    final String norm = normalizeFormula(originalFormula, defaultTemp: cleanDefaultTemp);
    String substituted = norm;

    final Map<String, double> lowerVars = {};
    for (final e in variables.entries) {
      lowerVars[e.key.toLowerCase()] = e.value;
    }

    // Expand lowerVars with fallbacks
    final expanded = Map<String, double>.from(lowerVars);
    for (final e in lowerVars.entries) {
      final k = e.key;
      final val = e.value;
      final lastUnderscore = k.lastIndexOf('_');
      if (lastUnderscore > 0) {
        final sfx = k.substring(lastUnderscore + 1);
        if (RegExp(r'^\d+$').hasMatch(sfx)) {
          final base = k.substring(0, lastUnderscore);
          expanded.putIfAbsent(base, () => val);
          if (base.contains('max_individual')) {
            final baseMax = base.replaceAll('max_individual', 'max');
            expanded.putIfAbsent(baseMax, () => val);
            expanded.putIfAbsent('${baseMax}_$sfx', () => val);
          } else if (base.contains('max')) {
            final baseInd = base.replaceAll('max', 'max_individual');
            expanded.putIfAbsent(baseInd, () => val);
            expanded.putIfAbsent('${baseInd}_$sfx', () => val);
          }
        }
      } else {
        expanded.putIfAbsent('${k}_21', () => val);
        expanded.putIfAbsent('${k}_$cleanDefaultTemp', () => val);
        if (k.contains('max_individual')) {
          final baseMax = k.replaceAll('max_individual', 'max');
          expanded.putIfAbsent(baseMax, () => val);
          expanded.putIfAbsent('${baseMax}_21', () => val);
          expanded.putIfAbsent('${baseMax}_$cleanDefaultTemp', () => val);
        } else if (k.contains('max')) {
          final baseInd = k.replaceAll('max', 'max_individual');
          expanded.putIfAbsent(baseInd, () => val);
          expanded.putIfAbsent('${baseInd}_21', () => val);
          expanded.putIfAbsent('${baseInd}_$cleanDefaultTemp', () => val);
        }
      }
    }

    // Sort variable keys by length descending to avoid partial replacement
    final keys = expanded.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (substituted.toLowerCase().contains(k)) {
        final val = expanded[k] ?? 0.0;
        final valStr = val == val.roundToDouble() && !val.isNaN && !val.isInfinite
            ? val.toInt().toString()
            : val.toStringAsFixed(2);
        substituted = substituted.replaceAll(RegExp(RegExp.escape(k), caseSensitive: false), valStr);
      }
    }

    // Any remaining unresolved variable stems default to 0
    substituted = substituted.replaceAll(RegExp(r'\b(p1|p2|vel|action_time|at)_[a-z0-9_]+\b'), '0');

    // Format display operators for clarity
    substituted = substituted.replaceAll('*', ' * ');
    substituted = substituted.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (substituted.startsWith('abs(') && substituted.endsWith(')')) {
      final inner = substituted.substring(4, substituted.length - 1).trim();
      substituted = '|$inner|';
    }

    final double result = _parseAndCompute(norm, variables);
    final resStr = result == result.roundToDouble() && !result.isNaN && !result.isInfinite
        ? result.toInt().toString()
        : result.toStringAsFixed(2);

    // If substituted is identical to resStr (single value), avoid "3800 = 3800" redundancy
    if (substituted == resStr) {
      return resStr;
    }

    return '$substituted = $resStr';
  }

  /// Converts pressure value between bar, MPa, and kg/cm²
  static double convertPressure(double val, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return val;
    double inBar = val;
    if (fromUnit == 'MPa') {
      inBar = val * 10.0;
    } else if (fromUnit == 'kg/cm²' || fromUnit == 'Kg/cm2') {
      inBar = val * 0.980665;
    }

    if (toUnit == 'bar') return inBar;
    if (toUnit == 'MPa') return inBar * 0.1;
    if (toUnit == 'kg/cm²' || toUnit == 'Kg/cm2') return inBar / 0.980665;
    return val;
  }

  /// Evaluates an admin formula item against variables and produces an EpvatFormulaResult
  static EpvatFormulaResult evaluateFormulaItem(
    Map<String, dynamic> item,
    Map<String, double> variables, {
    String defaultTemp = '21',
    String activePressureUnit = 'bar',
  }) {
    final String name = (item['name'] ?? 'Calculation').toString().trim();
    final String formula = (item['formula'] ?? '').toString().trim();
    final String op = (item['operator'] ?? '<=').toString().trim();
    final String limitStr = (item['limit'] ?? '0').toString().trim();
    String rawUnit = (item['unit'] ?? (formula.toLowerCase().contains('vel') ? 'm/s' : 'bar')).toString().trim();

    final bool isPressure = rawUnit.toLowerCase().contains('bar') || rawUnit.toLowerCase().contains('mpa') || rawUnit.toLowerCase().contains('kg');
    final String displayUnit = isPressure ? activePressureUnit : rawUnit;

    if (formula.isEmpty) {
      return EpvatFormulaResult(
        name: name,
        formula: formula,
        substitutedText: 'N/A',
        calculatedValue: 0.0,
        op: op,
        limitValue: 0.0,
        unit: displayUnit,
        isPassed: true,
      );
    }

    double calculated = evaluate(formula, variables, defaultTemp: defaultTemp);
    final String substitutedText = buildSubstitutedArithmetic(formula, variables, defaultTemp: defaultTemp);

    double limitVal = 0.0;
    bool passed = true;

    // Check if limitStr is formatted as "Target ± Tol" (e.g. "920 ± 15" or "920 +/- 15")
    final targetTolMatch = RegExp(r'^([\d\.\-]+)\s*(?:±|\+\/-)\s*([\d\.]+)$').firstMatch(limitStr);
    if (targetTolMatch != null) {
      final target = double.tryParse(targetTolMatch.group(1)!) ?? 0.0;
      final tol = double.tryParse(targetTolMatch.group(2)!) ?? 0.0;
      limitVal = tol;
      if (isPressure && rawUnit != activePressureUnit) {
        final convTarget = convertPressure(target, rawUnit, activePressureUnit);
        final convTol = convertPressure(tol, rawUnit, activePressureUnit);
        limitVal = convTol;
        passed = (calculated >= (convTarget - convTol - 0.0001)) && (calculated <= (convTarget + convTol + 0.0001));
      } else {
        passed = (calculated >= (target - tol - 0.0001)) && (calculated <= (target + tol + 0.0001));
      }
    } else {
      limitVal = evaluate(limitStr.replaceAll('±', '').replaceAll('+/-', '').trim(), variables, defaultTemp: defaultTemp);
      if (isPressure && rawUnit != activePressureUnit) {
        limitVal = convertPressure(limitVal, rawUnit, activePressureUnit);
      }
      switch (op) {
        case '<=':
          passed = calculated <= (limitVal + 0.0001);
          break;
        case '>=':
          passed = calculated >= (limitVal - 0.0001);
          break;
        case '<':
          passed = calculated < limitVal;
          break;
        case '>':
          passed = calculated > limitVal;
          break;
        case '==':
          passed = (calculated - limitVal).abs() < 0.01;
          break;
        case '±':
        case '+/-':
          passed = calculated.abs() <= (limitVal.abs() + 0.0001);
          break;
        default:
          passed = calculated <= limitVal;
      }
    }

    return EpvatFormulaResult(
      name: name,
      formula: formula,
      substitutedText: substitutedText,
      calculatedValue: calculated,
      op: op,
      limitValue: limitVal,
      unit: displayUnit,
      isPassed: passed,
    );
  }

  /// Retrieves custom formulas for a given caliber with resilient matching.
  /// Supports exact match ('5.56x45 SS109'), short code ('SS109'), case-insensitive matches,
  /// and falls back to 'default' or standard defaults.
  static List<Map<String, dynamic>> getFormulasForCaliber(
    Map<String, dynamic> formulasMap,
    String caliber, {
    bool isThreeTemp = true,
  }) {
    if (formulasMap.isEmpty) {
      return getDefaultFormulas(isThreeTemp: isThreeTemp);
    }
    // 1. Direct match (even if empty list, meaning admin deleted/cleared all rules for this caliber)
    if (formulasMap.containsKey(caliber) && formulasMap[caliber] is List) {
      return (formulasMap[caliber] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    // 2. Resilient substring / token match (e.g. SS109 <-> 5.56x45 SS109)
    final calLower = caliber.toLowerCase().replaceAll(' ', '').trim();
    for (final entry in formulasMap.entries) {
      final keyLower = entry.key.toLowerCase().replaceAll(' ', '').trim();
      if (entry.value is List) {
        if (keyLower == calLower ||
            (calLower.contains('ss109') && keyLower.contains('ss109')) ||
            (calLower.contains('m193') && keyLower.contains('m193')) ||
            (calLower.contains('m80') && keyLower.contains('m80')) ||
            (calLower.contains('para') && keyLower.contains('para')) ||
            (calLower.contains('luger') && keyLower.contains('luger')) ||
            (calLower.contains('cmj') && keyLower.contains('cmj')) ||
            (calLower.contains('m200') && keyLower.contains('m200')) ||
            (calLower.contains('m82') && keyLower.contains('m82')) ||
            (calLower.contains('69') && keyLower.contains('69')) ||
            (calLower.contains('77') && keyLower.contains('77')) ||
            (calLower.contains('55') && keyLower.contains('55')) ||
            (calLower.contains('308') && keyLower.contains('308'))) {
          return (entry.value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    }
    // 3. Fallback to 'default' key if specified
    if (formulasMap.containsKey('default') && formulasMap['default'] is List) {
      return (formulasMap['default'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    // 4. Return default NATO EPVAT formulas if caliber was never configured
    return getDefaultFormulas(isThreeTemp: isThreeTemp);
  }

  /// Returns standard default formulas if none are defined for the caliber
  static List<Map<String, dynamic>> getDefaultFormulas({bool isThreeTemp = true}) {
    if (!isThreeTemp) {
      return [
        {
          'name': 'P1 3-Sigma (Single Temp)',
          'formula': 'P1 Mean + 3 * P1 SD',
          'operator': '<=',
          'limit': '3800',
          'unit': 'bar',
        },
        {
          'name': 'P1 Peak Maximum',
          'formula': 'P1 Max',
          'operator': '<=',
          'limit': '3800',
          'unit': 'bar',
        },
      ];
    }
    return [
      {
        'name': 'P1 3-Sigma (+21°C)',
        'formula': 'P1 Mean @ 21 + 3 * P1 SD @ 21',
        'operator': '<=',
        'limit': '3800',
        'unit': 'bar',
      },
      {
        'name': 'P1 3-Sigma (+52°C)',
        'formula': 'P1 Mean @ 52 + 3 * P1 SD @ 52',
        'operator': '<=',
        'limit': '4200',
        'unit': 'bar',
      },
      {
        'name': 'P1 3-Sigma (-54°C)',
        'formula': 'P1 Mean @ 54 + 3 * P1 SD @ 54',
        'operator': '<=',
        'limit': '3800',
        'unit': 'bar',
      },
      {
        'name': 'P1 Difference (+21°C vs +52°C)',
        'formula': 'abs(P1 Mean @ 21 - P1 Mean @ 52)',
        'operator': '<=',
        'limit': '450',
        'unit': 'bar',
      },
      {
        'name': 'Velocity Delta (+21°C vs +52°C)',
        'formula': 'abs(Vel Mean @ 21 - Vel Mean @ 52)',
        'operator': '<=',
        'limit': '30',
        'unit': 'm/s',
      },
    ];
  }


  // --- Core Expression Parser ---
  static double _parseAndCompute(String expression, Map<String, double> variables) {
    String expr = expression.replaceAll(' ', '').toLowerCase();
    int index = 0;

    final Map<String, double> lowerVars = {};
    for (final e in variables.entries) {
      final k = e.key.toLowerCase();
      final val = e.value;
      lowerVars[k] = val;
      
      final lastUnderscore = k.lastIndexOf('_');
      if (lastUnderscore > 0) {
        final sfx = k.substring(lastUnderscore + 1);
        if (RegExp(r'^\d+$').hasMatch(sfx)) {
          final base = k.substring(0, lastUnderscore);
          lowerVars.putIfAbsent(base, () => val);
          if (base.contains('max_individual')) {
            final baseMax = base.replaceAll('max_individual', 'max');
            lowerVars.putIfAbsent(baseMax, () => val);
            lowerVars.putIfAbsent('${baseMax}_$sfx', () => val);
          } else if (base.contains('max')) {
            final baseInd = base.replaceAll('max', 'max_individual');
            lowerVars.putIfAbsent(baseInd, () => val);
            lowerVars.putIfAbsent('${baseInd}_$sfx', () => val);
          }
        }
      } else {
        lowerVars.putIfAbsent('${k}_21', () => val);
        if (k.contains('max_individual')) {
          final baseMax = k.replaceAll('max_individual', 'max');
          lowerVars.putIfAbsent(baseMax, () => val);
          lowerVars.putIfAbsent('${baseMax}_21', () => val);
        } else if (k.contains('max')) {
          final baseInd = k.replaceAll('max', 'max_individual');
          lowerVars.putIfAbsent(baseInd, () => val);
          lowerVars.putIfAbsent('${baseInd}_21', () => val);
        }
      }
    }

    late double Function() parseExpression;
    late double Function() parseTerm;
    late double Function() parseFactor;

    parseFactor = () {
      if (index >= expr.length) return 0.0;

      // Handle function: abs(...)
      if (expr.startsWith('abs(', index)) {
        index += 4; // consume 'abs('
        double val = parseExpression();
        if (index < expr.length && expr[index] == ')') {
          index++; // consume ')'
        }
        return val.abs();
      }

      // Handle function: sqrt(...)
      if (expr.startsWith('sqrt(', index)) {
        index += 5;
        double val = parseExpression();
        if (index < expr.length && expr[index] == ')') {
          index++;
        }
        return val >= 0 ? math.sqrt(val) : 0.0;
      }

      // Parenthesis
      if (expr[index] == '(') {
        index++;
        double val = parseExpression();
        if (index < expr.length && expr[index] == ')') {
          index++;
        }
        return val;
      }

      // Unary sign
      double sign = 1.0;
      if (expr[index] == '+') {
        index++;
      } else if (expr[index] == '-') {
        sign = -1.0;
        index++;
      }

      // Check again for parenthesis or functions after sign
      if (index < expr.length && expr[index] == '(') {
        return sign * parseFactor();
      }

      StringBuffer sb = StringBuffer();
      while (index < expr.length && RegExp(r'[a-z0-9_\.]').hasMatch(expr[index])) {
        sb.write(expr[index]);
        index++;
      }
      String token = sb.toString();
      if (token.isEmpty) return 0.0;

      final numVal = double.tryParse(token);
      if (numVal != null) {
        return sign * numVal;
      }

      double? getVarValue(String t) {
        if (lowerVars.containsKey(t)) return lowerVars[t];
        // 1. Try stripping temperature suffix: p1_mean_21 -> p1_mean
        String unSuffixed = t;
        final lastUnderscore = t.lastIndexOf('_');
        if (lastUnderscore > 0) {
          final sfx = t.substring(lastUnderscore + 1);
          if (RegExp(r'^\d+$').hasMatch(sfx)) {
            unSuffixed = t.substring(0, lastUnderscore);
            if (lowerVars.containsKey(unSuffixed)) return lowerVars[unSuffixed];
          }
        }
        // 2. Try adding default temperature suffix: p1_mean -> p1_mean_21
        if (lowerVars.containsKey('${t}_21')) return lowerVars['${t}_21'];
        if (lowerVars.containsKey('${unSuffixed}_21')) return lowerVars['${unSuffixed}_21'];

        // 3. Bidirectional max <-> max_individual alias
        if (t.contains('max_individual')) {
          final mapped = t.replaceAll('max_individual', 'max');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
          final baseMapped = mapped.replaceAll(RegExp(r'_\d+$'), '');
          if (lowerVars.containsKey(baseMapped)) return lowerVars[baseMapped];
        } else if (t.contains('max')) {
          final mapped = t.replaceAll('max', 'max_individual');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
          final baseMapped = mapped.replaceAll(RegExp(r'_\d+$'), '');
          if (lowerVars.containsKey(baseMapped)) return lowerVars[baseMapped];
        }

        if (unSuffixed.contains('max_individual')) {
          final mapped = unSuffixed.replaceAll('max_individual', 'max');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        } else if (unSuffixed.contains('max')) {
          final mapped = unSuffixed.replaceAll('max', 'max_individual');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        }

        // 4. Try action time alias: at_mean -> action_time_mean or vice versa
        if (t.startsWith('at_')) {
          final mapped = t.replaceFirst('at_', 'action_time_');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        } else if (t.startsWith('action_time_')) {
          final mapped = t.replaceFirst('action_time_', 'at_');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        }
        return null;
      }

      final varVal = getVarValue(token) ?? 0.0;
      return sign * varVal;
    };

    parseTerm = () {
      double val = parseFactor();
      while (index < expr.length) {
        if (expr[index] == '*') {
          index++;
          val *= parseFactor();
        } else if (expr[index] == '/') {
          index++;
          double denom = parseFactor();
          val = denom != 0 ? val / denom : 0.0;
        } else {
          break;
        }
      }
      return val;
    };

    parseExpression = () {
      double val = parseTerm();
      while (index < expr.length) {
        if (expr[index] == '+') {
          index++;
          val += parseTerm();
        } else if (expr[index] == '-') {
          index++;
          val -= parseTerm();
        } else {
          break;
        }
      }
      return val;
    };

    try {
      return parseExpression();
    } catch (_) {
      return 0.0;
    }
  }
}
