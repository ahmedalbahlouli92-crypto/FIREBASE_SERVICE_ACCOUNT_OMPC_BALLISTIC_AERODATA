import 'dart:convert';
import 'package:archive/archive.dart';

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

      // Check whitespace-separated table rows (machine reports)
      final wsParts = line.split(RegExp(r'\s{2,}|\t')).where((t) => t.trim().isNotEmpty).toList();
      if (wsParts.length >= 2) {
        tableData.add(wsParts);
        if (wsParts.length == 2 && wsParts[0].isNotEmpty && wsParts[1].isNotEmpty) {
          kvMap.putIfAbsent(wsParts[0].toLowerCase(), () => wsParts[1]);
        }
      }
      final spaceTokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (spaceTokens.length >= 2) {
        final firstUpper = spaceTokens[0].toUpperCase();
        if (firstUpper == 'MEAN' || firstUpper == 'MAX' || firstUpper == 'MIN' || firstUpper == 'RANGE' || firstUpper == 'STDEV' || firstUpper == 'STD' || int.tryParse(firstUpper) != null) {
          tableData.add(spaceTokens);
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

    // Mirror both camelCase and snake_case versions
    final mirror = <String, dynamic>{};
    fields.forEach((k, v) {
      if (k == 'accMeanX') mirror['acc_mean_x'] = v;
      if (k == 'accMeanY') mirror['acc_mean_y'] = v;
      if (k == 'accMaxX') mirror['acc_max_x'] = v;
      if (k == 'accMaxY') mirror['acc_max_y'] = v;
      if (k == 'accMinX') mirror['acc_min_x'] = v;
      if (k == 'accMinY') mirror['acc_min_y'] = v;
      if (k == 'accRangeX') mirror['acc_range_x'] = v;
      if (k == 'accRangeY') mirror['acc_range_y'] = v;
      if (k == 'accSDX') mirror['acc_sd_x'] = v;
      if (k == 'accSDY') mirror['acc_sd_y'] = v;
      if (k == 'accMeanRadius') mirror['acc_mean_radius'] = v;
      if (k == 'velMean') mirror['vel_mean'] = v;
      if (k == 'velMax') mirror['vel_max'] = v;
      if (k == 'velMin') mirror['vel_min'] = v;
      if (k == 'velRange') mirror['vel_range'] = v;
      if (k == 'velSD') mirror['vel_sd'] = v;
      if (k == 'lotNo') mirror['lot_no'] = v;
      if (k == 'hopperNo') mirror['hopper_no'] = v;
      if (k == 'testTime') mirror['test_time'] = v;
      if (k == 'barrelSN') mirror['barrel_sn'] = v;
      if (k == 'cartridgeTemp') mirror['cartridge_temp'] = v;
      if (k == 'cyclicRateValue') mirror['cyclic_rpm'] = v;
      if (k == 'primerHbar') mirror['primer_hbar'] = v;
      if (k == 'primerSD') mirror['primer_sd'] = v;
    });
    fields.addAll(mirror);

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

    final lot = find(['lot no', 'lot number', 'lot #', 'lot_no', 'lot', 'name']);
    if (lot != null && lot.isNotEmpty) {
      String cleanLot = lot.trim();
      final lotMatch = RegExp(r'(?:lot|lot\s*no\.?)\s*[:#\-]?\s*([A-Za-z0-9\/\s\-]+)', caseSensitive: false).firstMatch(cleanLot);
      if (lotMatch != null) {
        cleanLot = lotMatch.group(1)!.trim();
      }
      f['lotNo'] = cleanLot;
      s.add('Lot Number: $cleanLot');
    }

    final hopper = find(['hopper no', 'hopper number', 'hopper #', 'hopper']);
    if (hopper != null && hopper.isNotEmpty) {
      f['hopperNo'] = hopper;
      s.add('Hopper No: $hopper');
    }

    final caliber = find(['calibre', 'caliber', 'specification', 'ammo']);
    if (caliber != null && caliber.isNotEmpty) {
      String cleanCal = caliber.trim();
      if (cleanCal.toLowerCase().contains('ss109')) {
        cleanCal = '5.56x45 SS109';
      } else if (cleanCal.toLowerCase().contains('m193')) {
        cleanCal = '5.56x45 M193';
      } else if (cleanCal.toLowerCase().contains('m80')) {
        cleanCal = '7.62x51 M80';
      } else if (cleanCal.toLowerCase().contains('9mm') || cleanCal.toLowerCase().contains('9x19')) {
        cleanCal = '9x19mm Para';
      }
      f['caliber'] = cleanCal;
      s.add('Caliber: $cleanCal');
    }

    final inspector = find(['operator name', 'operator', 'inspector', 'technician', 'tested by']);
    if (inspector != null && inspector.isNotEmpty) {
      f['operators'] = inspector.trim();
      s.add('Inspector: ${f['operators']}');
    }

    final dateStr = find(['date', 'time', 'test time']);
    if (dateStr != null && dateStr.isNotEmpty) {
      f['testTime'] = dateStr.trim();
      s.add('Date/Time: ${f['testTime']}');
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

    // 1. Dedicated parser for ballistic measuring reports (Attachment 3: Statistic table with MEAN, MAX, MIN, RANGE, STDEV)
    for (final row in table) {
      if (row.isEmpty) continue;
      final label = row[0].toUpperCase().trim();
      final nums = row.skip(1).map((x) => parseNum(x)).where((n) => n != null).cast<double>().toList();
      if (label == 'MEAN' && nums.length >= 3) {
        f['accMeanX'] = nums[0].toStringAsFixed(2);
        f['accMeanY'] = nums[1].toStringAsFixed(2);
        f['velMean'] = nums[2].toStringAsFixed(2);
        s.add('Mean X: ${f['accMeanX']} mm, Mean Y: ${f['accMeanY']} mm, Mean Vel: ${f['velMean']} m/s');
      } else if (label == 'MAX' && nums.length >= 3) {
        f['accMaxX'] = nums[0].toStringAsFixed(2);
        f['accMaxY'] = nums[1].toStringAsFixed(2);
        f['velMax'] = nums[2].toStringAsFixed(2);
      } else if (label == 'MIN' && nums.length >= 3) {
        f['accMinX'] = nums[0].toStringAsFixed(2);
        f['accMinY'] = nums[1].toStringAsFixed(2);
        f['velMin'] = nums[2].toStringAsFixed(2);
      } else if (label == 'RANGE' && nums.length >= 3) {
        f['accRangeX'] = nums[0].toStringAsFixed(2);
        f['accRangeY'] = nums[1].toStringAsFixed(2);
        f['velRange'] = nums[2].toStringAsFixed(2);
      } else if ((label == 'STDEV' || label == 'STD' || label == 'SD') && nums.length >= 3) {
        f['accSDX'] = nums[0].toStringAsFixed(2);
        f['accSDY'] = nums[1].toStringAsFixed(2);
        f['velSD'] = nums[2].toStringAsFixed(2);
        s.add('SD X: ${f['accSDX']} mm, SD Y: ${f['accSDY']} mm, SD Vel: ${f['velSD']} m/s');
      }
    }

    // 2. Count tested shots from Round Table if present
    int maxRoundNo = 0;
    for (final row in table) {
      if (row.length >= 3) {
        final rNo = int.tryParse(row[0].trim());
        if (rNo != null && rNo > maxRoundNo && rNo <= 100) {
          maxRoundNo = rNo;
        }
      }
    }
    if (maxRoundNo > 0 && f['produced'] == null) {
      f['produced'] = '$maxRoundNo';
      s.add('Tested Rounds: $maxRoundNo');
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

  /// Extracts results from raw file bytes, supporting PDF, CSV, TSV, TXT, and JSON formats.
  static ExtractedResults extractFromBytes({
    required List<int> bytes,
    String? filename,
    String? preferredTestName,
  }) {
    final isPdf = (filename != null && filename.toLowerCase().endsWith('.pdf')) ||
        (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46); // %PDF

    String content = '';
    if (isPdf) {
      content = PdfTextExtractor.extractText(bytes);
    } else {
      content = utf8.decode(bytes, allowMalformed: true);
    }

    return extract(content: content, preferredTestName: preferredTestName);
  }
}

/// Standalone PDF Text Extraction engine supporting extraction of machine test results
class PdfTextExtractor {
  /// Extracts text from PDF bytes without requiring external native dependencies.
  static String extractText(List<int> bytes) {
    if (bytes.isEmpty) return '';

    final buffer = StringBuffer();

    // 1. Search for and decompress PDF stream objects (FlateDecode)
    final zlibDecoder = ZLibDecoder();
    int searchIdx = 0;
    while (searchIdx < bytes.length) {
      // Find "stream"
      int streamStart = -1;
      for (int i = searchIdx; i < bytes.length - 6; i++) {
        if (bytes[i] == 0x73 && // 's'
            bytes[i + 1] == 0x74 && // 't'
            bytes[i + 2] == 0x72 && // 'r'
            bytes[i + 3] == 0x65 && // 'e'
            bytes[i + 4] == 0x61 && // 'a'
            bytes[i + 5] == 0x6D) { // 'm'
          int offset = i + 6;
          if (offset < bytes.length && (bytes[offset] == 0x0D || bytes[offset] == 0x0A)) {
            if (bytes[offset] == 0x0D && offset + 1 < bytes.length && bytes[offset + 1] == 0x0A) {
              offset += 2;
            } else {
              offset += 1;
            }
            streamStart = offset;
            break;
          }
        }
      }

      if (streamStart == -1) break;

      // Find "endstream"
      int streamEnd = -1;
      for (int i = streamStart; i < bytes.length - 9; i++) {
        if (bytes[i] == 0x65 && // 'e'
            bytes[i + 1] == 0x6E && // 'n'
            bytes[i + 2] == 0x64 && // 'd'
            bytes[i + 3] == 0x73 && // 's'
            bytes[i + 4] == 0x74 && // 't'
            bytes[i + 5] == 0x72 && // 'r'
            bytes[i + 6] == 0x65 && // 'e'
            bytes[i + 7] == 0x61 && // 'a'
            bytes[i + 8] == 0x6D) { // 'm'
          int end = i;
          if (end > streamStart && (bytes[end - 1] == 0x0A || bytes[end - 1] == 0x0D)) {
            end--;
            if (end > streamStart && bytes[end - 1] == 0x0D) {
              end--;
            }
          }
          streamEnd = end;
          searchIdx = i + 9;
          break;
        }
      }

      if (streamEnd == -1 || streamEnd <= streamStart) {
        searchIdx = streamStart;
        continue;
      }

      final streamSlice = bytes.sublist(streamStart, streamEnd);
      List<int>? decompressed;
      try {
        decompressed = zlibDecoder.decodeBytes(streamSlice, verify: false);
      } catch (_) {}

      final streamTextBytes = decompressed ?? streamSlice;
      final streamStr = latin1.decode(streamTextBytes, allowInvalid: true);

      // Search BT ... ET in stream
      final btMatches = RegExp(r'BT\b([\s\S]*?)\bET', caseSensitive: false).allMatches(streamStr);
      for (final m in btMatches) {
        final parsedBlock = _parsePdfTextBlock(m.group(1) ?? '');
        if (parsedBlock.trim().isNotEmpty) {
          buffer.writeln(parsedBlock.trim());
        }
      }

      // Also search Tj and TJ in stream
      if (btMatches.isEmpty && decompressed != null) {
        final tjMatches = RegExp(r'\(([^)]+)\)\s*(?:Tj|\x27|\x22)', caseSensitive: false).allMatches(streamStr);
        for (final m in tjMatches) {
          final s = _unescapePdfString(m.group(1) ?? '').trim();
          if (s.isNotEmpty) buffer.writeln(s);
        }
      }
    }

    // Convert bytes to Latin-1 string as fallback
    final raw = latin1.decode(bytes, allowInvalid: true);

    // 2. Search for text objects BT ... ET in full file if buffer is still short
    if (buffer.length < 20) {
      final btEtPattern = RegExp(r'BT\b([\s\S]*?)\bET', caseSensitive: false);
      final btMatches = btEtPattern.allMatches(raw);

      if (btMatches.isNotEmpty) {
        for (final match in btMatches) {
          final textBlock = match.group(1) ?? '';
          final blockText = _parsePdfTextBlock(textBlock);
          if (blockText.trim().isNotEmpty) {
            buffer.writeln(blockText.trim());
          }
        }
      }
    }

    // 2. If BT ... ET was empty or yielded minimal text, parse all text string literals in the file
    if (buffer.length < 20) {
      final literalPattern = RegExp(r'\(([^)]+)\)\s*(?:Tj|\x27|\x22)', caseSensitive: false);
      for (final m in literalPattern.allMatches(raw)) {
        final unescaped = _unescapePdfString(m.group(1) ?? '');
        if (unescaped.trim().isNotEmpty) {
          buffer.writeln(unescaped.trim());
        }
      }

      final tjArrayPattern = RegExp(r'\[([\s\S]*?)\]\s*TJ', caseSensitive: false);
      for (final m in tjArrayPattern.allMatches(raw)) {
        final inner = m.group(1) ?? '';
        final parts = RegExp(r'\(([^)]*)\)').allMatches(inner).map((sm) => _unescapePdfString(sm.group(1) ?? '')).join('');
        if (parts.trim().isNotEmpty) {
          buffer.writeln(parts.trim());
        }
      }
    }

    // 3. Fallback: extract readable ASCII strings (measurements, labels, values)
    if (buffer.length < 20) {
      final readablePattern = RegExp(r'([A-Za-z0-9\.\-\:\,\=\s\/\+\#]{4,})');
      for (final m in readablePattern.allMatches(raw)) {
        final s = m.group(0)!.trim();
        if (s.length >= 4 && !s.contains('obj') && !s.contains('endobj') && !s.contains('xref') && !s.contains('/Filter') && !s.contains('/Type')) {
          buffer.writeln(s);
        }
      }
    }

    return buffer.toString().trim();
  }

  static String _parsePdfTextBlock(String block) {
    final sb = StringBuffer();
    final tjPattern = RegExp(r'\(([^)]*)\)\s*(?:Tj|\x27|\x22)', caseSensitive: false);
    for (final m in tjPattern.allMatches(block)) {
      final str = _unescapePdfString(m.group(1) ?? '');
      sb.write('$str ');
    }

    final arrayPattern = RegExp(r'\[([\s\S]*?)\]\s*TJ', caseSensitive: false);
    for (final m in arrayPattern.allMatches(block)) {
      final inner = m.group(1) ?? '';
      final innerMatches = RegExp(r'\(([^)]*)\)').allMatches(inner);
      for (final im in innerMatches) {
        sb.write(_unescapePdfString(im.group(1) ?? ''));
      }
      sb.write(' ');
    }

    return sb.toString();
  }

  static String _unescapePdfString(String input) {
    return input
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', ' ');
  }
}
