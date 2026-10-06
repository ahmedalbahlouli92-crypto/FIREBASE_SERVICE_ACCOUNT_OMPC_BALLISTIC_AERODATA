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

  /// Extracts numeric metric value for any ballistic parameter across tests
  static double? extractParamValue(BallisticRecord r, String param) {
    final p = param.toLowerCase();
    if (p.contains('velocity sd') || p.contains('vel sd')) return double.tryParse(r.velSD);
    if (p.contains('velocity') || p.contains('vel')) return double.tryParse(r.velMean);
    if (p.contains('p2') || p.contains('port')) return double.tryParse(r.epvatP2MeanPressure);
    if (p.contains('p1 max') || p.contains('chamber max')) return double.tryParse(r.epvatMaxPressure);
    if (p.contains('p1 sd') || p.contains('chamber sd')) return double.tryParse(r.epvatSDPressure);
    if (p.contains('pressure') || p.contains('p1') || p.contains('chamber')) return double.tryParse(r.epvatMeanPressure);
    if (p.contains('action time') || p.contains('at mean')) return double.tryParse(r.actionTimeMean);
    if (p.contains('mean radius') || p.contains('radius')) return double.tryParse(r.accMeanRadius);
    if (p.contains('sd x')) return double.tryParse(r.accSDX);
    if (p.contains('sd y')) return double.tryParse(r.accSDY);
    if (p.contains('extraction') || p.contains('min force')) return double.tryParse(r.accMinX.isNotEmpty ? r.accMinX : r.accMeanX);
    if (p.contains('mean force')) return double.tryParse(r.accMeanX);
    if (p.contains('leak') || p.contains('waterproof')) {
      final leaks = r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast;
      return leaks.toDouble();
    }
    if (p.contains('split') || p.contains('crack') || p.contains('residual')) {
      final cracks = r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast;
      return cracks.toDouble();
    }
    if (p.contains('defect') || p.contains('function')) return r.defects.toDouble();
    if (p.contains('cyclic') || p.contains('rpm') || p.contains('rate')) return double.tryParse(r.cyclicRateValue);
    if (p.contains('hbar') || p.contains('mean height')) return double.tryParse(r.primerHbar);
    if (p.contains('all fire') || p.contains('h+5') || p.contains('h + 5')) return double.tryParse(r.primerAllFireH);
    if (p.contains('no fire') || p.contains('h-2') || p.contains('h - 2')) return double.tryParse(r.primerNoFireH);
    if (p.contains('primer sd')) return double.tryParse(r.primerSD);
    return double.tryParse(r.velMean) ?? double.tryParse(r.epvatMeanPressure) ?? double.tryParse(r.accMeanRadius);
  }

  /// Generates an SVG Statistical Process Control (SPC) Chart with UCL, CL, and LCL limits
  static int _compareNatural(String a, String b) {
    final regA = RegExp(r'\d+').firstMatch(a);
    final regB = RegExp(r'\d+').firstMatch(b);
    if (regA != null && regB != null) {
      final prefixA = a.substring(0, regA.start);
      final prefixB = b.substring(0, regB.start);
      if (prefixA != prefixB) return prefixA.compareTo(prefixB);
      final numA = int.tryParse(regA.group(0)!);
      final numB = int.tryParse(regB.group(0)!);
      if (numA != null && numB != null && numA != numB) {
        return numA.compareTo(numB);
      }
    }
    return a.compareTo(b);
  }

  /// Generates an SVG Statistical Process Control (SPC) Chart with UCL, CL, and LCL limits
  static String generateSpcChartSvg(
    List<BallisticRecord> records, {
    String param = 'Mean Velocity (m/s)',
    double width = 800,
    double height = 230,
  }) {
    // Sort records strictly by lot number in natural numerical sequence
    final sortedRecords = List<BallisticRecord>.from(records)..sort((a, b) {
      final lotA = a.lotNo.trim().isNotEmpty ? a.lotNo.trim() : a.hopperNo.trim();
      final lotB = b.lotNo.trim().isNotEmpty ? b.lotNo.trim() : b.hopperNo.trim();
      return _compareNatural(lotA, lotB);
    });

    // 1. Extract values
    final List<Map<String, dynamic>> points = [];
    for (int i = 0; i < sortedRecords.length; i++) {
      final r = sortedRecords[i];
      final double? val = extractParamValue(r, param);

      if (val != null && (val > 0 || param.toLowerCase().contains('leak') || param.toLowerCase().contains('defect') || param.toLowerCase().contains('split') || param.toLowerCase().contains('crack'))) {
        final lot = r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : (r.hopperNo.trim().isNotEmpty ? r.hopperNo.trim() : 'Test ${i + 1}');
        points.add({
          'val': val,
          'label': lot.length > 8 ? lot.substring(lot.length - 8) : lot,
          'index': i + 1,
        });
      }
    }

    if (points.isEmpty) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="13" font-family="sans-serif">No SPC Data Available for Evaluation</text>
      </svg>
      ''';
    }

    // Limit to latest 15 points if too many
    final displayPoints = points.length > 15 ? points.sublist(points.length - 15) : points;
    final values = displayPoints.map((p) => p['val'] as double).toList();

    // 2. Compute Mean & SD
    final double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = 0.0;
    if (values.length > 1) {
      variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / (values.length - 1);
    }
    final double sd = math.sqrt(variance);
    final double ucl = mean + (3 * sd);
    final double lcl = math.max(0.0, mean - (3 * sd));

    final int oocCount = values.where((v) => v > ucl || v < lcl).length;

    // 3. Layout Dimensions
    final padLeft = 65.0;
    final padRight = 35.0;
    final padTop = 45.0;
    final padBottom = 40.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    // Scale range with 10% breathing room
    final double minVal = values.reduce(math.min);
    final double maxVal = values.reduce(math.max);
    final double axisMin = math.min(lcl, minVal) - (sd * 0.8);
    final double axisMax = math.max(ucl, maxVal) + (sd * 0.8);
    final double range = (axisMax - axisMin) > 0 ? (axisMax - axisMin) : 10.0;

    double getY(double v) => padTop + chartH - (((v - axisMin) / range) * chartH).clamp(0.0, chartH);

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#cbd5e1" stroke-width="1"/>''');

    // Title & Badges
    buffer.writeln('''  <text x="$padLeft" y="22" font-size="12" font-weight="bold" fill="#0f172a" font-family="sans-serif">Statistical Process Control (SPC) Chart - $param</text>''');
    
    // Limits Badges on the right
    buffer.writeln('''
  <g transform="translate(${width - padRight - 360}, 10)">
    <rect x="0" y="0" width="75" height="18" rx="3" fill="#fee2e2" stroke="#ef4444" stroke-width="0.8"/>
    <text x="37" y="12.5" text-anchor="middle" font-size="9" font-weight="bold" fill="#b91c1c" font-family="sans-serif">UCL: ${ucl.toStringAsFixed(1)}</text>

    <rect x="82" y="0" width="85" height="18" rx="3" fill="#e0f2fe" stroke="#0284c7" stroke-width="0.8"/>
    <text x="124" y="12.5" text-anchor="middle" font-size="9" font-weight="bold" fill="#0369a1" font-family="sans-serif">CL: ${mean.toStringAsFixed(1)}</text>

    <rect x="174" y="0" width="75" height="18" rx="3" fill="#fee2e2" stroke="#ef4444" stroke-width="0.8"/>
    <text x="211" y="12.5" text-anchor="middle" font-size="9" font-weight="bold" fill="#b91c1c" font-family="sans-serif">LCL: ${lcl.toStringAsFixed(1)}</text>

    <rect x="256" y="0" width="65" height="18" rx="3" fill="#f3e8ff" stroke="#a855f7" stroke-width="0.8"/>
    <text x="288" y="12.5" text-anchor="middle" font-size="9" font-weight="bold" fill="#7e22ce" font-family="sans-serif">σ: ${sd.toStringAsFixed(2)}</text>
''');
    if (oocCount > 0) {
      buffer.writeln('''
    <rect x="328" y="0" width="70" height="18" rx="3" fill="#ef4444"/>
    <text x="363" y="12.5" text-anchor="middle" font-size="9" font-weight="bold" fill="#ffffff" font-family="sans-serif">OOC: $oocCount</text>
''');
    }
    buffer.writeln('  </g>');

    // Y Grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padTop + chartH - (i * chartH / 4);
      final v = axisMin + (i * range / 4);
      buffer.writeln('''  <line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>''');
      buffer.writeln('''  <text x="${padLeft - 8}" y="${y + 3.5}" text-anchor="end" font-size="9" fill="#64748b" font-family="monospace">${v.toStringAsFixed(1)}</text>''');
    }

    // UCL line
    final uclY = getY(ucl);
    buffer.writeln('''  <line x1="$padLeft" y1="$uclY" x2="${width - padRight}" y2="$uclY" stroke="#ef4444" stroke-width="1.5" stroke-dasharray="5,4"/>''');
    buffer.writeln('''  <text x="${width - padRight + 4}" y="${uclY + 3}" font-size="8.5" font-weight="bold" fill="#ef4444" font-family="sans-serif">UCL</text>''');

    // CL / Mean line
    final clY = getY(mean);
    buffer.writeln('''  <line x1="$padLeft" y1="$clY" x2="${width - padRight}" y2="$clY" stroke="#0284c7" stroke-width="1.8" stroke-dasharray="4,3"/>''');
    buffer.writeln('''  <text x="${width - padRight + 4}" y="${clY + 3}" font-size="8.5" font-weight="bold" fill="#0284c7" font-family="sans-serif">CL</text>''');

    // LCL line
    final lclY = getY(lcl);
    buffer.writeln('''  <line x1="$padLeft" y1="$lclY" x2="${width - padRight}" y2="$lclY" stroke="#ef4444" stroke-width="1.5" stroke-dasharray="5,4"/>''');
    buffer.writeln('''  <text x="${width - padRight + 4}" y="${lclY + 3}" font-size="8.5" font-weight="bold" fill="#ef4444" font-family="sans-serif">LCL</text>''');

    // Points and polyline
    final stepX = displayPoints.length > 1 ? chartW / (displayPoints.length - 1) : chartW / 2;
    final polyPts = <String>[];
    for (int i = 0; i < displayPoints.length; i++) {
      final x = displayPoints.length > 1 ? padLeft + (i * stepX) : padLeft + chartW / 2;
      final y = getY(displayPoints[i]['val'] as double);
      polyPts.add('$x,$y');
    }

    buffer.writeln('''  <polyline fill="none" stroke="#0284c7" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" points="${polyPts.join(' ')}"/>''');

    for (int i = 0; i < displayPoints.length; i++) {
      final x = displayPoints.length > 1 ? padLeft + (i * stepX) : padLeft + chartW / 2;
      final val = displayPoints[i]['val'] as double;
      final y = getY(val);
      final isOoc = val > ucl || val < lcl;
      final color = isOoc ? '#ef4444' : '#0284c7';
      final radius = isOoc ? 6.0 : 4.5;
      final label = displayPoints[i]['label'] as String;

      buffer.writeln('''  <circle cx="$x" cy="$y" r="$radius" fill="$color" stroke="#ffffff" stroke-width="2"/>''');
      buffer.writeln('''  <text x="$x" y="${padTop + chartH + 16}" text-anchor="middle" font-size="9" font-weight="600" fill="#475569" font-family="sans-serif">$label</text>''');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Generates an SVG Box & Whisker Distribution Analysis Chart (Min, Q1, Median, Q3, Max)
  static String generateBoxPlotSvg(
    List<BallisticRecord> records, {
    String metric = 'Velocity (m/s)',
    double width = 800,
    double height = 230,
  }) {
    // Group records by lot or caliber
    final Map<String, List<double>> groups = {};
    for (var r in records) {
      final double? val = extractParamValue(r, metric);
      if (val != null) {
        final key = r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : r.caliber;
        groups.putIfAbsent(key, () => []).add(val);
      }
    }

    // If fewer than 2 groups, attempt grouping by caliber
    if (groups.length < 2) {
      groups.clear();
      for (var r in records) {
        final double? val = extractParamValue(r, metric);
        if (val != null) {
          groups.putIfAbsent(r.caliber, () => []).add(val);
        }
      }
    }

    if (groups.isEmpty) {
      return '''
      <svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#e2e8f0" stroke-width="1"/>
        <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="#94a3b8" font-size="13" font-family="sans-serif">No Data for Box & Whisker Distribution Analysis</text>
      </svg>
      ''';
    }

    final keys = groups.keys.toList()..sort(_compareNatural);
    final displayKeys = keys.length > 8 ? keys.sublist(keys.length - 8) : keys;

    // Compute stats for each group
    final List<Map<String, dynamic>> stats = [];
    double globalMin = double.infinity;
    double globalMax = -double.infinity;

    for (var key in displayKeys) {
      final vals = groups[key]!..sort();
      final n = vals.length;
      final min = vals.first;
      final max = vals.last;

      double getMedian(List<double> list) {
        if (list.isEmpty) return 0.0;
        final int mid = list.length ~/ 2;
        return (list.length % 2 == 1) ? list[mid] : ((list[mid - 1] + list[mid]) / 2.0);
      }

      final median = getMedian(vals);
      final List<double> lowerHalf = vals.sublist(0, n ~/ 2);
      final List<double> upperHalf = (n % 2 == 0) ? vals.sublist(n ~/ 2) : vals.sublist(n ~/ 2 + 1);
      final q1 = lowerHalf.isNotEmpty ? getMedian(lowerHalf) : min;
      final q3 = upperHalf.isNotEmpty ? getMedian(upperHalf) : max;

      if (min < globalMin) globalMin = min;
      if (max > globalMax) globalMax = max;

      stats.add({
        'label': key.length > 10 ? key.substring(key.length - 10) : key,
        'min': min,
        'q1': q1,
        'median': median,
        'q3': q3,
        'max': max,
        'count': n,
      });
    }

    if (globalMin == double.infinity) {
      globalMin = 0.0;
      globalMax = 100.0;
    }

    final padLeft = 65.0;
    final padRight = 35.0;
    final padTop = 45.0;
    final padBottom = 40.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    final span = globalMax - globalMin;
    final axisMin = globalMin - (span * 0.1);
    final axisMax = globalMax + (span * 0.1);
    final range = (axisMax - axisMin) > 0 ? (axisMax - axisMin) : 10.0;

    double getY(double v) => padTop + chartH - (((v - axisMin) / range) * chartH).clamp(0.0, chartH);

    final buffer = StringBuffer();
    buffer.writeln('''<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f8fafc" rx="8" stroke="#cbd5e1" stroke-width="1"/>''');

    // Title & Legend
    buffer.writeln('''  <text x="$padLeft" y="22" font-size="12" font-weight="bold" fill="#0f172a" font-family="sans-serif">Box & Whisker Distribution Analysis ($metric)</text>''');
    buffer.writeln('''
  <g transform="translate(${width - padRight - 320}, 10)">
    <line x1="0" y1="9" x2="16" y2="9" stroke="#475569" stroke-width="1.8"/>
    <text x="22" y="12" font-size="9" fill="#475569" font-family="sans-serif">Whiskers (Min/Max)</text>
    <rect x="120" y="2" width="14" height="14" rx="2" fill="#bae6fd" stroke="#0284c7" stroke-width="1.2"/>
    <text x="140" y="12" font-size="9" fill="#475569" font-family="sans-serif">IQR (Q1 - Q3)</text>
    <line x1="220" y1="9" x2="236" y2="9" stroke="#f59e0b" stroke-width="2.5"/>
    <text x="242" y="12" font-size="9" fill="#475569" font-family="sans-serif">Median</text>
  </g>
''');

    // Y Grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padTop + chartH - (i * chartH / 4);
      final v = axisMin + (i * range / 4);
      buffer.writeln('''  <line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>''');
      buffer.writeln('''  <text x="${padLeft - 8}" y="${y + 3.5}" text-anchor="end" font-size="9" fill="#64748b" font-family="monospace">${v.toStringAsFixed(1)}</text>''');
    }

    // Boxes & Whiskers
    final groupW = chartW / stats.length;
    final boxW = math.min(36.0, groupW * 0.55);

    for (int i = 0; i < stats.length; i++) {
      final s = stats[i];
      final cx = padLeft + (i * groupW) + (groupW / 2);
      final minY = getY(s['min'] as double);
      final q1Y = getY(s['q1'] as double);
      final medY = getY(s['median'] as double);
      final q3Y = getY(s['q3'] as double);
      final maxY = getY(s['max'] as double);

      // Whisker stem (Min to Max)
      buffer.writeln('''  <line x1="$cx" y1="$minY" x2="$cx" y2="$maxY" stroke="#475569" stroke-width="1.5"/>''');
      // Whisker caps
      buffer.writeln('''  <line x1="${cx - boxW / 3}" y1="$minY" x2="${cx + boxW / 3}" y2="$minY" stroke="#475569" stroke-width="2"/>''');
      buffer.writeln('''  <line x1="${cx - boxW / 3}" y1="$maxY" x2="${cx + boxW / 3}" y2="$maxY" stroke="#475569" stroke-width="2"/>''');

      // Box (Q1 to Q3)
      final boxTop = math.min(q1Y, q3Y);
      final boxHeight = math.max(2.0, (q1Y - q3Y).abs());
      buffer.writeln('''  <rect x="${cx - boxW / 2}" y="$boxTop" width="$boxW" height="$boxHeight" rx="3" fill="#bae6fd" stroke="#0284c7" stroke-width="1.8"/>''');

      // Median Line
      buffer.writeln('''  <line x1="${cx - boxW / 2}" y1="$medY" x2="${cx + boxW / 2}" y2="$medY" stroke="#f59e0b" stroke-width="2.5"/>''');

      // X-axis label
      buffer.writeln('''  <text x="$cx" y="${padTop + chartH + 16}" text-anchor="middle" font-size="9" font-weight="600" fill="#334155" font-family="sans-serif">${s['label']}</text>''');
      buffer.writeln('''  <text x="$cx" y="${padTop + chartH + 28}" text-anchor="middle" font-size="8" fill="#64748b" font-family="sans-serif">n=${s['count']}</text>''');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}
