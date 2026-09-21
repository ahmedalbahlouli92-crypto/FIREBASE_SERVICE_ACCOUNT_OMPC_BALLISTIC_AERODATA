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

    for (final r in records) {
      if (r.testName != 'EPVAT test') continue;
      String t = r.cartridgeTemp.trim();
      if (t.isEmpty) t = '+21';

      String sfx = '21';
      if (t.contains('52')) {
        sfx = '52';
      } else if (t.contains('54')) {
        sfx = '54';
      } else if (t.contains('32')) {
        sfx = '32';
      } else if (t.contains('21')) {
        sfx = '21';
      }

      vars['p1_mean_$sfx'] = double.tryParse(r.epvatMeanPressure) ?? 0.0;
      vars['p1_max_$sfx'] = double.tryParse(r.epvatMaxPressure) ?? 0.0;
      vars['p1_min_$sfx'] = double.tryParse(r.epvatMinPressure) ?? 0.0;
      vars['p1_range_$sfx'] = double.tryParse(r.epvatRangePressure) ?? 0.0;
      vars['p1_sd_$sfx'] = double.tryParse(r.epvatSDPressure) ?? 0.0;

      vars['p2_mean_$sfx'] = double.tryParse(r.epvatP2MeanPressure) ?? 0.0;
      vars['p2_max_$sfx'] = double.tryParse(r.epvatP2MaxPressure) ?? 0.0;
      vars['p2_min_$sfx'] = double.tryParse(r.epvatP2MinPressure) ?? 0.0;
      vars['p2_range_$sfx'] = double.tryParse(r.epvatP2RangePressure) ?? 0.0;
      vars['p2_sd_$sfx'] = double.tryParse(r.epvatP2SDPressure) ?? 0.0;

      vars['vel_mean_$sfx'] = double.tryParse(r.velMean) ?? 0.0;
      vars['vel_max_$sfx'] = double.tryParse(r.velMax) ?? 0.0;
      vars['vel_min_$sfx'] = double.tryParse(r.velMin) ?? 0.0;
      vars['vel_range_$sfx'] = double.tryParse(r.velRange) ?? 0.0;
      vars['vel_sd_$sfx'] = double.tryParse(r.velSD) ?? 0.0;
    }

    return vars;
  }

  /// Normalizes natural language formula into machine-parsable expression.
  /// Supports:
  /// - `3SD` -> `3 * sd`
  /// - `P1 Mean @ 21` -> `p1_mean_21`
  /// - `Mean P1 @ 21` -> `p1_mean_21`
  /// - `P1 Mean` (without temp) -> `p1_mean_$defaultTemp`
  /// - `|expr|` -> `abs(expr)`
  static String normalizeFormula(String input, {String defaultTemp = '21'}) {
    String expr = input.trim();

    // 1. Convert pipe absolute syntax |A - B| into abs(A - B)
    expr = expr.replaceAllMapped(RegExp(r'\|([^|]+)\|'), (m) => 'abs(${m[1]})');

    // 2. Handle implicit multiplication specifically for standalone numbers before SD, Sigma, or parenthesis:
    // e.g. "3SD" or "3 SD" or "3sd" -> "3 * sd"
    // Use negative lookbehind so digits inside "P1" or "P2" do NOT trigger multiplication on following words!
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z])(\d+)\s*(sd|sigma)\b', caseSensitive: false),
      (m) => '${m[1]} * ${m[2]}',
    );
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z])(\d+)\s*\('),
      (m) => '${m[1]} * (',
    );

    // 3. Normalise compound tokens WITH temperature suffixes or without:
    // e.g. "P1 Mean @ 21", "P1 Mean @ +21", "P1 Mean @52", "Mean P1 @ -54", "P1 SD @ 21", "P1 Mean"
    expr = expr.replaceAllMapped(
      RegExp(r'\b(p1|p2|vel(?:ocity)?|v)\s*(mean|sd|max|min|range)\s*(?:@\s*\+?(-?\d+))?\b', caseSensitive: false),
      (m) {
        final pRaw = m[1]!.toLowerCase();
        final param = pRaw.startsWith('v') ? 'vel' : pRaw;
        final metric = m[2]!.toLowerCase();
        String temp = m[3] ?? defaultTemp;
        temp = temp.replaceAll('-', '').replaceAll('+', '');
        return '${param}_${metric}_$temp';
      },
    );

    // Also inverted order: "Mean P1 @ 21", "SD P1 @ 52", "Mean P1", "SD P2"
    expr = expr.replaceAllMapped(
      RegExp(r'\b(mean|sd|max|min|range)\s*(p1|p2|vel(?:ocity)?|v)\s*(?:@\s*\+?(-?\d+))?\b', caseSensitive: false),
      (m) {
        final metric = m[1]!.toLowerCase();
        final pRaw = m[2]!.toLowerCase();
        final param = pRaw.startsWith('v') ? 'vel' : pRaw;
        String temp = m[3] ?? defaultTemp;
        temp = temp.replaceAll('-', '').replaceAll('+', '');
        return '${param}_${metric}_$temp';
      },
    );

    // 4. Standalone parameter mentions without metric (e.g. "P1 @ 21", "P1", "P2 @ 52")
    // Must NOT match already normalized tokens like p1_mean_21!
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_])(p1|p2)(?!\s*_[a-z0-9_])\s*(?:@\s*\+?(-?\d+))?(?![a-z0-9_])', caseSensitive: false),
      (m) {
        final param = m[1]!.toLowerCase();
        String temp = m[2] ?? defaultTemp;
        temp = temp.replaceAll('-', '').replaceAll('+', '');
        return '${param}_mean_$temp';
      },
    );

    // 5. Standalone "SD" or "Mean" or "Sigma" without parameter:
    // e.g. "3 * SD" -> "3 * p1_sd_21"
    expr = expr.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_])(sd|mean|sigma)(?:\s*@\s*\+?(-?\d+))?(?![a-z0-9_])', caseSensitive: false),
      (m) {
        final mRaw = m[1]!.toLowerCase();
        final metric = (mRaw == 'sigma' || mRaw == 'sd') ? 'sd' : 'mean';
        String temp = m[2] ?? defaultTemp;
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
  /// e.g. "3500 + 3 * 100 = 3800.00 bar"
  static String buildSubstitutedArithmetic(
    String originalFormula,
    Map<String, double> variables, {
    String defaultTemp = '21',
  }) {
    final String norm = normalizeFormula(originalFormula, defaultTemp: defaultTemp);
    String substituted = norm;

    // Sort variable keys by length descending to avoid partial replacement
    final keys = variables.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (substituted.contains(k)) {
        final val = variables[k] ?? 0.0;
        final valStr = val == val.roundToDouble() && !val.isNaN && !val.isInfinite
            ? val.toInt().toString()
            : val.toStringAsFixed(2);
        substituted = substituted.replaceAll(k, valStr);
      }
    }

    // Any remaining unresolved variable stems default to 0
    substituted = substituted.replaceAll(RegExp(r'\b(p1|p2|vel)_[a-z0-9_]+\b'), '0');

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

      final varVal = variables[token] ?? 0.0;
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
