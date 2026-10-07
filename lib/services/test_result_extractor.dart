import 'dart:convert';

/// Data extraction engine for automatic ballistic machine file parsing
class ExtractedResults {
  final Map<String, dynamic> fields;
  final List<String> summaryLines;
  final String detectedTest;

  const ExtractedResults({
    required this.fields,
    required this.summaryLines,
    required this.detectedTest,
  });

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => fields.isNotEmpty;
}

class TestResultExtractor {
  /// Parses raw file content (CSV, TSV, JSON, or plain text log)
  /// and extracts key ballistic test metrics.
  static ExtractedResults extract({
    required String content,
    String? preferredTestName,
  }) {
    final fields = <String, dynamic>{};
    final summary = <String>[];
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      return ExtractedResults(
        fields: fields,
        summaryLines: ['File is empty.'],
        detectedTest: preferredTestName ?? '',
      );
    }

    // 1. Try parsing as JSON first
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return _extractFromJson(decoded, preferredTestName);
        }
      } catch (_) {}
    }

    // 2. Parse text/CSV/TSV lines
    final lines = trimmed.split(RegExp(r'\r?\n'));
    final lowerContent = trimmed.toLowerCase();

    // Detect test name if not specified
    String detectedTest = preferredTestName ?? '';
    if (detectedTest.isEmpty) {
      if (lowerContent.contains('accuracy') || lowerContent.contains('mean radius') || lowerContent.contains('extreme spread') || lowerContent.contains('group sd')) {
        detectedTest = 'Accuracy Test';
      } else if (lowerContent.contains('epvat') || lowerContent.contains('chamber pressure') || lowerContent.contains('p1') || lowerContent.contains('port pressure')) {
        detectedTest = 'EPVAT test';
      } else if (lowerContent.contains('extraction force') || lowerContent.contains('pull force') || lowerContent.contains('bullet extraction')) {
        detectedTest = 'Extraction Force Test';
      } else if (lowerContent.contains('waterproof') || lowerContent.contains('bubble') || lowerContent.contains('leak')) {
        detectedTest = 'Waterproof Test';
      } else if (lowerContent.contains('function') || lowerContent.contains('malfunction') || lowerContent.contains('stoppage')) {
        detectedTest = 'Function Test';
      } else if (lowerContent.contains('residual stress') || lowerContent.contains('mercurous') || lowerContent.contains('splits')) {
        detectedTest = 'Residual Stress Test';
      } else if (lowerContent.contains('primer sensitivity') || lowerContent.contains('drop ball') || lowerContent.contains('h-bar')) {
        detectedTest = 'Primer Sensitivity Test';
      } else if (lowerContent.contains('rate of fire') || lowerContent.contains('cyclic')) {
        detectedTest = 'Firing Rate Cycle Test';
      } else {
        detectedTest = 'Accuracy Test';
      }
    }

    // Helper map of key-value patterns
    final kvMap = <String, String>{};
    final List<List<String>> tableData = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check CSV/TSV table row
      if (line.contains(',') || line.contains('\t') || line.contains(';')) {
        final parts = line.split(RegExp(r'[,;\t]')).map((s) => s.trim()).toList();
        if (parts.length >= 2) {
          tableData.add(parts);
          // Also try key-value extraction for 2-column tables
          if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
            kvMap[parts[0].toLowerCase()] = parts[1];
          }
        }
      }

      // Check colon or equals key:value
      final colonIdx = line.indexOf(':');
      final equalsIdx = line.indexOf('=');
      final sepIdx = colonIdx != -1 ? colonIdx : equalsIdx;
      if (sepIdx != -1 && sepIdx > 0 && sepIdx < line.length - 1) {
        final k = line.substring(0, sepIdx).trim().toLowerCase();
        final v = line.substring(sepIdx + 1).trim();
        kvMap[k] = v;
      }
    }

    // Extract General Meta Fields
    _extractGeneralFields(kvMap, fields, summary);

    // Extract based on detected test
    if (detectedTest == 'Accuracy Test') {
      _extractAccuracy(kvMap, tableData, fields, summary);
    } else if (detectedTest == 'EPVAT test' || detectedTest == 'Propellant Test') {
      _extractEpvat(kvMap, tableData, fields, summary);
    } else if (detectedTest == 'Extraction Force Test') {
      _extractExtraction(kvMap, tableData, fields, summary);
    } else if (detectedTest == 'Waterproof Test') {
      _extractWaterproof(kvMap, fields, summary);
    } else if (detectedTest == 'Function Test') {
      _extractFunction(kvMap, fields, summary);
    } else if (detectedTest == 'Primer Sensitivity Test') {
      _extractPrimer(kvMap, tableData, fields, summary);
    } else if (detectedTest == 'Residual Stress Test') {
      _extractResidualStress(kvMap, fields, summary);
    } else if (detectedTest == 'Firing Rate Cycle Test') {
      _extractCyclic(kvMap, fields, summary);
    }

    return ExtractedResults(
      fields: fields,
      summaryLines: summary,
      detectedTest: detectedTest,
    );
  }

  static void _extractGeneralFields(Map<String, String> kv, Map<String, dynamic> f, List<String> s) {
    String? find(List<String> keys) {
      for (final k in keys) {
        for (final entry in kv.entries) {
          if (entry.key.contains(k)) return entry.value;
        }
      }
      return null;
    }

    final lot = find(['lot no', 'lot number', 'lot #', 'lot_no', 'lot']);
    if (lot != null && lot.isNotEmpty) {
      f['lotNo'] = lot;
      s.add('Lot Number: $lot');
    }

    final hopper = find(['hopper no', 'hopper number', 'hopper #', 'hopper']);
    if (hopper != null && hopper.isNotEmpty) {
      f['hopperNo'] = hopper;
      s.add('Hopper No: $hopper');
    }

    final caliber = find(['caliber', 'calibre', 'specification', 'ammo']);
    if (caliber != null && caliber.isNotEmpty) {
      f['caliber'] = caliber;
      s.add('Caliber: $caliber');
    }

    final inspector = find(['inspector', 'operator', 'technician', 'tested by']);
    if (inspector != null && inspector.isNotEmpty) {
      f['operators'] = inspector;
      s.add('Inspector: $inspector');
    }

    final barrel = find(['barrel', 'barrel s.n', 'barrel sn', 'barrel_sn', 'weapon sn']);
    if (barrel != null && barrel.isNotEmpty) {
      f['barrelSN'] = barrel;
      s.add('Barrel SN: $barrel');
    }

    final temp = find(['temp', 'temperature', 'cartridge temp']);
    if (temp != null && temp.isNotEmpty) {
      final cleanTemp = temp.replaceAll(RegExp(r'[^0-9+\-]'), '');
      if (cleanTemp.isNotEmpty) {
        f['cartridgeTemp'] = cleanTemp;
        s.add('Temperature: $cleanTemp°C');
      }
    }
  }

  static void _extractAccuracy(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    // Try finding explicit statistics
    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('mean vel') || k.contains('velocity mean') || k.contains('avg vel') || k == 'v_mean' || k == 'vel mean') {
        final num = parseNum(v);
        if (num != null) f['velMean'] = num.toStringAsFixed(2);
      } else if (k.contains('min vel') || k == 'v_min' || k == 'vel min') {
        final num = parseNum(v);
        if (num != null) f['velMin'] = num.toStringAsFixed(2);
      } else if (k.contains('max vel') || k == 'v_max' || k == 'vel max') {
        final num = parseNum(v);
        if (num != null) f['velMax'] = num.toStringAsFixed(2);
      } else if (k.contains('sd vel') || k.contains('sd of vel') || k == 'v_sd' || k == 'vel sd') {
        final num = parseNum(v);
        if (num != null) f['velSD'] = num.toStringAsFixed(2);
      } else if (k.contains('range vel') || k == 'v_range') {
        final num = parseNum(v);
        if (num != null) f['velRange'] = num.toStringAsFixed(2);
      } else if (k.contains('mean radius') || k.contains('mean_radius') || k == 'mr') {
        final num = parseNum(v);
        if (num != null) f['accMeanRadius'] = num.toStringAsFixed(2);
      } else if (k.contains('extreme spread') || k.contains('extreme_spread') || k == 'es') {
        final num = parseNum(v);
        if (num != null) f['accExtremeSpread'] = num.toStringAsFixed(2);
      } else if (k.contains('figure of merit') || k == 'fom') {
        final num = parseNum(v);
        if (num != null) f['accFigureOfMerit'] = num.toStringAsFixed(2);
      } else if (k.contains('mean x') || k == 'x_mean') {
        final num = parseNum(v);
        if (num != null) f['accMeanX'] = num.toStringAsFixed(2);
      } else if (k.contains('sd x') || k.contains('sdx') || k == 'x_sd') {
        final num = parseNum(v);
        if (num != null) f['accSDX'] = num.toStringAsFixed(2);
      } else if (k.contains('min x') || k == 'x_min') {
        final num = parseNum(v);
        if (num != null) f['accMinX'] = num.toStringAsFixed(2);
      } else if (k.contains('max x') || k == 'x_max') {
        final num = parseNum(v);
        if (num != null) f['accMaxX'] = num.toStringAsFixed(2);
      } else if (k.contains('mean y') || k == 'y_mean') {
        final num = parseNum(v);
        if (num != null) f['accMeanY'] = num.toStringAsFixed(2);
      } else if (k.contains('sd y') || k.contains('sdy') || k == 'y_sd') {
        final num = parseNum(v);
        if (num != null) f['accSDY'] = num.toStringAsFixed(2);
      } else if (k.contains('min y') || k == 'y_min') {
        final num = parseNum(v);
        if (num != null) f['accMinY'] = num.toStringAsFixed(2);
      } else if (k.contains('max y') || k == 'y_max') {
        final num = parseNum(v);
        if (num != null) f['accMaxY'] = num.toStringAsFixed(2);
      }
    }

    // Try finding columnar shot data (e.g. shot, velocity, x, y)
    if (table.length >= 3) {
      final header = table.first.map((e) => e.toLowerCase()).toList();
      int velCol = header.indexWhere((h) => h.contains('vel') || h.contains('v(') || h == 'v');
      int xCol = header.indexWhere((h) => h == 'x' || h.contains('coord x') || h.contains('x('));
      int yCol = header.indexWhere((h) => h == 'y' || h.contains('coord y') || h.contains('y('));

      final velocities = <double>[];
      final xVals = <double>[];
      final yVals = <double>[];

      for (int i = 1; i < table.length; i++) {
        final row = table[i];
        if (velCol != -1 && velCol < row.length) {
          final v = parseNum(row[velCol]);
          if (v != null && v > 100) velocities.add(v);
        }
        if (xCol != -1 && xCol < row.length) {
          final x = parseNum(row[xCol]);
          if (x != null) xVals.add(x);
        }
        if (yCol != -1 && yCol < row.length) {
          final y = parseNum(row[yCol]);
          if (y != null) yVals.add(y);
        }
      }

      if (velocities.isNotEmpty && f['velMean'] == null) {
        final mean = velocities.reduce((a, b) => a + b) / velocities.length;
        final min = velocities.reduce((a, b) => a < b ? a : b);
        final max = velocities.reduce((a, b) => a > b ? a : b);
        final variance = velocities.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / (velocities.length > 1 ? (velocities.length - 1) : 1);
        final sd = variance > 0 ? (variance > 0 ? variance : 0) : 0;
        final sdVal = variance > 0 ? (variance) : 0;
        final double realSd = velocities.length > 1 ? (velocities.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / (velocities.length - 1)) : 0;
        f['velMean'] = mean.toStringAsFixed(2);
        f['velMin'] = min.toStringAsFixed(2);
        f['velMax'] = max.toStringAsFixed(2);
        f['velRange'] = (max - min).toStringAsFixed(2);
        f['velSD'] = (realSd > 0 ? (realSd) : 0).toStringAsFixed(2);
        f['produced'] = '${velocities.length}';
      }

      if (xVals.isNotEmpty && f['accMeanX'] == null) {
        final meanX = xVals.reduce((a, b) => a + b) / xVals.length;
        final minX = xVals.reduce((a, b) => a < b ? a : b);
        final maxX = xVals.reduce((a, b) => a > b ? a : b);
        final sdXVar = xVals.length > 1 ? (xVals.map((x) => (x - meanX) * (x - meanX)).reduce((a, b) => a + b) / (xVals.length - 1)) : 0.0;
        f['accMeanX'] = meanX.toStringAsFixed(2);
        f['accMinX'] = minX.toStringAsFixed(2);
        f['accMaxX'] = maxX.toStringAsFixed(2);
        f['accRangeX'] = (maxX - minX).toStringAsFixed(2);
        f['accSDX'] = (sdXVar > 0 ? (sdXVar) : 0.0).toStringAsFixed(2);
      }

      if (yVals.isNotEmpty && f['accMeanY'] == null) {
        final meanY = yVals.reduce((a, b) => a + b) / yVals.length;
        final minY = yVals.reduce((a, b) => a < b ? a : b);
        final maxY = yVals.reduce((a, b) => a > b ? a : b);
        final sdYVar = yVals.length > 1 ? (yVals.map((y) => (y - meanY) * (y - meanY)).reduce((a, b) => a + b) / (yVals.length - 1)) : 0.0;
        f['accMeanY'] = meanY.toStringAsFixed(2);
        f['accMinY'] = minY.toStringAsFixed(2);
        f['accMaxY'] = maxY.toStringAsFixed(2);
        f['accRangeY'] = (maxY - minY).toStringAsFixed(2);
        f['accSDY'] = (sdYVar > 0 ? (sdYVar) : 0.0).toStringAsFixed(2);
      }
    }

    if (f['velMean'] != null) s.add('Mean Velocity: ${f['velMean']} m/s');
    if (f['accSDX'] != null && f['accSDY'] != null) s.add('Group SD: X=${f['accSDX']} mm, Y=${f['accSDY']} mm');
    if (f['accMeanRadius'] != null) s.add('Mean Radius: ${f['accMeanRadius']} mm');
  }

  static void _extractEpvat(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;

      if (k.contains('p1 mean') || k.contains('p1_mean') || k.contains('chamber mean') || k == 'mean p1') {
        final num = parseNum(v);
        if (num != null) f['epvatMeanPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p1 max') || k.contains('p1_max') || k.contains('chamber max')) {
        final num = parseNum(v);
        if (num != null) f['epvatMaxPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p1 min') || k.contains('p1_min') || k.contains('chamber min')) {
        final num = parseNum(v);
        if (num != null) f['epvatMinPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p1 sd') || k.contains('p1_sd') || k.contains('chamber sd')) {
        final num = parseNum(v);
        if (num != null) f['epvatSDPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 mean') || k.contains('p2_mean') || k.contains('port mean') || k == 'mean p2') {
        final num = parseNum(v);
        if (num != null) f['epvatP2MeanPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 max') || k.contains('p2_max') || k.contains('port max')) {
        final num = parseNum(v);
        if (num != null) f['epvatP2MaxPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 min') || k.contains('p2_min') || k.contains('port min')) {
        final num = parseNum(v);
        if (num != null) f['epvatP2MinPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 sd') || k.contains('p2_sd') || k.contains('port sd')) {
        final num = parseNum(v);
        if (num != null) f['epvatP2SDPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('mean vel') || k.contains('vel mean') || k.contains('avg vel') || k == 'v_mean') {
        final num = parseNum(v);
        if (num != null) f['velMean'] = num.toStringAsFixed(2);
      } else if (k.contains('max vel') || k == 'v_max') {
        final num = parseNum(v);
        if (num != null) f['velMax'] = num.toStringAsFixed(2);
      } else if (k.contains('min vel') || k == 'v_min') {
        final num = parseNum(v);
        if (num != null) f['velMin'] = num.toStringAsFixed(2);
      } else if (k.contains('sd vel') || k == 'v_sd') {
        final num = parseNum(v);
        if (num != null) f['velSD'] = num.toStringAsFixed(2);
      } else if (k.contains('action time mean') || k.contains('at mean') || k == 'at_mean') {
        final num = parseNum(v);
        if (num != null) f['actionTimeMean'] = num.toStringAsFixed(3);
      } else if (k.contains('action time max') || k == 'at_max') {
        final num = parseNum(v);
        if (num != null) f['actionTimeMax'] = num.toStringAsFixed(3);
      } else if (k.contains('action time min') || k == 'at_min') {
        final num = parseNum(v);
        if (num != null) f['actionTimeMin'] = num.toStringAsFixed(3);
      } else if (k.contains('action time sd') || k == 'at_sd') {
        final num = parseNum(v);
        if (num != null) f['actionTimeSD'] = num.toStringAsFixed(3);
      } else if (k.contains('primer supplier')) {
        f['primerSupplier'] = v.trim();
      } else if (k.contains('primer lot')) {
        f['primerLot'] = v.trim();
      } else if (k.contains('propellant supplier')) {
        f['propellantSupplier'] = v.trim();
      } else if (k.contains('propellant lot')) {
        f['propellantLot'] = v.trim();
      } else if (k.contains('propellant code')) {
        f['propellantCode'] = v.trim();
      }
    }

    if (f['epvatMeanPressure'] != null) s.add('P1 Chamber Mean: ${f['epvatMeanPressure']} bar');
    if (f['epvatP2MeanPressure'] != null) s.add('P2 Port Mean: ${f['epvatP2MeanPressure']} bar');
    if (f['velMean'] != null) s.add('Mean Velocity: ${f['velMean']} m/s');
    if (f['actionTimeMean'] != null) s.add('Action Time Mean: ${f['actionTimeMean']} ms');
  }

  static void _extractExtraction(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    final forces = <double>[];
    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('min force') || k.contains('lowest force')) {
        final num = parseNum(v);
        if (num != null) f['accMinX'] = num.toStringAsFixed(1);
      } else if (k.contains('mean force') || k.contains('avg force')) {
        final num = parseNum(v);
        if (num != null) f['accMeanX'] = num.toStringAsFixed(1);
      } else if (k.contains('max force') || k.contains('peak force')) {
        final num = parseNum(v);
        if (num != null) f['accMaxX'] = num.toStringAsFixed(1);
      }
      if (RegExp(r'round\s*\d+').hasMatch(k) || RegExp(r'sample\s*\d+').hasMatch(k)) {
        final num = parseNum(v);
        if (num != null) forces.add(num);
      }
    }

    if (forces.isNotEmpty && f['accMinX'] == null) {
      final min = forces.reduce((a, b) => a < b ? a : b);
      final mean = forces.reduce((a, b) => a + b) / forces.length;
      final max = forces.reduce((a, b) => a > b ? a : b);
      f['accMinX'] = min.toStringAsFixed(1);
      f['accMeanX'] = mean.toStringAsFixed(1);
      f['accMaxX'] = max.toStringAsFixed(1);
      f['produced'] = '${forces.length}';
      f['roundForces'] = forces.map((e) => e.toStringAsFixed(1)).join(',');
    }

    if (f['accMinX'] != null) s.add('Min Force: ${f['accMinX']} N');
    if (f['accMeanX'] != null) s.add('Mean Force: ${f['accMeanX']} N');
  }

  static void _extractWaterproof(Map<String, String> kv, Map<String, dynamic> f, List<String> s) {
    int? parseInt(String? val) {
      if (val == null) return null;
      final match = RegExp(r'\d+').firstMatch(val);
      return match != null ? int.tryParse(match.group(0)!) : null;
    }

    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('mouth slow') || k == 'ms') f['mouthSlow'] = parseInt(v) ?? 0;
      else if (k.contains('mouth fast') || k == 'mf') f['mouthFast'] = parseInt(v) ?? 0;
      else if (k.contains('primer slow') || k == 'ps') f['primerSlow'] = parseInt(v) ?? 0;
      else if (k.contains('primer fast') || k == 'pf') f['primerFast'] = parseInt(v) ?? 0;
      else if (k.contains('pressure') && !k.contains('port')) {
        final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(v);
        if (match != null) f['pressureBar'] = match.group(0)!;
      } else if (k.contains('viscosity')) {
        final match = RegExp(r'\d+').firstMatch(v);
        if (match != null) f['viscosity'] = match.group(0)!;
      }
    }

    final totalLeaks = (f['mouthSlow'] as int? ?? 0) + (f['mouthFast'] as int? ?? 0) + (f['primerSlow'] as int? ?? 0) + (f['primerFast'] as int? ?? 0);
    s.add('Total Leaks: $totalLeaks (Mouth: ${f['mouthSlow'] ?? 0}/${f['mouthFast'] ?? 0}, Primer: ${f['primerSlow'] ?? 0}/${f['primerFast'] ?? 0})');
    if (f['pressureBar'] != null) s.add('Pressure: ${f['pressureBar']} bar');
  }

  static void _extractFunction(Map<String, String> kv, Map<String, dynamic> f, List<String> s) {
    int? parseInt(String? val) {
      if (val == null) return null;
      final match = RegExp(r'\d+').firstMatch(val);
      return match != null ? int.tryParse(match.group(0)!) : null;
    }

    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('level 1') || k.contains('l1') || k.contains('critical')) f['functionLevel1'] = parseInt(v) ?? 0;
      else if (k.contains('level 2') || k.contains('l2') || k.contains('major')) f['functionLevel2'] = parseInt(v) ?? 0;
      else if (k.contains('level 3') || k.contains('l3') || k.contains('minor')) f['functionLevel3'] = parseInt(v) ?? 0;
      else if (k.contains('level 4') || k.contains('l4')) f['functionLevel4'] = parseInt(v) ?? 0;
      else if (k.contains('tested') || k.contains('produced') || k.contains('rounds')) f['produced'] = '${parseInt(v) ?? 20}';
    }

    final l1 = f['functionLevel1'] as int? ?? 0;
    final l2 = f['functionLevel2'] as int? ?? 0;
    final l3 = f['functionLevel3'] as int? ?? 0;
    final l4 = f['functionLevel4'] as int? ?? 0;
    f['defects'] = '${l1 + l2 + l3 + l4}';
    s.add('Defects: L1=$l1, L2=$l2, L3=$l3, L4=$l4 (Total: ${l1 + l2 + l3 + l4})');
  }

  static void _extractPrimer(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('hbar') || k.contains('h-bar') || k.contains('average height') || k.contains('h̄')) {
        final num = parseNum(v);
        if (num != null) f['primerHbar'] = num.toStringAsFixed(2);
      } else if (k.contains('sd') || k.contains('standard deviation')) {
        final num = parseNum(v);
        if (num != null) f['primerSD'] = num.toStringAsFixed(2);
      } else if (k.contains('insertion depth') || k.contains('depth')) {
        final num = parseNum(v);
        if (num != null) f['primerInsertionDepth'] = num.toStringAsFixed(3);
      } else if (k.contains('weight') || k.contains('ball weight')) {
        final num = parseNum(v);
        if (num != null) f['primerDropWeight'] = num.toStringAsFixed(1);
      }
    }

    if (f['primerHbar'] != null) s.add('H-bar: ${f['primerHbar']} cm');
    if (f['primerSD'] != null) s.add('SD: ${f['primerSD']} cm');
    if (f['primerInsertionDepth'] != null) s.add('Insertion Depth: ${f['primerInsertionDepth']} mm');
  }

  static void _extractResidualStress(Map<String, String> kv, Map<String, dynamic> f, List<String> s) {
    int? parseInt(String? val) {
      if (val == null) return null;
      final match = RegExp(r'\d+').firstMatch(val);
      return match != null ? int.tryParse(match.group(0)!) : null;
    }

    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('neck slow') || k.contains('neck min')) f['neckSlow'] = parseInt(v) ?? 0;
      else if (k.contains('neck fast') || k.contains('neck maj')) f['neckFast'] = parseInt(v) ?? 0;
      else if (k.contains('shoulder slow') || k.contains('shoulder min')) f['shoulderSlow'] = parseInt(v) ?? 0;
      else if (k.contains('shoulder fast') || k.contains('shoulder maj')) f['shoulderFast'] = parseInt(v) ?? 0;
      else if (k.contains('body slow') || k.contains('body min')) f['bodySlow'] = parseInt(v) ?? 0;
      else if (k.contains('body fast') || k.contains('body maj')) f['bodyFast'] = parseInt(v) ?? 0;
      else if (k.contains('head slow') || k.contains('head min')) f['headSlow'] = parseInt(v) ?? 0;
      else if (k.contains('head fast') || k.contains('head maj')) f['headFast'] = parseInt(v) ?? 0;
    }

    final total = (f['neckSlow'] as int? ?? 0) + (f['neckFast'] as int? ?? 0) +
        (f['shoulderSlow'] as int? ?? 0) + (f['shoulderFast'] as int? ?? 0) +
        (f['bodySlow'] as int? ?? 0) + (f['bodyFast'] as int? ?? 0) +
        (f['headSlow'] as int? ?? 0) + (f['headFast'] as int? ?? 0);
    s.add('Total Splits/Cracks: $total');
  }

  static void _extractCyclic(Map<String, String> kv, Map<String, dynamic> f, List<String> s) {
    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('rpm') || k.contains('cyclic') || k.contains('rate of fire')) {
        final match = RegExp(r'\d+').firstMatch(v);
        if (match != null) f['cyclicRateValue'] = match.group(0)!;
      } else if (k.contains('weapon') || k.contains('model')) {
        f['cyclicRateWeaponType'] = v.trim();
      }
    }
    if (f['cyclicRateValue'] != null) s.add('Measured Cyclic RPM: ${f['cyclicRateValue']}');
  }

  static ExtractedResults _extractFromJson(Map<String, dynamic> json, String? preferredTest) {
    final fields = <String, dynamic>{};
    final summary = <String>[];
    json.forEach((k, v) {
      if (v != null) {
        fields[k] = v.toString();
        summary.add('$k: $v');
      }
    });
    return ExtractedResults(
      fields: fields,
      summaryLines: summary,
      detectedTest: preferredTest ?? (json['testName'] ?? json['test_name'] ?? 'Accuracy Test').toString(),
    );
  }
}
