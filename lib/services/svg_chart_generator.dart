import 'dart:math' as math;
import '../models/ballistic_record.dart';

class SvgChartGenerator {
  /// Generates an SVG Doughnut / Donut chart for Quality Status distribution
  static String generateStatusDonutSvg(
    Map<String, int> statusCounts,
    double yieldRate, {
    double width = 340,
    double height = 220,
  }) {
    final int total = statusCounts.values.fold(0, (sum, v) => sum + v);
    if (total == 0) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="12" font-family="sans-serif">No Status Data</text>
      </svg>
      ''';
    }

    final colors = {
      'Approved': '#10b981',
      'Pending Review': '#6366f1',
      'Rejected': '#ef4444',
      'Retest': '#f59e0b',
      'Approved with condition': '#06b6d4',
    };

    final cx = 100.0;
    final cy = height / 2;
    final r = 70.0;
    final innerR = 48.0;

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>''');

    double currentAngle = -math.pi / 2;
    for (var entry in statusCounts.entries) {
      final count = entry.value;
      if (count <= 0) continue;
      final sweep = (count / total) * 2 * math.pi;
      final endAngle = currentAngle + sweep;

      final x1 = cx + r * math.cos(currentAngle);
      final y1 = cy + r * math.sin(currentAngle);
      final x2 = cx + r * math.cos(endAngle);
      final y2 = cy + r * math.sin(endAngle);

      final ix1 = cx + innerR * math.cos(endAngle);
      final iy1 = cy + innerR * math.sin(endAngle);
      final ix2 = cx + innerR * math.cos(currentAngle);
      final iy2 = cy + innerR * math.sin(currentAngle);

      final largeArc = sweep > math.pi ? 1 : 0;
      final color = colors[entry.key] ?? '#64748b';

      buffer.writeln('''  <path d="M $x1 $y1 A $r $r 0 $largeArc 1 $x2 $y2 L $ix1 $iy1 A $innerR $innerR 0 $largeArc 0 $ix2 $iy2 Z" fill="$color"/>''');
      currentAngle = endAngle;
    }

    // Center text: Yield Rate
    buffer.writeln('''  <text x="$cx" y="${cy - 4}" text-anchor="middle" font-size="15" font-weight="bold" fill="#0f172a" font-family="sans-serif">${yieldRate.toStringAsFixed(1)}%</text>''');
    buffer.writeln('''  <text x="$cx" y="${cy + 12}" text-anchor="middle" font-size="9" font-weight="600" fill="#64748b" font-family="sans-serif">YIELD RATE</text>''');

    // Legend on the right
    double legendY = 35.0;
    for (var entry in statusCounts.entries) {
      final count = entry.value;
      if (count <= 0) continue;
      final pct = (count / total * 100).toStringAsFixed(0);
      final color = colors[entry.key] ?? '#64748b';
      final label = entry.key;

      buffer.writeln('''  <rect x="195" y="$legendY" width="10" height="10" rx="2" fill="$color"/>''');
      buffer.writeln('''  <text x="212" y="${legendY + 9}" font-size="11" font-family="sans-serif" fill="#334155">$label: <tspan font-weight="bold">$count ($pct%)</tspan></text>''');
      legendY += 22.0;
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Generates an SVG Bar Chart for Caliber Volumes
  static String generateCaliberVolumeSvg(
    Map<String, int> caliberCounts, {
    double width = 540,
    double height = 220,
  }) {
    if (caliberCounts.isEmpty) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="12" font-family="sans-serif">No Caliber Volume Data</text>
      </svg>
      ''';
    }

    final int maxVal = caliberCounts.values.fold(0, (max, v) => v > max ? v : max);
    final int axisMax = maxVal == 0 ? 100 : ((maxVal + 9) ~/ 10) * 10;

    final padLeft = 50.0;
    final padRight = 20.0;
    final padTop = 30.0;
    final padBottom = 40.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    final keys = caliberCounts.keys.toList();
    final barSpacing = 16.0;
    final barW = (chartW - (barSpacing * (keys.length + 1))) / keys.length;

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>''');

    // Grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padTop + chartH - (i * chartH / 4);
      final val = (i * axisMax ~/ 4);
      buffer.writeln('''  <line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>''');
      buffer.writeln('''  <text x="${padLeft - 8}" y="${y + 4}" text-anchor="end" font-size="9" fill="#64748b" font-family="sans-serif">$val</text>''');
    }

