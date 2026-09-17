import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import 'epvat_formula_helper.dart';

class ReportGenerator {
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

  static String generateCsv(List<BallisticRecord> records, String testName, String moduleName) {
    final buffer = StringBuffer();
    final lotHeader = moduleName == 'Daily Test' ? 'Hopper No. / Production Date' : 'Lot No';
    
    if (testName == 'Waterproof Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Pressure (Bar),Viscosity,Time of Test,Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.pressureBar, r.viscosity, r.testTime, r.samplingLocation,
          r.mouthSlow, r.mouthFast, r.primerSlow, r.primerFast
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
        buffer.writeln(row);
      }
    } else if (testName == 'Residual Stress Test') {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Room Temp,Neck Slow,Neck Fast,Shoulder Slow,Shoulder Fast,Body Slow,Body Fast,Head Slow,Head Fast,Location,Time of Test');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced,
          r.roomTemp, r.neckSlow, r.neckFast, r.shoulderSlow, r.shoulderFast,
          r.bodySlow, r.bodyFast, r.headSlow, r.headFast, r.samplingLocation, r.testTime
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
    } else {
      buffer.writeln('Time,Inspector,Shift Time,Caliber,$lotHeader,Result,Qty,Remarks');
      for (var r in records) {
        final row = [
          r.timestamp, r.operators, r.shift, r.caliber, r.lotNo, r.status, r.produced, r.notes
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
    var list = List<dynamic>.from(formulasMap[caliber] ?? []);
    if (list.isEmpty) {
      list = List<dynamic>.from(formulasMap['default'] ?? []);
    }
    if (list.isEmpty) {
      list = EpvatFormulaHelper.getDefaultFormulas();
    }

    final variables = EpvatFormulaHelper.extractVariablesFromRecords(records);
    final results = list.map((f) => EpvatFormulaHelper.evaluateFormulaItem(Map<String, dynamic>.from(f as Map), variables)).toList();
    final bool allPassed = results.every((r) => r.isPassed);

    // Kinetic Energy row if applicable
    String keHtml = '';
    final r21 = records.firstWhere((r) => r.cartridgeTemp == '+21', orElse: () => BallisticRecord.empty());
    if (adminRules.isNotEmpty && r21.velMean.isNotEmpty) {
      final massMap = epvRules['bullet_mass_grams'] ?? {};
      final double? massG = (massMap[caliber] as num?)?.toDouble();
      final double? vMean = double.tryParse(r21.velMean);
      if (massG != null && vMean != null && vMean > 0) {
        final double ke = 0.5 * (massG / 1000.0) * vMean * vMean;
        keHtml = '''
        <tr style="background-color: #f0f4ff;">
          <td colspan="5" style="padding: 8px 8px; font-size: 10.5px; border-bottom: 1px solid #e2e8f0;">
            <strong style="color:#4f46e5;">⚡ Kinetic Energy (+21 °C):</strong>
            <span style="font-family: monospace; font-weight: bold; color: #4f46e5; margin-left: 6px;">${ke.toStringAsFixed(1)} J</span>
            <span style="color: #64748b; margin-left: 8px;">(Bullet mass = ${massG.toStringAsFixed(2)} g, Mean velocity = ${vMean.toStringAsFixed(1)} m/s)</span>
          </td>
        </tr>''';
      }
    }

    final rowsBuffer = StringBuffer();
    for (int i = 0; i < results.length; i++) {
      final res = results[i];
      final bg = i % 2 == 1 ? 'background-color: #f8fafc;' : '';
      final color = res.isPassed ? '#15803d' : '#b91c1c';
      final statusText = res.isPassed ? 'PASSED' : 'FAILED';
      rowsBuffer.writeln('''
      <tr style="$bg">
        <td style="padding: 6px 8px; font-size: 10.5px; border-bottom: 1px solid #e2e8f0; font-weight: 600;">${res.name}</td>
        <td style="padding: 6px 8px; font-size: 10.5px; border-bottom: 1px solid #e2e8f0; font-family: monospace; color: #475569;">${res.formula}</td>
        <td style="padding: 6px 8px; font-size: 10.5px; border-bottom: 1px solid #e2e8f0; font-family: monospace; font-weight: bold; color: #1e293b;">${res.substitutedText} ${res.unit}</td>
        <td style="padding: 6px 8px; font-size: 10.5px; border-bottom: 1px solid #e2e8f0; font-family: monospace;">${res.op} ${res.limitValue.toStringAsFixed(1)} ${res.unit}</td>
        <td style="padding: 6px 8px; font-size: 10.5px; border-bottom: 1px solid #e2e8f0; font-weight: bold; color: $color;">$statusText</td>
      </tr>
      ''');
    }

    return '''
    <div style="margin-top: 15px; margin-bottom: 15px;">
      <h3 class="section-title" style="border-bottom: 2px solid #cbd5e1; padding-bottom: 4px; font-size: 12.5px; font-weight: bold; text-transform: uppercase;">Combined EPVAT Ballistic Analysis (Admin Adjustable Formulas)</h3>
      <table style="width: 100%; border-collapse: collapse; margin-bottom: 10px;">
        <thead>
          <tr style="background-color: #f1f5f9; color: #475569; font-size: 10.5px; font-weight: bold; text-align: left; text-transform: uppercase;">
            <th style="padding: 6px 8px; border-bottom: 2px solid #cbd5e1;">Rule / Check Name</th>
            <th style="padding: 6px 8px; border-bottom: 2px solid #cbd5e1;">Formula Expression</th>
            <th style="padding: 6px 8px; border-bottom: 2px solid #cbd5e1;">Evaluated Calculation</th>
            <th style="padding: 6px 8px; border-bottom: 2px solid #cbd5e1;">Configured Limit</th>
            <th style="padding: 6px 8px; border-bottom: 2px solid #cbd5e1;">Status</th>
          </tr>
        </thead>
        <tbody>
          ${rowsBuffer.toString()}
          $keHtml
        </tbody>
      </table>
      <div style="padding: 10px 12px; border: 1px solid ${allPassed ? '#bbf7d0' : '#fecaca'}; border-radius: 6px; background-color: ${allPassed ? '#f0fdf4' : '#fef2f2'}; font-size: 11.5px; font-weight: bold; line-height: 1.4; color: ${allPassed ? '#15803d' : '#b91c1c'};">
        <strong>Combined Sentencing Result:</strong> ${allPassed ? 'The lot satisfies all configured EPVAT ballistic criteria and is approved.' : 'The lot fails one or more configured EPVAT criteria and must be rejected.'}
      </div>
    </div>
    ''';
  }

  static String generateHtml(List<BallisticRecord> records, String testName, String moduleName, {String base64Logo = '', Map<String, dynamic> adminRules = const {}}) {
    final now = DateFormat('M/d/yyyy').format(DateTime.now());
    final totalQty = records.fold<int>(0, (sum, r) => sum + r.produced);
    final totalDefects = records.fold<int>(0, (sum, r) => sum + r.defects);
    final logoHtml = base64Logo.isNotEmpty 
        ? '<img src="data:image/png;base64,$base64Logo" style="height: 85px; width: auto; object-fit: contain;" />' 
        : '';

    final remarksList = records
        .map((r) => r.notes.trim())
        .where((n) => n.isNotEmpty && n.toLowerCase() != 'clear')
        .toSet()
        .toList();
    final remarksText = remarksList.join(', ');

    final requirementList = records
        .map((r) => r.requirement.trim())
        .where((req) => req.isNotEmpty)
        .toSet()
        .toList();
    final requirementText = requirementList.isNotEmpty ? requirementList.join(', ') : 'N/A';

    final title = testName == 'All' ? 'Combined Tests' : testName;

    String epvatCombinedSection = '';
    if (testName == 'EPVAT test') {
      epvatCombinedSection = _buildEpvatCombinedSectionHtml(
        records: records,
        adminRules: adminRules,
        isWord: false,
      );
    }

    // Classification reference image section (Residual Stress and Function Test)
    String classificationImageSection = '';
    if (adminRules.isNotEmpty) {
      if (testName == 'Residual Stress Test') {
        final rsImg = (adminRules['residual_stress']?['classification_image'] as String? ?? '').trim();
        if (rsImg.isNotEmpty) {
          final src = _formatImageSrc(rsImg);
          classificationImageSection = '''
          <div style="margin-top: 15px; margin-bottom: 15px;">
            <h3 class="section-title">Residual Stress Classification Reference</h3>
            <div style="text-align: center; margin: 10px 0; background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px;">
              <img src="$src" style="max-width: 100%; max-height: 400px; border-radius: 6px; border: 1px solid #cbd5e1; box-shadow: 0 2px 4px rgba(0,0,0,0.06);" alt="Residual Stress Classification Reference" />
              <div style="font-size: 10.5px; color: #64748b; margin-top: 6px; font-style: italic;">Visual Classification Standard for Residual Stress Cracks & Splits</div>
            </div>
          </div>
          ''';
        }
      } else if (testName == 'Function Test') {
        final funcImg = (adminRules['function_test']?['classification_image'] as String? ?? '').trim();
        if (funcImg.isNotEmpty) {
          final src = _formatImageSrc(funcImg);
          classificationImageSection = '''
          <div style="margin-top: 15px; margin-bottom: 15px;">
            <h3 class="section-title">Defect Classification Reference Guide</h3>
            <div style="text-align: center; margin: 10px 0; background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px;">
              <img src="$src" style="max-width: 100%; max-height: 400px; border-radius: 6px; border: 1px solid #cbd5e1; box-shadow: 0 2px 4px rgba(0,0,0,0.06);" alt="Defect Classification Reference" />
              <div style="font-size: 10.5px; color: #64748b; margin-top: 6px; font-style: italic;">Official Visual Classification Chart for Level 1 to Level 4 Defects</div>
            </div>
          </div>
          ''';
        }
      }
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

    final inspectorName = records.isNotEmpty ? records[0].operators : 'N/A';
    final caliber = records.isNotEmpty ? records[0].caliber : 'N/A';
    final lotNo = records.isNotEmpty
        ? (records[0].hopperNo.isEmpty && records[0].boxNo.isEmpty
            ? records[0].lotNo
            : '${records[0].lotNo} (Hopper: ${records[0].hopperNo}, Box: ${records[0].boxNo})')
        : 'N/A';

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
    final testTime = records.isNotEmpty ? records[0].testTime : '';
    final samplingLocation = records.isNotEmpty ? records[0].samplingLocation : '';
    final batchResult = records.isNotEmpty ? records[0].status : 'N/A';

    final hasRejected = records.any((r) => r.status.toLowerCase() == 'rejected' || r.status.toLowerCase() == 'failed');
    final hasRetest = records.any((r) => r.status.toLowerCase() == 'retest');
    final hasPending = records.any((r) => r.status.toLowerCase() == 'pending review');

    String sentenceRequirement = '';
    if (records.isEmpty) {
      sentenceRequirement = 'No records available to evaluate sentence requirements.';
    } else if (hasRejected) {
      sentenceRequirement = 'The inspected lot fails to satisfy waterproof test and ballistic specification criteria. The lot is officially REJECTED and quarantined.';
    } else if (hasRetest) {
      sentenceRequirement = 'Test results indicate marginal waterproof tolerances. The lot is sentenced to a mandatory RETEST under supervision.';
    } else if (hasPending) {
      sentenceRequirement = 'Evaluation in progress. The batch status remains PENDING REVIEW until supervisor verification is complete.';
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
      epvatRows.write('<td>${records.isNotEmpty && records[0].cartridgeTemp.isNotEmpty ? '${records[0].cartridgeTemp} &deg;C' : ''}</td>');
      epvatRows.write('<td></td><td></td>');
      epvatRows.write('</tr>');

      // Add Kinetic Energy row if adminRules has bullet mass for this caliber
      if (adminRules.isNotEmpty) {
        final epvR = adminRules['epvat'] ?? {};
        final massMap = epvR['bullet_mass_grams'] ?? {};
        final String cal = records.isNotEmpty ? records[0].caliber : '';
        final double? massG = (massMap[cal] as num?)?.toDouble();
        // Use +21°C record velocity if multi-temp, else single-record mean vel
        final r21 = records.firstWhere((r) => r.cartridgeTemp == '+21', orElse: () => records.isNotEmpty ? records[0] : BallisticRecord.empty());
        final double? vMean = double.tryParse(r21.velMean);
        if (massG != null && vMean != null && vMean > 0) {
          final double ke = 0.5 * (massG / 1000.0) * vMean * vMean;
          epvatRows.write('<tr style="background-color: #f0f4ff;">');
          epvatRows.write('<td style="font-weight: bold; color: #4f46e5;">⚡ Kinetic Energy (+21°C):</td>');
          epvatRows.write('<td style="font-family: monospace; font-weight: bold; color: #4f46e5;">${ke.toStringAsFixed(1)} J</td>');
          epvatRows.write('<td style="color: #64748b; font-size: 10px;">m = ${massG.toStringAsFixed(2)} g, v = ${vMean.toStringAsFixed(1)} m/s</td>');
          epvatRows.write('<td></td>');
          epvatRows.write('</tr>');
        }
      }
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

    final buffer = StringBuffer();
    buffer.writeln('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1e293b;
      padding: 15px 25px;
      margin: 0;
      background-color: #ffffff;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 12px;
      border-bottom: 3px solid #06b6d4;
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
      font-weight: 700;
      color: #0f172a;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .title-line {
      height: 2px;
      width: 100%;
      background-color: #06b6d4;
      margin-top: 4px;
    }
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 12px;
      margin-bottom: 15px;
    }
    .summary-card {
      background-color: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 8px 12px;
    }
    .summary-card .label {
      font-size: 9.5px;
      font-weight: 700;
      color: #64748b;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .summary-card .val {
      font-size: 16px;
      font-weight: 700;
      color: #0f172a;
      margin-top: 2px;
    }
    .section-title {
      font-size: 12.5px;
      font-weight: 700;
      color: #0f172a;
      border-bottom: 2px solid #cbd5e1;
      padding-bottom: 4px;
      margin-top: 14px;
      margin-bottom: 8px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .details-table {
      width: 100%;
      margin-bottom: 12px;
    }
    .details-table td {
      padding: 4px 8px;
      font-size: 11.5px;
      border: none !important;
      background: none !important;
    }
    table.data-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 15px;
    }
    table.data-table th {
      background-color: #f1f5f9;
      color: #475569;
      text-align: left;
      font-size: 10.5px;
      font-weight: 700;
      padding: 6px 8px;
      border-bottom: 2px solid #cbd5e1;
      text-transform: uppercase;
    }
    table.data-table td {
      padding: 6px 8px;
      font-size: 10.5px;
      border-bottom: 1px solid #e2e8f0;
      color: #334155;
    }
    tr:nth-child(even) td {
      background-color: #f8fafc;
    }
    .badge {
      padding: 3px 6px;
      border-radius: 4px;
      font-size: 9px;
      font-weight: bold;
      display: inline-block;
      text-transform: uppercase;
    }
    .badge-approved { background-color: #dcfce7; color: #15803d; }
    .badge-retest { background-color: #fef3c7; color: #b45309; }
    .badge-rejected { background-color: #fee2e2; color: #b91c1c; }
    .badge-pending { background-color: #fef3c7; color: #b45309; }
    .badge-approved-with-condition { background-color: #ccfbf1; color: #0f766e; }
    
    .sentence-box {
      padding: 10px 12px;
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      background-color: #f8fafc;
      font-size: 11.5px;
      font-weight: bold;
      line-height: 1.4;
      color: #1e293b;
    }
    .signatures {
      margin-top: 25px;
      display: flex;
      justify-content: space-between;
    }
    .sig-box {
      width: 40%;
      border-top: 1px solid #cbd5e1;
      text-align: center;
      padding-top: 6px;
      font-size: 11.5px;
      color: #475569;
    }
    @media print {
      @page { margin: 0; }
      body { margin: 12mm 15mm; padding: 0; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
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
        <td style="font-weight: bold; color: ${batchResult.toLowerCase() == 'approved' ? '#15803d' : (batchResult.toLowerCase() == 'retest' ? '#b45309' : '#b91c1c')};">$batchResult</td>
      </tr>
      ${testName == 'Waterproof Test' ? waterproofRows.toString() : ''}
      ${testName == 'Residual Stress Test' ? residualStressRows.toString() : ''}
      ${testName == 'Accuracy Test' ? accuracyRows.toString() : ''}
      ${testName == 'EPVAT test' ? epvatRows.toString() : ''}
      ${testName == 'Firing Rate Cycle Test' ? cyclicRows.toString() : ''}
      ${testName == 'Terminal Effect Test' ? terminalRows.toString() : ''}
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
    } else if (testName == 'Accuracy Test' || testName == 'Extraction Force Test' || testName == 'EPVAT test') {
      buffer.writeln('''
        <th>Coordinate / Parameter</th>
        <th>Mean</th>
        <th>Max</th>
        <th>Min</th>
        <th>Range</th>
        <th>SD</th>
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
      } else if (testName == 'EPVAT test') {
        final tempStr = r.cartridgeTemp.isNotEmpty ? '${r.cartridgeTemp} &deg;C' : 'N/A';
        buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp} &nbsp;|&nbsp; Temp: $tempStr &nbsp;|&nbsp; Status: ${r.status}</td></tr>');
        if (r.epvatPressureRounds.isNotEmpty) {
          final roundsList = r.epvatPressureRounds.split(',');
          final p2List = r.epvatP2PressureRounds.split(',');
          final velList = r.epvatVelRounds.split(',');
          final bufferRounds = StringBuffer();
          bufferRounds.write('<table style="width: 100%; border-collapse: collapse; border: 1px solid #cbd5e1; font-size: 11px;">');
          bufferRounds.write('<tr style="background-color: #f1f5f9; text-align: left;">');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Round</th>');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Velocity (m/s)</th>');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">P1 Chamber Pres (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</th>');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">P2 Port Pres (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</th>');
          bufferRounds.write('</tr>');
          for (int idx = 0; idx < roundsList.length; idx++) {
            final roundNo = idx + 1;
            final velVal = idx < velList.length ? velList[idx] : '';
            final p1Val = roundsList[idx];
            final p2Val = idx < p2List.length ? p2List[idx] : '';
            bufferRounds.write('<tr>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">Round $roundNo</td>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$velVal</td>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$p1Val</td>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$p2Val</td>');
            bufferRounds.write('</tr>');
          }
          bufferRounds.write('</table>');
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f8fafc;">Individual Round Details</td></tr>');
          buffer.writeln('<tr><td colspan="6" style="padding: 10px;">$bufferRounds</td></tr>');
        }

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

        final vMean = r.velMean.trim().isNotEmpty ? r.velMean : '-';
        final vMax = r.velMax.trim().isNotEmpty ? r.velMax : '-';
        final vMin = r.velMin.trim().isNotEmpty ? r.velMin : '-';
        final vRange = r.velRange.trim().isNotEmpty ? r.velRange : '-';
        final vSD = r.velSD.trim().isNotEmpty ? r.velSD : '-';

        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">Chamber Pressure P1 (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</td>
            <td>$p1Mean</td>
            <td>$p1Max</td>
            <td>$p1Min</td>
            <td>$p1Range</td>
            <td>$p1SD</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Port Pressure P2 (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</td>
            <td>$p2Mean</td>
            <td>$p2Max</td>
            <td>$p2Min</td>
            <td>$p2Range</td>
            <td>$p2SD</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Velocity (m/s)</td>
            <td>$vMean</td>
            <td>$vMax</td>
            <td>$vMin</td>
            <td>$vRange</td>
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
        final weaponStr = r.cyclicRateWeaponType.isNotEmpty ? ' &nbsp;|&nbsp; Weapon: ${r.cyclicRateWeaponType}' : '';
        final tempStr = r.cartridgeTemp.isNotEmpty ? ' &nbsp;|&nbsp; Temp: ${r.cartridgeTemp}' : '';
        buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}$weaponStr$tempStr &nbsp;|&nbsp; Status: ${r.status}</td></tr>');
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
      } else {
        buffer.writeln('<tr>');
        buffer.writeln('<td>${r.notes}</td>');
        buffer.writeln('</tr>');
      }
    }

    buffer.writeln('''
      </tbody>
    </table>
  </div>

  $epvatCombinedSection
  $classificationImageSection

  <!-- Requirement -->
  <div>
    <h3 class="section-title">Requirement</h3>
    <div class="sentence-box" style="min-height: 40px;">
      $requirementText
    </div>
  </div>

  <!-- Remarks -->
  <div>
    <h3 class="section-title">Remarks</h3>
    <div class="sentence-box" style="min-height: 50px;">
      $remarksText
    </div>
  </div>

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
</body>
</html>
''');

    return buffer.toString();
  }

  static String generateWordHtml(List<BallisticRecord> records, String testName, String moduleName, {String base64Logo = '', Map<String, dynamic> adminRules = const {}}) {
    final now = DateFormat('M/d/yyyy').format(DateTime.now());
    final totalQty = records.fold<int>(0, (sum, r) => sum + r.produced);
    final totalDefects = records.fold<int>(0, (sum, r) => sum + r.defects);
    final logoHtml = base64Logo.isNotEmpty 
        ? '<img src="data:image/png;base64,$base64Logo" width="140" height="85" style="object-fit: contain;" />' 
        : '';

    final remarksList = records
        .map((r) => r.notes.trim())
        .where((n) => n.isNotEmpty && n.toLowerCase() != 'clear')
        .toSet()
        .toList();
    final remarksText = remarksList.join(', ');

    final requirementList = records
        .map((r) => r.requirement.trim())
        .where((req) => req.isNotEmpty)
        .toSet()
        .toList();
    final requirementText = requirementList.isNotEmpty ? requirementList.join(', ') : 'N/A';

    final inspectorName = records.isNotEmpty ? records[0].operators : 'N/A';
    final caliber = records.isNotEmpty ? records[0].caliber : 'N/A';
    final lotNo = records.isNotEmpty
        ? (records[0].hopperNo.isEmpty && records[0].boxNo.isEmpty
            ? records[0].lotNo
            : '${records[0].lotNo} (Hopper: ${records[0].hopperNo}, Box: ${records[0].boxNo})')
        : 'N/A';

    String epvatCombinedSection = '';
    if (testName == 'EPVAT test') {
      epvatCombinedSection = _buildEpvatCombinedSectionHtml(
        records: records,
        adminRules: adminRules,
        isWord: true,
      );
    }

    // Classification reference image section (Residual Stress and Function Test)
    String classificationImageSection = '';
    if (adminRules.isNotEmpty) {
      if (testName == 'Residual Stress Test') {
        final rsImg = (adminRules['residual_stress']?['classification_image'] as String? ?? '').trim();
        if (rsImg.isNotEmpty) {
          final src = _formatImageSrc(rsImg);
          classificationImageSection = '''
          <div style="margin-top: 15px; margin-bottom: 15px;">
            <h2 class="section-title">Residual Stress Classification Reference</h2>
            <table style="width: 100%; border-collapse: collapse;">
              <tr>
                <td style="text-align: center; background-color: #f8fafc; border: 1px solid #e2e8f0; padding: 12px;">
                  <img src="$src" width="500" style="max-width: 100%; height: auto;" alt="Residual Stress Classification Reference" />
                  <p style="font-size: 10px; color: #64748b; margin-top: 6px; font-style: italic;">Visual Classification Standard for Residual Stress Cracks & Splits</p>
                </td>
              </tr>
            </table>
          </div>
          ''';
        }
      } else if (testName == 'Function Test') {
        final funcImg = (adminRules['function_test']?['classification_image'] as String? ?? '').trim();
        if (funcImg.isNotEmpty) {
          final src = _formatImageSrc(funcImg);
          classificationImageSection = '''
          <div style="margin-top: 15px; margin-bottom: 15px;">
            <h2 class="section-title">Defect Classification Reference Guide</h2>
            <table style="width: 100%; border-collapse: collapse;">
              <tr>
                <td style="text-align: center; background-color: #f8fafc; border: 1px solid #e2e8f0; padding: 12px;">
                  <img src="$src" width="500" style="max-width: 100%; height: auto;" alt="Defect Classification Reference" />
                  <p style="font-size: 10px; color: #64748b; margin-top: 6px; font-style: italic;">Official Visual Classification Chart for Level 1 to Level 4 Defects</p>
                </td>
              </tr>
            </table>
          </div>
          ''';
        }
      }
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
    final testTime = records.isNotEmpty ? records[0].testTime : '';
    final samplingLocation = records.isNotEmpty ? records[0].samplingLocation : '';
    final batchResult = records.isNotEmpty ? records[0].status : 'N/A';

    final hasRejected = records.any((r) => r.status.toLowerCase() == 'rejected' || r.status.toLowerCase() == 'failed');
    final hasRetest = records.any((r) => r.status.toLowerCase() == 'retest');
    final hasPending = records.any((r) => r.status.toLowerCase() == 'pending review');

    String sentenceRequirement = '';
    if (records.isEmpty) {
      sentenceRequirement = 'No records available to evaluate sentence requirements.';
    } else if (hasRejected) {
      sentenceRequirement = 'The inspected lot fails to satisfy waterproof test and ballistic specification criteria. The lot is officially REJECTED and quarantined.';
    } else if (hasRetest) {
      sentenceRequirement = 'Test results indicate marginal waterproof tolerances. The lot is sentenced to a mandatory RETEST under supervision.';
    } else if (hasPending) {
      sentenceRequirement = 'Evaluation in progress. The batch status remains PENDING REVIEW until supervisor verification is complete.';
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
      epvatRows.write('<td>${records.isNotEmpty && records[0].cartridgeTemp.isNotEmpty ? '${records[0].cartridgeTemp} &deg;C' : ''}</td>');
      epvatRows.write('<td></td><td></td>');
      epvatRows.write('</tr>');
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

    final buffer = StringBuffer();
    buffer.writeln('''<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
<head>
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
    .sentence-box { padding: 10px; border: 1px solid #cbd5e1; background-color: #f8fafc; font-size: 11px; font-weight: bold; color: #1e293b; }
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
      <td style="font-weight: bold; color: ${batchResult.toLowerCase() == 'approved' ? '#15803d' : (batchResult.toLowerCase() == 'retest' ? '#b45309' : '#b91c1c')};">$batchResult</td>
    </tr>
    ${testName == 'Waterproof Test' ? waterproofRows.toString() : ''}
    ${testName == 'Residual Stress Test' ? residualStressRows.toString() : ''}
    ${testName == 'Accuracy Test' ? accuracyRows.toString() : ''}
    ${testName == 'EPVAT test' ? epvatRows.toString() : ''}
    ${testName == 'Firing Rate Cycle Test' ? cyclicRows.toString() : ''}
    ${testName == 'Terminal Effect Test' ? terminalRows.toString() : ''}
  </table>

  <h2 class="section-title">Parameters/Results</h2>
  <table class="data-table">
    <thead>
      <tr>
        ${testName == 'Waterproof Test' ? '<th>Mouth Leaks (S/F)</th><th>Primer Leaks (S/F)</th>' : (testName == 'Residual Stress Test' ? '<th>Neck Splits (Min/Maj)</th><th>Shoulder Splits (Min/Maj)</th><th>Body Splits (Min/Maj)</th><th>Head Splits (Min/Maj)</th><th>Total Splits</th>' : (testName == 'Accuracy Test' || testName == 'Extraction Force Test' || testName == 'EPVAT test' ? '<th>Coordinate / Parameter</th><th>Mean</th><th>Max</th><th>Min</th><th>Range</th><th>SD</th>' : (testName == 'Firing Rate Cycle Test' ? '<th>Weapon Model</th><th>Category</th><th>Min RPM</th><th>Max RPM</th><th>Measured RPM</th>' : (testName == 'Terminal Effect Test' ? '<th colspan="6">Terminal Effect Test Metrics</th>' : (testName == 'Function Test' ? '<th>Tested Qty</th><th>Level 1 (Critical)</th><th>Level 2 (Major)</th><th>Level 3 (Minor)</th><th>Level 4</th><th>Total Defects</th>' : '<th>Remarks</th>')))))}
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
      } else if (testName == 'EPVAT test') {
        final tempStr = r.cartridgeTemp.isNotEmpty ? '${r.cartridgeTemp} &deg;C' : 'N/A';
        buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp} &nbsp;|&nbsp; Temp: $tempStr &nbsp;|&nbsp; Status: ${r.status}</td></tr>');
        if (r.epvatPressureRounds.isNotEmpty) {
          final roundsList = r.epvatPressureRounds.split(',');
          final p2List = r.epvatP2PressureRounds.split(',');
          final velList = r.epvatVelRounds.split(',');
          final bufferRounds = StringBuffer();
          bufferRounds.write('<table style="width: 100%; border-collapse: collapse; border: 1px solid #cbd5e1; font-size: 11px;">');
          bufferRounds.write('<tr style="background-color: #f1f5f9; text-align: left;">');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Round</th>');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">Velocity (m/s)</th>');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">P1 Chamber Pres (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</th>');
          bufferRounds.write('<th style="border: 1px solid #cbd5e1; padding: 4px;">P2 Port Pres (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</th>');
          bufferRounds.write('</tr>');
          for (int idx = 0; idx < roundsList.length; idx++) {
            final roundNo = idx + 1;
            final velVal = idx < velList.length ? velList[idx] : '';
            final p1Val = roundsList[idx];
            final p2Val = idx < p2List.length ? p2List[idx] : '';
            bufferRounds.write('<tr>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">Round $roundNo</td>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$velVal</td>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$p1Val</td>');
            bufferRounds.write('<td style="border: 1px solid #cbd5e1; padding: 4px;">$p2Val</td>');
            bufferRounds.write('</tr>');
          }
          bufferRounds.write('</table>');
          buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f8fafc;">Individual Round Details</td></tr>');
          buffer.writeln('<tr><td colspan="6" style="padding: 10px;">$bufferRounds</td></tr>');
        }

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

        final vMean = r.velMean.trim().isNotEmpty ? r.velMean : '-';
        final vMax = r.velMax.trim().isNotEmpty ? r.velMax : '-';
        final vMin = r.velMin.trim().isNotEmpty ? r.velMin : '-';
        final vRange = r.velRange.trim().isNotEmpty ? r.velRange : '-';
        final vSD = r.velSD.trim().isNotEmpty ? r.velSD : '-';

        buffer.writeln('''
          <tr>
            <td style="font-weight: bold;">Chamber Pressure P1 (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</td>
            <td>$p1Mean</td>
            <td>$p1Max</td>
            <td>$p1Min</td>
            <td>$p1Range</td>
            <td>$p1SD</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Port Pressure P2 (${r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'Bar'})</td>
            <td>$p2Mean</td>
            <td>$p2Max</td>
            <td>$p2Min</td>
            <td>$p2Range</td>
            <td>$p2SD</td>
          </tr>
          <tr>
            <td style="font-weight: bold;">Velocity (m/s)</td>
            <td>$vMean</td>
            <td>$vMax</td>
            <td>$vMin</td>
            <td>$vRange</td>
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
        final weaponStr = r.cyclicRateWeaponType.isNotEmpty ? ' &nbsp;|&nbsp; Weapon: ${r.cyclicRateWeaponType}' : '';
        final tempStr = r.cartridgeTemp.isNotEmpty ? ' &nbsp;|&nbsp; Temp: ${r.cartridgeTemp}' : '';
        buffer.writeln('<tr><td colspan="6" style="font-weight: bold; background-color: #f1f5f9; text-transform: uppercase;">Record: ${r.timestamp}$weaponStr$tempStr &nbsp;|&nbsp; Status: ${r.status}</td></tr>');
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
      } else {
        buffer.writeln('<tr>');
        buffer.writeln('<td>${r.notes}</td>');
        buffer.writeln('</tr>');
      }
    }

    buffer.writeln('''
    </tbody>
  </table>

  $epvatCombinedSection
  $classificationImageSection

  <h2 class="section-title">Requirement</h2>
  <div class="sentence-box" style="min-height: 40px;">
    $requirementText
  </div>

  <h2 class="section-title">Remarks</h2>
  <div class="sentence-box" style="min-height: 40px;">
    $remarksText
  </div>

  <h2 class="section-title">Recommendation</h2>
  <div class="sentence-box">
    $sentenceRequirement
  </div>

  $attachmentsSection

  <table class="signatures">
    <tr>
      <td style="border-top: 1px solid #cbd5e1; width: 45%;">Ballistic Inspector Signature</td>
      <td style="width: 10%; border: none;"></td>
      <td style="border-top: 1px solid #cbd5e1; width: 45%;">Ballistic Technician Approval</td>
    </tr>
  </table>
</body>
</html>
''');

    return buffer.toString();
  }
}
