import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import 'epvat_formula_helper.dart';
import 'default_cartridge_assets.dart';

class ReportGenerator {
  static String getStatusColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'approved') return '#15803d';
    if (s.contains('condition')) return '#0284c7';
    if (s == 'retest' || s == 'pending review') return '#b45309';
    return '#b91c1c';
  }

  static String formatCartridgeTemp(String raw) {
    if (raw.trim().isEmpty) return '';
    String s = raw.replaceAll('&deg;C', '°C').trim();
    while (s.endsWith('°C °C') || s.endsWith('°C°C')) {
      s = s.substring(0, s.lastIndexOf('°C')).trim();
    }
    if (!s.contains('°C')) {
      s = '$s&nbsp;°C';
    }
    s = s.replaceAll(RegExp(r'\s+°C'), '&nbsp;°C');
    return '<span style="white-space: nowrap;">$s</span>';
  }

  static String cleanRemarks(String raw) {
    if (raw.trim().isEmpty) return '';
    String s = raw.trim();
    if (s.toLowerCase() == 'no remarks recorded.' || s.toLowerCase() == 'no remarks recorded') {
      return '';
    }
    if (s.contains('Temps:')) {
      final idx = s.indexOf('Temps:');
      s = s.substring(0, idx).trim();
      if (s.endsWith('|')) {
        s = s.substring(0, s.length - 1).trim();
      }
    }
    if (s.contains('[RETEST|')) {
      final idx = s.indexOf('[RETEST|');
      s = s.substring(0, idx).trim();
    }
    if (s.contains('[RETEST by')) {
      final idx = s.indexOf('[RETEST by');
      s = s.substring(0, idx).trim();
    }
    if (s.toLowerCase() == 'no remarks recorded.' || s.toLowerCase() == 'no remarks recorded') {
      return '';
    }
    return s;
  }

  static String formatWeapons(String raw) {
    if (raw.trim().isEmpty) return '-';
    final items = <String>[];
    final parts = raw.split(RegExp(r'\r?\n+|;\s*'));
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      final subMatches = trimmed.split(RegExp(r',\s*|(?<=\))\s+(?=[A-Za-z0-9])'));
      for (final sub in subMatches) {
        final s = sub.trim();
        if (s.isNotEmpty && !items.contains(s)) {
          items.add(s);
        }
      }
    }
    if (items.isEmpty) return '-';
    return items.map((w) => '<div style="margin-bottom: 2px;">$w</div>').join('');
  }

  static String _formatImageSrc(String raw) {
    if (raw.startsWith('data:')) return raw;
    return 'data:image/png;base64,$raw';
  }

  static String getSdColor(String sdVal, String caliber) {
    final val = double.tryParse(sdVal);
    if (val == null) return '#1e293b';
    if (caliber.contains('Para') || caliber.contains('Luger') || caliber.contains('Match')) {
      if (val > 50.0) return '#ef4444';
      if (val >= 42.5) return '#b45309';
    } else {
      if (val > 200.0) return '#ef4444';
      if (val >= 170.0) return '#b45309';
    }
    return '#1e293b';
  }

  static String getMeanRadiusColor(String radiusVal) {
    final val = double.tryParse(radiusVal);
    if (val == null) return '#1e293b';
    if (val > 50.0) return '#ef4444';
    return '#1e293b';
  }

  static double getMinForceLimit(String caliber) {
    if (caliber.contains('SS109') ||
        caliber.contains('69') ||
        caliber.contains('77') ||
        caliber.contains('Luger') ||
        caliber.contains('Match') ||
        caliber.contains('Para') ||
        caliber.contains('CMJ')) {
      return 200.0;
    } else if (caliber.contains('M193') || caliber.contains('55 grains')) {
      return 165.0;
    } else if (caliber.contains('M80') || caliber.contains('.308')) {
      return 265.0;
    }
    return 0.0;
  }

  static String _getRecordMetricsSummary(BallisticRecord r) {
    if (r.testName == 'Waterproof Test') {
      final leaks = r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast;
      return '$leaks leaks (P: ${r.pressureBar} bar, Visc: ${r.viscosity} s)';
    } else if (r.testName == 'Residual Stress Test') {
      final total = r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast;
      final temp = r.roomTemp.isNotEmpty ? '${r.roomTemp} °C' : '-';
      return '$total splits, Room Temp: $temp';
    } else if (r.testName == 'Accuracy Test') {
      return 'SD X: ${r.accSDX.isNotEmpty ? r.accSDX : "-"} mm, SD Y: ${r.accSDY.isNotEmpty ? r.accSDY : "-"} mm, Mean Vel: ${r.velMean.isNotEmpty ? r.velMean : "-"} m/s';
    } else if (r.testName == 'EPVAT test') {
      final u = r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'bar';
      return 'Mean Chamber: ${r.epvatMeanPressure.isNotEmpty ? r.epvatMeanPressure : "-"} $u, Mean Port: ${r.epvatP2MeanPressure.isNotEmpty ? r.epvatP2MeanPressure : "-"} $u, Mean Vel (+21 °C): ${r.velMean.isNotEmpty ? r.velMean : "-"} m/s';
    } else if (r.testName == 'Extraction Force Test') {
      return 'Mean: ${r.accMeanX} N, Min: ${r.accMinX} N';
    } else if (r.testName == 'Function Test') {
      return '${r.defects} defects (L1:${r.functionLevel1}, L2:${r.functionLevel2}, L3:${r.functionLevel3}, L4:${r.functionLevel4})';
    } else if (r.testName == 'Firing Rate Cycle Test') {
      return '${r.cyclicRateValue} RPM (${r.cyclicRateWeaponType})';
    } else if (r.testName == 'Terminal Effect Test') {
      return 'Dist: ${r.velocityDistance}m, Hole: ${r.terminalHoleDiameter}';
    } else if (r.testName == 'Primer Sensitivity Test') {
      return 'Lot: ${r.primerLot.isNotEmpty ? r.primerLot : r.lotNo}, Sup: ${r.primerSupplier}, H̄: ${r.primerHbar} cm, SD: ${r.primerSD} cm';
    } else if (r.testName == 'Propellant Test') {
      return 'Lot: ${r.propellantLot.isNotEmpty ? r.propellantLot : r.lotNo}, Sup: ${r.propellantSupplier}, Code: ${r.propellantCode}, P1: ${r.epvatMeanPressure} ${r.epvatPressureUnit}, Vel: ${r.velMean} m/s';
    }
    return r.notes;
  }

  static String generateCsv(List<BallisticRecord> records, String testName, String moduleName) {
    final buffer = StringBuffer();
    final lotHeader = moduleName == 'Daily Test' ? 'Hopper No. / Production Date' : 'Lot No';
    
    if (testName == 'Waterproof Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Pressure (Bar),Viscosity,Time of Test,Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.pressureBar, r.viscosity, r.testTime, r.samplingLocation,
          r.mouthSlow, r.mouthFast, r.primerSlow, r.primerFast, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Residual Stress Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Room Temp,Neck Slow,Neck Fast,Shoulder Slow,Shoulder Fast,Body Slow,Body Fast,Head Slow,Head Fast,Location,Time of Test,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.roomTemp, r.neckSlow, r.neckFast, r.shoulderSlow, r.shoulderFast,
          r.bodySlow, r.bodyFast, r.headSlow, r.headFast, r.samplingLocation, r.testTime, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Extraction Force Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Mode,Min Force (N),Mean Force (N),Max Force (N),Range Force (N),SD Force (N),Round Values (N),Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.extractionForceType, r.accMinX, r.accMeanX, r.accMaxX, r.accRangeX, r.accSDX, r.extractionForceRounds, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Accuracy Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Barrel S.N.,Distance (m),Mean X,Max X,Min X,Range X,SD X,Mean Y,Max Y,Min Y,Range Y,SD Y,Mean Radius,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.barrelSN, r.velocityDistance,
          r.accMeanX, r.accMaxX, r.accMinX, r.accRangeX, r.accSDX,
          r.accMeanY, r.accMaxY, r.accMinY, r.accRangeY, r.accSDY,
          r.accMeanRadius, r.velMean, r.velMin, r.velMax, r.velRange, r.velSD, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'EPVAT test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Barrel S.N.,Distance (m),Cartridge Temp,Pressure Type,Pressure Unit,Mean P1,Max P1,Min P1,Range P1,SD P1,Mean P2,Max P2,Min P2,Range P2,SD P2,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,P1 Rounds,P2 Rounds,Vel Rounds,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.barrelSN, r.velocityDistance, r.cartridgeTemp, r.epvatPressureType, r.epvatPressureUnit,
          r.epvatMeanPressure, r.epvatMaxPressure, r.epvatMinPressure, r.epvatRangePressure, r.epvatSDPressure,
          r.epvatP2MeanPressure, r.epvatP2MaxPressure, r.epvatP2MinPressure, r.epvatP2RangePressure, r.epvatP2SDPressure,
          r.velMean, r.velMin, r.velMax, r.velRange, r.velSD,
          r.epvatPressureRounds, r.epvatP2PressureRounds, r.epvatVelRounds, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Firing Rate Cycle Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Weapon Model,Category,Min RPM,Max RPM,Measured RPM,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.cyclicRateWeaponType, r.cyclicRateAmmoType, r.cyclicRateMin, r.cyclicRateMax, r.cyclicRateValue, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Terminal Effect Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Barrel S.N.,Distance (m),Hole Diameter,Steel Plate,Aluminum Plate,Velocity,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.barrelSN, r.velocityDistance,
          r.terminalHoleDiameter, r.terminalSteelPenetration, r.terminalAluminumPenetration, r.terminalVelocity, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Function Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Weapon,Temperature,Result,Qty,Level 1 (Critical),Level 2 (Major),Level 3 (Minor),Level 4,Total Defects,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.cyclicRateWeaponType, r.cartridgeTemp, r.status, r.produced,
          r.functionLevel1, r.functionLevel2, r.functionLevel3, r.functionLevel4, r.defects, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Primer Sensitivity Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Primer Lot,Primer Supplier,Insertion Depth (mm),Hbar (cm),SD (cm),All Fire H (cm),No Fire H (cm),Drop Heights,Fire Results,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.primerLot, r.primerSupplier, r.primerInsertionDepth,
          r.primerHbar, r.primerSD, r.primerAllFireH, r.primerNoFireH,
          r.primerDropHeights, r.primerFireResults, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Propellant Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Propellant Lot,Propellant Supplier,Propellant Code,Barrel S.N.,Distance (m),Cartridge Temp,Pressure Type,Pressure Unit,Mean P1,Max P1,Min P1,Range P1,SD P1,Mean P2,Max P2,Min P2,Range P2,SD P2,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,P1 Rounds,P2 Rounds,Vel Rounds,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.propellantLot, r.propellantSupplier, r.propellantCode,
          r.barrelSN, r.velocityDistance, r.cartridgeTemp, r.epvatPressureType, r.epvatPressureUnit,
          r.epvatMeanPressure, r.epvatMaxPressure, r.epvatMinPressure, r.epvatRangePressure, r.epvatSDPressure,
          r.epvatP2MeanPressure, r.epvatP2MaxPressure, r.epvatP2MinPressure, r.epvatP2RangePressure, r.epvatP2SDPressure,
          r.velMean, r.velMin, r.velMax, r.velRange, r.velSD,
          r.epvatPressureRounds, r.epvatP2PressureRounds, r.epvatVelRounds, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Test Name,Result,Qty,Key Metrics,Remarks');
      for (var r in records) {
        final metrics = _getRecordMetricsSummary(r);
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.testName, r.status, r.produced, metrics, r.notes
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    }
    return buffer.toString();
  }

  static String _buildEpvatCombinedSectionHtml({
    required List<BallisticRecord> records,
    required Map<String, dynamic> adminRules,
    required bool isWord,
  }) {
    if (records.isEmpty) return '';
    final caliber = records[0].caliber;
    final epvRules = adminRules['epvat'] ?? {};
    final formulasMap = Map<String, dynamic>.from(epvRules['custom_formulas'] ?? {});
    final bool isThreeTemp = records.any((r) => r.epvatPressureType == 'Overall' || r.cartridgeTemp.contains(',') || r.cartridgeTemp.contains(';') || r.notes.contains('Temps:')) ||
        records.map((r) => r.cartridgeTemp).toSet().length > 1;
    var list = EpvatFormulaHelper.getFormulasForCaliber(
      formulasMap,
      caliber,
      isThreeTemp: isThreeTemp,
    );
    final String activePressureUnit = records.isNotEmpty && records[0].epvatPressureUnit.isNotEmpty
        ? records[0].epvatPressureUnit
        : 'bar';
    final String defaultTemp = '21';

    final variables = EpvatFormulaHelper.extractVariablesFromRecords(records);
    final results = list.map((f) => EpvatFormulaHelper.evaluateFormulaItem(
      Map<String, dynamic>.from(f as Map),
      variables,
      defaultTemp: defaultTemp,
      activePressureUnit: activePressureUnit,
    )).toList();
    final testedResults = results.where((r) => r.isApplicable).toList();
    final bool allPassed = testedResults.isEmpty || testedResults.every((r) => r.isPassed);

    // Kinetic Energy box if applicable
    String keBox = '';
    final r21 = records.firstWhere(
      (r) => r.cartridgeTemp.contains('21'),
      orElse: () => records.isNotEmpty ? records[0] : BallisticRecord.empty(),
    );
    final effectiveVel = r21.velMean.isNotEmpty ? r21.velMean : (records.isNotEmpty ? records[0].velMean : '');
    if (adminRules.isNotEmpty && effectiveVel.isNotEmpty) {
      final massMap = epvRules['bullet_mass_grams'] ?? {};
      final double? massG = (massMap[caliber] as num?)?.toDouble();
      final double? vMean = double.tryParse(effectiveVel);
      if (massG != null && vMean != null && vMean > 0) {
        final double ke = 0.5 * (massG / 1000.0) * vMean * vMean;
        keBox = '''
        <div style="margin-top: 6px; margin-bottom: 6px; padding: 6px 10px; background-color: #f0f4ff; border: 1px solid #c7d2fe; border-radius: 6px; font-size: 10.5px;">
          <strong style="color: #4f46e5;">&bull; Kinetic Energy (+21&deg;C):</strong>
          <span style="font-family: monospace; font-weight: bold; color: #4f46e5; margin-left: 6px;">${ke.toStringAsFixed(1)} J</span>
          <span style="color: #475569; margin-left: 10px; font-size: 10px;">m = ${massG.toStringAsFixed(2)} g, v = ${vMean.toStringAsFixed(1)} m/s</span>
        </div>''';
      }
    }

    final rowsBuffer = StringBuffer();
    for (int i = 0; i < results.length; i++) {
      final res = results[i];
      final bg = i % 2 == 1 ? 'background-color: #f8fafc;' : '';
      final color = !res.isApplicable ? '#64748b' : (res.isPassed ? '#15803d' : '#b91c1c');
      final statusText = !res.isApplicable ? 'N/A' : (res.isPassed ? 'PASSED' : 'FAILED');
      final displayCalculation = !res.isApplicable ? 'N/A' : '${res.calculatedValue.toStringAsFixed(1)} ${res.unit}';
      final displayOp = res.op == '<=' ? '&le;' : (res.op == '>=' ? '&ge;' : (res.op == '<' ? '&lt;' : (res.op == '>' ? '&gt;' : res.op)));
      rowsBuffer.writeln('''
      <tr style="$bg">
        <td style="padding: 4px 6px; font-size: 10px; border-bottom: 1px solid #e2e8f0; font-weight: 600;">${res.name}</td>
        <td style="padding: 4px 6px; font-size: 10px; border-bottom: 1px solid #e2e8f0; font-family: monospace; color: #475569;">${res.formula}</td>
        <td style="padding: 4px 6px; font-size: 10px; border-bottom: 1px solid #e2e8f0; font-family: monospace; font-weight: bold; color: ${!res.isApplicable ? '#64748b' : '#1e293b'};">$displayCalculation</td>
        <td style="padding: 4px 6px; font-size: 10px; border-bottom: 1px solid #e2e8f0; font-family: monospace;">$displayOp ${res.limitValue.toStringAsFixed(1)} ${res.unit}</td>
        <td style="padding: 4px 6px; font-size: 10px; border-bottom: 1px solid #e2e8f0; font-weight: bold; color: $color;">$statusText</td>
      </tr>
      ''');
    }

    return '''
    <div style="margin-top: 8px; margin-bottom: 8px;">
      <h3 class="section-title" style="border-bottom: 2px solid #cbd5e1; padding-bottom: 3px; font-size: 11.5px; font-weight: bold; text-transform: uppercase;">Combined EPVAT Ballistic Analysis (Admin Adjustable Formulas)</h3>
      <table style="width: 100%; border-collapse: collapse; margin-bottom: 6px;">
        <thead>
          <tr style="background-color: #f1f5f9; color: #475569; font-size: 10px; font-weight: bold; text-align: left; text-transform: uppercase;">
            <th style="padding: 4px 6px; border-bottom: 2px solid #cbd5e1;">Rule / Check Name</th>
            <th style="padding: 4px 6px; border-bottom: 2px solid #cbd5e1;">Formula Expression</th>
            <th style="padding: 4px 6px; border-bottom: 2px solid #cbd5e1;">Evaluated Calculation</th>
            <th style="padding: 4px 6px; border-bottom: 2px solid #cbd5e1;">Configured Limit</th>
            <th style="padding: 4px 6px; border-bottom: 2px solid #cbd5e1;">Status</th>
          </tr>
        </thead>
        <tbody>
          ${rowsBuffer.toString()}
        </tbody>
      </table>
      $keBox
      <div style="padding: 6px 10px; border: 1px solid ${allPassed ? '#bbf7d0' : '#fecaca'}; border-radius: 6px; background-color: ${allPassed ? '#f0fdf4' : '#fef2f2'}; font-size: 11px; font-weight: bold; line-height: 1.3; color: ${allPassed ? '#15803d' : '#b91c1c'};">
        <strong>Combined Sentencing Result:</strong> ${allPassed ? 'The lot satisfies all tested EPVAT ballistic criteria and is approved.' : 'The lot fails one or more configured EPVAT criteria and must be rejected.'}
      </div>
    </div>
    ''';
  }

  static String generateHtml(List<BallisticRecord> records, String testName, String moduleName, {String base64Logo = '', Map<String, dynamic> adminRules = const {}}) {
    final now = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final totalQty = records.fold<int>(0, (sum, r) => sum + r.produced);
    final logoHtml = base64Logo.isNotEmpty 
        ? '<img src="data:image/png;base64,$base64Logo" style="height: 85px; width: auto; object-fit: contain;" />' 
        : '';

    final remarksList = records
        .map((r) => cleanRemarks(r.notes))
        .where((n) => n.isNotEmpty && n.toLowerCase() != 'clear')
        .toSet()
        .toList();
    final remarksText = remarksList.isNotEmpty ? remarksList.join('<br/>') : '';

    final inspectorName = records.isNotEmpty ? records[0].operators : 'N/A';
    final caliber = records.isNotEmpty ? records[0].caliber : 'N/A';
    final lotNo = records.isNotEmpty
        ? (records[0].hopperNo.isEmpty && records[0].boxNo.isEmpty
            ? records[0].lotNo
            : '${records[0].lotNo} (Hopper: ${records[0].hopperNo}, Box: ${records[0].boxNo})')
        : 'N/A';

    final cleanLotNo = records.isNotEmpty ? records[0].lotNo : 'Lot';
    final cleanCaliber = caliber.replaceAll(';', ' ').trim();
    final defaultExportTitle = '${cleanCaliber}_${testName}_$cleanLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final title = defaultExportTitle;

    String epvatCombinedSection = '';
    if (testName == 'EPVAT test' || testName == 'Propellant Test') {
      epvatCombinedSection = _buildEpvatCombinedSectionHtml(
        records: records,
        adminRules: adminRules,
        isWord: false,
      );
    }

    // Classification reference image tag (Residual Stress and Function Test) - Minimized 2x
    String classificationImageTag = '';
    final bool isCaliber9mm = caliber.toLowerCase().contains('9mm') || caliber.toLowerCase().startsWith('9x19');
    final String defaultImg = isCaliber9mm ? DefaultCartridgeAssets.cartridge9mmBase64 : DefaultCartridgeAssets.cartridgeBottleneckBase64;
    final String fallbackCartridgeImg = isCaliber9mm
        ? (adminRules['default_cartridge_9mm'] as String? ?? '').trim()
        : (adminRules['default_cartridge_bottleneck'] as String? ?? '').trim();

    if (testName == 'Residual Stress Test') {
      final rsImg = (adminRules['residual_stress']?['classification_image'] as String? ?? '').trim();
      final imgToUse = rsImg.isNotEmpty ? rsImg : (fallbackCartridgeImg.isNotEmpty ? fallbackCartridgeImg : defaultImg);
      final src = _formatImageSrc(imgToUse);
      final title = isCaliber9mm ? '9mm Residual Stress Reference Diagram' : '5.56 / 7.62 Residual Stress Reference Diagram';
      classificationImageTag = '''
        <div style="min-height: 210px; height: 210px; box-sizing: border-box; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; margin: 0; background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 6px;">
          <img src="$src" style="max-width: 100%; max-height: 175px; object-fit: contain; border-radius: 6px; border: 1px solid #cbd5e1; box-shadow: 0 1px 3px rgba(0,0,0,0.06);" alt="Residual Stress Reference" />
          <div style="font-size: 10px; color: #64748b; margin-top: 4px; font-style: italic;">$title</div>
        </div>
      ''';
    } else if (testName == 'Function Test') {
      final funcImg = (adminRules['function_test']?['classification_image'] as String? ?? '').trim();
      final imgToUse = funcImg.isNotEmpty ? funcImg : (fallbackCartridgeImg.isNotEmpty ? fallbackCartridgeImg : defaultImg);
      final src = _formatImageSrc(imgToUse);
      final title = isCaliber9mm ? '9mm Function Test Reference Diagram' : '5.56 / 7.62 Function Test Reference Diagram';
      classificationImageTag = '''
        <div style="min-height: 210px; height: 210px; box-sizing: border-box; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; margin: 0; background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 6px;">
          <img src="$src" style="max-width: 100%; max-height: 175px; object-fit: contain; border-radius: 6px; border: 1px solid #cbd5e1; box-shadow: 0 1px 3px rgba(0,0,0,0.06);" alt="Function Test Reference" />
          <div style="font-size: 10px; color: #64748b; margin-top: 4px; font-style: italic;">$title</div>
        </div>
      ''';
    }

    String remarksAndDiagramSection = '';
    if (classificationImageTag.isNotEmpty) {
      remarksAndDiagramSection = '''
      <div style="margin-top: 10px; margin-bottom: 10px;">
        <table style="width: 100%; border: none; border-collapse: collapse;">
          <tr>
            <td style="width: 50%; vertical-align: top; border: none; padding-right: 8px; padding-left: 0; padding-top: 0; padding-bottom: 0;">
              <h3 class="section-title" style="margin-top: 0; margin-bottom: 6px;">Remarks</h3>
              <div class="sentence-box" style="min-height: 210px; height: 210px; box-sizing: border-box; overflow-y: auto;">
                $remarksText
              </div>
            </td>
            <td style="width: 50%; vertical-align: top; border: none; padding-left: 8px; padding-right: 0; padding-top: 0; padding-bottom: 0;">
              <h3 class="section-title" style="margin-top: 0; margin-bottom: 6px;">Defect Classification Reference Guide</h3>
              $classificationImageTag
            </td>
          </tr>
        </table>
      </div>
      ''';
    } else {
      remarksAndDiagramSection = '''
      <div>
        <h3 class="section-title">Remarks</h3>
        <div class="sentence-box" style="min-height: 50px;">
          $remarksText
        </div>
      </div>
      ''';
    }

    // Attachments & Evidence section
    String attachmentsSection = '';
    final recordsWithAttachment = records.where((r) => r.attachmentBase64.isNotEmpty).toList();
    if (recordsWithAttachment.isNotEmpty) {
      final attachBuffer = StringBuffer();
      attachBuffer.writeln('''
      <div style="margin-top: 15px; margin-bottom: 15px;">
        <h3 class="section-title">Inspection Attachments & Documentation</h3>
        <div style="display: flex; flex-wrap: wrap; gap: 15px; margin-top: 10px;">
      ''');
      for (var r in recordsWithAttachment) {
        final name = r.attachmentName.isNotEmpty ? r.attachmentName : 'Attachment';
        final isPdf = r.attachmentBase64.startsWith('data:application/pdf');
        final src = _formatImageSrc(r.attachmentBase64);
        attachBuffer.writeln('''
          <div style="border: 1px solid #cbd5e1; border-radius: 6px; padding: 10px; background-color: #f8fafc; max-width: 320px; text-align: center;">
            <div style="font-size: 11px; font-weight: bold; color: #1e293b; margin-bottom: 4px; word-break: break-all;">📎 $name</div>
            <div style="font-size: 9.5px; color: #64748b; margin-bottom: 8px;">Log Record: ${r.timestamp}</div>
        ''');
        if (isPdf) {
          attachBuffer.writeln('<div style="padding: 24px; background: #e2e8f0; border-radius: 4px; font-weight: bold; color: #475569; font-size: 11px;">📄 Document / PDF Attached</div>');
        } else {
          attachBuffer.writeln('<img src="$src" style="max-width: 100%; max-height: 240px; border-radius: 4px; border: 1px solid #cbd5e1;" alt="$name" />');
        }
        attachBuffer.writeln('</div>');
      }
      attachBuffer.writeln('</div></div>');
      attachmentsSection = attachBuffer.toString();
    }

    String formatViscosity(String vStr) {
      final v = vStr.trim();
      if (v.isEmpty) return '';
      if (v.endsWith('s') || v.endsWith('sec') || v.endsWith('second') || v.endsWith('seconds')) {
        return v;
      }
      return '$v seconds';
    }

    final pressure = records.isNotEmpty ? (records[0].pressureBar.isEmpty ? '' : '${records[0].pressureBar} bar') : '';
    final viscosity = records.isNotEmpty ? formatViscosity(records[0].viscosity) : '';
    final samplingLocation = records.isNotEmpty ? records[0].samplingLocation : '';
    final batchResult = records.isNotEmpty ? records[0].status : 'N/A';

    final hasRejected = records.any((r) => r.status.toLowerCase() == 'rejected' || r.status.toLowerCase() == 'failed');
    final hasRetest = records.any((r) => r.status.toLowerCase() == 'retest');
    final hasPending = records.any((r) => r.status.toLowerCase() == 'pending review');
    final hasCondition = records.any((r) => r.status.toLowerCase().contains('condition'));

    String sentenceRequirement = '';
    if (records.isEmpty) {
      sentenceRequirement = 'No records available to evaluate sentence requirements.';
    } else if (hasRejected) {
      sentenceRequirement = 'The inspected lot fails to satisfy quality and ballistic specification criteria. The lot is officially REJECTED and quarantined.';
    } else if (hasRetest) {
      sentenceRequirement = 'Test results indicate marginal quality tolerances. The lot is sentenced to a mandatory RETEST under supervision.';
    } else if (hasPending) {
      sentenceRequirement = 'Evaluation in progress. The batch status remains PENDING REVIEW until supervisor verification is complete.';
    } else if (hasCondition) {
      sentenceRequirement = 'The inspected lot meets operational parameters with accepted variances. The lot is officially APPROVED WITH CONDITION.';
    } else {
      sentenceRequirement = 'The lot meets all quality and ballistic specifications and is approved for final packaging and shipment.';
    }

    final bool hideViscosity = moduleName == 'Lot Acceptance Test' && viscosity.trim().isEmpty;
    final bool hideLocation = moduleName == 'Lot Acceptance Test' && samplingLocation.trim().isEmpty;

    final waterproofRows = StringBuffer();
    if (testName == 'Waterproof Test') {
      waterproofRows.write('<tr>');
      waterproofRows.write('<td style="font-weight: bold; color: #475569;">Test Pressure:</td>');
      waterproofRows.write('<td>$pressure</td>');
      if (!hideViscosity) {
        waterproofRows.write('<td style="font-weight: bold; color: #475569;">Viscosity:</td>');
        waterproofRows.write('<td>$viscosity</td>');
      } else {
        waterproofRows.write('<td></td><td></td>');
      }
      waterproofRows.write('</tr>');

      if (!hideLocation) {
        waterproofRows.write('<tr>');
        waterproofRows.write('<td style="font-weight: bold; color: #475569;">Sampling Location:</td>');
        waterproofRows.write('<td>$samplingLocation</td>');
        waterproofRows.write('<td></td><td></td>');
        waterproofRows.write('</tr>');
      }
    }

    final residualStressRows = StringBuffer();
    if (testName == 'Residual Stress Test') {
      final roomTempStr = records.isNotEmpty && records[0].roomTemp.isNotEmpty ? '${records[0].roomTemp} &deg;C' : 'N/A';
      final locationStr = records.isNotEmpty && records[0].samplingLocation.isNotEmpty ? records[0].samplingLocation : 'N/A';
      residualStressRows.write('<tr>');
      residualStressRows.write('<td style="font-weight: bold; color: #475569;">Room Temperature:</td>');
      residualStressRows.write('<td>$roomTempStr</td>');
      residualStressRows.write('<td style="font-weight: bold; color: #475569;">Sampling Location:</td>');
      residualStressRows.write('<td>$locationStr</td>');
      residualStressRows.write('</tr>');
    }

    final accuracyRows = StringBuffer();
    if (testName == 'Accuracy Test') {
      accuracyRows.write('<tr>');
      accuracyRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      accuracyRows.write('<td>${records.isNotEmpty ? records[0].barrelSN : ''}</td>');
      accuracyRows.write('<td style="font-weight: bold; color: #475569;">Distance of Velocity:</td>');
      accuracyRows.write('<td>${records.isNotEmpty && records[0].velocityDistance.isNotEmpty ? '${records[0].velocityDistance} m' : ''}</td>');
      accuracyRows.write('</tr>');
    }

    final epvatRows = StringBuffer();
    if (testName == 'EPVAT test') {
      epvatRows.write('<tr>');
      epvatRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      epvatRows.write('<td>${records.isNotEmpty ? records[0].barrelSN : ''}</td>');
      epvatRows.write('<td style="font-weight: bold; color: #475569;">Distance of Velocity:</td>');
      epvatRows.write('<td>${records.isNotEmpty && records[0].velocityDistance.isNotEmpty ? '${records[0].velocityDistance} m' : ''}</td>');
      epvatRows.write('</tr>');
      epvatRows.write('<tr>');
      epvatRows.write('<td style="font-weight: bold; color: #475569;">Cartridge Temp:</td>');
      epvatRows.write('<td>${records.isNotEmpty ? formatCartridgeTemp(records[0].cartridgeTemp) : ''}</td>');
      epvatRows.write('<td></td><td></td>');
      epvatRows.write('</tr>');
    }

    final functionRows = StringBuffer();
    if (testName == 'Function Test') {
      final allWeapons = records
          .map((r) => r.cyclicRateWeaponType.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .join('\n');
      final weaponName = allWeapons.isNotEmpty ? allWeapons : (records.isNotEmpty ? records[0].cyclicRateWeaponType : '');
      final rawTemp = records.isNotEmpty ? records[0].cartridgeTemp : '';
      functionRows.write('<tr>');
      functionRows.write('<td style="font-weight: bold; color: #475569; vertical-align: top;">Rifles / Weapons:</td>');
      functionRows.write('<td style="vertical-align: top;">${formatWeapons(weaponName)}</td>');
      functionRows.write('<td style="font-weight: bold; color: #475569; vertical-align: top;">Cartridge Temp:</td>');
      functionRows.write('<td style="white-space: nowrap; vertical-align: top;">${rawTemp.isNotEmpty ? formatCartridgeTemp(rawTemp) : '-'}</td>');
      functionRows.write('</tr>');
    }

    final cyclicRows = StringBuffer();
    if (testName == 'Firing Rate Cycle Test') {
      final wType = records.isNotEmpty ? records[0].cyclicRateWeaponType : '';
      final category = records.isNotEmpty ? records[0].cyclicRateAmmoType : '';
      final rateVal = records.isNotEmpty ? records[0].cyclicRateValue : '';
      final rpmMin = records.isNotEmpty ? records[0].cyclicRateMin : '';
      final rpmMax = records.isNotEmpty ? records[0].cyclicRateMax : '';
      final rpmMaxStr = (rpmMax == 'null' || rpmMax.isEmpty) ? 'No Limit' : '$rpmMax RPM';
      
      cyclicRows.write('<tr>');
      cyclicRows.write('<td style="font-weight: bold; color: #475569;">Weapon Model:</td>');
      cyclicRows.write('<td>$wType ($category)</td>');
      cyclicRows.write('<td style="font-weight: bold; color: #475569;">Allowed Limits:</td>');
      cyclicRows.write('<td>Min: $rpmMin RPM | Max: $rpmMaxStr</td>');
      cyclicRows.write('</tr>');
      cyclicRows.write('<tr>');
      cyclicRows.write('<td style="font-weight: bold; color: #475569;">Measured Rate:</td>');
      cyclicRows.write('<td style="font-weight: bold; color: #0f172a;">$rateVal RPM</td>');
      cyclicRows.write('<td></td><td></td>');
      cyclicRows.write('</tr>');
    }

    final terminalRows = StringBuffer();
    if (testName == 'Terminal Effect Test') {
      terminalRows.write('<tr>');
      terminalRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      terminalRows.write('<td>${records.isNotEmpty ? records[0].barrelSN : ''}</td>');
      terminalRows.write('<td style="font-weight: bold; color: #475569;">Distance:</td>');
      terminalRows.write('<td>${records.isNotEmpty && records[0].velocityDistance.isNotEmpty ? '${records[0].velocityDistance} m' : ''}</td>');
      terminalRows.write('</tr>');
    }

    final primerRows = StringBuffer();
    if (testName == 'Primer Sensitivity Test') {
      final r0 = records.isNotEmpty ? records[0] : null;
      primerRows.write('<tr>');
      primerRows.write('<td style="font-weight: bold; color: #475569;">Primer Lot:</td>');
      primerRows.write('<td>${r0 != null && r0.primerLot.isNotEmpty ? r0.primerLot : (r0?.lotNo ?? '')}</td>');
      primerRows.write('<td style="font-weight: bold; color: #475569;">Primer Supplier:</td>');
      primerRows.write('<td>${r0?.primerSupplier ?? ''}</td>');
      primerRows.write('</tr>');
      primerRows.write('<tr>');
      primerRows.write('<td style="font-weight: bold; color: #475569;">Avg Insertion Depth:</td>');
      primerRows.write('<td colspan="3">${r0 != null && r0.primerInsertionDepth.isNotEmpty ? '${r0.primerInsertionDepth} mm' : ''}</td>');
      primerRows.write('</tr>');
    }

    final propellantRows = StringBuffer();
    if (testName == 'Propellant Test') {
      final r0 = records.isNotEmpty ? records[0] : null;
      propellantRows.write('<tr>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Propellant Lot:</td>');
      propellantRows.write('<td>${r0 != null && r0.propellantLot.isNotEmpty ? r0.propellantLot : (r0?.lotNo ?? '')}</td>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Propellant Supplier:</td>');
      propellantRows.write('<td>${r0?.propellantSupplier ?? ''}</td>');
      propellantRows.write('</tr>');
      propellantRows.write('<tr>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Propellant Code:</td>');
      propellantRows.write('<td>${r0?.propellantCode ?? ''}</td>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      propellantRows.write('<td>${r0?.barrelSN ?? ''}</td>');
      propellantRows.write('</tr>');
    }

    final buffer = StringBuffer();
    buffer.writeln('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <style>
    html, body {
      height: 100%;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1e293b;
      background-color: #ffffff;
    }
    .report-wrapper {
      display: flex;
      flex-direction: column;
      min-height: 100vh;
      box-sizing: border-box;
      padding: 10px 16px;
    }
    .report-content {
      flex: 1 0 auto;
    }
    .report-footer {
      margin-top: auto;
      padding-top: 14px;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 8px;
      border-bottom: 2.5px solid #06b6d4;
      padding-bottom: 6px;
    }
    .header-table td {
      border: none !important;
      background: none !important;
      padding: 0 !important;
    }
    .title-section {
      text-align: center;
      margin-top: 3px;
      margin-bottom: 8px;
    }
    .title-section h2 {
      margin: 0;
      font-size: 15px;
      font-weight: 700;
      color: #0f172a;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .title-line {
      height: 2px;
      width: 100%;
      background-color: #06b6d4;
      margin-top: 3px;
    }
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 8px;
      margin-bottom: 10px;
    }
    .summary-card {
      background-color: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 6px 10px;
    }
    .summary-card .label {
      font-size: 9px;
      font-weight: 700;
      color: #64748b;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .summary-card .val {
      font-size: 15px;
      font-weight: 700;
      color: #0f172a;
      margin-top: 1px;
    }
    .section-title {
      font-size: 11.5px;
      font-weight: 700;
      color: #0f172a;
      border-bottom: 1.5px solid #cbd5e1;
      padding-bottom: 3px;
      margin-top: 8px;
      margin-bottom: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .details-table {
      width: 100%;
      margin-bottom: 8px;
    }
    .details-table td {
      padding: 2.5px 6px;
      font-size: 10.5px;
      border: none !important;
      background: none !important;
    }
    table.data-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 8px;
    }
    table.data-table th {
      background-color: #f1f5f9;
      color: #475569;
      text-align: left;
      font-size: 10px;
      font-weight: 700;
      padding: 4px 6px;
      border-bottom: 1.5px solid #cbd5e1;
      text-transform: uppercase;
    }
    table.data-table td {
      padding: 4px 6px;
      font-size: 10px;
      border-bottom: 1px solid #e2e8f0;
      color: #334155;
    }
    tr:nth-child(even) td {
      background-color: #f8fafc;
    }
    .badge {
      padding: 2px 5px;
      border-radius: 4px;
      font-size: 8.5px;
      font-weight: bold;
      display: inline-block;
      text-transform: uppercase;
    }
    .badge-approved { background-color: #dcfce7; color: #15803d; }
    .badge-retest { background-color: #fef3c7; color: #b45309; }
    .badge-rejected { background-color: #fee2e2; color: #b91c1c; }
    .badge-pending { background-color: #fef3c7; color: #b45309; }
    .badge-approved-with-condition { background-color: #e0f2fe; color: #0369a1; border: 1px solid #7dd3fc; }
    
    .sentence-box {
      padding: 6px 10px;
      border: 1px solid #cbd5e1;
      border-radius: 5px;
      background-color: #f8fafc;
      font-size: 10.5px;
      font-weight: bold;
      line-height: 1.35;
      color: #1e293b;
      white-space: pre-wrap;
    }
    .signatures {
      margin-top: 16px;
      display: flex;
      justify-content: space-between;
    }
    .sig-box {
      width: 40%;
      border-top: 1px solid #cbd5e1;
      text-align: center;
      padding-top: 4px;
      font-size: 10.5px;
      color: #475569;
    }
    @media print {
      @page { margin: 6mm 8mm; size: A4 portrait; }
      body { margin: 0; padding: 0; }
      .no-print { display: none; }
      .report-wrapper {
        min-height: calc(297mm - 14mm);
        padding: 0;
      }
      .report-footer {
        margin-top: auto;
        page-break-inside: avoid;
      }
      .summary-card, .data-table, .sentence-box, .signatures { page-break-inside: avoid; }
    }
  </style>
</head>
<body>
  <div class="report-wrapper">
    <div class="report-content">
      <!-- Header Text & Logo Section -->
  <table class="header-table">
    <tr>
      <td style="width: 70%; text-align: left; vertical-align: middle;">
        <div style="font-size: 16px; font-weight: bold; color: #0f172a; font-family: Arial, sans-serif;">Oman Munition Production Company</div>
        <div style="font-size: 12px; font-weight: bold; color: #475569; margin-top: 2px;">QC And Engineering Department</div>
        <div style="font-size: 11px; color: #64748b; margin-top: 1px;">Ballistic Lab Section</div>
        <div style="font-size: 11px; font-style: italic; color: #64748b; margin-top: 1px; margin-bottom: 15px;">
          ${moduleName == 'Daily Test' ? 'Ballistic Daily Test Report' : 'Lot Acceptance Test Report'}
        </div>
      </td>
      <td style="width: 30%; text-align: right; vertical-align: middle;">
        $logoHtml
      </td>
    </tr>
  </table>

  <!-- Title section with horizontal line -->
  <div class="title-section">
    <h2>${testName == 'All' ? 'Combined Tests' : testName}</h2>
    <div class="title-line"></div>
  </div>

  <!-- Details -->
  <div>
    <h3 class="section-title">Details</h3>
    <table class="details-table">
      <tr>
        <td style="width: 25%; font-weight: bold; color: #475569;">Inspector Name:</td>
        <td>$inspectorName</td>
        <td style="width: 25%; font-weight: bold; color: #475569;">Date:</td>
        <td>$now</td>
      </tr>
      <tr>
        <td style="font-weight: bold; color: #475569;">Caliber Specification:</td>
        <td>$caliber</td>
        <td style="font-weight: bold; color: #475569;">${moduleName == 'Daily Test' ? 'Hopper No. / Production Date:' : 'Lot Number:'}</td>
        <td>$lotNo</td>
      </tr>
      <tr>
        <td style="font-weight: bold; color: #475569;">Quantity Tested:</td>
        <td>$totalQty rounds</td>
        <td style="font-weight: bold; color: #475569;">Test Result:</td>
        <td style="font-weight: bold; color: ${getStatusColor(batchResult)};">$batchResult</td>
      </tr>
      ${testName == 'Waterproof Test' ? waterproofRows.toString() : ''}
      ${testName == 'Residual Stress Test' ? residualStressRows.toString() : ''}
      ${testName == 'Accuracy Test' ? accuracyRows.toString() : ''}
      ${testName == 'EPVAT test' || testName == 'Propellant Test' ? epvatRows.toString() : ''}
      ${testName == 'Function Test' ? functionRows.toString() : ''}
      ${testName == 'Firing Rate Cycle Test' ? cyclicRows.toString() : ''}
      ${testName == 'Terminal Effect Test' ? terminalRows.toString() : ''}
      ${testName == 'Primer Sensitivity Test' ? primerRows.toString() : ''}
      ${testName == 'Propellant Test' ? propellantRows.toString() : ''}
    </table>
  </div>

  <!-- Results -->
  <div>
    <h3 class="section-title">Parameters/Results</h3>
    <table class="data-table">
      <thead>
        <tr>
''');

    if (testName == 'Waterproof Test') {
      buffer.writeln('''
        <th>Mouth Leaks (Slow/Fast)</th>
        <th>Primer Leaks (Slow/Fast)</th>
      ''');
    } else if (testName == 'Residual Stress Test') {
      buffer.writeln('''
        <th>Neck Splits (Min/Maj)</th>
        <th>Shoulder Splits (Min/Maj)</th>
        <th>Body Splits (Min/Maj)</th>
        <th>Head Splits (Min/Maj)</th>
        <th>Total Splits</th>
      ''');
    } else if (testName == 'Accuracy Test' || testName == 'Extraction Force Test') {
      buffer.writeln('''
        <th>Coordinate / Parameter</th>
        <th>Mean</th>
        <th>Max</th>
        <th>Min</th>
        <th>Range</th>
        <th>SD</th>
      ''');
    } else if (testName == 'EPVAT test' || testName == 'Propellant Test') {
      final bool is9mm = records.isNotEmpty && (records[0].caliber.toLowerCase().contains('9mm') || records[0].caliber.toLowerCase().startsWith('9x19'));
      final pUnit = records.isNotEmpty && records[0].epvatPressureUnit.isNotEmpty ? records[0].epvatPressureUnit : 'Bar';
      buffer.writeln('''
        <th>Parameter</th>
        <th>P1 Chamber ($pUnit)</th>
        ${!is9mm ? '<th>P2 Port pressure ($pUnit)</th>' : ''}
        <th>Action Time (ms)</th>
        <th>Velocity (m/s)</th>
      ''');
    } else if (testName == 'Primer Sensitivity Test') {
      buffer.writeln('''
        <th>SD (Standard Deviation)</th>
        <th>All Fire Height (H̄ + 5S)</th>
        <th>No Fire Height (H̄ - 2S)</th>
        <th>Remarks</th>
      ''');
    } else if (testName == 'Firing Rate Cycle Test') {
      buffer.writeln('''
        <th>Weapon Model</th>
        <th>Category</th>
        <th>Min RPM</th>
        <th>Max RPM</th>
        <th>Measured RPM</th>
      ''');
    } else if (testName == 'Terminal Effect Test') {
      buffer.writeln('''
        <th colspan="6">Terminal Effect Test Metrics</th>
      ''');
    } else if (testName == 'Function Test') {
      buffer.writeln('''
        <th>Tested Qty</th>
        <th>Level 1 (Critical)</th>
        <th>Level 2 (Major)</th>
        <th>Level 3 (Minor)</th>
        <th>Level 4</th>
        <th>Total Defects</th>
      ''');
    } else {
      buffer.writeln('''
        <th>Test Name</th>
        <th>Time</th>
        <th>Inspector</th>
        <th>Sample Size</th>
        <th>Key Results / Metrics</th>
        <th>Status</th>
        <th>Remarks</th>
      ''');
    }

    buffer.writeln('''
        </tr>
      </thead>
      <tbody>
    ''');

    for (var r in records) {
      if (testName == 'Waterproof Test') {
        buffer.writeln('<tr>');
        buffer.writeln('<td>S: ${r.mouthSlow} | F: ${r.mouthFast}</td>');
        buffer.writeln('<td>S: ${r.primerSlow} | F: ${r.primerFast}</td>');
        buffer.writeln('</tr>');
      } else if (testName == 'Residual Stress Test') {
        final total = r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast;
        buffer.writeln('<tr>');
        buffer.writeln('<td>Min: ${r.neckSlow} | Maj: ${r.neckFast}</td>');
        buffer.writeln('<td>Min: ${r.shoulderSlow} | Maj: ${r.shoulderFast}</td>');
        buffer.writeln('<td>Min: ${r.bodySlow} | Maj: ${r.bodyFast}</td>');
        buffer.writeln('<td>Min: ${r.headSlow} | Maj: ${r.headFast}</td>');
        buffer.writeln('<td style="font-weight: bold;">$total</td>');
        buffer.writeln('</tr>');
      } else if (testName == 'Accuracy Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        if (r.caliber == '5.56x45 M193') {
          buffer.writeln('''
            <tr>
              <td style="font-weight: bold;">SD at X (mm)</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDX, r.caliber)};">${r.accSDX}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">SD at Y (mm)</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDY, r.caliber)};">${r.accSDY}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Mean Radius (mm)</td>
              <td style="font-weight: bold; color: ${getMeanRadiusColor(r.accMeanRadius)};">${r.accMeanRadius}</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Velocity (m/s)</td>
              <td>${r.velMean}</td>
              <td>${r.velMax}</td>
              <td>${r.velMin}</td>
              <td>${r.velRange}</td>
              <td>${r.velSD}</td>
            </tr>
          ''');
        } else {
          buffer.writeln('''
            <tr>
              <td style="font-weight: bold;">X-Coordinate Deviation (mm)</td>
              <td>${r.accMeanX}</td>
              <td>${r.accMaxX}</td>
              <td>${r.accMinX}</td>
              <td>${r.accRangeX}</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDX, r.caliber)};">${r.accSDX}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Y-Coordinate Deviation (mm)</td>
              <td>${r.accMeanY}</td>
              <td>${r.accMaxY}</td>
              <td>${r.accMinY}</td>
              <td>${r.accRangeY}</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDY, r.caliber)};">${r.accSDY}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Velocity (m/s)</td>
              <td>${r.velMean}</td>
              <td>${r.velMax}</td>
              <td>${r.velMin}</td>
              <td>${r.velRange}</td>
              <td>${r.velSD}</td>
            </tr>
            ${(double.tryParse(r.accLargestDistance) ?? 0) > 0 ? '''
            <tr>
              <td style="font-weight: bold;">Largest Distance (mm)</td>
              <td colspan="5" style="font-weight: bold; color: #0284c7;">${r.accLargestDistance} mm</td>
            </tr>''' : ''}
          ''');
        }
      } else if (testName == 'Extraction Force Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        if (r.extractionForceType == 'Individual' && r.extractionForceRounds.isNotEmpty) {
          final roundsList = r.extractionForceRounds.split(',');
          final roundsHtml = roundsList.asMap().entries.map((e) => '<div style="display:inline-block; width:18%; margin: 4px; border:1px solid #e2e8f0; padding:4px; text-align:center;">Round ${e.key + 1}: <strong>${e.value} N</strong></div>').join('');
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f8fafc;">Individual Round Results</td></tr>');
          buffer.writeln('<tr><td colspan="6" style="padding: 10px;">$roundsHtml</td></tr>');
        }
        final double limit = getMinForceLimit(r.caliber);
        final bool isLow = double.tryParse(r.accMinX) != null && double.parse(r.accMinX) < limit;
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">Extraction Force (Newtons)</td>
            <td>${r.accMeanX}</td>
            <td>${r.accMaxX}</td>
            <td style="font-weight: bold; color: ${isLow ? '#ef4444' : '#1e293b'};">${r.accMinX}</td>
            <td>${r.accRangeX}</td>
            <td>${r.accSDX}</td>
          </tr>
        ''');
      } else if (testName == 'EPVAT test' || testName == 'Propellant Test') {
        final bool is9mm = r.caliber.toLowerCase().contains('9mm') || r.caliber.toLowerCase().startsWith('9x19');
        // Side parameters: Mean, Max, Min, Range, SD
        final p1Mean = r.epvatMeanPressure.trim().isNotEmpty ? r.epvatMeanPressure : '-';
        final p1Max = r.epvatMaxPressure.trim().isNotEmpty ? r.epvatMaxPressure : '-';
        final p1Min = r.epvatMinPressure.trim().isNotEmpty ? r.epvatMinPressure : '-';
        final p1Range = r.epvatRangePressure.trim().isNotEmpty ? r.epvatRangePressure : '-';
        final p1SD = r.epvatSDPressure.trim().isNotEmpty ? r.epvatSDPressure : '-';

        final p2Mean = r.epvatP2MeanPressure.trim().isNotEmpty ? r.epvatP2MeanPressure : '-';
        final p2Max = r.epvatP2MaxPressure.trim().isNotEmpty ? r.epvatP2MaxPressure : '-';
        final p2Min = r.epvatP2MinPressure.trim().isNotEmpty ? r.epvatP2MinPressure : '-';
        final p2Range = r.epvatP2RangePressure.trim().isNotEmpty ? r.epvatP2RangePressure : '-';
        final p2SD = r.epvatP2SDPressure.trim().isNotEmpty ? r.epvatP2SDPressure : '-';

        final atMean = r.actionTimeMean.trim().isNotEmpty ? r.actionTimeMean : '-';
        final atMax = r.actionTimeMax.trim().isNotEmpty ? r.actionTimeMax : '-';
        final atMin = r.actionTimeMin.trim().isNotEmpty ? r.actionTimeMin : '-';
        final atRange = r.actionTimeRange.trim().isNotEmpty ? r.actionTimeRange : '-';
        final atSD = r.actionTimeSD.trim().isNotEmpty ? r.actionTimeSD : '-';

        final vMean = r.velMean.trim().isNotEmpty ? r.velMean : '-';
        final vMax = r.velMax.trim().isNotEmpty ? r.velMax : '-';
        final vMin = r.velMin.trim().isNotEmpty ? r.velMin : '-';
        final vRange = r.velRange.trim().isNotEmpty ? r.velRange : '-';
        final vSD = r.velSD.trim().isNotEmpty ? r.velSD : '-';

        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">Mean</td>
            <td>$p1Mean</td>
            ${!is9mm ? '<td>$p2Mean</td>' : ''}
            <td>$atMean</td>
            <td>$vMean</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Max</td>
            <td>$p1Max</td>
            ${!is9mm ? '<td>$p2Max</td>' : ''}
            <td>$atMax</td>
            <td>$vMax</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Min</td>
            <td>$p1Min</td>
            ${!is9mm ? '<td>$p2Min</td>' : ''}
            <td>$atMin</td>
            <td>$vMin</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Range</td>
            <td>$p1Range</td>
            ${!is9mm ? '<td>$p2Range</td>' : ''}
            <td>$atRange</td>
            <td>$vRange</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">SD</td>
            <td>$p1SD</td>
            ${!is9mm ? '<td>$p2SD</td>' : ''}
            <td>$atSD</td>
            <td>$vSD</td>
          </tr>
        ''');
      } else if (testName == 'Firing Rate Cycle Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="5" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        final rpmMaxStr = (r.cyclicRateMax == 'null' || r.cyclicRateMax.isEmpty) ? 'No Limit' : r.cyclicRateMax;
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">${r.cyclicRateWeaponType}</td>
            <td>${r.cyclicRateAmmoType}</td>
            <td>${r.cyclicRateMin}</td>
            <td>$rpmMaxStr</td>
            <td style="font-weight: bold;">${r.cyclicRateValue} RPM</td>
          </tr>
        ''');
      } else if (testName == 'Terminal Effect Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        final holeList = r.terminalHoleDiameter.split(',');
        final steelList = r.terminalSteelPenetration.split(',');
        final alumList = r.terminalAluminumPenetration.split(',');
        final velList = r.terminalVelocity.split(',');
        
        final bufferRounds = StringBuffer();
        bufferRounds.write('<table style="width: 100%; border-collapse: collapse; border: 1px solid #cbd5e1; font-size: 11px;">');
        bufferRounds.write('<tr style="background-color: #f1f5f9; text-align: left;">');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Round No.</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Hole > Bullet Dia.</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Steel Penetration</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Aluminum Penetration</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Velocity (m/s)</th>');
        bufferRounds.write('</tr>');
        
        final count = r.produced;
        for (int idx = 0; idx < count; idx++) {
          final roundNo = idx + 1;
          final holeVal = idx < holeList.length ? holeList[idx] : 'Yes';
          final steelVal = idx < steelList.length ? steelList[idx] : 'Yes';
          final alumVal = idx < alumList.length ? alumList[idx] : 'Yes';
          final velVal = (idx < velList.length && velList[idx].trim().isNotEmpty) ? velList[idx] : '-';
          
          final colorHole = holeVal == 'No' ? '#b91c1c' : '#15803d';
          final colorSteel = steelVal == 'No' ? '#b91c1c' : '#15803d';
          final colorAlum = alumVal == 'No' ? '#b91c1c' : '#15803d';
          
          bufferRounds.write('<tr>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">Round $roundNo</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px; font-weight: bold; color: $colorHole;">$holeVal</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px; font-weight: bold; color: $colorSteel;">$steelVal</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px; font-weight: bold; color: $colorAlum;">$alumVal</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$velVal</td>');
          bufferRounds.write('</tr>');
        }
        bufferRounds.write('</table>');
        buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f8fafc;">Round-by-Round Penetration & Velocity Details</td></tr>');
        buffer.writeln('<tr><td colspan="6" style="padding: 10px;">$bufferRounds</td></tr>');
      } else if (testName == 'Function Test') {
// Function Test record banner removed
        final l1Color = r.functionLevel1 > 0 ? '#b91c1c' : '#15803d';
        final l2Color = r.functionLevel2 > 0 ? '#b91c1c' : '#15803d';
        final l3Color = r.functionLevel3 > 2 ? '#b45309' : '#15803d';
        final l4Color = r.functionLevel4 > 5 ? '#b45309' : '#15803d';
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">${r.produced} rounds</td>
            <td style="font-weight: bold; color: $l1Color;">${r.functionLevel1}</td>
            <td style="font-weight: bold; color: $l2Color;">${r.functionLevel2}</td>
            <td style="font-weight: bold; color: $l3Color;">${r.functionLevel3}</td>
            <td style="font-weight: bold; color: $l4Color;">${r.functionLevel4}</td>
            <td style="font-weight: bold;">${r.defects}</td>
          </tr>
        ''');
        if (r.functionDefectDetails.isNotEmpty) {
          buffer.writeln('''
            <tr>
              <td colspan="6" style="padding: 6px 10px; font-size: 10px; color: #334155; background-color: #f1f5f9; border-bottom: 1px solid #cbd5e1;">
                <strong style="color: #0f172a;">Specific Defects Recorded:</strong> ${r.functionDefectDetails}
              </td>
            </tr>
          ''');
        }
      } else if (testName == 'Primer Sensitivity Test') {
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">${r.primerSD.isNotEmpty ? '${r.primerSD} cm' : '-'}</td>
            <td>${r.primerAllFireH.isNotEmpty ? '${r.primerAllFireH} cm' : '-'}</td>
            <td>${r.primerNoFireH.isNotEmpty ? '${r.primerNoFireH} cm' : '-'}</td>
            <td>${cleanRemarks(r.notes).isNotEmpty ? cleanRemarks(r.notes) : '-'}</td>
          </tr>
        ''');
      } else {
        final metrics = _getRecordMetricsSummary(r);
        final badgeClass = 'badge-${r.status.toLowerCase().replaceAll(' ', '-')}';
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold; color: #0284c7;">${r.testName}</td>
            <td>${r.timestamp}</td>
            <td>${r.operators}</td>
            <td>${r.produced} rounds</td>
            <td>$metrics</td>
            <td><span class="badge $badgeClass">${r.status}</span></td>
            <td>${r.notes}</td>
          </tr>
        ''');
      }
    }

    buffer.writeln('''
      </tbody>
    </table>
  </div>

  $epvatCombinedSection
  ${_buildRetestSectionHtml(records, testName, isWord: false)}
    </div> <!-- end report-content -->

    <div class="report-footer">
      $remarksAndDiagramSection

      <!-- Recommendation -->
      <div>
        <h3 class="section-title">Recommendation</h3>
        <div class="sentence-box">
          $sentenceRequirement
        </div>
      </div>

      $attachmentsSection

      <div class="signatures">
        <div class="sig-box">Ballistic Inspector Signature</div>
        <div class="sig-box">Ballistic Technician Approval</div>
      </div>
    </div> <!-- end report-footer -->
  </div> <!-- end report-wrapper -->
</body>
</html>
''');

    return buffer.toString();
  }

  static String _buildRetestSectionHtml(List<BallisticRecord> records, String testName, {required bool isWord}) {
    final retestRecords = records.where((r) => r.isRetest).toList();
    if (retestRecords.isEmpty) return '';

    final buffer = StringBuffer();
    final headingTag = isWord ? 'h2' : 'h3';
    buffer.writeln('''
      <div style="margin-top: 18px; margin-bottom: 12px; page-break-inside: avoid;">
        <$headingTag class="section-title" style="color: #b45309; border-left: 4px solid #f59e0b; padding-left: 8px;">Retest Verification Inspection Results</$headingTag>
        <table class="data-table" border="1" style="width: 100%; border-collapse: collapse; margin-top: 6px; font-size: 11px;">
          <thead>
            <tr style="background-color: #fef3c7; color: #92400e;">
    ''');

    if (testName == 'Waterproof Test') {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Mouth Leaks (S/F)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Primer Leaks (S/F)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Total Leaks</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Date & Time</th>
      ''');
    } else if (testName == 'Residual Stress Test') {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Neck Splits</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Shoulder Splits</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Body Splits</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Head Splits</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Total Splits</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
      ''');
    } else if (testName == 'Accuracy Test') {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Mean Radius (MR)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">SD X</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">SD Y</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Extreme Spread</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Mean Velocity</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
      ''');
    } else if (testName == 'EPVAT test' || testName == 'Propellant Test') {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Chamber P1 Mean</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Max P1</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Port P2 Mean</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Mean Velocity</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Action Time</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
      ''');
    } else if (testName == 'Function Test') {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">L1 (Critical)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">L2 (Major)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">L3 (Minor)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Level 4</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Total Defects</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
      ''');
    } else if (testName == 'Primer Sensitivity Test') {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Mean Height H̄</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">SD (S)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">All-Fire Height</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">No-Fire Height</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
      ''');
    } else if (testName == 'Extraction Force Test') {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Force Type</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Min Force (N)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Max Force (N)</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
      ''');
    } else {
      buffer.writeln('''
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Sample Qty</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Defects Found</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Disposition</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Retest Inspector</th>
        <th style="border: 1px solid #cbd5e1; padding: 5px 6px;">Date & Time</th>
      ''');
    }

    buffer.writeln('''
            </tr>
          </thead>
          <tbody>
    ''');

    for (final r in retestRecords) {
      final m = r.parsedRetestMetrics;
      final retestQty = r.retestProduced > 0 ? r.retestProduced : r.produced;
      final outcome = r.retestStatus.isNotEmpty ? r.retestStatus : r.status;
      final outcomeCol = getStatusColor(outcome);
      final badgeStyle = isWord
          ? 'font-weight: bold; color: $outcomeCol;'
          : 'background-color: ${outcomeCol}15; color: $outcomeCol; border: 1px solid $outcomeCol; padding: 2px 8px; border-radius: 4px; font-weight: bold;';

      if (testName == 'Waterproof Test') {
        final ms = m['mouthSlow'] ?? 0;
        final mf = m['mouthFast'] ?? 0;
        final ps = m['primerSlow'] ?? 0;
        final pf = m['primerFast'] ?? 0;
        final tot = ms + mf + ps + pf;
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">S: $ms | F: $mf</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">S: $ps | F: $pf</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold; color: ${tot > 0 ? '#b91c1c' : '#15803d'};">$tot</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestTimestamp.isNotEmpty ? r.retestTimestamp : r.timestamp}</td>
          </tr>
        ''');
      } else if (testName == 'Residual Stress Test') {
        final ns = (m['neckSlow'] ?? 0) + (m['neckFast'] ?? 0);
        final ss = (m['shoulderSlow'] ?? 0) + (m['shoulderFast'] ?? 0);
        final bs = (m['bodySlow'] ?? 0) + (m['bodyFast'] ?? 0);
        final hs = (m['headSlow'] ?? 0) + (m['headFast'] ?? 0);
        final tot = ns + ss + bs + hs;
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$ns</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$ss</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$bs</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$hs</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold; color: ${tot > 0 ? '#b91c1c' : '#15803d'};">$tot</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
          </tr>
        ''');
      } else if (testName == 'Accuracy Test') {
        final mr = m['accMeanRadius'] ?? '-';
        final sdx = m['accSDX'] ?? '-';
        final sdy = m['accSDY'] ?? '-';
        final maxD = m['accLargestDistance'] ?? '-';
        final vm = m['velMean'] ?? '-';
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$mr mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$sdx mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$sdy mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$maxD mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$vm m/s</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
          </tr>
        ''');
      } else if (testName == 'EPVAT test' || testName == 'Propellant Test') {
        final pUnit = r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'bar';
        final p1 = m['epvatMeanPressure'] ?? '-';
        final p1Max = m['epvatMaxPressure'] ?? '-';
        final p2 = m['epvatP2MeanPressure'] ?? '-';
        final vm = m['velMean'] ?? '-';
        final at = m['actionTimeMean'] ?? '-';
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$p1 $pUnit</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$p1Max $pUnit</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$p2 $pUnit</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$vm m/s</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$at ms</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
          </tr>
        ''');
      } else if (testName == 'Function Test') {
        final l1 = m['functionLevel1'] ?? 0;
        final l2 = m['functionLevel2'] ?? 0;
        final l3 = m['functionLevel3'] ?? 0;
        final l4 = m['functionLevel4'] ?? 0;
        final tot = r.retestDefects;
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold; color: ${l1 > 0 ? '#b91c1c' : '#15803d'};">$l1</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold; color: ${l2 > 0 ? '#b91c1c' : '#15803d'};">$l2</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold; color: ${l3 > 2 ? '#b45309' : '#15803d'};">$l3</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold; color: ${l4 > 5 ? '#b45309' : '#15803d'};">$l4</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold; color: ${tot > 0 ? '#b91c1c' : '#15803d'};">$tot</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
          </tr>
        ''');
      } else if (testName == 'Primer Sensitivity Test') {
        final hbar = m['primerHbar'] ?? '-';
        final sd = m['primerSD'] ?? '-';
        final af = m['primerAllFireH'] ?? '-';
        final nf = m['primerNoFireH'] ?? '-';
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$hbar mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$sd mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$af mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$nf mm</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
          </tr>
        ''');
      } else if (testName == 'Extraction Force Test') {
        final mode = m['extractionForceType'] ?? (r.extractionForceType.isNotEmpty ? r.extractionForceType : 'Bullet');
        final minF = m['accMinX'] ?? '-';
        final maxF = m['accMaxX'] ?? '-';
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$mode</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$minF N</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">$maxF N</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
          </tr>
        ''');
      } else {
        buffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">$retestQty rounds</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px; font-weight: bold;">${r.retestDefects}</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;"><span style="$badgeStyle">$outcome</span></td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestOperator.isNotEmpty ? r.retestOperator : r.operators}</td>
            <td style="border: 1px solid #cbd5e1; padding: 5px 6px;">${r.retestTimestamp.isNotEmpty ? r.retestTimestamp : r.timestamp}</td>
          </tr>
        ''');
      }

      if (r.retestNotes.isNotEmpty) {
        buffer.writeln('''
          <tr>
            <td colspan="8" style="padding: 6px 10px; font-size: 11px; background-color: #fffbeb; color: #92400e; border: 1px solid #fde68a;">
              <strong>Retest Notes:</strong> ${r.retestNotes}
            </td>
          </tr>
        ''');
      }
    }

    buffer.writeln('''
          </tbody>
        </table>
      </div>
    ''');
    return buffer.toString();
  }

  static String _buildWordTableHeader(String testName, [List<BallisticRecord> records = const []]) {
    if (testName == 'Waterproof Test') {
      return '<th>Mouth Leaks (S/F)</th><th>Primer Leaks (S/F)</th>';
    } else if (testName == 'Residual Stress Test') {
      return '<th>Neck Splits (Min/Maj)</th><th>Shoulder Splits (Min/Maj)</th><th>Body Splits (Min/Maj)</th><th>Head Splits (Min/Maj)</th><th>Total Splits</th>';
    } else if (testName == 'Accuracy Test' || testName == 'Extraction Force Test') {
      return '<th>Coordinate / Parameter</th><th>Mean</th><th>Max</th><th>Min</th><th>Range</th><th>SD</th>';
    } else if (testName == 'EPVAT test' || testName == 'Propellant Test') {
      final bool is9mm = records.isNotEmpty && (records[0].caliber.toLowerCase().contains('9mm') || records[0].caliber.toLowerCase().startsWith('9x19'));
      final pUnit = records.isNotEmpty && records[0].epvatPressureUnit.isNotEmpty ? records[0].epvatPressureUnit : 'Bar';
      return '<th>Parameter</th><th>P1 Chamber ($pUnit)</th>${!is9mm ? '<th>P2 Port pressure ($pUnit)</th>' : ''}<th>Action Time (ms)</th><th>Velocity (m/s)</th>';
    } else if (testName == 'Primer Sensitivity Test') {
      return '<th>SD (Standard Deviation)</th><th>All Fire Height (H̄ + 5S)</th><th>No Fire Height (H̄ - 2S)</th><th>Remarks</th>';
    } else if (testName == 'Firing Rate Cycle Test') {
      return '<th>Weapon Model</th><th>Category</th><th>Min RPM</th><th>Max RPM</th><th>Measured RPM</th>';
    } else if (testName == 'Terminal Effect Test') {
      return '<th colspan="6">Terminal Effect Test Metrics</th>';
    } else if (testName == 'Function Test') {
      return '<th>Tested Qty</th><th>Level 1 (Critical)</th><th>Level 2 (Major)</th><th>Level 3 (Minor)</th><th>Level 4</th><th>Total Defects</th>';
    }
    return '<th>Test Name</th><th>Time</th><th>Inspector</th><th>Sample Size</th><th>Key Results / Metrics</th><th>Status</th><th>Remarks</th>';
  }

  static String generateWordHtml(List<BallisticRecord> records, String testName, String moduleName, {String base64Logo = '', Map<String, dynamic> adminRules = const {}}) {
    final now = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final totalQty = records.fold<int>(0, (sum, r) => sum + r.produced);
    final logoHtml = base64Logo.isNotEmpty 
        ? '<img src="data:image/png;base64,$base64Logo" width="140" height="85" style="object-fit: contain;" />' 
        : '';

    final remarksList = records
        .map((r) => cleanRemarks(r.notes))
        .where((n) => n.isNotEmpty && n.toLowerCase() != 'clear')
        .toSet()
        .toList();
    final remarksText = remarksList.isNotEmpty ? remarksList.join('<br/>') : '';

    final inspectorName = records.isNotEmpty ? records[0].operators : 'N/A';
    final caliber = records.isNotEmpty ? records[0].caliber : 'N/A';
    final lotNo = records.isNotEmpty
        ? (records[0].hopperNo.isEmpty && records[0].boxNo.isEmpty
            ? records[0].lotNo
            : '${records[0].lotNo} (Hopper: ${records[0].hopperNo}, Box: ${records[0].boxNo})')
        : 'N/A';

    String epvatCombinedSection = '';
    if (testName == 'EPVAT test' || testName == 'Propellant Test') {
      epvatCombinedSection = _buildEpvatCombinedSectionHtml(
        records: records,
        adminRules: adminRules,
        isWord: true,
      );
    }

    // Classification reference image tag (Residual Stress and Function Test) - Minimized 2x
    String classificationImageTag = '';
    final bool isCaliber9mm = caliber.toLowerCase().contains('9mm') || caliber.toLowerCase().startsWith('9x19');
    final String defaultImg = isCaliber9mm ? DefaultCartridgeAssets.cartridge9mmBase64 : DefaultCartridgeAssets.cartridgeBottleneckBase64;
    final String fallbackCartridgeImg = isCaliber9mm
        ? (adminRules['default_cartridge_9mm'] as String? ?? '').trim()
        : (adminRules['default_cartridge_bottleneck'] as String? ?? '').trim();

    if (testName == 'Residual Stress Test') {
      final rsImg = (adminRules['residual_stress']?['classification_image'] as String? ?? '').trim();
      final imgToUse = rsImg.isNotEmpty ? rsImg : (fallbackCartridgeImg.isNotEmpty ? fallbackCartridgeImg : defaultImg);
      final src = _formatImageSrc(imgToUse);
      final title = isCaliber9mm ? '9mm Residual Stress Reference Diagram' : '5.56 / 7.62 Residual Stress Reference Diagram';
      classificationImageTag = '''
        <div style="min-height: 210px; height: 210px; box-sizing: border-box; text-align: center; margin: 0; background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 6px;">
          <img src="$src" width="250" style="max-width: 100%; max-height: 175px; object-fit: contain; border-radius: 6px; border: 1px solid #cbd5e1;" alt="Residual Stress Reference" />
          <div style="font-size: 10px; color: #64748b; margin-top: 4px; font-style: italic;">$title</div>
        </div>
      ''';
    } else if (testName == 'Function Test') {
      final funcImg = (adminRules['function_test']?['classification_image'] as String? ?? '').trim();
      final imgToUse = funcImg.isNotEmpty ? funcImg : (fallbackCartridgeImg.isNotEmpty ? fallbackCartridgeImg : defaultImg);
      final src = _formatImageSrc(imgToUse);
      final title = isCaliber9mm ? '9mm Function Test Reference Diagram' : '5.56 / 7.62 Function Test Reference Diagram';
      classificationImageTag = '''
        <div style="min-height: 210px; height: 210px; box-sizing: border-box; text-align: center; margin: 0; background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 6px;">
          <img src="$src" width="250" style="max-width: 100%; max-height: 175px; object-fit: contain; border-radius: 6px; border: 1px solid #cbd5e1;" alt="Function Test Reference" />
          <div style="font-size: 10px; color: #64748b; margin-top: 4px; font-style: italic;">$title</div>
        </div>
      ''';
    }

    String remarksAndDiagramSection = '';
    if (classificationImageTag.isNotEmpty) {
      remarksAndDiagramSection = '''
      <div style="margin-top: 10px; margin-bottom: 10px;">
        <table style="width: 100%; border: none; border-collapse: collapse;">
          <tr>
            <td style="width: 50%; vertical-align: top; border: none; padding-right: 8px; padding-left: 0; padding-top: 0; padding-bottom: 0;">
              <h2 class="section-title" style="margin-top: 0; margin-bottom: 6px;">Remarks</h2>
              <div class="sentence-box" style="min-height: 210px; height: 210px; box-sizing: border-box;">
                $remarksText
              </div>
            </td>
            <td style="width: 50%; vertical-align: top; border: none; padding-left: 8px; padding-right: 0; padding-top: 0; padding-bottom: 0;">
              <h2 class="section-title" style="margin-top: 0; margin-bottom: 6px;">Defect Classification Reference Guide</h2>
              $classificationImageTag
            </td>
          </tr>
        </table>
      </div>
      ''';
    } else {
      remarksAndDiagramSection = '''
      <div>
        <h2 class="section-title">Remarks</h2>
        <div class="sentence-box" style="min-height: 40px;">
          $remarksText
        </div>
      </div>
      ''';
    }

    // Attachments & Evidence section for Word
    String attachmentsSection = '';
    final recordsWithAttachment = records.where((r) => r.attachmentBase64.isNotEmpty).toList();
    if (recordsWithAttachment.isNotEmpty) {
      final attachBuffer = StringBuffer();
      attachBuffer.writeln('''
      <div style="margin-top: 15px; margin-bottom: 15px;">
        <h2 class="section-title">Inspection Attachments & Documentation</h2>
        <table style="width: 100%; border-collapse: collapse; margin-top: 10px;">
      ''');
      for (var r in recordsWithAttachment) {
        final name = r.attachmentName.isNotEmpty ? r.attachmentName : 'Attachment';
        final isPdf = r.attachmentBase64.startsWith('data:application/pdf');
        final src = _formatImageSrc(r.attachmentBase64);
        attachBuffer.writeln('''
          <tr>
            <td style="border: 1px solid #cbd5e1; padding: 10px; background-color: #f8fafc; text-align: center; margin-bottom: 10px;">
              <p style="font-size: 11px; font-weight: bold; color: #1e293b; margin: 0 0 4px 0;">📎 $name</p>
              <p style="font-size: 9.5px; color: #64748b; margin: 0 0 8px 0;">Log Record: ${r.timestamp}</p>
        ''');
        if (isPdf) {
          attachBuffer.writeln('<p style="padding: 20px; background: #e2e8f0; font-weight: bold; color: #475569; font-size: 11px;">📄 Document / PDF Attached</p>');
        } else {
          attachBuffer.writeln('<img src="$src" width="400" style="max-width: 100%; height: auto;" alt="$name" />');
        }
        attachBuffer.writeln('</td></tr>');
      }
      attachBuffer.writeln('</table></div>');
      attachmentsSection = attachBuffer.toString();
    }

    String formatViscosity(String vStr) {
      final v = vStr.trim();
      if (v.isEmpty) return '';
      if (v.endsWith('s') || v.endsWith('sec') || v.endsWith('second') || v.endsWith('seconds')) {
        return v;
      }
      return '$v seconds';
    }

    final pressure = records.isNotEmpty ? (records[0].pressureBar.isEmpty ? '' : '${records[0].pressureBar} bar') : '';
    final viscosity = records.isNotEmpty ? formatViscosity(records[0].viscosity) : '';
    final samplingLocation = records.isNotEmpty ? records[0].samplingLocation : '';
    final batchResult = records.isNotEmpty ? records[0].status : 'N/A';

    final hasRejected = records.any((r) => r.status.toLowerCase() == 'rejected' || r.status.toLowerCase() == 'failed');
    final hasRetest = records.any((r) => r.status.toLowerCase() == 'retest');
    final hasPending = records.any((r) => r.status.toLowerCase() == 'pending review');
    final hasCondition = records.any((r) => r.status.toLowerCase().contains('condition'));

    String sentenceRequirement = '';
    if (records.isEmpty) {
      sentenceRequirement = 'No records available to evaluate sentence requirements.';
    } else if (hasRejected) {
      sentenceRequirement = 'The inspected lot fails to satisfy quality and ballistic specification criteria. The lot is officially REJECTED and quarantined.';
    } else if (hasRetest) {
      sentenceRequirement = 'Test results indicate marginal quality tolerances. The lot is sentenced to a mandatory RETEST under supervision.';
    } else if (hasPending) {
      sentenceRequirement = 'Evaluation in progress. The batch status remains PENDING REVIEW until supervisor verification is complete.';
    } else if (hasCondition) {
      sentenceRequirement = 'The inspected lot meets operational parameters with accepted variances. The lot is officially APPROVED WITH CONDITION.';
    } else {
      sentenceRequirement = 'The lot meets all quality and ballistic specifications and is approved for final packaging and shipment.';
    }

    final bool hideViscosity = moduleName == 'Lot Acceptance Test' && viscosity.trim().isEmpty;
    final bool hideLocation = moduleName == 'Lot Acceptance Test' && samplingLocation.trim().isEmpty;

    final waterproofRows = StringBuffer();
    if (testName == 'Waterproof Test') {
      waterproofRows.write('<tr>');
      waterproofRows.write('<td style="font-weight: bold; color: #475569;">Test Pressure:</td>');
      waterproofRows.write('<td>$pressure</td>');
      if (!hideViscosity) {
        waterproofRows.write('<td style="font-weight: bold; color: #475569;">Viscosity:</td>');
        waterproofRows.write('<td>$viscosity</td>');
      } else {
        waterproofRows.write('<td></td><td></td>');
      }
      waterproofRows.write('</tr>');

      if (!hideLocation) {
        waterproofRows.write('<tr>');
        waterproofRows.write('<td style="font-weight: bold; color: #475569;">Sampling Location:</td>');
        waterproofRows.write('<td>$samplingLocation</td>');
        waterproofRows.write('<td></td><td></td>');
        waterproofRows.write('</tr>');
      }
    }

    final residualStressRows = StringBuffer();
    if (testName == 'Residual Stress Test') {
      final roomTempStr = records.isNotEmpty && records[0].roomTemp.isNotEmpty ? '${records[0].roomTemp} &deg;C' : 'N/A';
      final locationStr = records.isNotEmpty && records[0].samplingLocation.isNotEmpty ? records[0].samplingLocation : 'N/A';
      residualStressRows.write('<tr>');
      residualStressRows.write('<td style="font-weight: bold; color: #475569;">Room Temperature:</td>');
      residualStressRows.write('<td>$roomTempStr</td>');
      residualStressRows.write('<td style="font-weight: bold; color: #475569;">Sampling Location:</td>');
      residualStressRows.write('<td>$locationStr</td>');
      residualStressRows.write('</tr>');
    }

    final accuracyRows = StringBuffer();
    if (testName == 'Accuracy Test') {
      accuracyRows.write('<tr>');
      accuracyRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      accuracyRows.write('<td>${records.isNotEmpty ? records[0].barrelSN : ''}</td>');
      accuracyRows.write('<td style="font-weight: bold; color: #475569;">Distance of Velocity:</td>');
      accuracyRows.write('<td>${records.isNotEmpty && records[0].velocityDistance.isNotEmpty ? '${records[0].velocityDistance} m' : ''}</td>');
      accuracyRows.write('</tr>');
    }

    final epvatRows = StringBuffer();
    if (testName == 'EPVAT test' || testName == 'Propellant Test') {
      epvatRows.write('<tr>');
      epvatRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      epvatRows.write('<td>${records.isNotEmpty ? records[0].barrelSN : ''}</td>');
      epvatRows.write('<td style="font-weight: bold; color: #475569;">Distance of Velocity:</td>');
      epvatRows.write('<td>${records.isNotEmpty && records[0].velocityDistance.isNotEmpty ? '${records[0].velocityDistance} m' : ''}</td>');
      epvatRows.write('</tr>');
      epvatRows.write('<tr>');
      epvatRows.write('<td style="font-weight: bold; color: #475569;">Cartridge Temp:</td>');
      epvatRows.write('<td>${records.isNotEmpty ? formatCartridgeTemp(records[0].cartridgeTemp) : ''}</td>');
      epvatRows.write('<td></td><td></td>');
      epvatRows.write('</tr>');
    }

    final functionRows = StringBuffer();
    if (testName == 'Function Test') {
      final allWeapons = records
          .map((r) => r.cyclicRateWeaponType.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .join('\n');
      final weaponName = allWeapons.isNotEmpty ? allWeapons : (records.isNotEmpty ? records[0].cyclicRateWeaponType : '');
      final rawTemp = records.isNotEmpty ? records[0].cartridgeTemp : '';
      functionRows.write('<tr>');
      functionRows.write('<td style="font-weight: bold; color: #475569; vertical-align: top;">Rifles / Weapons:</td>');
      functionRows.write('<td style="vertical-align: top;">${formatWeapons(weaponName)}</td>');
      functionRows.write('<td style="font-weight: bold; color: #475569; vertical-align: top;">Cartridge Temp:</td>');
      functionRows.write('<td style="white-space: nowrap; vertical-align: top;">${rawTemp.isNotEmpty ? formatCartridgeTemp(rawTemp) : '-'}</td>');
      functionRows.write('</tr>');
    }

    final cyclicRows = StringBuffer();
    if (testName == 'Firing Rate Cycle Test') {
      final wType = records.isNotEmpty ? records[0].cyclicRateWeaponType : '';
      final category = records.isNotEmpty ? records[0].cyclicRateAmmoType : '';
      final rateVal = records.isNotEmpty ? records[0].cyclicRateValue : '';
      final rpmMin = records.isNotEmpty ? records[0].cyclicRateMin : '';
      final rpmMax = records.isNotEmpty ? records[0].cyclicRateMax : '';
      final rpmMaxStr = (rpmMax == 'null' || rpmMax.isEmpty) ? 'No Limit' : '$rpmMax RPM';
      
      cyclicRows.write('<tr>');
      cyclicRows.write('<td style="font-weight: bold; color: #475569;">Weapon Model:</td>');
      cyclicRows.write('<td>$wType ($category)</td>');
      cyclicRows.write('<td style="font-weight: bold; color: #475569;">Allowed Limits:</td>');
      cyclicRows.write('<td>Min: $rpmMin RPM | Max: $rpmMaxStr</td>');
      cyclicRows.write('</tr>');
      cyclicRows.write('<tr>');
      cyclicRows.write('<td style="font-weight: bold; color: #475569;">Measured Rate:</td>');
      cyclicRows.write('<td style="font-weight: bold; color: #0f172a;">$rateVal RPM</td>');
      cyclicRows.write('<td></td><td></td>');
      cyclicRows.write('</tr>');
    }

    final terminalRows = StringBuffer();
    if (testName == 'Terminal Effect Test') {
      terminalRows.write('<tr>');
      terminalRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      terminalRows.write('<td>${records.isNotEmpty ? records[0].barrelSN : ''}</td>');
      terminalRows.write('<td style="font-weight: bold; color: #475569;">Distance:</td>');
      terminalRows.write('<td>${records.isNotEmpty && records[0].velocityDistance.isNotEmpty ? '${records[0].velocityDistance} m' : ''}</td>');
      terminalRows.write('</tr>');
    }

    final primerRows = StringBuffer();
    if (testName == 'Primer Sensitivity Test') {
      final r0 = records.isNotEmpty ? records[0] : null;
      primerRows.write('<tr>');
      primerRows.write('<td style="font-weight: bold; color: #475569;">Primer Lot:</td>');
      primerRows.write('<td>${r0 != null && r0.primerLot.isNotEmpty ? r0.primerLot : (r0?.lotNo ?? '')}</td>');
      primerRows.write('<td style="font-weight: bold; color: #475569;">Primer Supplier:</td>');
      primerRows.write('<td>${r0?.primerSupplier ?? ''}</td>');
      primerRows.write('</tr>');
      primerRows.write('<tr>');
      primerRows.write('<td style="font-weight: bold; color: #475569;">Avg Insertion Depth:</td>');
      primerRows.write('<td colspan="3">${r0 != null && r0.primerInsertionDepth.isNotEmpty ? '${r0.primerInsertionDepth} mm' : ''}</td>');
      primerRows.write('</tr>');
    }

    final propellantRows = StringBuffer();
    if (testName == 'Propellant Test') {
      final r0 = records.isNotEmpty ? records[0] : null;
      propellantRows.write('<tr>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Propellant Lot:</td>');
      propellantRows.write('<td>${r0 != null && r0.propellantLot.isNotEmpty ? r0.propellantLot : (r0?.lotNo ?? '')}</td>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Propellant Supplier:</td>');
      propellantRows.write('<td>${r0?.propellantSupplier ?? ''}</td>');
      propellantRows.write('</tr>');
      propellantRows.write('<tr>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Propellant Code:</td>');
      propellantRows.write('<td>${r0?.propellantCode ?? ''}</td>');
      propellantRows.write('<td style="font-weight: bold; color: #475569;">Barrel S.N:</td>');
      propellantRows.write('<td>${r0?.barrelSN ?? ''}</td>');
      propellantRows.write('</tr>');
    }

    final buffer = StringBuffer();
    buffer.writeln('''<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; color: #1e293b; margin: 0; padding: 20px; }
    .header-table {
      width: 100%;
      border-bottom: 2px solid #e2e8f0;
      margin-bottom: 25px;
      padding-bottom: 10px;
    }
    .header-table td {
      border: none !important;
      background: none !important;
      padding: 0 !important;
    }
    .title-section {
      text-align: center;
      margin-top: 5px;
      margin-bottom: 10px;
    }
    .title-section h2 {
      margin: 0;
      font-size: 16px;
      font-weight: bold;
      color: #0f172a;
      text-align: center;
      text-transform: uppercase;
    }
    .title-line {
      height: 2px;
      width: 100%;
      background-color: #06b6d4;
      margin-top: 4px;
    }
    .summary-table {
      width: 100%;
      margin-bottom: 12px;
    }
    .summary-card {
      background-color: #f8fafc;
      border: 1px solid #e2e8f0;
      padding: 8px 10px;
      text-align: center;
    }
    .summary-card .label {
      font-size: 9px;
      font-weight: bold;
      color: #64748b;
      text-transform: uppercase;
    }
    .summary-card .val {
      font-size: 14px;
      font-weight: bold;
      color: #0f172a;
      margin-top: 2px;
    }
    .section-title {
      font-size: 12px;
      font-weight: bold;
      color: #0f172a;
      border-bottom: 2px solid #cbd5e1;
      padding-bottom: 4px;
      margin-top: 14px;
      text-transform: uppercase;
    }
    table.details-table { width: 100%; margin-bottom: 12px; }
    table.details-table td { padding: 4px 8px; font-size: 11px; border: none !important; background: none !important; }
    table.data-table { width: 100%; border-collapse: collapse; margin-bottom: 15px; }
    table.data-table th { background-color: #f1f5f9; color: #475569; text-align: left; font-size: 10px; font-weight: bold; padding: 6px 8px; border-bottom: 2px solid #cbd5e1; }
    table.data-table td { padding: 6px 8px; font-size: 10px; border-bottom: 1px solid #e2e8f0; color: #334155; }
    .sentence-box { padding: 10px; border: 1px solid #cbd5e1; background-color: #f8fafc; font-size: 11px; font-weight: bold; color: #1e293b; white-space: pre-wrap; }
    .signatures { margin-top: 25px; width: 100%; }
    .signatures td { width: 50%; text-align: center; font-size: 11px; color: #475569; padding-top: 20px; border-top: 1px solid #cbd5e1; }
    @media print { @page { margin: 0; } body { margin: 12mm 15mm; -webkit-print-color-adjust: exact; } }
  </style>
</head>
<body>
  <table class="header-table">
    <tr>
      <td style="width: 70%; text-align: left; vertical-align: middle; padding-bottom: 15px;">
        <h2 style="margin: 0; font-size: 16px; color: #0f172a;">Oman Munition Production Company</h2>
        <p style="margin: 2px 0; font-size: 12px; font-weight: bold; color: #475569;">QC And Engineering Department</p>
        <p style="margin: 1px 0; font-size: 11px; color: #64748b;">Ballistic Lab Section</p>
        <p style="margin: 1px 0 15px 0; font-size: 11px; font-style: italic; color: #64748b;">
          ${moduleName == 'Daily Test' ? 'Ballistic Daily Test Report' : 'Lot Acceptance Test Report'}
        </p>
      </td>
      <td style="width: 30%; text-align: right; vertical-align: middle; padding-bottom: 15px;">
        $logoHtml
      </td>
    </tr>
  </table>

  <div class="title-section">
    <h2>${testName == 'All' ? 'Combined Tests' : testName}</h2>
    <div class="title-line"></div>
  </div>

  <h2 class="section-title">Details</h2>
  <table class="details-table">
    <tr>
      <td style="width: 25%; font-weight: bold; color: #475569;">Inspector Name:</td>
      <td>$inspectorName</td>
      <td style="width: 25%; font-weight: bold; color: #475569;">Date:</td>
      <td>$now</td>
    </tr>
    <tr>
      <td style="font-weight: bold; color: #475569;">Caliber Specification:</td>
      <td>$caliber</td>
      <td style="font-weight: bold; color: #475569;">${moduleName == 'Daily Test' ? 'Hopper No. / Production Date:' : 'Lot Number:'}</td>
      <td>$lotNo</td>
    </tr>
    <tr>
      <td style="font-weight: bold; color: #475569;">Quantity Tested:</td>
      <td>$totalQty rounds</td>
      <td style="font-weight: bold; color: #475569;">Test Result:</td>
      <td style="font-weight: bold; color: ${getStatusColor(batchResult)};">$batchResult</td>
    </tr>
    ${testName == 'Waterproof Test' ? waterproofRows.toString() : ''}
    ${testName == 'Residual Stress Test' ? residualStressRows.toString() : ''}
    ${testName == 'Accuracy Test' ? accuracyRows.toString() : ''}
    ${testName == 'EPVAT test' || testName == 'Propellant Test' ? epvatRows.toString() : ''}
    ${testName == 'Function Test' ? functionRows.toString() : ''}
    ${testName == 'Firing Rate Cycle Test' ? cyclicRows.toString() : ''}
    ${testName == 'Terminal Effect Test' ? terminalRows.toString() : ''}
    ${testName == 'Primer Sensitivity Test' ? primerRows.toString() : ''}
    ${testName == 'Propellant Test' ? propellantRows.toString() : ''}
  </table>

  <h2 class="section-title">Parameters/Results</h2>
  <table class="data-table">
    <thead>
      <tr>
        ${_buildWordTableHeader(testName, records)}
      </tr>
    </thead>
    <tbody>
''');

    for (var r in records) {
      if (testName == 'Waterproof Test') {
        buffer.writeln('<tr>');
        buffer.writeln('<td>S: ${r.mouthSlow} | F: ${r.mouthFast}</td>');
        buffer.writeln('<td>S: ${r.primerSlow} | F: ${r.primerFast}</td>');
        buffer.writeln('</tr>');
      } else if (testName == 'Residual Stress Test') {
        final total = r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast;
        buffer.writeln('<tr>');
        buffer.writeln('<td>Min: ${r.neckSlow} | Maj: ${r.neckFast}</td>');
        buffer.writeln('<td>Min: ${r.shoulderSlow} | Maj: ${r.shoulderFast}</td>');
        buffer.writeln('<td>Min: ${r.bodySlow} | Maj: ${r.bodyFast}</td>');
        buffer.writeln('<td>Min: ${r.headSlow} | Maj: ${r.headFast}</td>');
        buffer.writeln('<td style="font-weight: bold;">$total</td>');
        buffer.writeln('</tr>');
      } else if (testName == 'Accuracy Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        if (r.caliber == '5.56x45 M193') {
          buffer.writeln('''
            <tr>
              <td style="font-weight: bold;">SD at X (mm)</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDX, r.caliber)};">${r.accSDX}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">SD at Y (mm)</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDY, r.caliber)};">${r.accSDY}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Mean Radius (mm)</td>
              <td style="font-weight: bold; color: ${getMeanRadiusColor(r.accMeanRadius)};">${r.accMeanRadius}</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Velocity (m/s)</td>
              <td>${r.velMean}</td>
              <td>${r.velMax}</td>
              <td>${r.velMin}</td>
              <td>${r.velRange}</td>
              <td>${r.velSD}</td>
            </tr>
          ''');
        } else {
          buffer.writeln('''
            <tr>
              <td style="font-weight: bold;">X-Coordinate Deviation (mm)</td>
              <td>${r.accMeanX}</td>
              <td>${r.accMaxX}</td>
              <td>${r.accMinX}</td>
              <td>${r.accRangeX}</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDX, r.caliber)};">${r.accSDX}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Y-Coordinate Deviation (mm)</td>
              <td>${r.accMeanY}</td>
              <td>${r.accMaxY}</td>
              <td>${r.accMinY}</td>
              <td>${r.accRangeY}</td>
              <td style="font-weight: bold; color: ${getSdColor(r.accSDY, r.caliber)};">${r.accSDY}</td>
            </tr>
            <tr>
              <td style="font-weight: bold;">Velocity (m/s)</td>
              <td>${r.velMean}</td>
              <td>${r.velMax}</td>
              <td>${r.velMin}</td>
              <td>${r.velRange}</td>
              <td>${r.velSD}</td>
            </tr>
            ${(double.tryParse(r.accLargestDistance) ?? 0) > 0 ? '''
            <tr>
              <td style="font-weight: bold;">Largest Distance (mm)</td>
              <td colspan="5" style="font-weight: bold; color: #0284c7;">${r.accLargestDistance} mm</td>
            </tr>''' : ''}
          ''');
        }
      } else if (testName == 'Extraction Force Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        if (r.extractionForceType == 'Individual' && r.extractionForceRounds.isNotEmpty) {
          final roundsList = r.extractionForceRounds.split(',');
          final roundsHtml = roundsList.asMap().entries.map((e) => '<div style="display:inline-block; width:18%; margin: 4px; border:1px solid #e2e8f0; padding:4px; text-align:center;">Round ${e.key + 1}: <strong>${e.value} N</strong></div>').join('');
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f8fafc;">Individual Round Results</td></tr>');
          buffer.writeln('<tr><td colspan="6" style="padding: 10px;">$roundsHtml</td></tr>');
        }
        final double limit = getMinForceLimit(r.caliber);
        final bool isLow = double.tryParse(r.accMinX) != null && double.parse(r.accMinX) < limit;
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">Extraction Force (Newtons)</td>
            <td>${r.accMeanX}</td>
            <td>${r.accMaxX}</td>
            <td style="font-weight: bold; color: ${isLow ? '#ef4444' : '#1e293b'};">${r.accMinX}</td>
            <td>${r.accRangeX}</td>
            <td>${r.accSDX}</td>
          </tr>
        ''');
      } else if (testName == 'EPVAT test' || testName == 'Propellant Test') {
        final bool is9mm = r.caliber.toLowerCase().contains('9mm') || r.caliber.toLowerCase().startsWith('9x19');
        final p1Mean = r.epvatMeanPressure.trim().isNotEmpty ? r.epvatMeanPressure : '-';
        final p1Max = r.epvatMaxPressure.trim().isNotEmpty ? r.epvatMaxPressure : '-';
        final p1Min = r.epvatMinPressure.trim().isNotEmpty ? r.epvatMinPressure : '-';
        final p1Range = r.epvatRangePressure.trim().isNotEmpty ? r.epvatRangePressure : '-';
        final p1SD = r.epvatSDPressure.trim().isNotEmpty ? r.epvatSDPressure : '-';

        final p2Mean = r.epvatP2MeanPressure.trim().isNotEmpty ? r.epvatP2MeanPressure : '-';
        final p2Max = r.epvatP2MaxPressure.trim().isNotEmpty ? r.epvatP2MaxPressure : '-';
        final p2Min = r.epvatP2MinPressure.trim().isNotEmpty ? r.epvatP2MinPressure : '-';
        final p2Range = r.epvatP2RangePressure.trim().isNotEmpty ? r.epvatP2RangePressure : '-';
        final p2SD = r.epvatP2SDPressure.trim().isNotEmpty ? r.epvatP2SDPressure : '-';

        final atMean = r.actionTimeMean.trim().isNotEmpty ? r.actionTimeMean : '-';
        final atMax = r.actionTimeMax.trim().isNotEmpty ? r.actionTimeMax : '-';
        final atMin = r.actionTimeMin.trim().isNotEmpty ? r.actionTimeMin : '-';
        final atRange = r.actionTimeRange.trim().isNotEmpty ? r.actionTimeRange : '-';
        final atSD = r.actionTimeSD.trim().isNotEmpty ? r.actionTimeSD : '-';

        final vMean = r.velMean.trim().isNotEmpty ? r.velMean : '-';
        final vMax = r.velMax.trim().isNotEmpty ? r.velMax : '-';
        final vMin = r.velMin.trim().isNotEmpty ? r.velMin : '-';
        final vRange = r.velRange.trim().isNotEmpty ? r.velRange : '-';
        final vSD = r.velSD.trim().isNotEmpty ? r.velSD : '-';

        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">Mean</td>
            <td>$p1Mean</td>
            ${!is9mm ? '<td>$p2Mean</td>' : ''}
            <td>$atMean</td>
            <td>$vMean</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Max</td>
            <td>$p1Max</td>
            ${!is9mm ? '<td>$p2Max</td>' : ''}
            <td>$atMax</td>
            <td>$vMax</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Min</td>
            <td>$p1Min</td>
            ${!is9mm ? '<td>$p2Min</td>' : ''}
            <td>$atMin</td>
            <td>$vMin</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Range</td>
            <td>$p1Range</td>
            ${!is9mm ? '<td>$p2Range</td>' : ''}
            <td>$atRange</td>
            <td>$vRange</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">SD</td>
            <td>$p1SD</td>
            ${!is9mm ? '<td>$p2SD</td>' : ''}
            <td>$atSD</td>
          </tr>
        ''');
      } else if (testName == 'Firing Rate Cycle Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="5" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        final rpmMaxStr = (r.cyclicRateMax == 'null' || r.cyclicRateMax.isEmpty) ? 'No Limit' : r.cyclicRateMax;
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">${r.cyclicRateWeaponType}</td>
            <td>${r.cyclicRateAmmoType}</td>
            <td>${r.cyclicRateMin}</td>
            <td>$rpmMaxStr</td>
            <td style="font-weight: bold;">${r.cyclicRateValue} RPM</td>
          </tr>
        ''');
      } else if (testName == 'Terminal Effect Test') {
        if (records.length > 1) {
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}</td></tr>');
        }
        final holeList = r.terminalHoleDiameter.split(',');
        final steelList = r.terminalSteelPenetration.split(',');
        final alumList = r.terminalAluminumPenetration.split(',');
        final velList = r.terminalVelocity.split(',');
        
        final bufferRounds = StringBuffer();
        bufferRounds.write('<table style="width: 100%; border-collapse: collapse; border: 1px solid #cbd5e1; font-size: 11px;">');
        bufferRounds.write('<tr style="background-color: #f1f5f9; text-align: left;">');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Round No.</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Hole > Bullet Dia.</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Steel Penetration</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Aluminum Penetration</th>');
        bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Velocity (m/s)</th>');
        bufferRounds.write('</tr>');
        
        final count = r.produced;
        for (int idx = 0; idx < count; idx++) {
          final roundNo = idx + 1;
          final holeVal = idx < holeList.length ? holeList[idx] : 'Yes';
          final steelVal = idx < steelList.length ? steelList[idx] : 'Yes';
          final alumVal = idx < alumList.length ? alumList[idx] : 'Yes';
          final velVal = (idx < velList.length && velList[idx].trim().isNotEmpty) ? velList[idx] : '-';
          
          final colorHole = holeVal == 'No' ? '#b91c1c' : '#15803d';
          final colorSteel = steelVal == 'No' ? '#b91c1c' : '#15803d';
          final colorAlum = alumVal == 'No' ? '#b91c1c' : '#15803d';
          
          bufferRounds.write('<tr>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">Round $roundNo</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px; font-weight: bold; color: $colorHole;">$holeVal</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px; font-weight: bold; color: $colorSteel;">$steelVal</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px; font-weight: bold; color: $colorAlum;">$alumVal</td>');
          bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$velVal</td>');
          bufferRounds.write('</tr>');
        }
        bufferRounds.write('</table>');
        buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f8fafc;">Round-by-Round Penetration & Velocity Details</td></tr>');
        buffer.writeln('<tr><td colspan="6" style="padding: 10px;">$bufferRounds</td></tr>');
      } else if (testName == 'Function Test') {
// Function Test record banner removed
        final l1Color = r.functionLevel1 > 0 ? '#b91c1c' : '#15803d';
        final l2Color = r.functionLevel2 > 0 ? '#b91c1c' : '#15803d';
        final l3Color = r.functionLevel3 > 2 ? '#b45309' : '#15803d';
        final l4Color = r.functionLevel4 > 5 ? '#b45309' : '#15803d';
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">${r.produced} rounds</td>
            <td style="font-weight: bold; color: $l1Color;">${r.functionLevel1}</td>
            <td style="font-weight: bold; color: $l2Color;">${r.functionLevel2}</td>
            <td style="font-weight: bold; color: $l3Color;">${r.functionLevel3}</td>
            <td style="font-weight: bold; color: $l4Color;">${r.functionLevel4}</td>
            <td style="font-weight: bold;">${r.defects}</td>
          </tr>
        ''');
        if (r.functionDefectDetails.isNotEmpty) {
          buffer.writeln('''
            <tr>
              <td colspan="6" style="padding: 6px 10px; font-size: 10px; color: #334155; background-color: #f1f5f9; border-bottom: 1px solid #cbd5e1;">
                <strong style="color: #0f172a;">Specific Defects Recorded:</strong> ${r.functionDefectDetails}
              </td>
            </tr>
          ''');
        }
      } else if (testName == 'Primer Sensitivity Test') {
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">${r.primerSD.isNotEmpty ? '${r.primerSD} cm' : '-'}</td>
            <td>${r.primerAllFireH.isNotEmpty ? '${r.primerAllFireH} cm' : '-'}</td>
            <td>${r.primerNoFireH.isNotEmpty ? '${r.primerNoFireH} cm' : '-'}</td>
            <td>${cleanRemarks(r.notes).isNotEmpty ? cleanRemarks(r.notes) : '-'}</td>
          </tr>
        ''');
      } else {
        final metrics = _getRecordMetricsSummary(r);
        final badgeClass = 'badge-${r.status.toLowerCase().replaceAll(' ', '-')}';
        buffer.writeln('''
          <tr>
            <td style="font-weight: bold; color: #0284c7;">${r.testName}</td>
            <td>${r.timestamp}</td>
            <td>${r.operators}</td>
            <td>${r.produced} rounds</td>
            <td>$metrics</td>
            <td><span class="badge $badgeClass">${r.status}</span></td>
            <td>${r.notes}</td>
          </tr>
        ''');
      }
    }

    buffer.writeln('''
    </tbody>
  </table>

  $epvatCombinedSection
  ${_buildRetestSectionHtml(records, testName, isWord: true)}

  <div style="margin-top: 25px;">
    $remarksAndDiagramSection

    <h2 class="section-title">Recommendation</h2>
    <div class="sentence-box">
      $sentenceRequirement
    </div>

    $attachmentsSection

    <table class="signatures" style="margin-top: 30px;">
      <tr>
        <td style="border-top: 1px solid #cbd5e1; width: 45%;">Ballistic Inspector Signature</td>
        <td style="width: 10%; border: none;"></td>
        <td style="border-top: 1px solid #cbd5e1; width: 45%;">Ballistic Technician Approval</td>
      </tr>
    </table>
  </div>
</body>
</html>
''');

    return buffer.toString();
  }
}