    // Bars
    for (int i = 0; i < keys.length; i++) {
      final cal = keys[i];
      final val = caliberCounts[cal] ?? 0;
      final h = chartH * (val / axisMax);
      final x = padLeft + barSpacing + i * (barW + barSpacing);
      final y = padTop + chartH - h;

      buffer.writeln('''  <rect x="$x" y="$y" width="$barW" height="$h" rx="4" fill="#06b6d4"/>''');
      buffer.writeln('''  <text x="${x + barW / 2}" y="${y - 5}" text-anchor="middle" font-size="10" font-weight="bold" fill="#0f172a" font-family="sans-serif">$val</text>''');

      // Caliber label
      final shortCal = cal.length > 12 ? cal.substring(0, 10) + '..' : cal;
      buffer.writeln('''  <text x="${x + barW / 2}" y="${padTop + chartH + 16}" text-anchor="middle" font-size="9" font-weight="600" fill="#475569" font-family="sans-serif">$shortCal</text>''');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Generates an SVG Bar Chart for EPVAT test (Chamber P1, Port P2, Velocity)
  static String generateEpvatChartSvg(
    List<BallisticRecord> records, {
    double width = 560,
    double height = 230,
  }) {
    final epv = records.where((r) => r.testName == 'EPVAT test').toList();
    if (epv.isEmpty) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="12" font-family="sans-serif">No EPVAT Data</text>
      </svg>
      ''';
    }

    final display = epv.length > 5 ? epv.sublist(epv.length - 5) : epv;
    final padLeft = 55.0;
    final padRight = 20.0;
    final padTop = 40.0;
    final padBottom = 40.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    // Maximum P1 pressure for axis
    double maxP1 = 0.0;
    for (var r in display) {
      final p1 = double.tryParse(r.epvatMeanPressure) ?? 0.0;
      if (p1 > maxP1) maxP1 = p1;
    }
    if (maxP1 == 0.0) maxP1 = 4500.0;
    final axisMax = math.max(4500.0, ((maxP1 + 499) ~/ 500) * 500.0);

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>''');

    // Legend
    buffer.writeln('''
  <rect x="60" y="12" width="10" height="10" rx="2" fill="#06b6d4"/>
  <text x="75" y="20" font-size="10" fill="#334155" font-family="sans-serif">Chamber P1 (Bar)</text>
  <rect x="190" y="12" width="10" height="10" rx="2" fill="#8b5cf6"/>
  <text x="205" y="20" font-size="10" fill="#334155" font-family="sans-serif">Port P2 (Bar)</text>
  <rect x="300" y="12" width="10" height="10" rx="2" fill="#10b981"/>
  <text x="315" y="20" font-size="10" fill="#334155" font-family="sans-serif">Mean Vel (m/s)</text>
''');

    // Y Grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padTop + chartH - (i * chartH / 4);
      final val = (i * axisMax ~/ 4);
      buffer.writeln('''  <line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>''');
      buffer.writeln('''  <text x="${padLeft - 8}" y="${y + 4}" text-anchor="end" font-size="9" fill="#64748b" font-family="sans-serif">$val</text>''');
    }

    // Reference Limit Line (3800 Bar)
    final limitY = padTop + chartH - (3800.0 / axisMax * chartH);
    if (limitY >= padTop && limitY <= padTop + chartH) {
      buffer.writeln('''  <line x1="$padLeft" y1="$limitY" x2="${width - padRight}" y2="$limitY" stroke="#ef4444" stroke-width="1.5" stroke-dasharray="4,3"/>''');
      buffer.writeln('''  <text x="${width - padRight - 5}" y="${limitY - 3}" text-anchor="end" font-size="8" font-weight="bold" fill="#ef4444" font-family="sans-serif">3800 Bar Standard Limit</text>''');
    }

    // Grouped Bars
    final groupW = chartW / display.length;
    final barW = math.min(18.0, (groupW - 16) / 3);

