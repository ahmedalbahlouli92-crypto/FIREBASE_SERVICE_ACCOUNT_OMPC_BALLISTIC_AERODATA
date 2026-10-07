import 'dart:math' as math;
import '../models/ballistic_record.dart';

class EpvatFormulaResult {
  final String name;
  final String formula;
  final String substitutedText;
  final double calculatedValue;
  final String op;
  final double limitValue;
  final double? toleranceValue;
  final String unit;
  final bool isPassed;
  final bool isApplicable;

  const EpvatFormulaResult({
    required this.name,
    required this.formula,
    required this.substitutedText,
    required this.calculatedValue,
    required this.op,
    required this.limitValue,
    this.toleranceValue,
    required this.unit,
    required this.isPassed,
    this.isApplicable = true,
  });
}

class EpvatFormulaHelper {
  /// Returns a normalized map of variables for all temperatures.
  static Map<String, double> extractVariablesFromRecords(
    List<BallisticRecord> records, {
    String blankColdTemp = '-32',
  }) {
    final Map<String, double> vars = {};

    Map<String, double> computeStats(String rawString) {
      if (rawString.contains('=')) {
        double mean = 0.0, max = 0.0, min = 0.0, range = 0.0, sd = 0.0;
        final meanMatch = RegExp(r'(?:mean|p1|p2|v|vel|at)\s*=\s*([\d.]+)', caseSensitive: false).firstMatch(rawString);
        if (meanMatch != null) mean = double.tryParse(meanMatch.group(1)!) ?? 0.0;
        final maxMatch = RegExp(r'(?:max|p1max|p2max|vmax|atmax)\s*=\s*([\d.]+)', caseSensitive: false).firstMatch(rawString);
        if (maxMatch != null) max = double.tryParse(maxMatch.group(1)!) ?? 0.0;
        final minMatch = RegExp(r'(?:min|p1min|p2min|vmin|atmin)\s*=\s*([\d.]+)', caseSensitive: false).firstMatch(rawString);
        if (minMatch != null) min = double.tryParse(minMatch.group(1)!) ?? 0.0;
        final rangeMatch = RegExp(r'(?:range|p1range|p2range|vrange|atrange)\s*=\s*([\d.]+)', caseSensitive: false).firstMatch(rawString);
        if (rangeMatch != null) range = double.tryParse(rangeMatch.group(1)!) ?? 0.0;
        final sdMatch = RegExp(r'(?:sd|p1sd|p2sd|vsd|atsd)\s*=\s*([\d.]+)', caseSensitive: false).firstMatch(rawString);
        if (sdMatch != null) sd = double.tryParse(sdMatch.group(1)!) ?? 0.0;
        if (range == 0.0 && max > min && min > 0) range = max - min;
        return {'mean': mean, 'max': max, 'min': min, 'range': range, 'sd': sd};
      }
      final nums = rawString
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

      // Determine baseline temperature suffix for record's primary fields.
      // Priority: If t contains '21', primary fields are for 21. Only if 21 is absent, check others.
      String sfx = '21';
      if (!t.contains('21')) {
        if (t.contains('52')) {
          sfx = '52';
        } else if (t.contains('54')) {
          sfx = '54';
        } else if (t.contains('32')) {
          sfx = '32';
        }
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
      if (r.epvatPressureRounds.contains(';') || r.epvatVelRounds.contains(';') || r.actionTimeRounds.contains(';') || r.epvatP2PressureRounds.contains(';')) {
        final p1Secs = r.epvatPressureRounds.split(';');
        final p2Secs = r.epvatP2PressureRounds.split(';');
        final velSecs = r.epvatVelRounds.split(';');
        final actSecs = r.actionTimeRounds.split(';');

        List<String> tempKeys = ['21', '52', '54'];
        if (r.cartridgeTemp.isNotEmpty) {
          final matches = RegExp(r'([+-]?\d+)').allMatches(r.cartridgeTemp);
          final extractedKeys = matches
              .map((m) => m.group(1)!.replaceAll('+', '').replaceAll('-', '').trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          if (extractedKeys.length >= 3 || extractedKeys.length >= p1Secs.length) {
            tempKeys = extractedKeys;
          } else if (extractedKeys.isNotEmpty) {
            final Set<String> merged = {...extractedKeys, '21', '52', '54'};
            tempKeys = merged.toList();
          }
        }

        for (int i = 0; i < tempKeys.length; i++) {
          final curSfx = tempKeys[i];
          if (i < p1Secs.length && p1Secs[i].trim().isNotEmpty) {
            final st = computeStats(p1Secs[i]);
            if (st['mean']! > 0 || st['sd']! > 0 || st['max']! > 0) {
              vars['p1_mean_$curSfx'] = st['mean']!;
              vars['p1_max_$curSfx'] = st['max']!;
              vars['p1_max_individual_$curSfx'] = st['max']!;
              vars['p1_min_$curSfx'] = st['min']!;
              vars['p1_range_$curSfx'] = st['range']!;
              vars['p1_sd_$curSfx'] = st['sd']!;
            }
          }
          if (i < p2Secs.length && p2Secs[i].trim().isNotEmpty) {
            final st = computeStats(p2Secs[i]);
            if (st['mean']! > 0 || st['sd']! > 0 || st['max']! > 0) {
              vars['p2_mean_$curSfx'] = st['mean']!;
              vars['p2_max_$curSfx'] = st['max']!;
              vars['p2_min_$curSfx'] = st['min']!;
              vars['p2_range_$curSfx'] = st['range']!;
              vars['p2_sd_$curSfx'] = st['sd']!;
            }
          }
          if (i < velSecs.length && velSecs[i].trim().isNotEmpty) {
            final st = computeStats(velSecs[i]);
            if (st['mean']! > 0 || st['sd']! > 0 || st['max']! > 0) {
              vars['vel_mean_$curSfx'] = st['mean']!;
              vars['vel_max_$curSfx'] = st['max']!;
              vars['vel_min_$curSfx'] = st['min']!;
              vars['vel_range_$curSfx'] = st['range']!;
              vars['vel_sd_$curSfx'] = st['sd']!;
            }
          }
          if (i < actSecs.length && actSecs[i].trim().isNotEmpty) {
            final st = computeStats(actSecs[i]);
            if (st['mean']! > 0 || st['sd']! > 0 || st['max']! > 0) {
              vars['action_time_mean_$curSfx'] = st['mean']!;
              vars['action_time_max_$curSfx'] = st['max']!;
              vars['action_time_min_$curSfx'] = st['min']!;
              vars['action_time_range_$curSfx'] = st['range']!;
              vars['action_time_sd_$curSfx'] = st['sd']!;
            }
          }
        }
      }

      // Also parse notes for temperature metrics (both legacy and rich summary formats)
      if (r.notes.contains('Temps:')) {
        final matches = RegExp(r'([+-]?\d+)(?:°C)?\s*\(([^)]+)\)').allMatches(r.notes);
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
  /// - `P1 Mean @ 21` -> `p1_mean_21`
  /// - `Mean P1 @ 21` -> `p1_mean_21`
  /// - `Mean Action Time @-54` -> `action_time_mean_54`
  /// - `SD Action Time @-54` -> `action_time_sd_54`
  /// - `P1 Mean` (without temp) -> `p1_mean_$defaultTemp`
  /// - `|expr|` -> `abs(expr)`
  static String normalizeFormula(String input, {String defaultTemp = '21'}) {
    String expr = input.trim();
    // Clean degree symbols and notations (e.g. °C, °c, degC, °)
    expr = expr.replaceAll(RegExp(r'°\s*c|°|deg\s*c', caseSensitive: false), '');
    final match = RegExp(r'\d+').firstMatch(defaultTemp);
    final cleanDefaultTemp = match != null ? match.group(0)! : '21';

    // 1. Convert pipe absolute syntax |A - B| into abs(A - B)
    expr = expr.replaceAllMapped(RegExp(r'\|([^|]+)\|'), (m) => 'abs(${m[1]})');

    // 2. Pre-normalize NATO individual max expressions
    expr = expr.replaceAllMapped(
      RegExp(r'\b(p1|p2)[\s_]+max[\s_]+individual\b', caseSensitive: false),
      (m) => '${m[1]}_max',
    );

    // 3. Handle implicit multiplication specifically for standalone numbers before SD, Sigma, or parenthesis:
    // e.g. "3SD" or "3 SD" or "3sd" -> "3 * sd"
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z0-9_])(\d+)\s*(sd|sigma)\b', caseSensitive: false),
      (m) => '${m[1]} * ${m[2]}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z0-9_])(\d+)\s*\('),
      (m) => '${m[1]} * (',
    );

    String cleanParam(String pRaw) {
      final p = pRaw.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
      if (p.startsWith('ch') || p == 'p1') return 'p1';
      if (p.startsWith('po') || p == 'p2') return 'p2';
      if (p.startsWith('v') || p.startsWith('sp')) return 'vel';
      if (p.startsWith('a')) return 'action_time';
      return p;
    }

    String cleanMetric(String mRaw) {
      final m = mRaw.toLowerCase();
      if (m == 'sigma' || m == 'std') return 'sd';
      if (m == 'avg' || m == 'average') return 'mean';
      if (m == 'peak') return 'max';
      return m;
    }

    String cleanTemp(String? tRaw) {
      if (tRaw == null || tRaw.trim().isEmpty) return cleanDefaultTemp;
      final digits = tRaw.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isNotEmpty ? digits : cleanDefaultTemp;
    }

    // 4. Inverted order: "Mean P1 @ 21", "Mean Action Time @-54", "SD Action Time @-54", "SD P2 @52"
    expr = expr.replaceAllMapped(
      RegExp(r'\b(mean|avg|average|sd|sigma|std|max|peak|min|range)[\s_]+(chamber[\s_]*pressure|p1|port[\s_]*pressure|p2|vel(?:ocity)?|speed|v|action[\s_]*time|actiontime|at)(?:[\s_]*(?:@|at)?[\s_]*([+-]?\d+))?\b', caseSensitive: false),
      (m) {
        final metric = cleanMetric(m[1]!);
        final param = cleanParam(m[2]!);
        final temp = cleanTemp(m[3]);
        return '${param}_${metric}_$temp';
      },
    );

    // 5. Standard order: "P1 Mean @ 21", "Action Time Mean @-54", "Vel Mean @ 52"
    expr = expr.replaceAllMapped(
      RegExp(r'\b(chamber[\s_]*pressure|p1|port[\s_]*pressure|p2|vel(?:ocity)?|speed|v|action[\s_]*time|actiontime|at)[\s_]+(mean|avg|average|sd|sigma|std|max|peak|min|range)(?:[\s_]*(?:@|at)?[\s_]*([+-]?\d+))?\b', caseSensitive: false),
      (m) {
        final param = cleanParam(m[1]!);
        final metric = cleanMetric(m[2]!);
        final temp = cleanTemp(m[3]);
        return '${param}_${metric}_$temp';
      },
    );

    // 6. Standalone Parameter mentions with optional @temp: e.g. "P1 @ 52", "Action Time @ -54", "P2 @ 54", "P1"
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_])(chamber[\s_]*pressure|p1|port[\s_]*pressure|p2|vel(?:ocity)?|speed|action[\s_]*time|actiontime|at)(?!\s*_[a-z0-9_])(?:[\s_]*(?:@|at)[\s_]*([+-]?\d+))?(?![a-z0-9_])', caseSensitive: false),
      (m) {
        final param = cleanParam(m[1]!);
        final temp = cleanTemp(m[2]);
        return '${param}_mean_$temp';
      },
    );

    // 7. Standalone Metric without parameter: e.g. "3 * SD" -> "3 * p1_sd_21", "5*SD"
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_])(sd|sigma|mean)(?:[\s_]*(?:@|at)[\s_]*([+-]?\d+))?(?![a-z0-9_])', caseSensitive: false),
      (m) {
        final metric = cleanMetric(m[1]!);
        final temp = cleanTemp(m[2]);
        return 'p1_${metric}_$temp';
      },
    );

    return expr.trim();
  }

  /// Evaluates an expression string using variables.
  static double evaluate(String expression, Map<String, double> variables, {String defaultTemp = '21'}) {
    final match = RegExp(r'\d+').firstMatch(defaultTemp);
    final cleanDefaultTemp = match != null ? match.group(0)! : '21';
    final normalized = normalizeFormula(expression, defaultTemp: cleanDefaultTemp);
    return _parseAndCompute(normalized, variables);
  }

  /// Builds a human-readable arithmetic substitution string:
  /// e.g. "3500 + 3 * 100 = 3800.00 bar"
  static String buildSubstitutedArithmetic(
    String originalFormula,
    Map<String, double> variables, {
    String defaultTemp = '21',
  }) {
    final match = RegExp(r'\d+').firstMatch(defaultTemp);
    final cleanDefaultTemp = match != null ? match.group(0)! : '21';
    final String norm = normalizeFormula(originalFormula, defaultTemp: cleanDefaultTemp);

    final Map<String, double> lowerVars = {};
    for (final e in variables.entries) {
      lowerVars[e.key.toLowerCase()] = e.value;
    }

    final varMatches = RegExp(r'\b(?:p1|p2|vel|action_time|at)_(?:mean|max|min|range|sd|max_individual)_(\d+)\b').allMatches(norm.toLowerCase());
    final requiredTemps = varMatches.map((m) => m.group(1)!).toSet();
    bool hasTempData(String t) {
      if (t == cleanDefaultTemp) {
        if (lowerVars.keys.any((k) => !k.contains('_21') && !k.contains('_52') && !k.contains('_54') && !k.contains('_32') && (lowerVars[k] ?? 0.0) != 0.0)) {
          return true;
        }
        if (lowerVars.keys.any((k) => k.endsWith('_$t') && (lowerVars[k] ?? 0.0) != 0.0)) {
          return true;
        }
      }
      return lowerVars.keys.any((k) => k.endsWith('_$t') && (lowerVars[k] ?? 0.0) != 0.0);
    }
    if (requiredTemps.isNotEmpty && !requiredTemps.every((t) => hasTempData(t))) {
      return 'Not Tested';
    }
    String substituted = norm;

    // Expand lowerVars with fallbacks and aliases
    final expanded = Map<String, double>.from(lowerVars);
    for (final e in lowerVars.entries) {
      final k = e.key;
      final val = e.value;
      final lastUnderscore = k.lastIndexOf('_');
      final sfx = lastUnderscore > 0 ? k.substring(lastUnderscore + 1) : '';
      final bool hasNumericSuffix = lastUnderscore > 0 && RegExp(r'^\d+$').hasMatch(sfx);

      if (hasNumericSuffix) {
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
        if (base.startsWith('action_time_')) {
          final baseAt = base.replaceFirst('action_time_', 'at_');
          expanded.putIfAbsent(baseAt, () => val);
          expanded.putIfAbsent('${baseAt}_$sfx', () => val);
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
        if (k.startsWith('action_time_')) {
          final baseAt = k.replaceFirst('action_time_', 'at_');
          expanded.putIfAbsent(baseAt, () => val);
          expanded.putIfAbsent('${baseAt}_21', () => val);
          expanded.putIfAbsent('${baseAt}_$cleanDefaultTemp', () => val);
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

    final match = RegExp(r'\d+').firstMatch(defaultTemp);
    final cleanDefaultTemp = match != null ? match.group(0)! : '21';
    final normalized = normalizeFormula(formula, defaultTemp: cleanDefaultTemp);

    final Map<String, double> lowerVars = {};
    for (final e in variables.entries) {
      lowerVars[e.key.toLowerCase()] = e.value;
    }

    // Identify required temperatures
    final varMatches = RegExp(r'\b(?:p1|p2|vel|action_time|at)_(?:mean|max|min|range|sd|max_individual)_(\d+)\b').allMatches(normalized.toLowerCase());
    final requiredTemps = varMatches.map((m) => m.group(1)!).toSet();

    bool hasTempData(String t) {
      if (t == cleanDefaultTemp) {
        if (lowerVars.keys.any((k) => !k.contains('_21') && !k.contains('_52') && !k.contains('_54') && !k.contains('_32') && (lowerVars[k] ?? 0.0) != 0.0)) {
          return true;
        }
        if (lowerVars.keys.any((k) => k.endsWith('_$t') && (lowerVars[k] ?? 0.0) != 0.0)) {
          return true;
        }
      }
      return lowerVars.keys.any((k) => k.endsWith('_$t') && (lowerVars[k] ?? 0.0) != 0.0);
    }

    final bool isApplicable = requiredTemps.isEmpty || requiredTemps.every((t) => hasTempData(t));

    if (!isApplicable) {
      double limitVal = 0.0;
      final targetTolMatch = RegExp(r'^([\d\.\-]+)\s*(?:±|\+\/-)\s*([\d\.]+)$').firstMatch(limitStr);
      if (targetTolMatch != null) {
        limitVal = double.tryParse(targetTolMatch.group(2)!) ?? 0.0;
        if (isPressure && rawUnit != activePressureUnit) {
          limitVal = convertPressure(limitVal, rawUnit, activePressureUnit);
        }
      } else {
        limitVal = evaluate(limitStr.replaceAll('±', '').replaceAll('+/-', '').trim(), variables, defaultTemp: defaultTemp);
        if (isPressure && rawUnit != activePressureUnit) {
          limitVal = convertPressure(limitVal, rawUnit, activePressureUnit);
        }
      }
      return EpvatFormulaResult(
        name: name,
        formula: formula,
        substitutedText: 'Not Tested',
        calculatedValue: 0.0,
        op: op,
        limitValue: limitVal,
        unit: displayUnit,
        isPassed: true,
        isApplicable: false,
      );
    }

    final bool requiresP2 = normalized.toLowerCase().contains('p2');
    final bool hasAnyP2 = lowerVars.entries.any((e) => e.key.toLowerCase().contains('p2') && e.value != 0.0);
    if (requiresP2 && !hasAnyP2) {
      return EpvatFormulaResult(
        name: name,
        formula: formula,
        substitutedText: 'Not Tested (No P2)',
        calculatedValue: 0.0,
        op: op,
        limitValue: 0.0,
        unit: displayUnit,
        isPassed: true,
        isApplicable: false,
      );
    }

    final bool requiresVel = normalized.toLowerCase().contains('vel');
    final bool hasAnyVel = lowerVars.entries.any((e) => e.key.toLowerCase().contains('vel') && e.value != 0.0);
    if (requiresVel && !hasAnyVel) {
      return EpvatFormulaResult(
        name: name,
        formula: formula,
        substitutedText: 'Not Tested (No Vel)',
        calculatedValue: 0.0,
        op: op,
        limitValue: 0.0,
        unit: displayUnit,
        isPassed: true,
        isApplicable: false,
      );
    }

    double calculated = evaluate(formula, variables, defaultTemp: defaultTemp);
    final String substitutedText = buildSubstitutedArithmetic(formula, variables, defaultTemp: defaultTemp);

    double limitVal = 0.0;
    bool passed = true;

    double? toleranceVal;

    // Check if tolerance is explicitly defined in item or limitStr is formatted as "Target ± Tol"
    final double? explicitTol = (item['tolerance'] is num)
        ? (item['tolerance'] as num).toDouble()
        : double.tryParse('${item['tolerance'] ?? ''}');
    final targetTolMatch = RegExp(r'^([\d\.\-]+)\s*(?:±|\+\/-)\s*([\d\.]+)$').firstMatch(limitStr);

    if (explicitTol != null && explicitTol > 0.0) {
      double target = evaluate(limitStr.replaceAll('±', '').replaceAll('+/-', '').trim(), variables, defaultTemp: defaultTemp);
      double tol = explicitTol;
      if (isPressure && rawUnit != activePressureUnit) {
        target = convertPressure(target, rawUnit, activePressureUnit);
        tol = convertPressure(tol, rawUnit, activePressureUnit);
      }
      limitVal = target;
      toleranceVal = tol;
      passed = (calculated >= (target - tol - 0.0001)) && (calculated <= (target + tol + 0.0001));
    } else if (targetTolMatch != null) {
      final target = double.tryParse(targetTolMatch.group(1)!) ?? 0.0;
      final tol = double.tryParse(targetTolMatch.group(2)!) ?? 0.0;
      limitVal = target;
      toleranceVal = tol;
      if (isPressure && rawUnit != activePressureUnit) {
        final convTarget = convertPressure(target, rawUnit, activePressureUnit);
        final convTol = convertPressure(tol, rawUnit, activePressureUnit);
        limitVal = convTarget;
        toleranceVal = convTol;
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
          toleranceVal = limitVal.abs();
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
      toleranceValue: toleranceVal,
      unit: displayUnit,
      isPassed: passed,
    );
  }

  /// Retrieves custom formulas for a given caliber with resilient matching.
  /// Supports exact match ('5.56x45 SS109'), short code ('SS109'), case-insensitive matches,
  /// and returns only formulas explicitly configured by the admin (no hardcoded fallback failures).
  static List<Map<String, dynamic>> getFormulasForCaliber(
    Map<String, dynamic> formulasMap,
    String caliber, {
    bool isThreeTemp = true,
  }) {
    if (formulasMap.isEmpty) {
      return [];
    }
    // 1. Direct match (if list is non-empty)
    if (formulasMap.containsKey(caliber) && formulasMap[caliber] is List) {
      final list = (formulasMap[caliber] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (list.isNotEmpty) return list;
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
          final list = (entry.value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (list.isNotEmpty) return list;
        }
      }
    }
    // Only return formulas explicitly configured by admin for this caliber - no default or hardcoded fallbacks
    return [];
  }

  /// Returns standard default formulas if none are defined for the caliber
  static List<Map<String, dynamic>> getDefaultFormulas({bool isThreeTemp = true}) {
    if (!isThreeTemp) {
      return [
        {
          'name': 'P1 3-Sigma (Single Temp)',
          'formula': 'P1 Mean + 3 * P1 SD',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
        },
        {
          'name': 'P1 Peak Maximum',
          'formula': 'P1 Max',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
        },
      ];
    }
    return [
      {
        'name': 'P1 3-Sigma (+21°C)',
        'formula': 'P1 Mean @ 21 + 3 * P1 SD @ 21',
        'operator': '<=',
        'limit': '4500',
        'unit': 'bar',
      },
      {
        'name': 'P1 3-Sigma (+52°C)',
        'formula': 'P1 Mean @ 52 + 3 * P1 SD @ 52',
        'operator': '<=',
        'limit': '4600',
        'unit': 'bar',
      },
      {
        'name': 'P1 3-Sigma (-54°C)',
        'formula': 'P1 Mean @ 54 + 3 * P1 SD @ 54',
        'operator': '<=',
        'limit': '4600',
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
      final sfx = lastUnderscore > 0 ? k.substring(lastUnderscore + 1) : '';
      final bool hasNumericSuffix = lastUnderscore > 0 && RegExp(r'^\d+$').hasMatch(sfx);

      if (hasNumericSuffix) {
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
        if (base.startsWith('action_time_')) {
          final baseAt = base.replaceFirst('action_time_', 'at_');
          lowerVars.putIfAbsent(baseAt, () => val);
          lowerVars.putIfAbsent('${baseAt}_$sfx', () => val);
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
        if (k.startsWith('action_time_')) {
          final baseAt = k.replaceFirst('action_time_', 'at_');
          lowerVars.putIfAbsent(baseAt, () => val);
          lowerVars.putIfAbsent('${baseAt}_21', () => val);
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

        if (t.contains('max_individual')) {
          final mapped = t.replaceAll('max_individual', 'max');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        } else if (t.contains('max')) {
          final mapped = t.replaceAll('max', 'max_individual');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        }

        if (t.startsWith('at_')) {
          final mapped = t.replaceFirst('at_', 'action_time_');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        } else if (t.startsWith('action_time_')) {
          final mapped = t.replaceFirst('action_time_', 'at_');
          if (lowerVars.containsKey(mapped)) return lowerVars[mapped];
        }

        String unSuffixed = t;
        String sfx = '';
        final lastUnderscore = t.lastIndexOf('_');
        if (lastUnderscore > 0) {
          final candidate = t.substring(lastUnderscore + 1);
          if (RegExp(r'^\d+$').hasMatch(candidate)) {
            sfx = candidate;
            unSuffixed = t.substring(0, lastUnderscore);
          }
        }

        // Only fall back to un-suffixed if the variable had NO temperature suffix or is the default baseline 21.
        // NEVER fall back to 21 for specific non-baseline temperatures (e.g. 52, 54, 32)!
        if (sfx.isEmpty || sfx == '21') {
          if (lowerVars.containsKey(unSuffixed)) return lowerVars[unSuffixed];
          if (lowerVars.containsKey('${unSuffixed}_21')) return lowerVars['${unSuffixed}_21'];
          if (lowerVars.containsKey('${t}_21')) return lowerVars['${t}_21'];
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

  /// Evaluates an EPVAT record against the admin custom formulas for its caliber.
  /// Returns 'Approved' if all applicable formulas pass (or if none configured).
  /// Returns 'Rejected' if any applicable formula fails.
  static String calculateEpvatRecordStatus(
    BallisticRecord record,
    Map<String, dynamic> customFormulasMap,
  ) {
    final bool isThreeTemp = record.epvatPressureType == 'Overall' ||
        record.cartridgeTemp.contains(',') ||
        record.cartridgeTemp.contains(';') ||
        record.notes.contains('Temps:') ||
        (record.cartridgeTemp.contains('21') && (record.cartridgeTemp.contains('52') || record.cartridgeTemp.contains('54')));

    final formulas = getFormulasForCaliber(
      customFormulasMap,
      record.caliber,
      isThreeTemp: isThreeTemp,
    );

    if (formulas.isEmpty) {
      return 'Approved';
    }

    final vars = extractVariablesFromRecords([record]);
    final defaultTemp = isThreeTemp
        ? '21'
        : (record.cartridgeTemp.replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim().isEmpty
            ? '21'
            : record.cartridgeTemp.replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim());

    for (final f in formulas) {
      final item = Map<String, dynamic>.from(f as Map);
      final res = evaluateFormulaItem(
        item,
        vars,
        defaultTemp: defaultTemp,
        activePressureUnit: record.epvatPressureUnit.isNotEmpty ? record.epvatPressureUnit : 'bar',
      );
      if (res.isApplicable && !res.isPassed) {
        return 'Rejected';
      }
    }
    return 'Approved';
  }
}
