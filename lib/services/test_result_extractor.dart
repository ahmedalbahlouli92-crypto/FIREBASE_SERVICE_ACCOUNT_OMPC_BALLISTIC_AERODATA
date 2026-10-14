import 'dart:convert';
import 'dart:math' as math;
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
  /// Safely normalizes text affected by raw glyph index font offsets (+29 Caesar cipher shift)
  static String normalizeShiftedText(String input) {
    if (!input.contains('5(&25') &&
        !input.contains('&DOLEUH') &&
        !input.contains('6XSSOLHU') &&
        !input.contains('3ULPHU') &&
        !input.contains("'\$7(")) {
      return input;
    }
    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (c >= 36 && c <= 61) {
        sb.writeCharCode(c + 29);
      } else if (c >= 68 && c <= 93) {
        sb.writeCharCode(c + 29);
      } else if (c == 63 || c == 73) {
        sb.write(':');
      } else {
        sb.writeCharCode(c);
      }
    }
    return sb.toString();
  }

  /// Parses raw file content (CSV, TSV, JSON, or plain text log)
  /// and extracts key ballistic test metrics.
  static ExtractedResults extract({
    required String content,
    String? preferredTestName,
  }) {
    final fields = <String, dynamic>{};
    final summary = <String>[];
    final normalizedContent = normalizeShiftedText(content);
    final trimmed = normalizedContent.trim();

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

    // Detect test name from content
    String? contentDetectedTest;
    if (lowerContent.contains('primer sensitivity') ||
        lowerContent.contains('hm+5sd') ||
        lowerContent.contains('hm-2sd') ||
        lowerContent.contains('h-bar') ||
        lowerContent.contains('drop ball') ||
        lowerContent.contains('primer insertion depth') ||
        (lowerContent.contains('primer') &&
            (lowerContent.contains('insertion depth') ||
             lowerContent.contains('hm') ||
             lowerContent.contains('alpha3') ||
             lowerContent.contains('misfire')))) {
      contentDetectedTest = 'Primer Sensitivity Test';
    } else if (lowerContent.contains('epvat') ||
        lowerContent.contains('p max') ||
        lowerContent.contains('p_max') ||
        lowerContent.contains('p max_1') ||
        lowerContent.contains('p max_2') ||
        lowerContent.contains('chamber pressure') ||
        lowerContent.contains('port pressure') ||
        lowerContent.contains('transducer') ||
        (lowerContent.contains('t4') && lowerContent.contains('ta'))) {
      contentDetectedTest = 'EPVAT test';
    } else if (lowerContent.contains('accuracy') ||
        lowerContent.contains('mean radius') ||
        lowerContent.contains('extreme spread') ||
        lowerContent.contains('group sd') ||
        lowerContent.contains('x_1') ||
        lowerContent.contains('y_1') ||
        lowerContent.contains('target system') ||
        lowerContent.contains('impact mean point') ||
        lowerContent.contains('largest distance')) {
      contentDetectedTest = 'Accuracy Test';
    } else if (lowerContent.contains('extraction force') ||
        lowerContent.contains('pull force') ||
        lowerContent.contains('bullet extraction')) {
      contentDetectedTest = 'Extraction Force Test';
    } else if (lowerContent.contains('waterproof') || lowerContent.contains('bubble') || lowerContent.contains('leak')) {
      contentDetectedTest = 'Waterproof Test';
    } else if (lowerContent.contains('function') || lowerContent.contains('malfunction') || lowerContent.contains('stoppage')) {
      contentDetectedTest = 'Function Test';
    } else if (lowerContent.contains('residual stress') || lowerContent.contains('mercurous') || lowerContent.contains('splits')) {
      contentDetectedTest = 'Residual Stress Test';
    } else if (lowerContent.contains('rate of fire') || lowerContent.contains('cyclic')) {
      contentDetectedTest = 'Firing Rate Cycle Test';
    } else if (lowerContent.contains('round table')) {
      if (lowerContent.contains('x_1') || lowerContent.contains('y_1')) {
        contentDetectedTest = 'Accuracy Test';
      } else {
        contentDetectedTest = 'EPVAT test';
      }
    }

    String detectedTest = preferredTestName ?? '';
    if (contentDetectedTest != null) {
      if (detectedTest.isEmpty ||
          detectedTest == 'Ballistic Tests' ||
          contentDetectedTest == 'Primer Sensitivity Test' ||
          !lowerContent.contains(detectedTest.toLowerCase())) {
        detectedTest = contentDetectedTest;
      }
    } else if (detectedTest.isEmpty) {
      detectedTest = 'Accuracy Test';
    }

    // Helper map of key-value patterns
    final kvMap = <String, String>{};
    final List<List<String>> tableData = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
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
        if (firstUpper == 'MEAN' ||
            firstUpper == 'MAX' ||
            firstUpper == 'MIN' ||
            firstUpper == 'RANGE' ||
            firstUpper == 'STDEV' ||
            firstUpper == 'STD' ||
            firstUpper == 'HM' ||
            firstUpper == 'SD' ||
            firstUpper == 'ALPHA3' ||
            firstUpper == 'EMAX' ||
            firstUpper == 'EMIN' ||
            int.tryParse(firstUpper) != null) {
          tableData.add(spaceTokens);
        }
        if (spaceTokens.length == 2 &&
            (firstUpper == 'HM' ||
             firstUpper == 'SD' ||
             firstUpper == 'ALPHA3' ||
             firstUpper == 'EMAX' ||
             firstUpper == 'EMIN')) {
          kvMap.putIfAbsent(firstUpper.toLowerCase(), () => spaceTokens[1]);
        }
      }

      // Check colon or equals key:value
      final colonIdx = line.indexOf(':');
      final equalsIdx = line.indexOf('=');
      final sepIdx = colonIdx != -1 ? colonIdx : equalsIdx;
      if (sepIdx != -1) {
        final k = line.substring(0, sepIdx).trim().toLowerCase();
        final v = line.substring(sepIdx + 1).trim();
        if (v.isNotEmpty) {
          kvMap.putIfAbsent(k, () => v);
        } else if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (nextLine.isNotEmpty && !nextLine.endsWith(':') && !nextLine.contains('=')) {
            kvMap.putIfAbsent(k, () => nextLine);
          }
        }
      } else {
        // Multi-line header without colon (e.g. Date \n Aug 4... or Calibre \n 7.62...)
        final lLower = line.toLowerCase();
        if ((lLower == 'date' ||
             lLower == 'calibre' ||
             lLower == 'caliber' ||
             lLower == 'operator name' ||
             lLower == 'operator' ||
             lLower == 'inspector name' ||
             lLower == 'inspector' ||
             lLower == 'measurement name' ||
             lLower == 'lot number' ||
             lLower == 'lot no' ||
             lLower == 'batch id' ||
             lLower == 'transducer 1' ||
             lLower == 'transducer 2' ||
             lLower == 'sensor 1' ||
             lLower == 'sensor 2' ||
             lLower == 'supplier' ||
             lLower == 'temperature' ||
             lLower.startsWith('temperature') ||
             lLower == 'primer insertion depth' ||
             lLower.startsWith('primer insertion depth') ||
             lLower == 'hm' ||
             lLower == 'sd' ||
             lLower == 'alpha3' ||
             lLower == 'emax' ||
             lLower == 'emin' ||
             lLower == 'hbar' ||
             lLower == 'h-bar' ||
             lLower == 'h̄' ||
             lLower == 'hm+5sd' ||
             lLower == 'hm-2sd') && i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (nextLine.isNotEmpty && !nextLine.endsWith(':') && !nextLine.contains('=')) {
            kvMap.putIfAbsent(lLower, () => nextLine);
          }
        }
      }
    }

    // Extract General Meta Fields
    _extractGeneralFields(kvMap, fields, summary, trimmed);

    // Extract based on detected test
    if (detectedTest == 'Accuracy Test') {
      _extractAccuracy(kvMap, tableData, fields, summary, trimmed);
    } else if (detectedTest == 'EPVAT test' || detectedTest == 'Propellant Test') {
      _extractEpvat(kvMap, tableData, fields, summary, trimmed);
    } else if (detectedTest == 'Extraction Force Test') {
      _extractExtraction(kvMap, tableData, fields, summary, trimmed);
    } else if (detectedTest == 'Waterproof Test') {
      _extractWaterproof(kvMap, fields, summary);
    } else if (detectedTest == 'Function Test') {
      _extractFunction(kvMap, fields, summary);
    } else if (detectedTest == 'Primer Sensitivity Test') {
      _extractPrimer(kvMap, tableData, fields, summary, trimmed);
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
      if (k == 'accLargestDistance') {
        mirror['acc_largest_distance'] = v;
        mirror['largest_distance'] = v;
      }
      if (k == 'accExtremeSpread') mirror['acc_extreme_spread'] = v;
      if (k == 'accSumHW') mirror['acc_sum_hw'] = v;
      if (k == 'distance') mirror['distance'] = v;
      if (k == 'velMean') mirror['vel_mean'] = v;
      if (k == 'velMax') mirror['vel_max'] = v;
      if (k == 'velMin') mirror['vel_min'] = v;
      if (k == 'velRange') mirror['vel_range'] = v;
      if (k == 'velSD') mirror['vel_sd'] = v;
      if (k == 'lotNo') mirror['lot_no'] = v;
      if (k == 'lotDigits') mirror['lot_digits'] = v;
      if (k == 'lotYear') mirror['lot_year'] = v;
      if (k == 'roundForces') {
        mirror['round_forces'] = v;
        mirror['extraction_force_rounds'] = v;
      }
      if (k == 'extractionForceType') mirror['extraction_force_type'] = v;
      if (k == 'hopperNo') mirror['hopper_no'] = v;
      if (k == 'testTime') mirror['test_time'] = v;
      if (k == 'barrelSN') mirror['barrel_sn'] = v;
      if (k == 'cartridgeTemp') mirror['cartridge_temp'] = v;
      if (k == 'cartridge_temp') mirror['cartridgeTemp'] = v;
      if (k == 'cyclicRateValue') mirror['cyclic_rpm'] = v;
      if (k == 'primerHbar') mirror['primer_hbar'] = v;
      if (k == 'primer_hbar') mirror['primerHbar'] = v;
      if (k == 'primerSD') mirror['primer_sd'] = v;
      if (k == 'primer_sd') mirror['primerSD'] = v;
      if (k == 'primerAllFire') {
        mirror['primer_all_fire'] = v;
        mirror['primer_hbar_plus_5s'] = v;
      }
      if (k == 'primer_all_fire' || k == 'primer_hbar_plus_5s') mirror['primerAllFire'] = v;
      if (k == 'primerNoFire') {
        mirror['primer_no_fire'] = v;
        mirror['primer_hbar_minus_2s'] = v;
      }
      if (k == 'primer_no_fire' || k == 'primer_hbar_minus_2s') mirror['primerNoFire'] = v;
      if (k == 'primerSupplier') mirror['primer_supplier'] = v;
      if (k == 'primer_supplier') mirror['primerSupplier'] = v;
      if (k == 'primerLot') mirror['primer_lot'] = v;
      if (k == 'primer_lot') mirror['primerLot'] = v;
      if (k == 'primerInsertionDepth') mirror['primer_insertion_depth'] = v;
      if (k == 'primer_insertion_depth') mirror['primerInsertionDepth'] = v;
      if (k == 'primerTotalTested') mirror['primer_total_tested'] = v;
      if (k == 'primer_total_tested') mirror['primerTotalTested'] = v;
      if (k == 'primerTotalRounds') mirror['primer_total_rounds'] = v;
      if (k == 'primer_total_rounds') mirror['primerTotalRounds'] = v;
      if (k == 'primerTotalFires') mirror['primer_total_fires'] = v;
      if (k == 'primer_total_fires') mirror['primerTotalFires'] = v;
      if (k == 'primerTotalMisfires') {
        mirror['primer_total_misfires'] = v;
        mirror['misfires'] = v;
      }
      if (k == 'primer_total_misfires' || k == 'misfires') mirror['primerTotalMisfires'] = v;
      if (k == 'primerAlpha3') mirror['primer_alpha3'] = v;
      if (k == 'primer_alpha3') mirror['primerAlpha3'] = v;
      if (k == 'primerEmax') mirror['primer_emax'] = v;
      if (k == 'primer_emax') mirror['primerEmax'] = v;
      if (k == 'primerEmin') mirror['primer_emin'] = v;
      if (k == 'primer_emin') mirror['primerEmin'] = v;
      if (k == 'roomTemp') mirror['room_temp'] = v;
      if (k == 'room_temp') mirror['roomTemp'] = v;
      if (k == 'testDate') mirror['test_date'] = v;
      if (k == 'test_date') mirror['testDate'] = v;

      // EPVAT field mirrors
      if (k == 'epvatMeanPressure') mirror['epvat_mean_pressure'] = v;
      if (k == 'epvat_mean_pressure') mirror['epvatMeanPressure'] = v;
      if (k == 'epvatMaxPressure') mirror['epvat_max_pressure'] = v;
      if (k == 'epvat_max_pressure') mirror['epvatMaxPressure'] = v;
      if (k == 'epvatMinPressure') mirror['epvat_min_pressure'] = v;
      if (k == 'epvat_min_pressure') mirror['epvatMinPressure'] = v;
      if (k == 'epvatRangePressure') mirror['epvat_range_pressure'] = v;
      if (k == 'epvat_range_pressure') mirror['epvatRangePressure'] = v;
      if (k == 'epvatSDPressure') mirror['epvat_sd_pressure'] = v;
      if (k == 'epvat_sd_pressure') mirror['epvatSDPressure'] = v;

      if (k == 'epvatP2MeanPressure') {
        mirror['epvat_p2_mean_pressure'] = v;
        mirror['epvat_p2_mean'] = v;
      }
      if (k == 'epvat_p2_mean_pressure' || k == 'epvat_p2_mean') mirror['epvatP2MeanPressure'] = v;
      if (k == 'epvatP2MaxPressure') {
        mirror['epvat_p2_max_pressure'] = v;
        mirror['epvat_p2_max'] = v;
      }
      if (k == 'epvat_p2_max_pressure' || k == 'epvat_p2_max') mirror['epvatP2MaxPressure'] = v;
      if (k == 'epvatP2MinPressure') {
        mirror['epvat_p2_min_pressure'] = v;
        mirror['epvat_p2_min'] = v;
      }
      if (k == 'epvat_p2_min_pressure' || k == 'epvat_p2_min') mirror['epvatP2MinPressure'] = v;
      if (k == 'epvatP2RangePressure') {
        mirror['epvat_p2_range_pressure'] = v;
        mirror['epvat_p2_range'] = v;
      }
      if (k == 'epvat_p2_range_pressure' || k == 'epvat_p2_range') mirror['epvatP2RangePressure'] = v;
      if (k == 'epvatP2SDPressure') {
        mirror['epvat_p2_sd_pressure'] = v;
        mirror['epvat_p2_sd'] = v;
      }
      if (k == 'epvat_p2_sd_pressure' || k == 'epvat_p2_sd') mirror['epvatP2SDPressure'] = v;

      if (k == 'actionTimeMean') mirror['action_time_mean'] = v;
      if (k == 'action_time_mean') mirror['actionTimeMean'] = v;
      if (k == 'actionTimeMax') mirror['action_time_max'] = v;
      if (k == 'action_time_max') mirror['actionTimeMax'] = v;
      if (k == 'actionTimeMin') mirror['action_time_min'] = v;
      if (k == 'action_time_min') mirror['actionTimeMin'] = v;
      if (k == 'actionTimeRange') mirror['action_time_range'] = v;
      if (k == 'action_time_range') mirror['actionTimeRange'] = v;
      if (k == 'actionTimeSD') mirror['action_time_sd'] = v;
      if (k == 'action_time_sd') mirror['actionTimeSD'] = v;

      if (k == 't4Mean') mirror['t4_mean'] = v;
      if (k == 't4_mean') mirror['t4Mean'] = v;
      if (k == 't4Max') mirror['t4_max'] = v;
      if (k == 't4_max') mirror['t4Max'] = v;
      if (k == 't4Min') mirror['t4_min'] = v;
      if (k == 't4_min') mirror['t4Min'] = v;
      if (k == 't4Range') mirror['t4_range'] = v;
      if (k == 't4_range') mirror['t4Range'] = v;
      if (k == 't4SD') mirror['t4_sd'] = v;
      if (k == 't4_sd') mirror['t4SD'] = v;
      if (k == 't4Rounds') mirror['t4_rounds'] = v;
      if (k == 't4_rounds') mirror['t4Rounds'] = v;

      if (k == 'primerDropTable') mirror['primer_drop_table'] = v;
      if (k == 'primer_drop_table') mirror['primerDropTable'] = v;

      if (k == 'epvatPressureUnit') mirror['epvat_pressure_unit'] = v;
      if (k == 'epvat_pressure_unit') mirror['epvatPressureUnit'] = v;
      if (k == 'epvatSensor1') {
        mirror['epvat_sensor1'] = v;
        mirror['transducer1'] = v;
      }
      if (k == 'epvat_sensor1' || k == 'transducer1') mirror['epvatSensor1'] = v;
      if (k == 'epvatSensor2') {
        mirror['epvat_sensor2'] = v;
        mirror['transducer2'] = v;
      }
      if (k == 'epvat_sensor2' || k == 'transducer2') mirror['epvatSensor2'] = v;

      if (k == 'epvatPressureRounds') mirror['epvat_pressure_rounds'] = v;
      if (k == 'epvat_pressure_rounds') mirror['epvatPressureRounds'] = v;
      if (k == 'epvatP2PressureRounds') mirror['epvat_p2_pressure_rounds'] = v;
      if (k == 'epvat_p2_pressure_rounds') mirror['epvatP2PressureRounds'] = v;
      if (k == 'actionTimeRounds') mirror['action_time_rounds'] = v;
      if (k == 'action_time_rounds') mirror['actionTimeRounds'] = v;
      if (k == 'epvatVelRounds') mirror['epvat_vel_rounds'] = v;
      if (k == 'epvat_vel_rounds') mirror['epvatVelRounds'] = v;
    });
    fields.addAll(mirror);

    return ExtractedResults(
      fields: fields,
      summaryLines: summary,
      detectedTest: detectedTest,
    );
  }

  static void _extractGeneralFields(Map<String, String> kv, Map<String, dynamic> f, List<String> s, [String content = '']) {
    String? find(List<String> keys, {List<String> exclude = const []}) {
      for (final k in keys) {
        for (final entry in kv.entries) {
          if (entry.key.contains(k) || (k == 'name' && entry.key == 'name')) {
            if (exclude.any((ex) => entry.key.contains(ex))) continue;
            return entry.value;
          }
        }
      }
      return null;
    }

    final lot = find(
      ['lot no', 'lot number', 'lot #', 'lot_no', 'lot', 'measurement name', 'measuring name', 'sample name', 'name', 'batchid', 'batch id', 'batch'],
      exclude: ['operator', 'inspector', 'technician', 'supplier', 'vendor'],
    );
    if (lot != null && lot.isNotEmpty) {
      String cleanLot = lot.trim();
      final lotMatch = RegExp(r'(?:lot|lot\s*no\.?)\s*[:#\-]?\s*([A-Za-z0-9\/\s\-]+)', caseSensitive: false).firstMatch(cleanLot);
      if (lotMatch != null) {
        cleanLot = lotMatch.group(1)!.trim();
      }
      final ompcMatch = RegExp(r'(?:Lot\s*)?(\d{1,4})\s*(?:OMPC[/\s]*)(\d{2})', caseSensitive: false).firstMatch(cleanLot);
      final dashYrMatch = RegExp(r'(\d{1,4})[\-\/](\d{2})\b').firstMatch(cleanLot);
      if (ompcMatch != null) {
        final digits = ompcMatch.group(1)!.padLeft(3, '0');
        final yr = ompcMatch.group(2)!;
        f['lotDigits'] = digits;
        f['lotYear'] = yr;
        f['lotNo'] = '$digits/OMPC/$yr';
        f['primerLot'] = cleanLot;
      } else if (dashYrMatch != null) {
        final digits = dashYrMatch.group(1)!.padLeft(3, '0');
        final yr = dashYrMatch.group(2)!;
        f['lotDigits'] = digits;
        f['lotYear'] = yr;
        f['primerLot'] = cleanLot;
        f['lotNo'] = cleanLot;
      } else {
        final numMatch = RegExp(r'(\d{1,4})').firstMatch(cleanLot);
        if (numMatch != null) {
          f['lotDigits'] = numMatch.group(1)!.padLeft(3, '0');
        }
        f['primerLot'] = cleanLot;
        f['lotNo'] = cleanLot;
      }
      s.add('Lot Number: ${f['lotNo']}');
    } else if (content.isNotEmpty) {
      final lotMatch = RegExp(
        r'(?:BatchID|Batch\s*ID|Lot\s*No\.?|Lot\s*Number|Lot\s*#|Lot)\s*[:=\t\s]*\r?\n?\s*([^\r\n,;]+)',
        caseSensitive: false,
      ).firstMatch(content);
      if (lotMatch != null) {
        final rawLot = lotMatch.group(1)!.trim();
        final ompcMatch = RegExp(r'(?:Lot\s*)?(\d{1,4})\s*(?:OMPC[/\s]*)(\d{2})', caseSensitive: false).firstMatch(rawLot);
        final dashYrMatch = RegExp(r'(\d{1,4})[\-\/](\d{2})\b').firstMatch(rawLot);
        if (ompcMatch != null) {
          final digits = ompcMatch.group(1)!.padLeft(3, '0');
          final yr = ompcMatch.group(2)!;
          f['lotDigits'] = digits;
          f['lotYear'] = yr;
          f['lotNo'] = '$digits/OMPC/$yr';
          f['primerLot'] = rawLot;
        } else if (dashYrMatch != null) {
          final digits = dashYrMatch.group(1)!.padLeft(3, '0');
          final yr = dashYrMatch.group(2)!;
          f['lotDigits'] = digits;
          f['lotYear'] = yr;
          f['primerLot'] = rawLot;
          f['lotNo'] = rawLot;
        } else {
          final numMatch = RegExp(r'(\d{1,4})').firstMatch(rawLot);
          if (numMatch != null) {
            f['lotDigits'] = numMatch.group(1)!.padLeft(3, '0');
          }
          f['primerLot'] = rawLot;
          f['lotNo'] = rawLot;
        }
        s.add('Lot Number: ${f['lotNo']}');
      }
    }

    final hopper = find(['hopper no', 'hopper number', 'hopper #', 'hopper']);
    if (hopper != null && hopper.isNotEmpty) {
      f['hopperNo'] = hopper;
      s.add('Hopper No: $hopper');
    }

    final supplier = find(['supplier name', 'supplier', 'manufacturer', 'vendor', 'primer supplier', 'primer_supplier']);
    if (supplier != null && supplier.isNotEmpty) {
      final cleanSup = supplier.trim();
      f['primerSupplier'] = cleanSup;
      f['supplier'] = cleanSup;
      s.add('Supplier: $cleanSup');
    } else if (content.isNotEmpty) {
      final supMatch = RegExp(
        r'(?:Supplier\s*Name|Supplier|Manufacturer|Vendor)\s*[:=\t\s]*\r?\n?\s*([^\r\n,;]+)',
        caseSensitive: false,
      ).firstMatch(content);
      if (supMatch != null) {
        final cleanSup = supMatch.group(1)!.trim();
        if (cleanSup.isNotEmpty) {
          f['primerSupplier'] = cleanSup;
          f['supplier'] = cleanSup;
          s.add('Supplier: $cleanSup');
        }
      }
    }

    final caliber = find(['calibre', 'caliber', 'specification', 'ammo']);
    if (caliber != null && caliber.isNotEmpty) {
      String cleanCal = caliber.trim();
      if (!cleanCal.toLowerCase().startsWith('specification') && !cleanCal.endsWith(':')) {
        if (cleanCal.toLowerCase().contains('ss109')) {
          cleanCal = '5.56x45 SS109';
        } else if (cleanCal.toLowerCase().contains('m193')) {
          cleanCal = '5.56x45 M193';
        } else if (cleanCal.toLowerCase().contains('m80') || cleanCal.toLowerCase().contains('7.62')) {
          cleanCal = '7.62x51 M80';
        } else if (cleanCal.toLowerCase().contains('9mm') || cleanCal.toLowerCase().contains('9x19')) {
          cleanCal = '9x19mm Para';
        } else if (cleanCal.contains('5.56')) {
          cleanCal = '5.56x45 SS109';
        }
        f['caliber'] = cleanCal;
        s.add('Caliber: $cleanCal');
      }
    }
    if (f['caliber'] == null && content.isNotEmpty) {
      final calMatch = RegExp(
        r'(?:Calibre|Caliber)(?:\s*(?:Specification|Spec|Type|Name|Description))?\s*[:=\t\s]*\r?\n?\s*([^\r\n,;]+)',
        caseSensitive: false,
      ).firstMatch(content);
      String? cleanCal;
      if (calMatch != null) {
        final raw = calMatch.group(1)!.trim().toLowerCase();
        if (raw.contains('ss109')) cleanCal = '5.56x45 SS109';
        else if (raw.contains('m193')) cleanCal = '5.56x45 M193';
        else if (raw.contains('5.56')) cleanCal = '5.56x45 SS109';
        else if (raw.contains('7.62') || raw.contains('m80')) cleanCal = '7.62x51 M80';
        else if (raw.contains('9mm') || raw.contains('9x19')) cleanCal = '9x19mm Para';
        else if (!raw.startsWith('specification') && !raw.endsWith(':')) cleanCal = calMatch.group(1)!.trim();
      }
      if (cleanCal == null) {
        final lower = content.toLowerCase();
        if (lower.contains('m80') || lower.contains('cal 7.62') || lower.contains('7.62x51') || lower.contains('cal. 7.62') || (lower.contains('extraction force') && lower.contains('7.62'))) {
          cleanCal = '7.62x51 M80';
        } else if (lower.contains('ss109') || (lower.contains('5.56') && lower.contains('ss109'))) {
          cleanCal = '5.56x45 SS109';
        } else if (lower.contains('m193') || (lower.contains('5.56') && lower.contains('m193'))) {
          cleanCal = '5.56x45 M193';
        } else if (lower.contains('5.56') || lower.contains('calibre: 5.56') || lower.contains('caliber: 5.56')) {
          cleanCal = '5.56x45 SS109';
        } else if (lower.contains('9mm') || lower.contains('9x19')) {
          cleanCal = '9x19mm Para';
        }
      }
      if (cleanCal != null) {
        f['caliber'] = cleanCal;
        s.add('Caliber: $cleanCal');
      }
    }

    final inspector = find(['operator name', 'operator', 'inspector name', 'inspector', 'technician', 'tested by', 'notes']);
    if (inspector != null && inspector.isNotEmpty) {
      final cleanVal = inspector.trim();
      if (!cleanVal.toLowerCase().contains('signature') &&
          !cleanVal.toLowerCase().contains('calculation') &&
          !cleanVal.toLowerCase().contains('overall result')) {
        f['operators'] = cleanVal;
        s.add('Inspector: $cleanVal');
      }
    }
    if (f['operators'] == null && content.isNotEmpty) {
      final opMatch = RegExp(
        r'(?:Inspector\s*Name|Operator\s*Name|Operator|Inspector|Technician|Tested\s*by|Notes)\s*[:=\t\s]*\r?\n?\s*([^\r\n]+)',
        caseSensitive: false,
      ).firstMatch(content);
      if (opMatch != null) {
        final val = opMatch.group(1)!.trim();
        if (val.isNotEmpty &&
            !val.toLowerCase().contains('signature') &&
            !val.toLowerCase().contains('calculation') &&
            !val.toLowerCase().contains('overall result')) {
          f['operators'] = val;
          s.add('Inspector: $val');
        }
      }
    }

    final dateStr = find(['date', 'time', 'test time', 'test date']);
    if (dateStr != null && dateStr.isNotEmpty) {
      final isDateLike = RegExp(r'\d{1,4}[.\/-]\d{1,2}[.\/-]\d{2,4}|[A-Za-z]{3,9}\s+\d{1,2}|\d{1,2}\s+[A-Za-z]{3,9}').hasMatch(dateStr);
      if (isDateLike) {
        f['testTime'] = dateStr.trim();
        f['testDate'] = dateStr.trim();
        s.add('Date/Time: ${f['testTime']}');
      }
    }
    if (f['testDate'] == null && content.isNotEmpty) {
      // 1. Check Date header followed by date
      final headerDateMatch = RegExp(
        r'(?:DATE|Date\s*of\s*Test|Test\s*Date|Test\s*Time|Time)\s*[:=\t\s]*\r?\n?\s*('
        r'[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?)?'
        r'|\d{1,2}\s+[A-Za-z]{3,9},?\s+\d{4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?)?'
        r'|\d{1,2}[.\/-]\d{1,2}[.\/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?)?'
        r'|\d{4}[.\/-]\d{1,2}[.\/-]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?)?'
        r')',
        caseSensitive: false,
      ).firstMatch(content);
      if (headerDateMatch != null) {
        final dVal = headerDateMatch.group(1)!.trim();
        f['testTime'] = dVal;
        f['testDate'] = dVal;
        s.add('Date/Time: $dVal');
      } else {
        // 2. Search standalone date formats anywhere in content
        final anyDateMatch = RegExp(
          r'\b('
          r'[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?)?'
          r'|\d{1,2}[.\/-]\d{1,2}[.\/-]\d{2,4}'
          r'|\d{4}[.\/-]\d{1,2}[.\/-]\d{1,2}'
          r')\b',
          caseSensitive: false,
        ).firstMatch(content);
        if (anyDateMatch != null) {
          final dVal = anyDateMatch.group(1)!.trim();
          f['testTime'] = dVal;
          f['testDate'] = dVal;
          s.add('Date/Time: $dVal');
        }
      }
    }

    final barrel = find(['barrel', 'barrel s.n', 'barrel sn', 'barrel_sn', 'weapon sn']);
    if (barrel != null && barrel.isNotEmpty) {
      f['barrelSN'] = barrel;
      s.add('Barrel SN: $barrel');
    }

    final temp = find(['temp', 'temperature', 'cartridge temp', 'room temp']);
    if (temp != null && temp.isNotEmpty) {
      final m = RegExp(r'([+\-]?\s*\d{1,3})\s*(?:°\s*[cC]|\b[cC]\b|deg)?').firstMatch(temp);
      if (m != null) {
        String cleanTemp = m.group(1)!.replaceAll(RegExp(r'\s+'), '');
        if (!cleanTemp.startsWith('+') && !cleanTemp.startsWith('-')) {
          cleanTemp = '+$cleanTemp';
        }
        f['cartridgeTemp'] = cleanTemp;
        f['roomTemp'] = cleanTemp;
        s.add('Temperature: $cleanTemp°C');
      }
    }
    if ((f['cartridgeTemp'] == null || f['roomTemp'] == null) && content.isNotEmpty) {
      final tempMatch = RegExp(r'(?:Temperature\s*\(?C°?\)?|Room\s*Temp|Temp)\s*[:=\t\s]*([+\-]?\s*\d{1,3})\s*(?:°\s*[cC]|\b[cC]\b|deg|deg\s*[cC])?', caseSensitive: false).firstMatch(content);
      if (tempMatch != null) {
        String cleanTemp = tempMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
        if (!cleanTemp.startsWith('+') && !cleanTemp.startsWith('-')) {
          cleanTemp = '+$cleanTemp';
        }
        f['cartridgeTemp'] = cleanTemp;
        f['roomTemp'] = cleanTemp;
        s.add('Temperature: $cleanTemp°C');
      } else {
        final altMatch = RegExp(r'([+\-]\s*\d{1,3})\s*(?:°\s*[cC]|\b[cC]\b|deg|deg\s*[cC])').firstMatch(content);
        if (altMatch != null) {
          final cleanTemp = altMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
          f['cartridgeTemp'] = cleanTemp;
          f['roomTemp'] = cleanTemp;
          s.add('Temperature: $cleanTemp°C');
        }
      }
    }

    final t1 = find(['transducer 1', 'transducer1', 'transducer_1', 'sensor 1', 'sensor1', 'sensor_1', 'transducer', 'channel 1']);
    if (t1 != null && t1.isNotEmpty) {
      f['epvatSensor1'] = t1.trim();
      s.add('Transducer 1: ${f['epvatSensor1']}');
    } else if (content.isNotEmpty) {
      final m = RegExp(r'(?:Transducer\s*1|Sensor\s*1|Channel\s*1)\s*[:=\t\s]*\r?\n?\s*([A-Za-z0-9\-]+)', caseSensitive: false).firstMatch(content);
      if (m != null) {
        f['epvatSensor1'] = m.group(1)!.trim();
        s.add('Transducer 1: ${f['epvatSensor1']}');
      }
    }

    final t2 = find(['transducer 2', 'transducer2', 'transducer_2', 'sensor 2', 'sensor2', 'sensor_2', 'channel 2']);
    if (t2 != null && t2.isNotEmpty) {
      f['epvatSensor2'] = t2.trim();
      s.add('Transducer 2: ${f['epvatSensor2']}');
    } else if (content.isNotEmpty) {
      final m = RegExp(r'(?:Transducer\s*2|Sensor\s*2|Channel\s*2)\s*[:=\t\s]*\r?\n?\s*([A-Za-z0-9\-]+)', caseSensitive: false).firstMatch(content);
      if (m != null) {
        f['epvatSensor2'] = m.group(1)!.trim();
        s.add('Transducer 2: ${f['epvatSensor2']}');
      }
    }
  }

  static void _extractAccuracy(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s, [String content = '']) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    // 1. Direct Regex Parser for Statistic table in report text:
    // Rows: MEAN, MAX, MIN, RANGE, STDEV
    // Columns: x_1 [mm], y_1 [mm], V24.00_1 [m/s]
    if (content.isNotEmpty) {
      final statRows = ['MEAN', 'MAX', 'MIN', 'RANGE', 'STDEV', 'STD', 'SD'];
      for (final stat in statRows) {
        // Try same line with any separator (space, tab, pipe, colon, comma, semicolon)
        RegExpMatch? reg = RegExp(
          '''(?:\\b|^)$stat\\b[^0-9\\-+\\r\\n]*?([-+]?\\d*\\.?\\d+)[^0-9\\-+\\r\\n]+([-+]?\\d*\\.?\\d+)[^0-9\\-+\\r\\n]+([-+]?\\d*\\.?\\d+)''',
          caseSensitive: false,
        ).firstMatch(content);

        // Fallback: multiline where numbers might be on following lines
        reg ??= RegExp(
          '''(?:\\b|^)$stat\\b[\\s:\\t|,;]+([-+]?\\d*\\.?\\d+)[\\s:\\t|,;]+([-+]?\\d*\\.?\\d+)[\\s:\\t|,;]+([-+]?\\d*\\.?\\d+)''',
          caseSensitive: false,
        ).firstMatch(content);

        if (reg != null) {
          final x = reg.group(1)!;
          final y = reg.group(2)!;
          final v = reg.group(3)!;
          if (stat == 'MEAN') {
            f['accMeanX'] ??= x;
            f['accMeanY'] ??= y;
            f['velMean'] ??= v;
          } else if (stat == 'MAX') {
            f['accMaxX'] ??= x;
            f['accMaxY'] ??= y;
            f['velMax'] ??= v;
          } else if (stat == 'MIN') {
            f['accMinX'] ??= x;
            f['accMinY'] ??= y;
            f['velMin'] ??= v;
          } else if (stat == 'RANGE') {
            f['accRangeX'] ??= x;
            f['accRangeY'] ??= y;
            f['velRange'] ??= v;
          } else if (stat == 'STDEV' || stat == 'STD' || stat == 'SD') {
            f['accSDX'] ??= x;
            f['accSDY'] ??= y;
            f['velSD'] ??= v;
          }
        }
      }

      // Column-oriented Statistic table (e.g. PDF text streams where columns are extracted sequentially)
      if (f['accMeanX'] == null || f['velMean'] == null) {
        final xColMatch = RegExp(r'x_1\s*(?:\[mm\])?[\s\S]*?(?=y_1|V\d|\$)', caseSensitive: false).firstMatch(content);
        final yColMatch = RegExp(r'y_1\s*(?:\[mm\])?[\s\S]*?(?=V\d|x_1|\$)', caseSensitive: false).firstMatch(content);
        final vColMatch = RegExp(r'V\d+(?:\.\d+)?(?:_\d+)?\s*(?:\[m/s\])?[\s\S]*?(?=x_1|y_1|\$)', caseSensitive: false).firstMatch(content);

        if (xColMatch != null && yColMatch != null) {
          final xNums = RegExp(r'[-+]?\d*\.?\d+').allMatches(xColMatch.group(0)!).map((m) => m.group(0)!).toList();
          final yNums = RegExp(r'[-+]?\d*\.?\d+').allMatches(yColMatch.group(0)!).map((m) => m.group(0)!).toList();
          final vNums = vColMatch != null ? RegExp(r'[-+]?\d*\.?\d+').allMatches(vColMatch.group(0)!).map((m) => m.group(0)!).toList() : <String>[];

          if (xNums.length >= 5 && yNums.length >= 5) {
            f['accMeanX'] ??= xNums[0];
            f['accMaxX'] ??= xNums[1];
            f['accMinX'] ??= xNums[2];
            f['accRangeX'] ??= xNums[3];
            f['accSDX'] ??= xNums[4];

            f['accMeanY'] ??= yNums[0];
            f['accMaxY'] ??= yNums[1];
            f['accMinY'] ??= yNums[2];
            f['accRangeY'] ??= yNums[3];
            f['accSDY'] ??= yNums[4];

            if (vNums.length >= 5) {
              f['velMean'] ??= vNums[0];
              f['velMax'] ??= vNums[1];
              f['velMin'] ??= vNums[2];
              f['velRange'] ??= vNums[3];
              f['velSD'] ??= vNums[4];
            }
          }
        }
      }

      // Evaluation metrics
      final mrMatch = RegExp(r'(?:Mean\s*Radius|Radius\s*Mean|\bMR\b)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (mrMatch != null) {
        f['accMeanRadius'] ??= mrMatch.group(1)!;
      } else {
        final mrMulti = RegExp(r'(?:Mean\s*Radius|Radius\s*Mean|\bMR\b)[\s:\t|,;=]+([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
        if (mrMulti != null) f['accMeanRadius'] ??= mrMulti.group(1)!;
      }

      final ldMatch = RegExp(r'(?:Largest\s*Distance|Extreme\s*Spread|Dispersion|\bES\b)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (ldMatch != null) {
        f['accLargestDistance'] ??= ldMatch.group(1)!;
        f['accExtremeSpread'] ??= ldMatch.group(1)!;
      } else {
        final ldMulti = RegExp(r'(?:Largest\s*Distance|Extreme\s*Spread|Dispersion|\bES\b)[\s:\t|,;=]+([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
        if (ldMulti != null) {
          f['accLargestDistance'] ??= ldMulti.group(1)!;
          f['accExtremeSpread'] ??= ldMulti.group(1)!;
        }
      }

      final impXMatch = RegExp(r'(?:Impact\s*Mean\s*Point\s*X|Mean\s*Point\s*X)[^0-9\r\n\-+]*?([-+]?[0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (impXMatch != null) {
        f['accMeanX'] ??= impXMatch.group(1)!;
      }

      final impYMatch = RegExp(r'(?:Impact\s*Mean\s*Point\s*Y|Mean\s*Point\s*Y)[^0-9\r\n\-+]*?([-+]?[0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (impYMatch != null) {
        f['accMeanY'] ??= impYMatch.group(1)!;
      }

      final sumHWMatch = RegExp(r'(?:Sum\s*H\+W|H\+W)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (sumHWMatch != null) {
        f['accSumHW'] ??= sumHWMatch.group(1)!;
      }

      final distMatch = RegExp(r'V\s*(\d+(?:\.\d+)?)(?:_\d+)?(?:\s*\[m/s\]|\s*m/s|\b)', caseSensitive: false).firstMatch(content);
      if (distMatch != null && f['distance'] == null) {
        final d = double.tryParse(distMatch.group(1)!);
        f['distance'] = d != null ? d.toStringAsFixed(2) : distMatch.group(1)!;
      }
    }

    // 2. Parser for ballistic measuring reports from table rows
    for (final row in table) {
      if (row.isEmpty) continue;
      final label = row[0].toUpperCase().trim();
      final nums = row.skip(1).map((x) => parseNum(x)).where((n) => n != null).cast<double>().toList();
      if (label == 'MEAN' && nums.length >= 3) {
        f['accMeanX'] ??= nums[0].toString();
        f['accMeanY'] ??= nums[1].toString();
        f['velMean'] ??= nums[2].toString();
      } else if (label == 'MAX' && nums.length >= 3) {
        f['accMaxX'] ??= nums[0].toString();
        f['accMaxY'] ??= nums[1].toString();
        f['velMax'] ??= nums[2].toString();
      } else if (label == 'MIN' && nums.length >= 3) {
        f['accMinX'] ??= nums[0].toString();
        f['accMinY'] ??= nums[1].toString();
        f['velMin'] ??= nums[2].toString();
      } else if (label == 'RANGE' && nums.length >= 3) {
        f['accRangeX'] ??= nums[0].toString();
        f['accRangeY'] ??= nums[1].toString();
        f['velRange'] ??= nums[2].toString();
      } else if ((label == 'STDEV' || label == 'STD' || label == 'SD') && nums.length >= 3) {
        f['accSDX'] ??= nums[0].toString();
        f['accSDY'] ??= nums[1].toString();
        f['velSD'] ??= nums[2].toString();
      }
    }

    // 3. Count tested shots & parse individual shots from Round Table
    final shotList = <Map<String, double>>[];
    if (content.isNotEmpty) {
      final roundMatches = RegExp(
        r'^\s*(\d{1,3})\s+([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)\s+(\d*\.?\d+)',
        multiLine: true,
      ).allMatches(content);
      for (final rm in roundMatches) {
        final r = int.tryParse(rm.group(1)!);
        final x = double.tryParse(rm.group(2)!);
        final y = double.tryParse(rm.group(3)!);
        final v = double.tryParse(rm.group(4)!);
        if (r != null && x != null && y != null && v != null && r <= 200) {
          shotList.add({'no': r.toDouble(), 'x': x, 'y': y, 'v': v});
        }
      }
    }
    for (final row in table) {
      if (row.length >= 4) {
        final rNo = int.tryParse(row[0].trim());
        final x = parseNum(row[1]);
        final y = parseNum(row[2]);
        final v = parseNum(row[3]);
        if (rNo != null && x != null && y != null && v != null && rNo <= 200) {
          if (!shotList.any((s) => s['no'] == rNo.toDouble())) {
            shotList.add({'no': rNo.toDouble(), 'x': x, 'y': y, 'v': v});
          }
        }
      }
    }

    if (shotList.isNotEmpty) {
      shotList.sort((a, b) => a['no']!.compareTo(b['no']!));
      final count = shotList.length;
      f['produced'] ??= '$count';
      s.add('Tested Rounds: $count');

      // Calculate ballistic statistics from round coordinates and velocities if not present
      final xVals = shotList.map((s) => s['x']!).toList();
      final yVals = shotList.map((s) => s['y']!).toList();
      final vVals = shotList.map((s) => s['v']!).toList();

      final meanX = xVals.reduce((a, b) => a + b) / count;
      final meanY = yVals.reduce((a, b) => a + b) / count;
      final meanV = vVals.reduce((a, b) => a + b) / count;

      final minX = xVals.reduce((a, b) => a < b ? a : b);
      final maxX = xVals.reduce((a, b) => a > b ? a : b);
      final rangeX = maxX - minX;

      final minY = yVals.reduce((a, b) => a < b ? a : b);
      final maxY = yVals.reduce((a, b) => a > b ? a : b);
      final rangeY = maxY - minY;

      final minV = vVals.reduce((a, b) => a < b ? a : b);
      final maxV = vVals.reduce((a, b) => a > b ? a : b);
      final rangeV = maxV - minV;

      final sdX = count > 1 ? math.sqrt(xVals.map((x) => math.pow(x - meanX, 2)).reduce((a, b) => a + b) / (count - 1)) : 0.0;
      final sdY = count > 1 ? math.sqrt(yVals.map((y) => math.pow(y - meanY, 2)).reduce((a, b) => a + b) / (count - 1)) : 0.0;
      final sdV = count > 1 ? math.sqrt(vVals.map((v) => math.pow(v - meanV, 2)).reduce((a, b) => a + b) / (count - 1)) : 0.0;

      // Mean Radius
      final radii = shotList.map((s) => math.sqrt(math.pow(s['x']! - meanX, 2) + math.pow(s['y']! - meanY, 2))).toList();
      final meanRadius = radii.reduce((a, b) => a + b) / count;

      // Largest Distance (Dispersion / Extreme Spread)
      double largestDist = 0.0;
      for (int i = 0; i < count; i++) {
        for (int j = i + 1; j < count; j++) {
          final d = math.sqrt(math.pow(shotList[i]['x']! - shotList[j]['x']!, 2) + math.pow(shotList[i]['y']! - shotList[j]['y']!, 2));
          if (d > largestDist) largestDist = d;
        }
      }

      f['accMeanX'] ??= meanX.toStringAsFixed(1);
      f['accMaxX'] ??= maxX.toStringAsFixed(1);
      f['accMinX'] ??= minX.toStringAsFixed(1);
      f['accRangeX'] ??= rangeX.toStringAsFixed(1);
      f['accSDX'] ??= sdX.toStringAsFixed(1);

      f['accMeanY'] ??= meanY.toStringAsFixed(1);
      f['accMaxY'] ??= maxY.toStringAsFixed(1);
      f['accMinY'] ??= minY.toStringAsFixed(1);
      f['accRangeY'] ??= rangeY.toStringAsFixed(1);
      f['accSDY'] ??= sdY.toStringAsFixed(1);

      f['velMean'] ??= meanV.toStringAsFixed(2);
      f['velMax'] ??= maxV.toStringAsFixed(2);
      f['velMin'] ??= minV.toStringAsFixed(2);
      f['velRange'] ??= rangeV.toStringAsFixed(2);
      f['velSD'] ??= sdV.toStringAsFixed(2);

      f['accMeanRadius'] ??= meanRadius.toStringAsFixed(1);
      f['accLargestDistance'] ??= largestDist.toStringAsFixed(1);
      f['accExtremeSpread'] ??= largestDist.toStringAsFixed(1);
      f['accSumHW'] ??= (rangeX + rangeY).toStringAsFixed(1);
    }

    // 4. Try finding explicit statistics from kvMap
    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('mean vel') || k.contains('velocity mean') || k.contains('avg vel') || k == 'v_mean' || k == 'vel mean') {
        final num = parseNum(v);
        if (num != null && f['velMean'] == null) f['velMean'] = num.toStringAsFixed(2);
      } else if (k.contains('min vel') || k == 'v_min' || k == 'vel min') {
        final num = parseNum(v);
        if (num != null && f['velMin'] == null) f['velMin'] = num.toStringAsFixed(2);
      } else if (k.contains('max vel') || k == 'v_max' || k == 'vel max') {
        final num = parseNum(v);
        if (num != null && f['velMax'] == null) f['velMax'] = num.toStringAsFixed(2);
      } else if (k.contains('sd vel') || k.contains('sd of vel') || k == 'v_sd' || k == 'vel sd') {
        final num = parseNum(v);
        if (num != null && f['velSD'] == null) f['velSD'] = num.toStringAsFixed(2);
      } else if (k.contains('range vel') || k == 'v_range') {
        final num = parseNum(v);
        if (num != null && f['velRange'] == null) f['velRange'] = num.toStringAsFixed(2);
      } else if (k.contains('mean radius') || k.contains('mean_radius') || k == 'mr') {
        final num = parseNum(v);
        if (num != null && f['accMeanRadius'] == null) f['accMeanRadius'] = num.toStringAsFixed(1);
      } else if (k.contains('largest distance') || k.contains('largest_distance') || k.contains('extreme spread') || k.contains('extreme_spread') || k == 'es') {
        final num = parseNum(v);
        if (num != null && f['accLargestDistance'] == null) {
          f['accLargestDistance'] = num.toStringAsFixed(1);
          f['accExtremeSpread'] = num.toStringAsFixed(1);
        }
      } else if (k.contains('figure of merit') || k == 'fom') {
        final num = parseNum(v);
        if (num != null) f['accFigureOfMerit'] = num.toStringAsFixed(2);
      } else if (k.contains('mean x') || k == 'x_mean') {
        final num = parseNum(v);
        if (num != null && f['accMeanX'] == null) f['accMeanX'] = num.toStringAsFixed(1);
      } else if (k.contains('sd x') || k.contains('sdx') || k == 'x_sd') {
        final num = parseNum(v);
        if (num != null && f['accSDX'] == null) f['accSDX'] = num.toStringAsFixed(1);
      } else if (k.contains('min x') || k == 'x_min') {
        final num = parseNum(v);
        if (num != null && f['accMinX'] == null) f['accMinX'] = num.toStringAsFixed(1);
      } else if (k.contains('max x') || k == 'x_max') {
        final num = parseNum(v);
        if (num != null && f['accMaxX'] == null) f['accMaxX'] = num.toStringAsFixed(1);
      } else if (k.contains('mean y') || k == 'y_mean') {
        final num = parseNum(v);
        if (num != null && f['accMeanY'] == null) f['accMeanY'] = num.toStringAsFixed(1);
      } else if (k.contains('sd y') || k.contains('sdy') || k == 'y_sd') {
        final num = parseNum(v);
        if (num != null && f['accSDY'] == null) f['accSDY'] = num.toStringAsFixed(1);
      } else if (k.contains('min y') || k == 'y_min') {
        final num = parseNum(v);
        if (num != null && f['accMinY'] == null) f['accMinY'] = num.toStringAsFixed(1);
      } else if (k.contains('max y') || k == 'y_max') {
        final num = parseNum(v);
        if (num != null && f['accMaxY'] == null) f['accMaxY'] = num.toStringAsFixed(1);
      } else if (k == 'distance' || k == 'dist' || k.contains('test distance')) {
        final num = parseNum(v);
        if (num != null && f['distance'] == null) f['distance'] = num.toStringAsFixed(2);
      }
    }

    if (f['velMean'] != null) s.add('Mean Velocity: ${f['velMean']} m/s');
    if (f['accSDX'] != null && f['accSDY'] != null) s.add('Group SD: X=${f['accSDX']} mm, Y=${f['accSDY']} mm');
    if (f['accMeanRadius'] != null) s.add('Mean Radius: ${f['accMeanRadius']} mm');
    if (f['accLargestDistance'] != null) s.add('Largest Distance: ${f['accLargestDistance']} mm');
    if (f['accSumHW'] != null) s.add('Sum H+W: ${f['accSumHW']} mm');
  }

  static void _extractEpvat(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s, [String content = '']) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    // 1. Detect Pressure Unit & Velocity Distance from content
    if (content.isNotEmpty) {
      final unitMatch = RegExp(r'(?:\[|\b)(kg/cm2|kg/cm²|bar|MPa|PSI)(?:\]|\b)', caseSensitive: false).firstMatch(content);
      if (unitMatch != null) {
        final u = unitMatch.group(1)!.toLowerCase();
        if (u.contains('kg/cm')) {
          f['epvatPressureUnit'] ??= 'kg/cm²';
        } else if (u == 'bar') {
          f['epvatPressureUnit'] ??= 'bar';
        } else if (u == 'mpa') {
          f['epvatPressureUnit'] ??= 'MPa';
        } else if (u == 'psi') {
          f['epvatPressureUnit'] ??= 'PSI';
        }
      }

      // Distance from Velocity column (e.g., V24.00_2 [m/s] or V25.00)
      final distMatch = RegExp(r'V(\d+(?:\.\d+)?)(?:_\d+)?\s*(?:\[m/s\]|\b)', caseSensitive: false).firstMatch(content);
      if (distMatch != null) {
        f['distance'] ??= distMatch.group(1);
      }
    }

    // 2. Extract Individual Rounds from "Round Table:"
    // Columns: No., P max_1, P max_2, t4, ta, V...
    final p1Shots = <int, double>{};
    final p2Shots = <int, double>{};
    final t4Shots = <int, double>{};
    final taShots = <int, double>{};
    final velShots = <int, double>{};

    if (content.isNotEmpty) {
      final lines = content.split(RegExp(r'\r?\n'));
      bool inRoundTable = false;
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final lower = line.toLowerCase();
        if (lower.contains('round table')) {
          inRoundTable = true;
          continue;
        }
        if (inRoundTable && (lower.contains('statistic only') || lower.contains('statistic') || lower.contains('mean') || lower.contains('comment'))) {
          inRoundTable = false;
        }

        // Parse line tokens
        final tokens = line.split(RegExp(r'[\s,\t|;]+')).where((t) => t.isNotEmpty).toList();
        if (tokens.isNotEmpty) {
          final shotNo = int.tryParse(tokens[0]);
          if (shotNo != null && shotNo >= 1 && shotNo <= 200) {
            final nums = tokens.sublist(1).map(parseNum).whereType<double>().toList();
            if (nums.length >= 5) {
              // 5 cols: P1, P2, t4, ta, Vel
              p1Shots[shotNo] = nums[0];
              p2Shots[shotNo] = nums[1];
              t4Shots[shotNo] = nums[2];
              taShots[shotNo] = nums[3];
              velShots[shotNo] = nums[4];
            } else if (nums.length == 4) {
              // 4 cols: P1, P2, ta, Vel OR P1, t4, ta, Vel
              if (nums[3] > 100) {
                // Last is vel
                p1Shots[shotNo] = nums[0];
                p2Shots[shotNo] = nums[1];
                taShots[shotNo] = nums[2];
                velShots[shotNo] = nums[3];
              }
            } else if (nums.length == 3) {
              // 3 cols: P1, ta, Vel
              p1Shots[shotNo] = nums[0];
              taShots[shotNo] = nums[1];
              velShots[shotNo] = nums[2];
            }
          }
        }
      }

      // Regex fallback if lines didn't match (e.g. dense PDF stream)
      if (p1Shots.isEmpty) {
        final roundPattern = RegExp(
          r'(?:^|\r|\n)\s*(\d{1,3})\s+([0-9]+\.[0-9]+)\s+([0-9]+\.[0-9]+)\s+([0-9]+\.[0-9]+)\s+([0-9]+\.[0-9]+)\s+([0-9]+\.[0-9]+)',
        );
        for (final m in roundPattern.allMatches(content)) {
          final no = int.tryParse(m.group(1)!);
          if (no != null && no >= 1 && no <= 200) {
            p1Shots[no] = double.parse(m.group(2)!);
            p2Shots[no] = double.parse(m.group(3)!);
            t4Shots[no] = double.parse(m.group(4)!);
            taShots[no] = double.parse(m.group(5)!);
            velShots[no] = double.parse(m.group(6)!);
          }
        }
      }
    }

    if (p1Shots.isNotEmpty) {
      final sortedKeys = p1Shots.keys.toList()..sort();
      final p1List = sortedKeys.map((k) => p1Shots[k]!.toStringAsFixed(1)).toList();
      final p2List = sortedKeys.where((k) => p2Shots.containsKey(k)).map((k) => p2Shots[k]!.toStringAsFixed(1)).toList();
      final t4List = sortedKeys.where((k) => t4Shots.containsKey(k)).map((k) => t4Shots[k]!.toStringAsFixed(3)).toList();
      final taList = sortedKeys.where((k) => taShots.containsKey(k)).map((k) => taShots[k]!.toStringAsFixed(3)).toList();
      final velList = sortedKeys.where((k) => velShots.containsKey(k)).map((k) => velShots[k]!.toStringAsFixed(2)).toList();

      f['epvatPressureRounds'] = p1List.join(', ');
      if (p2List.isNotEmpty) f['epvatP2PressureRounds'] = p2List.join(', ');
      if (t4List.isNotEmpty) f['t4Rounds'] = t4List.join(', ');
      if (taList.isNotEmpty) f['actionTimeRounds'] = taList.join(', ');
      if (velList.isNotEmpty) f['epvatVelRounds'] = velList.join(', ');
      f['produced'] ??= sortedKeys.length.toString();
    }

    // 3. Extract Statistics Table ("Statistic only:")
    // Rows: MEAN, MAX, MIN, RANGE, STDEV
    // Columns: P1, P2, t4, ta, Vel
    void assignStats(String stat, List<double> nums) {
      final sUpper = stat.toUpperCase();
      if (nums.length >= 5) {
        final p1 = nums[0];
        final p2 = nums[1];
        final t4 = nums[2];
        final ta = nums[3];
        final vel = nums[4];
        if (sUpper == 'MEAN') {
          f['epvatMeanPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2MeanPressure'] ??= p2.toStringAsFixed(1);
          f['t4Mean'] ??= t4.toStringAsFixed(3);
          f['actionTimeMean'] ??= ta.toStringAsFixed(3);
          f['velMean'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'MAX') {
          f['epvatMaxPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2MaxPressure'] ??= p2.toStringAsFixed(1);
          f['t4Max'] ??= t4.toStringAsFixed(3);
          f['actionTimeMax'] ??= ta.toStringAsFixed(3);
          f['velMax'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'MIN') {
          f['epvatMinPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2MinPressure'] ??= p2.toStringAsFixed(1);
          f['t4Min'] ??= t4.toStringAsFixed(3);
          f['actionTimeMin'] ??= ta.toStringAsFixed(3);
          f['velMin'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'RANGE') {
          f['epvatRangePressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2RangePressure'] ??= p2.toStringAsFixed(1);
          f['t4Range'] ??= t4.toStringAsFixed(3);
          f['actionTimeRange'] ??= ta.toStringAsFixed(3);
          f['velRange'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'STDEV' || sUpper == 'STD' || sUpper == 'SD') {
          f['epvatSDPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2SDPressure'] ??= p2.toStringAsFixed(1);
          f['t4SD'] ??= t4.toStringAsFixed(3);
          f['actionTimeSD'] ??= ta.toStringAsFixed(3);
          f['velSD'] ??= vel.toStringAsFixed(2);
        }
      } else if (nums.length == 4) {
        final p1 = nums[0];
        final p2 = nums[1];
        final ta = nums[2];
        final vel = nums[3];
        if (sUpper == 'MEAN') {
          f['epvatMeanPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2MeanPressure'] ??= p2.toStringAsFixed(1);
          f['actionTimeMean'] ??= ta.toStringAsFixed(3);
          f['velMean'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'MAX') {
          f['epvatMaxPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2MaxPressure'] ??= p2.toStringAsFixed(1);
          f['actionTimeMax'] ??= ta.toStringAsFixed(3);
          f['velMax'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'MIN') {
          f['epvatMinPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2MinPressure'] ??= p2.toStringAsFixed(1);
          f['actionTimeMin'] ??= ta.toStringAsFixed(3);
          f['velMin'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'RANGE') {
          f['epvatRangePressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2RangePressure'] ??= p2.toStringAsFixed(1);
          f['actionTimeRange'] ??= ta.toStringAsFixed(3);
          f['velRange'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'STDEV' || sUpper == 'STD' || sUpper == 'SD') {
          f['epvatSDPressure'] ??= p1.toStringAsFixed(1);
          f['epvatP2SDPressure'] ??= p2.toStringAsFixed(1);
          f['actionTimeSD'] ??= ta.toStringAsFixed(3);
          f['velSD'] ??= vel.toStringAsFixed(2);
        }
      } else if (nums.length == 3) {
        final p1 = nums[0];
        final ta = nums[1];
        final vel = nums[2];
        if (sUpper == 'MEAN') {
          f['epvatMeanPressure'] ??= p1.toStringAsFixed(1);
          f['actionTimeMean'] ??= ta.toStringAsFixed(3);
          f['velMean'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'MAX') {
          f['epvatMaxPressure'] ??= p1.toStringAsFixed(1);
          f['actionTimeMax'] ??= ta.toStringAsFixed(3);
          f['velMax'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'MIN') {
          f['epvatMinPressure'] ??= p1.toStringAsFixed(1);
          f['actionTimeMin'] ??= ta.toStringAsFixed(3);
          f['velMin'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'RANGE') {
          f['epvatRangePressure'] ??= p1.toStringAsFixed(1);
          f['actionTimeRange'] ??= ta.toStringAsFixed(3);
          f['velRange'] ??= vel.toStringAsFixed(2);
        } else if (sUpper == 'STDEV' || sUpper == 'STD' || sUpper == 'SD') {
          f['epvatSDPressure'] ??= p1.toStringAsFixed(1);
          f['actionTimeSD'] ??= ta.toStringAsFixed(3);
          f['velSD'] ??= vel.toStringAsFixed(2);
        }
      }
    }

    if (content.isNotEmpty) {
      final statWords = ['MEAN', 'MAX', 'MIN', 'RANGE', 'STDEV', 'STD', 'SD'];
      for (final sw in statWords) {
        final match = RegExp('(?:^|\\r|\\n)\\s*$sw\\b([^\r\n]*)', caseSensitive: false).firstMatch(content);
        if (match != null) {
          final rest = match.group(1)!;
          final nums = RegExp(r'[-+]?\d*\.?\d+').allMatches(rest).map((m) => double.tryParse(m.group(0)!)).whereType<double>().toList();
          if (nums.isNotEmpty) {
            assignStats(sw, nums);
          }
        }
      }
    }

    // Also check tableData if passed
    for (final row in table) {
      if (row.isNotEmpty) {
        final first = row[0].toUpperCase();
        if (['MEAN', 'MAX', 'MIN', 'RANGE', 'STDEV', 'STD', 'SD'].contains(first)) {
          final nums = row.sublist(1).map(parseNum).whereType<double>().toList();
          if (nums.isNotEmpty) {
            assignStats(first, nums);
          }
        }
      }
    }

    // 4. Mathematical fallback calculation from shots if statistics table missing
    if (p1Shots.isNotEmpty) {
      final p1Vals = p1Shots.values.toList();
      final n = p1Vals.length;
      if (f['epvatMeanPressure'] == null && n > 0) {
        final mean = p1Vals.reduce((a, b) => a + b) / n;
        f['epvatMeanPressure'] = mean.toStringAsFixed(1);
      }
      if (f['epvatMaxPressure'] == null && n > 0) {
        final max = p1Vals.reduce((a, b) => a > b ? a : b);
        f['epvatMaxPressure'] = max.toStringAsFixed(1);
      }
      if (f['epvatMinPressure'] == null && n > 0) {
        final min = p1Vals.reduce((a, b) => a < b ? a : b);
        f['epvatMinPressure'] = min.toStringAsFixed(1);
      }
      if (f['epvatRangePressure'] == null && f['epvatMaxPressure'] != null && f['epvatMinPressure'] != null) {
        final max = double.tryParse(f['epvatMaxPressure']!) ?? 0;
        final min = double.tryParse(f['epvatMinPressure']!) ?? 0;
        f['epvatRangePressure'] = (max - min).toStringAsFixed(1);
      }
      if (f['epvatSDPressure'] == null && n > 1) {
        final mean = double.tryParse(f['epvatMeanPressure']!) ?? (p1Vals.reduce((a, b) => a + b) / n);
        final sumSq = p1Vals.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b);
        f['epvatSDPressure'] = math.sqrt(sumSq / (n - 1)).toStringAsFixed(1);
      }
    }

    if (p2Shots.isNotEmpty) {
      final p2Vals = p2Shots.values.toList();
      final n = p2Vals.length;
      if (f['epvatP2MeanPressure'] == null && n > 0) {
        final mean = p2Vals.reduce((a, b) => a + b) / n;
        f['epvatP2MeanPressure'] = mean.toStringAsFixed(1);
      }
      if (f['epvatP2MaxPressure'] == null && n > 0) {
        final max = p2Vals.reduce((a, b) => a > b ? a : b);
        f['epvatP2MaxPressure'] = max.toStringAsFixed(1);
      }
      if (f['epvatP2MinPressure'] == null && n > 0) {
        final min = p2Vals.reduce((a, b) => a < b ? a : b);
        f['epvatP2MinPressure'] = min.toStringAsFixed(1);
      }
      if (f['epvatP2RangePressure'] == null && f['epvatP2MaxPressure'] != null && f['epvatP2MinPressure'] != null) {
        final max = double.tryParse(f['epvatP2MaxPressure']!) ?? 0;
        final min = double.tryParse(f['epvatP2MinPressure']!) ?? 0;
        f['epvatP2RangePressure'] = (max - min).toStringAsFixed(1);
      }
      if (f['epvatP2SDPressure'] == null && n > 1) {
        final mean = double.tryParse(f['epvatP2MeanPressure']!) ?? (p2Vals.reduce((a, b) => a + b) / n);
        final sumSq = p2Vals.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b);
        f['epvatP2SDPressure'] = math.sqrt(sumSq / (n - 1)).toStringAsFixed(1);
      }
    }

    if (taShots.isNotEmpty) {
      final taVals = taShots.values.toList();
      final n = taVals.length;
      if (f['actionTimeMean'] == null && n > 0) {
        final mean = taVals.reduce((a, b) => a + b) / n;
        f['actionTimeMean'] = mean.toStringAsFixed(3);
      }
      if (f['actionTimeMax'] == null && n > 0) {
        final max = taVals.reduce((a, b) => a > b ? a : b);
        f['actionTimeMax'] = max.toStringAsFixed(3);
      }
      if (f['actionTimeMin'] == null && n > 0) {
        final min = taVals.reduce((a, b) => a < b ? a : b);
        f['actionTimeMin'] = min.toStringAsFixed(3);
      }
      if (f['actionTimeRange'] == null && f['actionTimeMax'] != null && f['actionTimeMin'] != null) {
        final max = double.tryParse(f['actionTimeMax']!) ?? 0;
        final min = double.tryParse(f['actionTimeMin']!) ?? 0;
        f['actionTimeRange'] = (max - min).toStringAsFixed(3);
      }
      if (f['actionTimeSD'] == null && n > 1) {
        final mean = double.tryParse(f['actionTimeMean']!) ?? (taVals.reduce((a, b) => a + b) / n);
        final sumSq = taVals.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b);
        f['actionTimeSD'] = math.sqrt(sumSq / (n - 1)).toStringAsFixed(3);
      }
    }

    if (velShots.isNotEmpty) {
      final vVals = velShots.values.toList();
      final n = vVals.length;
      if (f['velMean'] == null && n > 0) {
        final mean = vVals.reduce((a, b) => a + b) / n;
        f['velMean'] = mean.toStringAsFixed(2);
      }
      if (f['velMax'] == null && n > 0) {
        final max = vVals.reduce((a, b) => a > b ? a : b);
        f['velMax'] = max.toStringAsFixed(2);
      }
      if (f['velMin'] == null && n > 0) {
        final min = vVals.reduce((a, b) => a < b ? a : b);
        f['velMin'] = min.toStringAsFixed(2);
      }
      if (f['velRange'] == null && f['velMax'] != null && f['velMin'] != null) {
        final max = double.tryParse(f['velMax']!) ?? 0;
        final min = double.tryParse(f['velMin']!) ?? 0;
        f['velRange'] = (max - min).toStringAsFixed(2);
      }
      if (f['velSD'] == null && n > 1) {
        final mean = double.tryParse(f['velMean']!) ?? (vVals.reduce((a, b) => a + b) / n);
        final sumSq = vVals.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b);
        f['velSD'] = math.sqrt(sumSq / (n - 1)).toStringAsFixed(2);
      }
    }

    // 5. Explicit kvMap search
    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;

      if (k.contains('p1 mean') || k.contains('p1_mean') || k.contains('chamber mean') || k == 'mean p1') {
        final num = parseNum(v);
        if (num != null && f['epvatMeanPressure'] == null) f['epvatMeanPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p1 max') || k.contains('p1_max') || k.contains('chamber max')) {
        final num = parseNum(v);
        if (num != null && f['epvatMaxPressure'] == null) f['epvatMaxPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p1 min') || k.contains('p1_min') || k.contains('chamber min')) {
        final num = parseNum(v);
        if (num != null && f['epvatMinPressure'] == null) f['epvatMinPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p1 sd') || k.contains('p1_sd') || k.contains('chamber sd')) {
        final num = parseNum(v);
        if (num != null && f['epvatSDPressure'] == null) f['epvatSDPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p1 range') || k.contains('p1_range') || k.contains('chamber range')) {
        final num = parseNum(v);
        if (num != null && f['epvatRangePressure'] == null) f['epvatRangePressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 mean') || k.contains('p2_mean') || k.contains('port mean') || k == 'mean p2') {
        final num = parseNum(v);
        if (num != null && f['epvatP2MeanPressure'] == null) f['epvatP2MeanPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 max') || k.contains('p2_max') || k.contains('port max')) {
        final num = parseNum(v);
        if (num != null && f['epvatP2MaxPressure'] == null) f['epvatP2MaxPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 min') || k.contains('p2_min') || k.contains('port min')) {
        final num = parseNum(v);
        if (num != null && f['epvatP2MinPressure'] == null) f['epvatP2MinPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 sd') || k.contains('p2_sd') || k.contains('port sd')) {
        final num = parseNum(v);
        if (num != null && f['epvatP2SDPressure'] == null) f['epvatP2SDPressure'] = num.toStringAsFixed(1);
      } else if (k.contains('p2 range') || k.contains('p2_range') || k.contains('port range')) {
        final num = parseNum(v);
        if (num != null && f['epvatP2RangePressure'] == null) f['epvatP2RangePressure'] = num.toStringAsFixed(1);
      } else if (k.contains('mean vel') || k.contains('vel mean') || k.contains('avg vel') || k == 'v_mean') {
        final num = parseNum(v);
        if (num != null && f['velMean'] == null) f['velMean'] = num.toStringAsFixed(2);
      } else if (k.contains('max vel') || k == 'v_max') {
        final num = parseNum(v);
        if (num != null && f['velMax'] == null) f['velMax'] = num.toStringAsFixed(2);
      } else if (k.contains('min vel') || k == 'v_min') {
        final num = parseNum(v);
        if (num != null && f['velMin'] == null) f['velMin'] = num.toStringAsFixed(2);
      } else if (k.contains('sd vel') || k == 'v_sd') {
        final num = parseNum(v);
        if (num != null && f['velSD'] == null) f['velSD'] = num.toStringAsFixed(2);
      } else if (k.contains('range vel') || k == 'v_range') {
        final num = parseNum(v);
        if (num != null && f['velRange'] == null) f['velRange'] = num.toStringAsFixed(2);
      } else if (k.contains('action time mean') || k.contains('at mean') || k == 'at_mean') {
        final num = parseNum(v);
        if (num != null && f['actionTimeMean'] == null) f['actionTimeMean'] = num.toStringAsFixed(3);
      } else if (k.contains('action time max') || k == 'at_max') {
        final num = parseNum(v);
        if (num != null && f['actionTimeMax'] == null) f['actionTimeMax'] = num.toStringAsFixed(3);
      } else if (k.contains('action time min') || k == 'at_min') {
        final num = parseNum(v);
        if (num != null && f['actionTimeMin'] == null) f['actionTimeMin'] = num.toStringAsFixed(3);
      } else if (k.contains('action time sd') || k == 'at_sd') {
        final num = parseNum(v);
        if (num != null && f['actionTimeSD'] == null) f['actionTimeSD'] = num.toStringAsFixed(3);
      } else if (k.contains('action time range') || k == 'at_range') {
        final num = parseNum(v);
        if (num != null && f['actionTimeRange'] == null) f['actionTimeRange'] = num.toStringAsFixed(3);
      } else if (k.contains('distance') || k == 'dist') {
        final num = parseNum(v);
        if (num != null && f['distance'] == null) f['distance'] = num.toStringAsFixed(2);
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

    // Auto calculate Range if max & min exist
    if (f['epvatRangePressure'] == null && f['epvatMaxPressure'] != null && f['epvatMinPressure'] != null) {
      final max = double.tryParse(f['epvatMaxPressure']!);
      final min = double.tryParse(f['epvatMinPressure']!);
      if (max != null && min != null) f['epvatRangePressure'] = (max - min).toStringAsFixed(1);
    }
    if (f['epvatP2RangePressure'] == null && f['epvatP2MaxPressure'] != null && f['epvatP2MinPressure'] != null) {
      final max = double.tryParse(f['epvatP2MaxPressure']!);
      final min = double.tryParse(f['epvatP2MinPressure']!);
      if (max != null && min != null) f['epvatP2RangePressure'] = (max - min).toStringAsFixed(1);
    }
    if (f['actionTimeRange'] == null && f['actionTimeMax'] != null && f['actionTimeMin'] != null) {
      final max = double.tryParse(f['actionTimeMax']!);
      final min = double.tryParse(f['actionTimeMin']!);
      if (max != null && min != null) f['actionTimeRange'] = (max - min).toStringAsFixed(3);
    }
    if (f['velRange'] == null && f['velMax'] != null && f['velMin'] != null) {
      final max = double.tryParse(f['velMax']!);
      final min = double.tryParse(f['velMin']!);
      if (max != null && min != null) f['velRange'] = (max - min).toStringAsFixed(2);
    }

    final pUnit = f['epvatPressureUnit'] ?? 'bar';
    if (p1Shots.isNotEmpty) s.add('Extracted ${p1Shots.length} Individual EPVAT Rounds');
    if (f['epvatMeanPressure'] != null) s.add('P1 Chamber Mean: ${f['epvatMeanPressure']} $pUnit');
    if (f['epvatP2MeanPressure'] != null) s.add('P2 Port Mean: ${f['epvatP2MeanPressure']} $pUnit');
    if (f['velMean'] != null) s.add('Mean Velocity: ${f['velMean']} m/s');
    if (f['actionTimeMean'] != null) s.add('Action Time Mean: ${f['actionTimeMean']} ms');
    if (f['distance'] != null) s.add('Test Distance: ${f['distance']} m');
  }

  static void _extractExtraction(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s, [String content = '']) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    final sampleMap = <int, double>{};

    // 1. Extract BatchID and Notes directly from content if present
    if (content.isNotEmpty) {
      final batchMatch = RegExp(r'(?:BatchID|Batch\s*ID)\s*[:=\t\s]*\r?\n?\s*([^\r\n,;]+)', caseSensitive: false).firstMatch(content);
      if (batchMatch != null && (f['lotNo'] == null || f['lotNo'].toString().isEmpty)) {
        final bVal = batchMatch.group(1)!.trim();
        if (bVal.isNotEmpty) {
          f['lotNo'] = bVal;
          s.add('BatchID: $bVal');
        }
      }
      final notesMatch = RegExp(r'(?:Notes|Comments|Remarks)\s*[:=\t\s]*\r?\n?\s*([^\r\n]+(?:\r?\n[^\r\n]+)*?)(?=\b(?:Calculation|Units|Sample|Overall\s*result|Minimum|Maximum|\Z))', caseSensitive: false).firstMatch(content);
      if (notesMatch != null && (f['notes'] == null || f['notes'].toString().isEmpty)) {
        final nVal = notesMatch.group(1)!.trim();
        if (nVal.isNotEmpty) {
          f['notes'] = nVal;
          s.add('Notes: $nVal');
        }
      }
    }

    // 2. Extract Sample / Round forces directly from content
    if (content.isNotEmpty) {
      final sampleMatches = RegExp(
        r'(?:Sample|Round|No\.?)\s*(\d+)[\s:\t,;]+([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ).allMatches(content);

      for (final m in sampleMatches) {
        final idx = int.tryParse(m.group(1)!);
        final val = double.tryParse(m.group(2)!);
        if (idx != null && val != null) {
          sampleMap[idx] = val;
        }
      }
    }

    // 2. Extract from tableData
    // 2. Extract summary stats directly from content regex (exact report representation)
    if (content.isNotEmpty) {
      final minMatch = RegExp(
        r'(?:Minimum|Min(?:\s*Force)?|Lowest)\s*[:=\t\s]+([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(content);
      if (minMatch != null) {
        f['accMinX'] = minMatch.group(1)!;
      }
      final maxMatch = RegExp(
        r'(?:Maximum|Max(?:\s*Force)?|Peak|Highest)\s*[:=\t\s]+([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(content);
      if (maxMatch != null) {
        f['accMaxX'] = maxMatch.group(1)!;
      }
      final meanMatch = RegExp(
        r'(?:Mean(?:\s*Force)?|Average|Avg)\s*[:=\t\s]+([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(content);
      if (meanMatch != null) {
        f['accMeanX'] = meanMatch.group(1)!;
      }
      final sdMatch = RegExp(
        r'(?:Standard\s*Deviation|STDEV|Std\s*Dev|\bSD\b)\s*[:=\t\s]+([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(content);
      if (sdMatch != null) {
        f['accSDX'] = sdMatch.group(1)!;
      }
      final rangeMatch = RegExp(
        r'(?:Range(?:\s*Force)?)\s*[:=\t\s]+([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(content);
      if (rangeMatch != null) {
        f['accRangeX'] = rangeMatch.group(1)!;
      }
    }

    // 3. Extract from tableData
    for (final row in table) {
      if (row.length >= 2) {
        final first = row[0].trim();
        final match = RegExp(r'^(?:Sample|Round|No\.?)?\s*(\d+)$', caseSensitive: false).firstMatch(first);
        if (match != null) {
          final idx = int.tryParse(match.group(1)!);
          final val = parseNum(row[1]);
          if (idx != null && val != null && !sampleMap.containsKey(idx)) {
            sampleMap[idx] = val;
          }
        }
      }
    }

    // 4. Extract from kvMap
    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if ((k.contains('min force') || k.contains('lowest force') || k == 'minimum' || k == 'min') && f['accMinX'] == null) {
        final num = parseNum(v);
        if (num != null) f['accMinX'] = v.trim();
      } else if ((k.contains('mean force') || k.contains('avg force') || k == 'mean' || k == 'average') && f['accMeanX'] == null) {
        final num = parseNum(v);
        if (num != null) f['accMeanX'] = v.trim();
      } else if ((k.contains('max force') || k.contains('peak force') || k == 'maximum' || k == 'max') && f['accMaxX'] == null) {
        final num = parseNum(v);
        if (num != null) f['accMaxX'] = v.trim();
      } else if ((k.contains('force sd') || k.contains('sd force') || k == 'sd' || k == 'stdev') && f['accSDX'] == null) {
        final num = parseNum(v);
        if (num != null) f['accSDX'] = v.trim();
      } else if ((k.contains('range force') || k.contains('force range') || k == 'range') && f['accRangeX'] == null) {
        final num = parseNum(v);
        if (num != null) f['accRangeX'] = v.trim();
      }

      final rMatch = RegExp(r'(?:round|sample)\s*(\d+)', caseSensitive: false).firstMatch(k);
      if (rMatch != null) {
        final idx = int.tryParse(rMatch.group(1)!);
        final num = parseNum(v);
        if (idx != null && num != null && !sampleMap.containsKey(idx)) {
          sampleMap[idx] = num;
        }
      }
    }

    // Convert sampleMap to ordered list
    final forces = <double>[];
    if (sampleMap.isNotEmpty) {
      final sortedKeys = sampleMap.keys.toList()..sort();
      for (final k in sortedKeys) {
        forces.add(sampleMap[k]!);
      }
    }

    if (forces.isNotEmpty) {
      f['produced'] = '${forces.length}';
      f['roundForces'] = forces.map((e) => e.toStringAsFixed(1)).join(',');
      f['extractionForceRounds'] = f['roundForces'];
      f['extractionForceType'] = 'Individual';

      if (f['accMinX'] == null) {
        final min = forces.reduce((a, b) => a < b ? a : b);
        f['accMinX'] = min.toStringAsFixed(1);
      }
      if (f['accMaxX'] == null) {
        final max = forces.reduce((a, b) => a > b ? a : b);
        f['accMaxX'] = max.toStringAsFixed(1);
      }
      if (f['accMeanX'] == null) {
        final mean = forces.reduce((a, b) => a + b) / forces.length;
        f['accMeanX'] = mean.toStringAsFixed(1);
      }
      if (f['accSDX'] == null && forces.length > 1) {
        final mean = forces.reduce((a, b) => a + b) / forces.length;
        final variance = forces.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / (forces.length - 1);
        f['accSDX'] = math.sqrt(variance).toStringAsFixed(1);
      }
    }

    // Auto calculate Range = Max - Min if not explicit
    if (f['accRangeX'] == null && f['accMinX'] != null && f['accMaxX'] != null) {
      final minVal = double.tryParse(f['accMinX']!);
      final maxVal = double.tryParse(f['accMaxX']!);
      if (minVal != null && maxVal != null) {
        f['accRangeX'] = (maxVal - minVal).toStringAsFixed(1);
      }
    }

    if (f['roundForces'] != null) s.add('Extracted ${forces.length} Individual Rounds');
    if (f['accMinX'] != null) s.add('Min Force: ${f['accMinX']} N');
    if (f['accMaxX'] != null) s.add('Max Force: ${f['accMaxX']} N');
    if (f['accMeanX'] != null) s.add('Mean Force: ${f['accMeanX']} N');
    if (f['accSDX'] != null) s.add('Force SD: ${f['accSDX']} N');
    if (f['accRangeX'] != null) s.add('Force Range: ${f['accRangeX']} N');
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

  static void _extractPrimer(Map<String, String> kv, List<List<String>> table, Map<String, dynamic> f, List<String> s, [String content = '']) {
    double? parseNum(String? val) {
      if (val == null) return null;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(val);
      return match != null ? double.tryParse(match.group(0)!) : null;
    }

    // 1. Insertion Depth extraction & average calculation
    String? rawDepth;
    for (final entry in kv.entries) {
      final k = entry.key;
      if (k.contains('insertion depth') || (k.contains('primer') && k.contains('depth')) || k == 'depth') {
        rawDepth = entry.value;
        break;
      }
    }
    if (rawDepth == null && content.isNotEmpty) {
      final depthMatch = RegExp(
        r'(?:Primer\s*)?insertion\s*depth\s*(?:\([a-zA-Z°]+\)|\[[a-zA-Z°]+\])?\s*[:=\t\s]+([0-9\.\s\-,\/]+)',
        caseSensitive: false,
      ).firstMatch(content);
      if (depthMatch != null) {
        rawDepth = depthMatch.group(1)!.trim();
      }
    }

    if (rawDepth != null && rawDepth.isNotEmpty) {
      final nums = RegExp(r'\d+(?:\.\d+)?')
          .allMatches(rawDepth)
          .map((m) => double.tryParse(m.group(0)!))
          .where((n) => n != null)
          .cast<double>()
          .toList();
      if (nums.isNotEmpty) {
        final double avg = nums.reduce((a, b) => a + b) / nums.length;
        final formatted = (avg * 100).roundToDouble() == (avg * 100)
            ? avg.toStringAsFixed(2)
            : avg.toStringAsFixed(3);
        f['primerInsertionDepth'] = formatted;
        f['primer_insertion_depth'] = formatted;
        s.add('Insertion Depth: $formatted mm (Average)');
      }
    }

    // 2. Drop Table parsing (H, F, M, PI) to calculate Total Quantity Tested and Misfires
    int totalFires = 0;
    int totalMisfires = 0;
    bool foundDropTable = false;
    final dropTableRows = <Map<String, dynamic>>[];

    if (content.isNotEmpty) {
      final lines = content.split(RegExp(r'\r?\n'));
      bool inDropTable = false;
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // Check for table header: H, F, M or Height, Fire, Misfire
        if (RegExp(r'\bH\b[\s\t|,;]+\bF\b[\s\t|,;]+\bM\b', caseSensitive: false).hasMatch(trimmedLine) ||
            RegExp(r'\bHeight\b[\s\t|,;]+\bFire\b[\s\t|,;]+\bMis', caseSensitive: false).hasMatch(trimmedLine)) {
          inDropTable = true;
          continue;
        }

        if (inDropTable) {
          final rowMatch = RegExp(r'^(?:[|,\s\t]+)?(\d+(?:\.\d+)?)[,\s\t|;]+(\d+)[,\s\t|;]+(\d+)(?:[,\s\t|;]+(\d+(?:\.\d+)?))?').firstMatch(trimmedLine);
          if (rowMatch != null) {
            final h = double.tryParse(rowMatch.group(1)!);
            final fVal = int.tryParse(rowMatch.group(2)!);
            final mVal = int.tryParse(rowMatch.group(3)!);
            if (h != null && fVal != null && mVal != null) {
              totalFires += fVal;
              totalMisfires += mVal;
              foundDropTable = true;
              final pi = (fVal + mVal > 0) ? (mVal / (fVal + mVal)) : 0.0;
              dropTableRows.add({'h': h, 'f': fVal, 'm': mVal, 'pi': double.parse(pi.toStringAsFixed(3))});
              continue;
            }
          }
          if (foundDropTable && !RegExp(r'^[|\s\t]*\d').hasMatch(trimmedLine)) {
            inDropTable = false;
          }
        }
      }

      // Check vertical drop table format (lines: H, F, M, PI followed by data quads/triplets)
      if (!foundDropTable) {
        for (int i = 0; i < lines.length - 3; i++) {
          final l0 = lines[i].trim().toUpperCase();
          final l1 = lines[i + 1].trim().toUpperCase();
          final l2 = lines[i + 2].trim().toUpperCase();
          if (l0 == 'H' && l1 == 'F' && l2 == 'M') {
            int cur = i + 3;
            if (cur < lines.length && lines[cur].trim().toUpperCase().startsWith('PI')) {
              cur++;
            }
            while (cur + 2 < lines.length) {
              final hVal = double.tryParse(lines[cur].trim());
              final fVal = int.tryParse(lines[cur + 1].trim());
              final mVal = int.tryParse(lines[cur + 2].trim());
              if (hVal != null && fVal != null && mVal != null && (fVal >= 0 && mVal >= 0 && (fVal + mVal > 0))) {
                totalFires += fVal;
                totalMisfires += mVal;
                foundDropTable = true;
                cur += 3;
                double? parsedPi;
                if (cur < lines.length) {
                  final piVal = double.tryParse(lines[cur].trim());
                  if (piVal != null && piVal >= 0.0 && piVal <= 1.0) {
                    parsedPi = piVal;
                    cur++;
                  }
                }
                final pi = parsedPi ?? ((fVal + mVal > 0) ? (mVal / (fVal + mVal)) : 0.0);
                dropTableRows.add({'h': hVal, 'f': fVal, 'm': mVal, 'pi': double.parse(pi.toStringAsFixed(3))});
              } else {
                break;
              }
            }
            if (foundDropTable) break;
          }
        }
      }

      // Fallback: search all lines for consecutive rows matching (H F M PI) where H >= 10
      if (!foundDropTable) {
        for (final line in lines) {
          final rowMatch = RegExp(r'^\s*(?:[|,\s\t]+)?(\d{2,3}(?:\.\d+)?)[,\s\t|;]+(\d+)[,\s\t|;]+(\d+)(?:[,\s\t|;]+(\d+(?:\.\d+)?))?').firstMatch(line);
          if (rowMatch != null) {
            final h = double.tryParse(rowMatch.group(1)!);
            final fVal = int.tryParse(rowMatch.group(2)!);
            final mVal = int.tryParse(rowMatch.group(3)!);
            if (h != null && fVal != null && mVal != null && (fVal > 0 || mVal > 0)) {
              totalFires += fVal;
              totalMisfires += mVal;
              foundDropTable = true;
              final pi = (fVal + mVal > 0) ? (mVal / (fVal + mVal)) : 0.0;
              dropTableRows.add({'h': h, 'f': fVal, 'm': mVal, 'pi': double.parse(pi.toStringAsFixed(3))});
            }
          }
        }
      }

      // Column-oriented drop table fallback (e.g. F column followed by M column in PDF streams)
      if (!foundDropTable) {
        final fColMatch = RegExp(r'\b(?:F|Fire)\b([\s\S]*?)(?=\b(?:M|Misfire|PI|HM|SD|Alpha3)\b|$)', caseSensitive: false).firstMatch(content);
        final mColMatch = RegExp(r'\b(?:M|Misfire)\b([\s\S]*?)(?=\b(?:PI|HM|SD|Alpha3|Emax|Emin)\b|$)', caseSensitive: false).firstMatch(content);
        if (fColMatch != null && mColMatch != null) {
          final fInts = RegExp(r'\b\d+\b').allMatches(fColMatch.group(1)!).map((m) => int.tryParse(m.group(0)!)).where((n) => n != null).cast<int>().toList();
          final mInts = RegExp(r'\b\d+\b').allMatches(mColMatch.group(1)!).map((m) => int.tryParse(m.group(0)!)).where((n) => n != null).cast<int>().toList();
          if (fInts.length >= 3 && mInts.length >= 3 && fInts.length == mInts.length) {
            final sumF = fInts.reduce((a, b) => a + b);
            final sumM = mInts.reduce((a, b) => a + b);
            if (sumF + sumM > 0) {
              totalFires = sumF;
              totalMisfires = sumM;
              foundDropTable = true;
            }
          }
        }
      }
    }

    // Also check tableData if not found from content
    if (!foundDropTable && table.isNotEmpty) {
      for (final row in table) {
        if (row.length >= 3) {
          final h = parseNum(row[0]);
          final fVal = int.tryParse(row[1].trim());
          final mVal = int.tryParse(row[2].trim());
          if (h != null && fVal != null && mVal != null && (fVal > 0 || mVal > 0)) {
            totalFires += fVal;
            totalMisfires += mVal;
            foundDropTable = true;
            final pi = (fVal + mVal > 0) ? (mVal / (fVal + mVal)) : 0.0;
            dropTableRows.add({'h': h, 'f': fVal, 'm': mVal, 'pi': double.parse(pi.toStringAsFixed(3))});
          }
        }
      }
    }

    if (foundDropTable) {
      final totalTested = totalFires + totalMisfires;
      f['produced'] = '$totalTested';
      f['shot_count'] = '$totalTested';
      f['primerTotalTested'] = '$totalTested';
      f['primerTotalRounds'] = '$totalTested';
      f['primerTotalFires'] = '$totalFires';
      f['primerTableFires'] = '$totalFires';
      f['primerTableMisfires'] = '$totalMisfires';
      f['primerTotalMisfires'] = '$totalMisfires';
      f['misfires'] = '$totalMisfires';
      f['defects'] = '$totalMisfires';
      if (dropTableRows.isNotEmpty) {
        f['primerDropTable'] = jsonEncode(dropTableRows);
      }
      s.add('Total Rounds (Sample Size): $totalTested (Fires: $totalFires, Misfires: $totalMisfires)');
    }

    // Extract Comments/Notes if present
    if (content.isNotEmpty) {
      final commMatch = RegExp(
        r'(?:Comments|Notes|Remarks)\s*[:=\t\s]*\r?\n?\s*([^\r\n]+(?:\r?\n[^\r\n]+)*?)(?=\b(?:HM\s*\+\s*5\s*SD|HM\s*-\s*2\s*SD|Approved|Rejected|H\b|\Z))',
        caseSensitive: false,
      ).firstMatch(content);
      if (commMatch != null && (f['notes'] == null || f['notes'].toString().isEmpty)) {
        final cVal = commMatch.group(1)!.trim();
        if (cVal.isNotEmpty) {
          f['notes'] = cVal;
          s.add('Comments: $cVal');
        }
      }
    }

    // 3. Statistical Metrics: HM, SD, HM+5SD, HM-2SD, Alpha3, Emax, Emin
    // Line-by-line check first (handles single-space logs without colons, e.g. 'HM 205.5')
    if (content.isNotEmpty) {
      final contentLines = content.split(RegExp(r'\r?\n'));
      for (int i = 0; i < contentLines.length; i++) {
        final line = contentLines[i].trim();
        if (line.isEmpty) continue;

        // HM+5SD / HM-2SD matches on line
        final allFireLineMatch = RegExp(r'^(?:HM\s*\+\s*5\s*SD|H̄\s*\+\s*5\s*S|H-bar\s*\+\s*5\s*S|All\s*Fire(?:\s*Height)?)\s*[:=\s]+([0-9]+(?:\.[0-9]+)?)$', caseSensitive: false).firstMatch(line);
        if (allFireLineMatch != null) {
          f['primerAllFire'] ??= allFireLineMatch.group(1)!;
        }

        final noFireLineMatch = RegExp(r'^(?:HM\s*-\s*2\s*SD|H̄\s*-\s*2\s*S|H-bar\s*-\s*2\s*S|No\s*Fire(?:\s*Height)?)\s*[:=\s]+([0-9]+(?:\.[0-9]+)?)$', caseSensitive: false).firstMatch(line);
        if (noFireLineMatch != null) {
          f['primerNoFire'] ??= noFireLineMatch.group(1)!;
        }

        // Standalone HM line (ensure line does NOT contain + or -)
        final hmLineMatch = RegExp(r'^(?:HM|H-bar|Hbar)\s*[:=\s]+([0-9]+(?:\.[0-9]+)?)$', caseSensitive: false).firstMatch(line);
        if (hmLineMatch != null && !line.contains('+') && !line.contains('-')) {
          f['primerHbar'] ??= hmLineMatch.group(1)!;
        }

        // Standalone SD line (ensure line does NOT contain + or -)
        final sdLineMatch = RegExp(r'^(?:SD|Stdev)\s*[:=\s]+([0-9]+(?:\.[0-9]+)?)$', caseSensitive: false).firstMatch(line);
        if (sdLineMatch != null && !line.contains('+') && !line.contains('-')) {
          f['primerSD'] ??= sdLineMatch.group(1)!;
        }

        final a3LineMatch = RegExp(r'^(?:Alpha3|α3)\s*[:=\s]+([-+]?[0-9]+(?:\.[0-9]+)?)$', caseSensitive: false).firstMatch(line);
        if (a3LineMatch != null) {
          f['primerAlpha3'] ??= a3LineMatch.group(1)!;
        }

        final emaxLineMatch = RegExp(r'^(?:Emax|E\s*max)\s*[:=\s]+([0-9]+(?:\.[0-9]+)?)$', caseSensitive: false).firstMatch(line);
        if (emaxLineMatch != null) {
          f['primerEmax'] ??= emaxLineMatch.group(1)!;
        }

        final eminLineMatch = RegExp(r'^(?:Emin|E\s*min)\s*[:=\s]+([0-9]+(?:\.[0-9]+)?)$', caseSensitive: false).firstMatch(line);
        if (eminLineMatch != null) {
          f['primerEmin'] ??= eminLineMatch.group(1)!;
        }

        // Check if line is header with value on next line (e.g. 'HM' on line i, '205.5' on line i+1)
        if (i < contentLines.length - 1) {
          final nextLine = contentLines[i + 1].trim();
          final nextNumMatch = RegExp(r'^[-+]?[0-9]+(?:\.[0-9]+)?$').firstMatch(nextLine);
          if (nextNumMatch != null) {
            final lLower = line.toLowerCase();
            if ((lLower == 'hm' || lLower == 'hbar' || lLower == 'h-bar' || lLower == 'h̄') && f['primerHbar'] == null) {
              f['primerHbar'] = nextLine;
            } else if ((lLower == 'sd' || lLower == 'stdev') && f['primerSD'] == null) {
              f['primerSD'] = nextLine;
            } else if ((lLower == 'alpha3' || lLower == 'α3') && f['primerAlpha3'] == null) {
              f['primerAlpha3'] = nextLine;
            } else if (lLower == 'emax' && f['primerEmax'] == null) {
              f['primerEmax'] = nextLine;
            } else if (lLower == 'emin' && f['primerEmin'] == null) {
              f['primerEmin'] = nextLine;
            } else if ((lLower == 'hm+5sd' || lLower == 'h̄+5s' || lLower == 'hm+5sd:') && f['primerAllFire'] == null) {
              f['primerAllFire'] = nextLine;
            } else if ((lLower == 'hm-2sd' || lLower == 'h̄-2s' || lLower == 'hm-2sd:') && f['primerNoFire'] == null) {
              f['primerNoFire'] = nextLine;
            }
          }
        }

        // Check if line is header row: HM SD Alpha3 Emax Emin followed by values
        if (i < contentLines.length - 1) {
          final nextLine = contentLines[i + 1].trim();
          final lLower = line.toLowerCase();
          if (lLower.contains('hm') && lLower.contains('sd') && !lLower.contains('+')) {
            final headers = line.split(RegExp(r'\s+'));
            final vals = nextLine.split(RegExp(r'\s+'));
            if (headers.length == vals.length) {
              for (int j = 0; j < headers.length; j++) {
                final h = headers[j].toLowerCase();
                final v = vals[j];
                if (h == 'hm') f['primerHbar'] ??= v;
                if (h == 'sd') f['primerSD'] ??= v;
                if (h == 'alpha3' || h == 'α3') f['primerAlpha3'] ??= v;
                if (h == 'emax') f['primerEmax'] ??= v;
                if (h == 'emin') f['primerEmin'] ??= v;
              }
            }
          }
        }
      }
    }

    for (final entry in kv.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k.contains('hm+5sd') || k.contains('hm + 5sd') || k.contains('hbar+5s') || k.contains('all fire') || k.contains('h̄+5s')) {
        final num = parseNum(v);
        if (num != null) f['primerAllFire'] ??= v.trim();
      } else if (k.contains('hm-2sd') || k.contains('hm - 2sd') || k.contains('hbar-2s') || k.contains('no fire') || k.contains('h̄-2s')) {
        final num = parseNum(v);
        if (num != null) f['primerNoFire'] ??= v.trim();
      } else if (k == 'hm' || k == 'hbar' || k == 'h-bar' || k.contains('average height') || k.contains('mean height') || k == 'h̄') {
        final num = parseNum(v);
        if (num != null) f['primerHbar'] ??= v.trim();
      } else if (k == 'sd' || k == 'standard deviation' || k == 'stdev' || k == 's') {
        final num = parseNum(v);
        if (num != null) f['primerSD'] ??= v.trim();
      } else if (k == 'alpha3' || k == 'α3') {
        final num = parseNum(v);
        if (num != null) f['primerAlpha3'] ??= v.trim();
      } else if (k == 'emax') {
        final num = parseNum(v);
        if (num != null) f['primerEmax'] ??= v.trim();
      } else if (k == 'emin') {
        final num = parseNum(v);
        if (num != null) f['primerEmin'] ??= v.trim();
      } else if (k.contains('weight') || k.contains('ball weight') || k.contains('drop weight')) {
        final num = parseNum(v);
        if (num != null) f['primerDropWeight'] ??= v.trim();
      }
    }

    if (content.isNotEmpty) {
      if (f['primerAllFire'] == null) {
        final allFireMatch = RegExp(r'(?:HM\s*\+\s*5\s*SD|H̄\s*\+\s*5\s*S|H-bar\s*\+\s*5\s*S|All\s*Fire(?:\s*Height)?)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
        if (allFireMatch != null) f['primerAllFire'] = allFireMatch.group(1)!;
      }
      if (f['primerNoFire'] == null) {
        final noFireMatch = RegExp(r'(?:HM\s*-\s*2\s*SD|H̄\s*-\s*2\s*S|H-bar\s*-\s*2\s*S|No\s*Fire(?:\s*Height)?)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
        if (noFireMatch != null) f['primerNoFire'] = noFireMatch.group(1)!;
      }
      if (f['primerHbar'] == null) {
        // Negative lookahead (?!\s*[\+\-]) to ensure HM+5SD is NOT matched
        final hmMatch = RegExp(r'(?:\bHM\b(?!\s*[\+\-])|\bH-bar\b|\bHbar\b|Mean\s*Height|H̄)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
        if (hmMatch != null) f['primerHbar'] = hmMatch.group(1)!;
      }
      if (f['primerSD'] == null) {
        // Negative lookbehind (?<![0-9\+\-\/]) to ensure 5SD or 2SD is NOT matched
        final sdMatch = RegExp(r'(?<![0-9\+\-\/])(?:\bSD\b|Standard\s*Deviation)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
        if (sdMatch != null) f['primerSD'] = sdMatch.group(1)!;
      }
      if (f['primerDropWeight'] == null) {
        final weightMatch = RegExp(r'(?:Drop\s*Weight|Ball\s*Weight)[^0-9\r\n]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
        if (weightMatch != null) f['primerDropWeight'] = weightMatch.group(1)!;
      }

      final alphaMatch = RegExp(r'(?:\bAlpha3\b|α3)[^0-9\r\n\-+]*?([-+]?[0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (alphaMatch != null) f['primerAlpha3'] ??= alphaMatch.group(1)!;

      final emaxMatch = RegExp(r'(?:\bEmax\b|E\s*max)[^0-9\r\n\-+]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (emaxMatch != null) f['primerEmax'] ??= emaxMatch.group(1)!;

      final eminMatch = RegExp(r'(?:\bEmin\b|E\s*min)[^0-9\r\n\-+]*?([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(content);
      if (eminMatch != null) f['primerEmin'] ??= eminMatch.group(1)!;
    }

    // Auto calculate HM+5SD and HM-2SD if missing
    if (f['primerHbar'] != null && f['primerSD'] != null) {
      final h = double.tryParse(f['primerHbar']!);
      final sVal = double.tryParse(f['primerSD']!);
      if (h != null && sVal != null) {
        if (f['primerAllFire'] == null) {
          f['primerAllFire'] = (h + 5 * sVal).toStringAsFixed(1);
        }
        if (f['primerNoFire'] == null) {
          f['primerNoFire'] = (h - 2 * sVal).toStringAsFixed(1);
        }
      }
    }

    if (f['primerHbar'] != null) s.add('Mean Height (HM): ${f['primerHbar']} mm');
    if (f['primerSD'] != null) s.add('Standard Deviation (SD): ${f['primerSD']} mm');
    if (f['primerAllFire'] != null) s.add('All Fire (HM+5SD): ${f['primerAllFire']} mm');
    if (f['primerNoFire'] != null) s.add('No Fire (HM-2SD): ${f['primerNoFire']} mm');
    if (f['primerDropWeight'] != null) s.add('Drop Weight: ${f['primerDropWeight']} g');
    if (f['primerAlpha3'] != null) s.add('Alpha3: ${f['primerAlpha3']}');
    if (f['primerEmax'] != null) s.add('Emax: ${f['primerEmax']}');
    if (f['primerEmin'] != null) s.add('Emin: ${f['primerEmin']}');
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
    final zlibDecoder = ZLibDecoder();
    final globalCMap = <int, String>{};
    final streamBlocks = <String>[];

    // 1. Search for and decompress all PDF stream objects (FlateDecode)
    int searchIdx = 0;
    while (searchIdx < bytes.length) {
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
        searchIdx = streamStart + 1;
        continue;
      }

      final streamSlice = bytes.sublist(streamStart, streamEnd);
      List<int>? decompressed;
      try {
        final decoded = ZLibDecoder().decodeBytes(streamSlice, verify: false);
        if (decoded.isNotEmpty) {
          decompressed = decoded;
        }
      } catch (_) {
        try {
          final inflated = Inflate(streamSlice).getBytes();
          if (inflated.isNotEmpty) {
            decompressed = inflated;
          }
        } catch (_) {}
      }

      final streamTextBytes = (decompressed != null && decompressed.isNotEmpty) ? decompressed : streamSlice;
      final streamStr = latin1.decode(streamTextBytes, allowInvalid: true);

      // Collect CMap definitions (mapping CIDs to Unicode)
      if (streamStr.contains('begincmap') || streamStr.contains('/CIDInit')) {
        final cmap = _parseCMap(streamStr);
        globalCMap.addAll(cmap);
      }

      if (streamStr.contains('BT')) {
        streamBlocks.add(streamStr);
      }
    }

    // 2. Parse text blocks from streams using global CMap
    for (final streamStr in streamBlocks) {
      final btMatches = RegExp(r'BT\b([\s\S]*?)\bET', caseSensitive: false).allMatches(streamStr);
      for (final m in btMatches) {
        final parsed = _parsePdfTextBlock(m.group(1) ?? '', globalCMap);
        if (parsed.trim().isNotEmpty) {
          buffer.writeln(parsed.trim());
        }
      }
    }

    // Convert bytes to Latin-1 string as fallback if buffer is minimal
    final raw = latin1.decode(bytes, allowInvalid: true);

    if (buffer.length < 20) {
      final btMatches = RegExp(r'BT\b([\s\S]*?)\bET', caseSensitive: false).allMatches(raw);
      for (final m in btMatches) {
        final parsed = _parsePdfTextBlock(m.group(1) ?? '', globalCMap);
        if (parsed.trim().isNotEmpty) {
          buffer.writeln(parsed.trim());
        }
      }
    }

    if (buffer.length < 20) {
      final literalPattern = RegExp(r'(?:\(((?:\\.|[^)])*)\)|<([0-9A-Fa-f\s]+)>)\s*(?:Tj|\x27|\x22)', caseSensitive: false);
      for (final m in literalPattern.allMatches(raw)) {
        final unescaped = m.group(1) != null ? _unescapeAndDecodePdfLiteralString(m.group(1)!, globalCMap) : _decodePdfHexString(m.group(2)!, globalCMap);
        if (unescaped.trim().isNotEmpty) {
          buffer.writeln(unescaped.trim());
        }
      }
    }

    if (buffer.length < 20) {
      // Only extract recognizable plain ASCII words if they form coherent English/ballistic text
      final readablePattern = RegExp(r'\b[A-Za-z][A-Za-z0-9\.\-\:\,\=\s\/\+\#]{3,}\b');
      for (final m in readablePattern.allMatches(raw)) {
        final s = m.group(0)!.trim();
        if (s.length >= 4 &&
            !s.contains('obj') &&
            !s.contains('endobj') &&
            !s.contains('xref') &&
            !s.contains('/Filter') &&
            !s.contains('/Type') &&
            !s.contains('stream') &&
            RegExp(r'[A-Za-z]{3,}').hasMatch(s)) {
          buffer.writeln(s);
        }
      }
    }

    final rawText = buffer.toString().trim();
    return TestResultExtractor.normalizeShiftedText(rawText);
  }

  static Map<int, String> _parseCMap(String cmapText) {
    final map = <int, String>{};
    final bfCharPattern = RegExp(r'(\d+)\s+beginbfchar([\s\S]*?)endbfchar', caseSensitive: false);
    for (final match in bfCharPattern.allMatches(cmapText)) {
      final block = match.group(2) ?? '';
      final entryPattern = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>');
      for (final em in entryPattern.allMatches(block)) {
        final src = int.tryParse(em.group(1)!, radix: 16);
        final dstHex = em.group(2)!;
        if (src != null && dstHex.isNotEmpty) {
          final sb = StringBuffer();
          for (int i = 0; i < dstHex.length; i += 4) {
            final end = (i + 4 <= dstHex.length) ? i + 4 : dstHex.length;
            final code = int.tryParse(dstHex.substring(i, end), radix: 16);
            if (code != null) sb.writeCharCode(code);
          }
          map[src] = sb.toString();
        }
      }
    }

    final bfRangePattern = RegExp(r'(\d+)\s+beginbfrange([\s\S]*?)endbfrange', caseSensitive: false);
    for (final match in bfRangePattern.allMatches(cmapText)) {
      final block = match.group(2) ?? '';
      final rangePattern1 = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>');
      for (final rm in rangePattern1.allMatches(block)) {
        final start = int.tryParse(rm.group(1)!, radix: 16);
        final end = int.tryParse(rm.group(2)!, radix: 16);
        final dst = int.tryParse(rm.group(3)!, radix: 16);
        if (start != null && end != null && dst != null && start <= end) {
          int dstVal = dst;
          for (int c = start; c <= end; c++) {
            map[c] = String.fromCharCode(dstVal++);
          }
        }
      }

      final rangePattern2 = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*\[([\s\S]*?)\]');
      for (final rm in rangePattern2.allMatches(block)) {
        final start = int.tryParse(rm.group(1)!, radix: 16);
        final arrayBlock = rm.group(3) ?? '';
        final hexItems = RegExp(r'<([0-9A-Fa-f]+)>').allMatches(arrayBlock);
        if (start != null) {
          int offset = 0;
          for (final hi in hexItems) {
            final hexVal = hi.group(1)!;
            final sb = StringBuffer();
            for (int i = 0; i < hexVal.length; i += 4) {
              final end = (i + 4 <= hexVal.length) ? i + 4 : hexVal.length;
              final code = int.tryParse(hexVal.substring(i, end), radix: 16);
              if (code != null) sb.writeCharCode(code);
            }
            map[start + offset] = sb.toString();
            offset++;
          }
        }
      }
    }
    return map;
  }

  static String _parsePdfTextBlock(String block, Map<int, String> cMap) {
    final sb = StringBuffer();
    final opPattern = RegExp(
      r'\(((?:\\.|[^)])*)\)\s*(Tj|\x27|\x22)'
      r'|<([0-9A-Fa-f\s]+)>\s*(Tj|\x27|\x22)'
      r'|\[([\s\S]*?)\]\s*TJ'
      r'|T\*'
      r'|([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)\s+(?:Td|TD)'
      r'|(?:[-+]?\d*\.?\d+\s+){5}([-+]?\d*\.?\d+)\s+Tm',
      caseSensitive: false,
    );

    double lastY = double.nan;
    for (final m in opPattern.allMatches(block)) {
      final fullMatch = m.group(0)!;
      if (m.group(1) != null) {
        final str = _unescapeAndDecodePdfLiteralString(m.group(1)!, cMap);
        final op = m.group(2);
        if (op == "'" || op == '"') sb.writeln();
        sb.write(str);
      } else if (m.group(3) != null) {
        final str = _decodePdfHexString(m.group(3)!, cMap);
        final op = m.group(4);
        if (op == "'" || op == '"') sb.writeln();
        sb.write(str);
      } else if (m.group(5) != null) {
        final inner = m.group(5)!;
        final innerRegex = RegExp(r'\(((?:\\.|[^)])*)\)|<([0-9A-Fa-f\s]+)>|(-?\d+(?:\.\d+)?)');
        for (final im in innerRegex.allMatches(inner)) {
          if (im.group(1) != null) {
            sb.write(_unescapeAndDecodePdfLiteralString(im.group(1)!, cMap));
          } else if (im.group(2) != null) {
            sb.write(_decodePdfHexString(im.group(2)!, cMap));
          } else if (im.group(3) != null) {
            final offset = double.tryParse(im.group(3)!) ?? 0;
            if (offset < -150) sb.write(' ');
          }
        }
        sb.write(' ');
      } else if (fullMatch.startsWith('T*')) {
        sb.writeln();
      } else if (m.group(7) != null) {
        final ty = double.tryParse(m.group(7)!) ?? 0;
        if (ty.abs() > 0.01) {
          sb.writeln();
        }
      } else if (m.group(8) != null) {
        final y = double.tryParse(m.group(8)!) ?? 0;
        if (!lastY.isNaN && (y - lastY).abs() > 2.0) {
          sb.writeln();
        }
        lastY = y;
      }
    }

    if (sb.isEmpty) {
      final tjPattern = RegExp(r'\(([^)]*)\)\s*(?:Tj|\x27|\x22)', caseSensitive: false);
      for (final m in tjPattern.allMatches(block)) {
        final str = _unescapeAndDecodePdfLiteralString(m.group(1) ?? '', cMap);
        sb.write(str);
      }
    }

    return sb.toString();
  }

  static String _decodePdfHexString(String hex, [Map<int, String>? cMap]) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '';

    // Check CMap first (2-byte CIDs for Type0, 1-byte for 8-bit TrueType)
    if (cMap != null && cMap.isNotEmpty) {
      final sb = StringBuffer();
      bool any = false;
      for (int i = 0; i < clean.length; i += 4) {
        final end = (i + 4 <= clean.length) ? i + 4 : clean.length;
        final cid = int.tryParse(clean.substring(i, end), radix: 16);
        if (cid != null && cMap.containsKey(cid)) {
          sb.write(cMap[cid]);
          any = true;
        }
      }
      if (any) return sb.toString();

      // Try 1-byte CIDs
      sb.clear();
      for (int i = 0; i < clean.length; i += 2) {
        final end = (i + 2 <= clean.length) ? i + 2 : clean.length;
        final cid = int.tryParse(clean.substring(i, end), radix: 16);
        if (cid != null && cMap.containsKey(cid)) {
          sb.write(cMap[cid]);
          any = true;
        }
      }
      if (any) return sb.toString();
    }

    // Fallback: UTF-16BE / ASCII / Latin-1
    final padded = clean.length.isOdd ? '${clean}0' : clean;
    final bytes = <int>[];
    for (int i = 0; i < padded.length; i += 2) {
      final b = int.tryParse(padded.substring(i, i + 2), radix: 16);
      if (b != null) bytes.add(b);
    }
    if (bytes.isEmpty) return '';
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final chars = <int>[];
      for (int i = 2; i < bytes.length - 1; i += 2) {
        chars.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(chars);
    }
    if (bytes.length >= 2 && bytes[0] == 0x00 && bytes[1] > 0) {
      final chars = <int>[];
      for (int i = 0; i < bytes.length - 1; i += 2) {
        chars.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(chars);
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  static String _unescapeAndDecodePdfLiteralString(String raw, [Map<int, String>? cMap]) {
    final bytes = <int>[];
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] == '\\' && i + 1 < raw.length) {
        final next = raw[i + 1];
        if (next == 'n') {
          bytes.add(10);
          i++;
        } else if (next == 'r') {
          bytes.add(13);
          i++;
        } else if (next == 't') {
          bytes.add(9);
          i++;
        } else if (next == 'b') {
          bytes.add(8);
          i++;
        } else if (next == 'f') {
          bytes.add(12);
          i++;
        } else if (next == '(' || next == ')' || next == '\\') {
          bytes.add(raw.codeUnitAt(i + 1));
          i++;
        } else if (RegExp(r'[0-7]').hasMatch(next)) {
          int octLen = 1;
          while (octLen < 3 && i + 1 + octLen < raw.length && RegExp(r'[0-7]').hasMatch(raw[i + 1 + octLen])) {
            octLen++;
          }
          final octStr = raw.substring(i + 1, i + 1 + octLen);
          bytes.add(int.tryParse(octStr, radix: 8) ?? 0);
          i += octLen;
        } else if (next == '\r' || next == '\n') {
          // Line continuation
          i++;
          if (next == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') {
            i++;
          }
        } else {
          bytes.add(raw.codeUnitAt(i + 1));
          i++;
        }
      } else {
        bytes.add(raw.codeUnitAt(i));
      }
    }

    if (cMap != null && cMap.isNotEmpty) {
      final sb = StringBuffer();
      bool mappedAny = false;
      for (final b in bytes) {
        if (cMap.containsKey(b)) {
          sb.write(cMap[b]);
          mappedAny = true;
        } else {
          sb.writeCharCode(b);
        }
      }
      if (mappedAny) return sb.toString();
    }

    return latin1.decode(bytes, allowInvalid: true);
  }

  static String _unescapePdfString(String input) {
    return _unescapeAndDecodePdfLiteralString(input, null);
  }
}