    for (int i = 0; i < display.length; i++) {
      final r = display[i];
      final p1 = double.tryParse(r.epvatMeanPressure) ?? 0.0;
      final p2 = double.tryParse(r.epvatP2MeanPressure) ?? 0.0;
      final vel = double.tryParse(r.velMean) ?? 0.0;

      final groupCenter = padLeft + (i * groupW) + (groupW / 2);

      // P1 bar
      final h1 = chartH * (p1 / axisMax);
      final x1 = groupCenter - (barW * 1.5) - 2;
      final y1 = padTop + chartH - h1;
      if (h1 > 0) {
        buffer.writeln('''  <rect x="$x1" y="$y1" width="$barW" height="$h1" rx="2" fill="#06b6d4"/>''');
      }

      // P2 bar
      final h2 = chartH * (p2 / axisMax);
      final x2 = groupCenter - (barW * 0.5);
      final y2 = padTop + chartH - h2;
      if (h2 > 0) {
        buffer.writeln('''  <rect x="$x2" y="$y2" width="$barW" height="$h2" rx="2" fill="#8b5cf6"/>''');
      }

      // Vel bar
      final h3 = chartH * (vel / axisMax);
      final x3 = groupCenter + (barW * 0.5) + 2;
      final y3 = padTop + chartH - h3;
      if (h3 > 0) {
        buffer.writeln('''  <rect x="$x3" y="$y3" width="$barW" height="$h3" rx="2" fill="#10b981"/>''');
      }

      // Label (Temperature / Lot)
      final label = r.cartridgeTemp.isNotEmpty ? '${r.cartridgeTemp}°C' : (r.lotNo.length > 5 ? r.lotNo.substring(r.lotNo.length - 5) : r.lotNo);
      buffer.writeln('''  <text x="$groupCenter" y="${padTop + chartH + 16}" text-anchor="middle" font-size="9" font-weight="600" fill="#475569" font-family="sans-serif">$label</text>''');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Generates an SVG Bar Chart for Function Test 4-level defect breakdown
  static String generateFunctionTestChartSvg(
    List<BallisticRecord> records, {
    double width = 560,
    double height = 230,
  }) {
    final fnRecords = records.where((r) => r.testName == 'Function Test').toList();
    if (fnRecords.isEmpty) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="12" font-family="sans-serif">No Function Test Data</text>
      </svg>
      ''';
    }

    final display = fnRecords.length > 6 ? fnRecords.sublist(fnRecords.length - 6) : fnRecords;
    final padLeft = 45.0;
    final padRight = 20.0;
    final padTop = 40.0;
    final padBottom = 40.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    int maxDefects = 0;
    for (var r in display) {
      final m = math.max(math.max(r.functionLevel1, r.functionLevel2), math.max(r.functionLevel3, r.functionLevel4));
      if (m > maxDefects) maxDefects = m;
    }
    if (maxDefects == 0) maxDefects = 5;
    final axisMax = ((maxDefects + 3) ~/ 4) * 4;

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>''');

    // Legend
    buffer.writeln('''
  <rect x="50" y="12" width="10" height="10" rx="2" fill="#ef4444"/>
  <text x="65" y="20" font-size="9" font-weight="bold" fill="#334155" font-family="sans-serif">Level 1 (Critical)</text>
  <rect x="170" y="12" width="10" height="10" rx="2" fill="#f59e0b"/>
  <text x="185" y="20" font-size="9" font-weight="bold" fill="#334155" font-family="sans-serif">Level 2 (Major)</text>
  <rect x="280" y="12" width="10" height="10" rx="2" fill="#3b82f6"/>
  <text x="295" y="20" font-size="9" font-weight="bold" fill="#334155" font-family="sans-serif">Level 3 (Minor)</text>
  <rect x="390" y="12" width="10" height="10" rx="2" fill="#10b981"/>
  <text x="405" y="20" font-size="9" font-weight="bold" fill="#334155" font-family="sans-serif">Level 4</text>
''');

    // Y Grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padTop + chartH - (i * chartH / 4);
      final val = (i * axisMax ~/ 4);
      buffer.writeln('''  <line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>''');
      buffer.writeln('''  <text x="${padLeft - 8}" y="${y + 4}" text-anchor="end" font-size="9" fill="#64748b" font-family="sans-serif">$val</text>''');
    }

    // 4 Grouped bars per batch
    final groupW = chartW / display.length;
    final barW = math.min(12.0, (groupW - 12) / 4);

    for (int i = 0; i < display.length; i++) {
      final r = display[i];
      final groupCenter = padLeft + (i * groupW) + (groupW / 2);

      // Level 1
      final h1 = chartH * (r.functionLevel1 / axisMax);
      final x1 = groupCenter - (barW * 2);
      final y1 = padTop + chartH - h1;
      if (h1 > 0) buffer.writeln('''  <rect x="$x1" y="$y1" width="$barW" height="$h1" rx="2" fill="#ef4444"/>''');

      // Level 2
      final h2 = chartH * (r.functionLevel2 / axisMax);
      final x2 = groupCenter - barW;
      final y2 = padTop + chartH - h2;
      if (h2 > 0) buffer.writeln('''  <rect x="$x2" y="$y2" width="$barW" height="$h2" rx="2" fill="#f59e0b"/>''');

      // Level 3
      final h3 = chartH * (r.functionLevel3 / axisMax);
      final x3 = groupCenter;
      final y3 = padTop + chartH - h3;
      if (h3 > 0) buffer.writeln('''  <rect x="$x3" y="$y3" width="$barW" height="$h3" rx="2" fill="#3b82f6"/>''');

      // Level 4
      final h4 = chartH * (r.functionLevel4 / axisMax);
      final x4 = groupCenter + barW;
      final y4 = padTop + chartH - h4;
      if (h4 > 0) buffer.writeln('''  <rect x="$x4" y="$y4" width="$barW" height="$h4" rx="2" fill="#10b981"/>''');

      final label = r.lotNo.length > 6 ? r.lotNo.substring(r.lotNo.length - 6) : r.lotNo;
      buffer.writeln('''  <text x="$groupCenter" y="${padTop + chartH + 16}" text-anchor="middle" font-size="9" font-weight="600" fill="#475569" font-family="sans-serif">$label</text>''');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Generates an SVG Trend Line Chart
  static String generateTrendLineSvg(
    List<BallisticRecord> records, {
    double width = 560,
    double height = 200,
  }) {
    if (records.isEmpty) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="12" font-family="sans-serif">No Trend Data</text>
      </svg>
      ''';
    }

    final display = records.length > 12 ? records.sublist(records.length - 12) : records;
    final padLeft = 45.0;
    final padRight = 20.0;
    final padTop = 25.0;
    final padBottom = 30.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>''');

    // Y Grid: 0 to 100%
    for (int i = 0; i <= 4; i++) {
      final y = padTop + chartH - (i * chartH / 4);
      final val = i * 25;
      buffer.writeln('''  <line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>''');
      buffer.writeln('''  <text x="${padLeft - 8}" y="${y + 4}" text-anchor="end" font-size="9" fill="#64748b" font-family="sans-serif">$val%</text>''');
    }

    // Points
    final points = <String>[];
    final stepX = display.length > 1 ? chartW / (display.length - 1) : chartW / 2;

    for (int i = 0; i < display.length; i++) {
      final r = display[i];
      final double yPct = r.produced > 0 ? (((r.produced - r.defects) / r.produced) * 100.0).clamp(0.0, 100.0) : 100.0;
      final x = display.length > 1 ? padLeft + i * stepX : padLeft + chartW / 2;
      final y = padTop + chartH - (yPct / 100.0 * chartH);
      points.add('$x,$y');
    }

    if (points.isNotEmpty) {
      final pointsStr = points.join(' ');
      buffer.writeln('''  <polyline fill="none" stroke="#6366f1" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" points="$pointsStr"/>''');
      for (var pt in points) {
        final coords = pt.split(',');
        buffer.writeln('''  <circle cx="${coords[0]}" cy="${coords[1]}" r="4" fill="#06b6d4" stroke="#ffffff" stroke-width="1.5"/>''');
      }
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Generates a dedicated Velocity Trend Chart for each test (Test 1, Test 2, Test 3...)
  /// showing how velocity changes across tests (e.g. Test 1: 915 m/s, Test 2: 920 m/s, Test 3: 890 m/s).
  static String generateVelocityTrendSvg(
    List<BallisticRecord> records, {
    double width = 800,
    double height = 240,
  }) {
    final validRecords = records.where((r) {
      final v = double.tryParse(r.velMean);
      return v != null && v > 0;
    }).toList();

    if (validRecords.isEmpty) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="13" font-family="sans-serif">No Velocity Data Recorded</text>
      </svg>
      ''';
    }

    final display = validRecords.length > 15 ? validRecords.sublist(validRecords.length - 15) : validRecords;
    final padLeft = 60.0;
    final padRight = 35.0;
    final padTop = 35.0;
    final padBottom = 45.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    final velocities = display.map((r) => double.parse(r.velMean)).toList();
    double minV = velocities.reduce((a, b) => a < b ? a : b);
    double maxV = velocities.reduce((a, b) => a > b ? a : b);
    if ((maxV - minV) < 15.0) {
      minV -= 10.0;
      maxV += 10.0;
    }
    final vRange = maxV - minV;
    final paddedMin = (minV - vRange * 0.1).floorToDouble();
    final paddedMax = (maxV + vRange * 0.15).ceilToDouble();
    final paddedRange = paddedMax - paddedMin;

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="velGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#06b6d4" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#06b6d4" stop-opacity="0.0"/>
    </linearGradient>
  </defs>
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>''');

    // Title inside SVG
    buffer.writeln('''  <text x="$padLeft" y="20" font-size="12" font-weight="bold" fill="#0f172a" font-family="sans-serif">Muzzle Velocity Trend Across Tests (m/s)</text>''');

    // Y Grid: 4 horizontal grid lines
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i * chartH / gridCount);
      final val = paddedMin + (i * paddedRange / gridCount);
      buffer.writeln('''  <line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" stroke="#e2e8f0" stroke-width="1" stroke-dasharray="3,3"/>''');
      buffer.writeln('''  <text x="${padLeft - 8}" y="${y + 4}" text-anchor="end" font-size="9.5" fill="#64748b" font-family="monospace">${val.toStringAsFixed(1)}</text>''');
    }

    // Points calculation
    final points = <Map<String, dynamic>>[];
    final stepX = display.length > 1 ? chartW / (display.length - 1) : chartW / 2;

    for (int i = 0; i < display.length; i++) {
      final r = display[i];
      final v = double.parse(r.velMean);
      final x = display.length > 1 ? padLeft + i * stepX : padLeft + chartW / 2;
      final y = padTop + chartH - ((v - paddedMin) / paddedRange * chartH);
      points.add({
        'x': x,
        'y': y,
        'v': v,
        'testNum': i + 1,
        'lot': r.lotNo.isNotEmpty ? r.lotNo : (r.caliber.length > 10 ? r.caliber.substring(0, 10) : r.caliber),
      });
    }

    // Filled area under curve
    if (points.isNotEmpty) {
      final areaPts = <String>[];
      areaPts.add('${points.first['x']},${padTop + chartH}');
      for (final pt in points) {
        areaPts.add('${pt['x']},${pt['y']}');
      }
      areaPts.add('${points.last['x']},${padTop + chartH}');
      buffer.writeln('''  <polygon points="${areaPts.join(' ')}" fill="url(#velGrad)"/>''');

      // Polyline curve
      final polylinePts = points.map((p) => '${p['x']},${p['y']}').join(' ');
      buffer.writeln('''  <polyline fill="none" stroke="#06b6d4" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" points="$polylinePts"/>''');

      // Points, Callout Badges, and X-axis Labels
      for (final pt in points) {
        final double x = pt['x'];
        final double y = pt['y'];
        final double v = pt['v'];
        final int testNum = pt['testNum'];
        final String lot = pt['lot'];

        // Node circle
        buffer.writeln('''  <circle cx="$x" cy="$y" r="5" fill="#0891b2" stroke="#ffffff" stroke-width="2"/>''');

        // Value callout pill above node (e.g. 915 m/s)
        final vStr = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
        final pillW = 52.0;
        final pillH = 18.0;
        final pillX = x - pillW / 2;
        final pillY = y - 24;
        buffer.writeln('''  <rect x="$pillX" y="$pillY" width="$pillW" height="$pillH" rx="4" fill="#0f172a" stroke="#06b6d4" stroke-width="1"/>''');
        buffer.writeln('''  <text x="$x" y="${pillY + 13}" text-anchor="middle" font-size="9.5" font-weight="bold" fill="#38bdf8" font-family="monospace">$vStr m/s</text>''');

        // X-axis label: "Test 1", "Test 2", etc.
        buffer.writeln('''  <text x="$x" y="${padTop + chartH + 16}" text-anchor="middle" font-size="10" font-weight="bold" fill="#0f172a" font-family="sans-serif">Test $testNum</text>''');
        buffer.writeln('''  <text x="$x" y="${padTop + chartH + 28}" text-anchor="middle" font-size="8.5" fill="#64748b" font-family="sans-serif">$lot</text>''');
      }
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}
