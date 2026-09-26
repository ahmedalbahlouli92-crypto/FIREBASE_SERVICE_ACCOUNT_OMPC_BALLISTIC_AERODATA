import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/ballistic_record.dart';

// 1. BAR CHART FOR CALIBERS
class CaliberBarChart extends StatelessWidget {
  final Map<String, int> caliberCounts;

  const CaliberBarChart({Key? key, required this.caliberCounts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _BarChartPainter(caliberCounts: caliberCounts),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<String, int> caliberCounts;

  _BarChartPainter({required this.caliberCounts});

  @override
  void paint(Canvas canvas, Size size) {
    if (caliberCounts.isEmpty) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    final double paddingLeft = 40.0;
    final double paddingRight = 10.0;
    final double paddingTop = 25.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final int maxValue = caliberCounts.values.fold(0, (max, val) => val > max ? val : max);
    final int maxAxisValue = maxValue == 0 ? 100 : ((maxValue + 9) ~/ 10) * 10; // round to nearest 10

    // Paint axis grids
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
      
    final textStyle = TextStyle(
      color: const Color(0xFF8E96A3),
      fontSize: 10.0,
      fontFamily: 'Outfit',
    );

    // Draw horizontal grid lines and Y-axis labels
    final int divisions = 4;
    for (int i = 0; i <= divisions; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / divisions);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);
      
      final int value = (i * maxAxisValue ~/ divisions);
      final textPainter = TextPainter(
        text: TextSpan(text: value.toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 8, y - textPainter.height / 2));
    }

    // Draw bars
    final keys = caliberCounts.keys.toList();
    final double barGap = 16.0;
    final double totalGaps = barGap * (keys.length + 1);
    final double barWidth = (chartWidth - totalGaps) / keys.length;

    for (int i = 0; i < keys.length; i++) {
      final String caliber = keys[i];
      final int count = caliberCounts[caliber] ?? 0;
      final double percent = count / maxAxisValue;
      final double barHeight = chartHeight * percent;

      final double x = paddingLeft + barGap + i * (barWidth + barGap);
      final double y = paddingTop + chartHeight - barHeight;

      // Draw Bar Gradient Rect
      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.4),
            const Color(0xFF06B6D4),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      // Draw rounded top bar
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(4.0),
        topRight: const Radius.circular(4.0),
      );
      canvas.drawRRect(rrect, barPaint);

      // Draw count text on top of bar
      final countPainter = TextPainter(
        text: TextSpan(
          text: count.toString(),
          style: textStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 9.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      countPainter.paint(
        canvas,
        Offset(x + (barWidth - countPainter.width) / 2, y - countPainter.height - 4),
      );

      // Draw X-axis label
      String shortLabel = caliber.replaceAll(' NATO', '').replaceAll(' Parabellum', '');
      final labelPainter = TextPainter(
        text: TextSpan(text: shortLabel, style: textStyle.copyWith(fontSize: 9.0)),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(x + (barWidth - labelPainter.width) / 2, paddingTop + chartHeight + 8),
      );
    }
  }

  void _drawNoDataMessage(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: "No logged caliber data yet",
        style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontFamily: 'Outfit'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.caliberCounts != caliberCounts;
  }
}

// 2. DOUGHNUT CHART FOR STATUS
class StatusDoughnutChart extends StatelessWidget {
  final Map<String, int> statusCounts;
  final double yieldRate;

  const StatusDoughnutChart({
    Key? key,
    required this.statusCounts,
    required this.yieldRate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _DoughnutChartPainter(
            statusCounts: statusCounts,
            yieldRate: yieldRate,
          ),
        );
      },
    );
  }
}

class _DoughnutChartPainter extends CustomPainter {
  final Map<String, int> statusCounts;
  final double yieldRate;

  _DoughnutChartPainter({required this.statusCounts, required this.yieldRate});

  @override
  void paint(Canvas canvas, Size size) {
    final int total = statusCounts.values.fold(0, (sum, val) => sum + val);

    final double side = math.min(size.width * 0.5, size.height);
    final Rect chartRect = Rect.fromLTWH(
      (size.width * 0.5 - side) / 2,
      (size.height - side) / 2,
      side,
      side,
    );

    if (total == 0) {
      // Draw placeholder circle
      final emptyPaint = Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.16;
      canvas.drawCircle(chartRect.center, side * 0.4, emptyPaint);
      _drawCenterText(canvas, chartRect, "100%", "YIELD RATE");
      _drawLegend(canvas, size, side);
      return;
    }

    final double strokeWidth = side * 0.16;
    final double radius = (side - strokeWidth) / 2;

    // Ordered segment definitions
    final segments = [
      _DoughnutSegment('Approved', statusCounts['Approved'] ?? 0, const Color(0xFF10B981)),
      _DoughnutSegment('Pending Review', statusCounts['Pending Review'] ?? 0, const Color(0xFFF59E0B)),
      _DoughnutSegment('Rejected', statusCounts['Rejected'] ?? 0, const Color(0xFFEF4444)),
      _DoughnutSegment('Retest', statusCounts['Retest'] ?? 0, const Color(0xFF3B82F6)),
      _DoughnutSegment('Approved with condition', statusCounts['Approved with condition'] ?? 0, const Color(0xFF06B6D4)),
    ];

    double startAngle = -math.pi / 2; // start at top

    for (var segment in segments) {
      if (segment.count == 0) continue;
      final sweepAngle = (segment.count / total) * 2 * math.pi;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: chartRect.center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw central yield rating label
    _drawCenterText(canvas, chartRect, "${yieldRate.toStringAsFixed(1)}%", "YIELD RATE");
    _drawLegend(canvas, size, side);
  }

  void _drawCenterText(Canvas canvas, Rect rect, String value, String label) {
    final valuePainter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFF8E96A3),
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontFamily: 'Outfit',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    valuePainter.paint(
      canvas,
      Offset(rect.center.dx - valuePainter.width / 2, rect.center.dy - valuePainter.height / 1.2),
    );
    labelPainter.paint(
      canvas,
      Offset(rect.center.dx - labelPainter.width / 2, rect.center.dy + 4),
    );
  }

  void _drawLegend(Canvas canvas, Size size, double chartSide) {
    final double legendX = size.width * 0.55;
    final double startY = size.height * 0.22;
    final double rowHeight = 22.0;

    final statuses = [
      _DoughnutSegment('Approved', statusCounts['Approved'] ?? 0, const Color(0xFF10B981)),
      _DoughnutSegment('Pending', statusCounts['Pending Review'] ?? 0, const Color(0xFFF59E0B)),
      _DoughnutSegment('Rejected', statusCounts['Rejected'] ?? 0, const Color(0xFFEF4444)),
      _DoughnutSegment('Retest', statusCounts['Retest'] ?? 0, const Color(0xFF3B82F6)),
      _DoughnutSegment('Cond. Approved', statusCounts['Approved with condition'] ?? 0, const Color(0xFF06B6D4)),
    ];

    for (int i = 0; i < statuses.length; i++) {
      final item = statuses[i];
      final double y = startY + i * rowHeight;

      // Color indicator dot
      final dotPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(legendX + 6, y + 6), 5.0, dotPaint);

      // Label text
      final textPainter = TextPainter(
        text: TextSpan(
          text: "${item.name} (${item.count})",
          style: const TextStyle(
            color: Color(0xFF8E96A3),
            fontSize: 10.5,
            fontFamily: 'Outfit',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(legendX + 20, y));
    }
  }

  @override
  bool shouldRepaint(covariant _DoughnutChartPainter oldDelegate) {
    return oldDelegate.statusCounts != statusCounts || oldDelegate.yieldRate != yieldRate;
  }
}

class _DoughnutSegment {
  final String name;
  final int count;
  final Color color;

  _DoughnutSegment(this.name, this.count, this.color);
}

// 3. NUMERIC LIST FOR CALIBERS (Replaces CaliberBarChart on Dashboard)
const List<String> allCaliberSpecifications = [
  '5.56x45 SS109',
  '5.56x45 M193',
  '5.56x45 .223 69 grains',
  '5.56x45 .223 55 grains',
  '5.56x45 .223 77 grains',
  '5.56x45 M200 Blank',
  '7.62x51 M80',
  '7.62x51 .308',
  '7.62x51 M82',
  '9x19mm Para',
  '9x19mm Luger',
  '9x19mm Match',
  '9x19mm 124 grains CMJ',
];

class CaliberVolumeList extends StatelessWidget {
  final Map<String, int> caliberCounts;

  const CaliberVolumeList({Key? key, required this.caliberCounts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allCaliberSpecifications.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 1.0),
      itemBuilder: (context, index) {
        final caliber = allCaliberSpecifications[index];
        final count = caliberCounts[caliber] ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  caliber,
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'sans-serif'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FC),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFF4D99DB).withOpacity(0.4)),
                ),
                child: Text(
                  '$count rounds',
                  style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.5, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 4. CHART FOR EACH TEST TYPE (SD comparison, Waterproof Leak categories, or general Defects trend)
class TestMetricChart extends StatelessWidget {
  final List<BallisticRecord> filteredRecords;
  final String selectedTestName;

  const TestMetricChart({
    Key? key,
    required this.filteredRecords,
    required this.selectedTestName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _TestMetricPainter(
            filteredRecords: filteredRecords,
            selectedTestName: selectedTestName,
          ),
        );
      },
    );
  }
}

class _TestMetricPainter extends CustomPainter {
  final List<BallisticRecord> filteredRecords;
  final String selectedTestName;

  _TestMetricPainter({
    required this.filteredRecords,
    required this.selectedTestName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (filteredRecords.isEmpty) {
      _drawMessage(canvas, size, "No logged data for current selection");
      return;
    }

    if (selectedTestName == 'Accuracy Test') {
      _paintAccuracyChart(canvas, size);
    } else if (selectedTestName == 'Waterproof Test') {
      _paintWaterproofChart(canvas, size);
    } else if (selectedTestName == 'EPVAT test') {
      _paintEpvatChart(canvas, size);
    } else if (selectedTestName == 'Function Test') {
      _paintFunctionTestChart(canvas, size);
    } else if (selectedTestName == 'Residual Stress Test') {
      _paintResidualStressChart(canvas, size);
    } else if (selectedTestName == 'Firing Rate Cycle Test') {
      _paintFiringRateChart(canvas, size);
    } else {
      _paintGeneralDefectsChart(canvas, size);
    }
  }

  void _drawMessage(Canvas canvas, Size size, String msg) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: msg,
        style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontFamily: 'Outfit'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _paintAccuracyChart(Canvas canvas, Size size) {
    final accRecords = filteredRecords
        .where((r) =>
            r.testName == 'Accuracy Test' &&
            (r.accMeanX.isNotEmpty ||
                r.accMeanY.isNotEmpty ||
                r.accSDX.isNotEmpty ||
                r.accSDY.isNotEmpty))
        .toList();

    if (accRecords.isEmpty) {
      _drawMessage(canvas, size, "No Accuracy Test records found");
      return;
    }

    // Limit to last 8 records to fit cleanly
    final displayRecords =
        accRecords.length > 8 ? accRecords.sublist(accRecords.length - 8) : accRecords;

    final double paddingLeft = 48.0;
    final double paddingRight = 20.0;
    final double paddingTop = 36.0;
    final double paddingBottom = 32.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Calculate (Mean X + Mean Y) / 2 for each record
    final List<double> avgMeans = [];
    for (var r in displayRecords) {
      final mx = double.tryParse(r.accMeanX) ?? 0.0;
      final my = double.tryParse(r.accMeanY) ?? 0.0;
      double avg = 0.0;
      if (mx > 0 && my > 0) {
        avg = (mx + my) / 2.0;
      } else if (mx > 0) {
        avg = mx;
      } else if (my > 0) {
        avg = my;
      } else {
        final sx = double.tryParse(r.accSDX) ?? 0.0;
        final sy = double.tryParse(r.accSDY) ?? 0.0;
        avg = (sx + sy) / 2.0;
      }
      avgMeans.add(avg);
    }

    // Find max value for Y-axis
    double maxVal = avgMeans.fold(0.0, (max, v) => v > max ? v : max);
    if (maxVal <= 0.0) maxVal = 10.0;
    final double maxAxisValue = ((maxVal * 1.25 + 4.9) ~/ 5) * 5.0;

    // Draw Y-axis grid and labels
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(
        color: Color(0xFF64748B), fontSize: 10.0, fontFamily: 'Outfit');

    final int divisions = 4;
    for (int i = 0; i <= divisions; i++) {
      final double y =
          paddingTop + chartHeight - (i * chartHeight / divisions);
      canvas.drawLine(
          Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final double val = (i * maxAxisValue / divisions);
      final textPainter = TextPainter(
        text: TextSpan(text: '${val.toStringAsFixed(1)} mm', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
          canvas, Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2));
    }

    // Draw Legend at top
    _drawLegend(canvas, size, [
      _LegendItem('Avg Mean ((X+Y)/2) mm', const Color(0xFF0284C7)),
    ]);

    // Build trend line points
    final List<Offset> points = [];
    final int count = displayRecords.length;
    for (int i = 0; i < count; i++) {
      final double x = count == 1
          ? paddingLeft + chartWidth / 2
          : paddingLeft + (i / (count - 1)) * chartWidth;
      final double y = paddingTop +
          chartHeight -
          ((avgMeans[i] / maxAxisValue) * chartHeight).clamp(0.0, chartHeight);
      points.add(Offset(x, y));
    }

    // Draw Area gradient under trend line
    if (points.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, paddingTop + chartHeight);
      fillPath.lineTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0284C7).withOpacity(0.22),
            const Color(0xFF0284C7).withOpacity(0.01),
          ],
        ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, chartWidth, chartHeight))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Draw Trend Line
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      final linePaint = Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);
    }

    // Draw Nodes, Values, and Lot labels
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final r = displayRecords[i];
      final val = avgMeans[i];

      // Outer circle (white)
      canvas.drawCircle(pt, 5.5, Paint()..color = Colors.white);
      // Inner circle (Sea-Blue)
      canvas.drawCircle(
          pt, 4.0, Paint()..color = const Color(0xFF0284C7));

      // Value badge above point
      final vPainter = TextPainter(
        text: TextSpan(
          text: '${val.toStringAsFixed(2)} mm',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      vPainter.paint(canvas, Offset(pt.dx - vPainter.width / 2, pt.dy - vPainter.height - 5));

      // Draw X Axis label (Lot No)
      final String lotLabel = r.lotNo.length > 6 ? r.lotNo.substring(r.lotNo.length - 6) : r.lotNo;
      final labelPainter = TextPainter(
        text: TextSpan(
          text: 'Lot $lotLabel',
          style: textStyle.copyWith(fontSize: 9.0, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
          canvas, Offset(pt.dx - labelPainter.width / 2, paddingTop + chartHeight + 6));
    }
  }

  void _paintWaterproofChart(Canvas canvas, Size size) {
    int mouthSlowTotal = 0;
    int mouthFastTotal = 0;
    int primerSlowTotal = 0;
    int primerFastTotal = 0;

    for (var r in filteredRecords) {
      if (r.testName == 'Waterproof Test') {
        mouthSlowTotal += r.mouthSlow;
        mouthFastTotal += r.mouthFast;
        primerSlowTotal += r.primerSlow;
        primerFastTotal += r.primerFast;
      }
    }

    final double paddingLeft = 40.0;
    final double paddingRight = 10.0;
    final double paddingTop = 35.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final List<_DefectBarData> data = [
      _DefectBarData('Mouth Slow', mouthSlowTotal, const Color(0xFF60A5FA)),
      _DefectBarData('Mouth Fast', mouthFastTotal, const Color(0xFFF87171)),
      _DefectBarData('Primer Slow', primerSlowTotal, const Color(0xFF34D399)),
      _DefectBarData('Primer Fast', primerFastTotal, const Color(0xFFFBBF24)),
    ];

    int maxVal = data.fold(0, (max, d) => d.count > max ? d.count : max);
    if (maxVal == 0) maxVal = 10;
    final int maxAxisValue = ((maxVal + 4) ~/ 5) * 5;

    // Draw Y-axis grid and labels
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF8E96A3), fontSize: 10.0, fontFamily: 'Outfit');

    final int divisions = 4;
    for (int i = 0; i <= divisions; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / divisions);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final int val = (i * maxAxisValue ~/ divisions);
      final textPainter = TextPainter(
        text: TextSpan(text: val.toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 8, y - textPainter.height / 2));
    }

    // Draw Bars
    final double barGap = 24.0;
    final double barWidth = (chartWidth - (barGap * 5)) / 4;

    for (int i = 0; i < 4; i++) {
      final item = data[i];
      final double barHeight = chartHeight * (item.count / maxAxisValue);

      final double x = paddingLeft + barGap + i * (barWidth + barGap);
      final double y = paddingTop + chartHeight - barHeight;

      if (barHeight > 0) {
        final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
        final barPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [item.color.withOpacity(0.4), item.color],
          ).createShader(rect)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4.0), topRight: const Radius.circular(4.0)), barPaint);

        // Draw count text on top of bar
        final countPainter = TextPainter(
          text: TextSpan(
            text: item.count.toString(),
            style: textStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 9.5),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        countPainter.paint(canvas, Offset(x + (barWidth - countPainter.width) / 2, y - countPainter.height - 4));
      }

      // Draw X-axis label
      final labelPainter = TextPainter(
        text: TextSpan(text: item.label, style: textStyle.copyWith(fontSize: 9.0)),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(x + (barWidth - labelPainter.width) / 2, paddingTop + chartHeight + 8));
    }
  }

  void _paintGeneralDefectsChart(Canvas canvas, Size size) {
    final List<BallisticRecord> records = filteredRecords;
    final displayRecords = records.length > 6 ? records.sublist(records.length - 6) : records;

    final double paddingLeft = 40.0;
    final double paddingRight = 10.0;
    final double paddingTop = 35.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    int maxVal = displayRecords.fold(0, (max, r) => r.defects > max ? r.defects : max);
    if (maxVal == 0) maxVal = 5;
    final int maxAxisValue = ((maxVal + 4) ~/ 5) * 5;

    // Draw Y-axis grid and labels
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF8E96A3), fontSize: 10.0, fontFamily: 'Outfit');

    final int divisions = 4;
    for (int i = 0; i <= divisions; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / divisions);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final int val = (i * maxAxisValue ~/ divisions);
      final textPainter = TextPainter(
        text: TextSpan(text: val.toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 8, y - textPainter.height / 2));
    }

    // Draw Legend
    _drawLegend(canvas, size, [
      _LegendItem('Defects', const Color(0xFFEF4444)),
    ]);

    // Draw Bars
    final double barGap = 16.0;
    final double totalGaps = barGap * (displayRecords.length + 1);
    final double barWidth = (chartWidth - totalGaps) / displayRecords.length;

    for (int i = 0; i < displayRecords.length; i++) {
      final r = displayRecords[i];
      final double barHeight = chartHeight * (r.defects / maxAxisValue);

      final double x = paddingLeft + barGap + i * (barWidth + barGap);
      final double y = paddingTop + chartHeight - barHeight;

      if (barHeight > 0) {
        final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
        final barPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [const Color(0xFFEF4444).withOpacity(0.4), const Color(0xFFEF4444)],
          ).createShader(rect)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4.0), topRight: const Radius.circular(4.0)), barPaint);

        // Draw count text on top of bar
        final countPainter = TextPainter(
          text: TextSpan(
            text: r.defects.toString(),
            style: textStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 9.0),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        countPainter.paint(canvas, Offset(x + (barWidth - countPainter.width) / 2, y - countPainter.height - 4));
      }

      // Draw X-axis label (Lot No)
      final String lotLabel = r.lotNo.length > 5 ? r.lotNo.substring(r.lotNo.length - 5) : r.lotNo;
      final labelPainter = TextPainter(
        text: TextSpan(text: "Lot $lotLabel", style: textStyle.copyWith(fontSize: 8.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(x + (barWidth - labelPainter.width) / 2, paddingTop + chartHeight + 8));
    }
  }

  void _drawLegend(Canvas canvas, Size size, List<_LegendItem> items) {
    final textStyle = const TextStyle(color: Color(0xFF8E96A3), fontSize: 9.5, fontFamily: 'Outfit');
    double startX = size.width - 10.0;

    for (int i = items.length - 1; i >= 0; i--) {
      final item = items[i];

      final textPainter = TextPainter(
        text: TextSpan(text: item.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      startX -= textPainter.width;
      textPainter.paint(canvas, Offset(startX, 8));

      startX -= 12.0;
      final boxPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(startX, 10, 8, 8), const Radius.circular(2.0)), boxPaint);

      startX -= 16.0;
    }
  }

  void _paintEpvatChart(Canvas canvas, Size size) {
    final epvRecords = filteredRecords
        .where((r) => r.testName == 'EPVAT test')
        .toList();

    if (epvRecords.isEmpty) {
      _drawMessage(canvas, size, "No EPVAT test records found");
      return;
    }

    final displayRecords = epvRecords.length > 5 ? epvRecords.sublist(epvRecords.length - 5) : epvRecords;

    final double paddingLeft = 45.0;
    final double paddingRight = 10.0;
    final double paddingTop = 35.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    double maxPressure = 0.0;
    for (var r in displayRecords) {
      final p1 = double.tryParse(r.epvatMeanPressure) ?? 0.0;
      if (p1 > maxPressure) maxPressure = p1;
    }
    if (maxPressure == 0.0) maxPressure = 4500.0;
    final double maxAxisValue = math.max(4500.0, ((maxPressure + 499) ~/ 500) * 500.0);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF8E96A3), fontSize: 9.5, fontFamily: 'Outfit');

    final int divisions = 4;
    for (int i = 0; i <= divisions; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / divisions);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final double val = (i * maxAxisValue / divisions);
      final textPainter = TextPainter(
        text: TextSpan(text: '${val.toInt()}', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2));
    }

    _drawLegend(canvas, size, [
      _LegendItem('P1 Chamber', const Color(0xFF06B6D4)),
      _LegendItem('P2 Port', const Color(0xFF8B5CF6)),
      _LegendItem('Velocity', const Color(0xFF10B981)),
    ]);

    final double groupWidth = chartWidth / displayRecords.length;
    final double barWidth = math.min(14.0, (groupWidth - 16) / 3);

    for (int i = 0; i < displayRecords.length; i++) {
      final r = displayRecords[i];
      final p1 = double.tryParse(r.epvatMeanPressure) ?? 0.0;
      final p2 = double.tryParse(r.epvatP2MeanPressure) ?? 0.0;
      final vel = double.tryParse(r.velMean) ?? 0.0;

      final double groupCenterX = paddingLeft + (i * groupWidth) + (groupWidth / 2);

      // P1 bar
      final double h1 = chartHeight * (p1 / maxAxisValue);
      final double x1 = groupCenterX - (barWidth * 1.5) - 2;
      final double y1 = paddingTop + chartHeight - h1;
      if (h1 > 0) {
        final rect1 = Rect.fromLTWH(x1, y1, barWidth, h1);
        final paint1 = Paint()..color = const Color(0xFF06B6D4);
        canvas.drawRRect(RRect.fromRectAndCorners(rect1, topLeft: const Radius.circular(3.0), topRight: const Radius.circular(3.0)), paint1);
      }

      // P2 bar
      final double h2 = chartHeight * (p2 / maxAxisValue);
      final double x2 = groupCenterX - (barWidth * 0.5);
      final double y2 = paddingTop + chartHeight - h2;
      if (h2 > 0) {
        final rect2 = Rect.fromLTWH(x2, y2, barWidth, h2);
        final paint2 = Paint()..color = const Color(0xFF8B5CF6);
        canvas.drawRRect(RRect.fromRectAndCorners(rect2, topLeft: const Radius.circular(3.0), topRight: const Radius.circular(3.0)), paint2);
      }

      // Vel bar
      final double h3 = chartHeight * (vel / maxAxisValue);
      final double x3 = groupCenterX + (barWidth * 0.5) + 2;
      final double y3 = paddingTop + chartHeight - h3;
      if (h3 > 0) {
        final rect3 = Rect.fromLTWH(x3, y3, barWidth, h3);
        final paint3 = Paint()..color = const Color(0xFF10B981);
        canvas.drawRRect(RRect.fromRectAndCorners(rect3, topLeft: const Radius.circular(3.0), topRight: const Radius.circular(3.0)), paint3);
      }

      final String label = r.cartridgeTemp.isNotEmpty ? '${r.cartridgeTemp}°C' : (r.lotNo.length > 5 ? r.lotNo.substring(r.lotNo.length - 5) : r.lotNo);
      final labelPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle.copyWith(fontSize: 8.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(groupCenterX - labelPainter.width / 2, paddingTop + chartHeight + 6));
    }
  }

  void _paintFunctionTestChart(Canvas canvas, Size size) {
    final fnRecords = filteredRecords
        .where((r) => r.testName == 'Function Test')
        .toList();

    if (fnRecords.isEmpty) {
      _drawMessage(canvas, size, "No Function Test records found");
      return;
    }

    final displayRecords = fnRecords.length > 6 ? fnRecords.sublist(fnRecords.length - 6) : fnRecords;

    final double paddingLeft = 40.0;
    final double paddingRight = 10.0;
    final double paddingTop = 35.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    int maxDefects = 0;
    for (var r in displayRecords) {
      final m = math.max(math.max(r.functionLevel1, r.functionLevel2), math.max(r.functionLevel3, r.functionLevel4));
      if (m > maxDefects) maxDefects = m;
    }
    if (maxDefects == 0) maxDefects = 5;
    final int maxAxisValue = ((maxDefects + 3) ~/ 4) * 4;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF8E96A3), fontSize: 9.5, fontFamily: 'Outfit');

    final int divisions = 4;
    for (int i = 0; i <= divisions; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / divisions);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final int val = (i * maxAxisValue ~/ divisions);
      final textPainter = TextPainter(
        text: TextSpan(text: '$val', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2));
    }

    _drawLegend(canvas, size, [
      _LegendItem('L1 (Crit)', const Color(0xFFEF4444)),
      _LegendItem('L2 (Maj)', const Color(0xFFF59E0B)),
      _LegendItem('L3 (Min)', const Color(0xFF3B82F6)),
      _LegendItem('L4', const Color(0xFF10B981)),
    ]);

    final double groupWidth = chartWidth / displayRecords.length;
    final double barWidth = math.min(10.0, (groupWidth - 12) / 4);

    for (int i = 0; i < displayRecords.length; i++) {
      final r = displayRecords[i];
      final double groupCenterX = paddingLeft + (i * groupWidth) + (groupWidth / 2);

      // Level 1
      final double h1 = chartHeight * (r.functionLevel1 / maxAxisValue);
      final double x1 = groupCenterX - (barWidth * 2);
      final double y1 = paddingTop + chartHeight - h1;
      if (h1 > 0) {
        canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x1, y1, barWidth, h1), topLeft: const Radius.circular(2.0), topRight: const Radius.circular(2.0)), Paint()..color = const Color(0xFFEF4444));
      }

      // Level 2
      final double h2 = chartHeight * (r.functionLevel2 / maxAxisValue);
      final double x2 = groupCenterX - barWidth;
      final double y2 = paddingTop + chartHeight - h2;
      if (h2 > 0) {
        canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x2, y2, barWidth, h2), topLeft: const Radius.circular(2.0), topRight: const Radius.circular(2.0)), Paint()..color = const Color(0xFFF59E0B));
      }

      // Level 3
      final double h3 = chartHeight * (r.functionLevel3 / maxAxisValue);
      final double x3 = groupCenterX;
      final double y3 = paddingTop + chartHeight - h3;
      if (h3 > 0) {
        canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x3, y3, barWidth, h3), topLeft: const Radius.circular(2.0), topRight: const Radius.circular(2.0)), Paint()..color = const Color(0xFF3B82F6));
      }

      // Level 4
      final double h4 = chartHeight * (r.functionLevel4 / maxAxisValue);
      final double x4 = groupCenterX + barWidth;
      final double y4 = paddingTop + chartHeight - h4;
      if (h4 > 0) {
        canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x4, y4, barWidth, h4), topLeft: const Radius.circular(2.0), topRight: const Radius.circular(2.0)), Paint()..color = const Color(0xFF10B981));
      }

      final String label = r.lotNo.length > 5 ? r.lotNo.substring(r.lotNo.length - 5) : r.lotNo;
      final labelPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle.copyWith(fontSize: 8.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(groupCenterX - labelPainter.width / 2, paddingTop + chartHeight + 6));
    }
  }

  void _paintResidualStressChart(Canvas canvas, Size size) {
    int neck = 0, shoulder = 0, body = 0, head = 0;
    for (var r in filteredRecords) {
      if (r.testName == 'Residual Stress Test') {
        neck += (r.neckSlow + r.neckFast);
        shoulder += (r.shoulderSlow + r.shoulderFast);
        body += (r.bodySlow + r.bodyFast);
        head += (r.headSlow + r.headFast);
      }
    }

    final double paddingLeft = 40.0;
    final double paddingRight = 10.0;
    final double paddingTop = 35.0;
    final double paddingBottom = 30.0;
    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final List<_DefectBarData> data = [
      _DefectBarData('Neck', neck, const Color(0xFF60A5FA)),
      _DefectBarData('Shoulder', shoulder, const Color(0xFFFBBF24)),
      _DefectBarData('Body', body, const Color(0xFFF87171)),
      _DefectBarData('Head', head, const Color(0xFF34D399)),
    ];

    int maxVal = data.fold(0, (max, d) => d.count > max ? d.count : max);
    if (maxVal == 0) maxVal = 5;
    final int maxAxisValue = ((maxVal + 4) ~/ 5) * 5;

    final gridPaint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF8E96A3), fontSize: 10.0, fontFamily: 'Outfit');

    for (int i = 0; i <= 4; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / 4);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);
      final int val = (i * maxAxisValue ~/ 4);
      final tp = TextPainter(text: TextSpan(text: '$val', style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 8, y - tp.height / 2));
    }

    final double barGap = 20.0;
    final double barWidth = (chartWidth - (barGap * 5)) / 4;

    for (int i = 0; i < 4; i++) {
      final item = data[i];
      final double barHeight = chartHeight * (item.count / maxAxisValue);
      final double x = paddingLeft + barGap + i * (barWidth + barGap);
      final double y = paddingTop + chartHeight - barHeight;

      if (barHeight > 0) {
        final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
        canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4.0), topRight: const Radius.circular(4.0)), Paint()..color = item.color);
        final tp = TextPainter(text: TextSpan(text: '${item.count}', style: textStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x + (barWidth - tp.width) / 2, y - tp.height - 4));
      }

      final lp = TextPainter(text: TextSpan(text: item.label, style: textStyle), textDirection: TextDirection.ltr)..layout();
      lp.paint(canvas, Offset(x + (barWidth - lp.width) / 2, paddingTop + chartHeight + 8));
    }
  }

  void _paintFiringRateChart(Canvas canvas, Size size) {
    final frRecords = filteredRecords.where((r) => r.testName == 'Firing Rate Cycle Test' && r.cyclicRateValue.isNotEmpty).toList();
    if (frRecords.isEmpty) {
      _drawMessage(canvas, size, "No Firing Rate records found");
      return;
    }

    final display = frRecords.length > 5 ? frRecords.sublist(frRecords.length - 5) : frRecords;
    final double paddingLeft = 45.0;
    final double paddingRight = 10.0;
    final double paddingTop = 35.0;
    final double paddingBottom = 30.0;
    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final maxAxisValue = 1200.0;
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF8E96A3), fontSize: 9.5, fontFamily: 'Outfit');

    for (int i = 0; i <= 4; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / 4);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);
      final int val = (i * 1200 ~/ 4);
      final tp = TextPainter(text: TextSpan(text: '$val', style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }

    final double groupWidth = chartWidth / display.length;
    final double barWidth = math.min(22.0, groupWidth * 0.4);

    for (int i = 0; i < display.length; i++) {
      final r = display[i];
      final rpm = double.tryParse(r.cyclicRateValue) ?? 0.0;
      final double groupCenterX = paddingLeft + (i * groupWidth) + (groupWidth / 2);
      final double barH = chartHeight * (rpm / maxAxisValue);
      final double x = groupCenterX - barWidth / 2;
      final double y = paddingTop + chartHeight - barH;

      if (barH > 0) {
        final rect = Rect.fromLTWH(x, y, barWidth, barH);
        canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4.0), topRight: const Radius.circular(4.0)), Paint()..color = const Color(0xFFF59E0B));
        final tp = TextPainter(text: TextSpan(text: '${rpm.toInt()}', style: textStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8.5)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x + (barWidth - tp.width) / 2, y - tp.height - 3));
      }

      final String label = r.lotNo.length > 5 ? r.lotNo.substring(r.lotNo.length - 5) : r.lotNo;
      final lp = TextPainter(text: TextSpan(text: label, style: textStyle.copyWith(fontSize: 8.5)), textDirection: TextDirection.ltr)..layout();
      lp.paint(canvas, Offset(groupCenterX - lp.width / 2, paddingTop + chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TestMetricPainter oldDelegate) {
    return oldDelegate.filteredRecords != filteredRecords || oldDelegate.selectedTestName != selectedTestName;
  }
}

class _LegendItem {
  final String label;
  final Color color;
  _LegendItem(this.label, this.color);
}

class _DefectBarData {
  final String label;
  final int count;
  final Color color;
  _DefectBarData(this.label, this.count, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// CALIBER INDIVIDUAL PERFORMANCE WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class CaliberIndividualChart extends StatelessWidget {
  final List<BallisticRecord> records;
  final String caliber;

  const CaliberIndividualChart({
    Key? key,
    required this.records,
    required this.caliber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final calRecords = caliber == 'All' ? records : records.where((r) => r.caliber == caliber).toList();
    if (calRecords.isEmpty) {
      return const Center(
        child: Text('No logged records for this caliber', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 13.0)),
      );
    }

    // Group by test type
    final Map<String, List<BallisticRecord>> testGroups = {};
    for (var r in calRecords) {
      testGroups.putIfAbsent(r.testName, () => []).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              caliber == 'All' ? 'All Calibers Performance' : '$caliber Performance',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              ),
              child: Text(
                '${calRecords.length} Tests Logged',
                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14.0),
        Expanded(
          child: ListView.separated(
            itemCount: testGroups.keys.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 16.0),
            itemBuilder: (context, index) {
              final testName = testGroups.keys.elementAt(index);
              final list = testGroups[testName]!;
              final int qty = list.fold<int>(0, (sum, r) => sum + r.produced);
              final int defects = list.fold<int>(0, (sum, r) => sum + r.defects);
              final int approved = list.where((r) => r.status == 'Approved' || r.status == 'Approved with condition').length;
              final int rejected = list.where((r) => r.status == 'Rejected').length;
              final int retest = list.where((r) => r.status == 'Retest').length;

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(testName, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2.0),
                        Text('$qty rounds tested • $defects defects', style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 10.5)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (approved > 0)
                        _buildBadge('$approved PASS', const Color(0xFF10B981)),
                      if (retest > 0) ...[
                        const SizedBox(width: 4.0),
                        _buildBadge('$retest RETEST', const Color(0xFFF59E0B)),
                      ],
                      if (rejected > 0) ...[
                        const SizedBox(width: 4.0),
                        _buildBadge('$rejected REJ', const Color(0xFFEF4444)),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOX AND WHISKER CHART (Instruction 14)
// Displays Min, Q1, Median, Q3, Max distributions across Lots/Calibers
// ─────────────────────────────────────────────────────────────────────────────
class BoxPlotStats {
  final String label;
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final int sampleCount;

  BoxPlotStats({
    required this.label,
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
    required this.sampleCount,
  });
}

class BoxPlotChart extends StatefulWidget {
  final List<BallisticRecord> records;

  const BoxPlotChart({Key? key, required this.records}) : super(key: key);

  @override
  State<BoxPlotChart> createState() => _BoxPlotChartState();
}

class _BoxPlotChartState extends State<BoxPlotChart> {
  String _selectedMetric = '';
  String _selectedTemperature = 'All Temperatures';

  List<String> _getMetricOptions() {
    final hasPrimer = widget.records.any((r) => r.testName == 'Primer Sensitivity Test');
    final hasPropellant = widget.records.any((r) => r.testName == 'Propellant Test');
    final hasEpvat = widget.records.any((r) => r.testName.contains('EPVAT'));

    final options = <String>[];
    if (hasPrimer) {
      options.addAll([
        'Primer Mean Height H̄ (mm)',
        'Primer Std Dev S (mm)',
        'Primer All-Fire Height (mm)',
      ]);
    }
    if (hasPropellant) {
      options.addAll([
        'Propellant Mean Pressure (bar)',
        'Propellant Velocity (m/s)',
      ]);
    }
    if (hasEpvat || (!hasPrimer && !hasPropellant)) {
      options.addAll([
        'Velocity SD (m/s)',
        'Pressure SD (bar)',
        'Mean Velocity (m/s)',
        'Mean Chamber Pressure (bar)',
      ]);
    }
    if (options.isEmpty) {
      options.addAll(['Velocity SD (m/s)', 'Pressure SD (bar)']);
    }
    return options;
  }

  static const List<String> _temperatureOptions = [
    'All Temperatures',
    '+21 °C',
    '+52 °C',
    '-54 °C',
  ];

  @override
  Widget build(BuildContext context) {
    final metricOptions = _getMetricOptions();
    if (!metricOptions.contains(_selectedMetric)) {
      _selectedMetric = metricOptions.first;
    }
    final statsList = _computeStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8.0,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.candlestick_chart_outlined, color: Color(0xFF0284C7), size: 20.0),
                const SizedBox(width: 8.0),
                const Text(
                  'Box & Whisker Distribution Analysis',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 6.0,
              children: [
                // Metric Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF7DD3FC)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMetric,
                      dropdownColor: const Color(0xFFE0F2FE),
                      style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.0, fontWeight: FontWeight.bold),
                      items: metricOptions.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Color(0xFF0C2A4D))))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedMetric = v);
                      },
                    ),
                  ),
                ),
                // Temperature Filter Dropdown: All, +21 °C, +52 °C, -54 °C
                if (!_selectedMetric.startsWith('Primer'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTemperature,
                        dropdownColor: const Color(0xFFF8FAFC),
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.0, fontWeight: FontWeight.bold),
                        items: _temperatureOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Color(0xFF0F172A))))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedTemperature = v);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        Text(
          'Distribution of $_selectedMetric across evaluated lots based on inspection logs.',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
        ),
        const SizedBox(height: 16.0),
        Expanded(
          child: statsList.isEmpty
              ? Center(
                  child: Text(
                    'No data available for $_selectedMetric at $_selectedTemperature.',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                  ),
                )
              : CustomPaint(
                  size: Size.infinite,
                  painter: _BoxPlotPainter(statsList: statsList, metricName: _selectedMetric),
                ),
        ),
      ],
    );
  }

  List<BoxPlotStats> _computeStats() {
    final Map<String, List<double>> lotValues = {};

    final isPrimerMetric = _selectedMetric.startsWith('Primer');
    final isPropellantMetric = _selectedMetric.startsWith('Propellant');

    final relevantRecords = widget.records.where((r) {
      if (isPrimerMetric) {
        return r.testName == 'Primer Sensitivity Test';
      }
      if (isPropellantMetric) {
        return r.testName == 'Propellant Test';
      }
      final name = r.testName.toLowerCase().trim();
      final isEpvat = name == 'epvat test' || name.contains('epvat');
      if (!isEpvat && !r.testName.contains('Propellant')) return false;

      // Filter by single temperature choice
      if (_selectedTemperature != 'All Temperatures') {
        final tCond = r.cartridgeTemp.trim();
        final tVal = r.roomTemp.trim();
        final cleanFilter = _selectedTemperature.replaceAll('°C', '').trim();
        final matches = tCond.contains(cleanFilter) || tVal.contains(cleanFilter) || tCond == _selectedTemperature || tVal == _selectedTemperature;
        if (!matches) return false;
      }
      return true;
    }).toList();

    for (var r in relevantRecords) {
      final lot = (r.primerLot.trim().isNotEmpty
          ? r.primerLot.trim()
          : (r.propellantLot.trim().isNotEmpty
              ? r.propellantLot.trim()
              : (r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : (r.hopperNo.trim().isNotEmpty ? 'Hopper ${r.hopperNo.trim()}' : 'General'))));
      final List<double> vals = [];

      if (_selectedMetric == 'Primer Mean Height H̄ (mm)') {
        final h = double.tryParse(r.primerHbar);
        if (h != null && h > 0) vals.add(h);
      } else if (_selectedMetric == 'Primer Std Dev S (mm)') {
        final s = double.tryParse(r.primerSD);
        if (s != null && s > 0) vals.add(s);
      } else if (_selectedMetric == 'Primer All-Fire Height (mm)') {
        final af = double.tryParse(r.primerAllFireH);
        if (af != null && af > 0) vals.add(af);
      } else if (_selectedMetric == 'Propellant Mean Pressure (bar)' || _selectedMetric == 'Mean Chamber Pressure (bar)') {
        final p = double.tryParse(r.epvatMeanPressure);
        if (p != null && p > 0) vals.add(p);
      } else if (_selectedMetric == 'Propellant Velocity (m/s)' || _selectedMetric == 'Mean Velocity (m/s)') {
        final v = double.tryParse(r.velMean);
        if (v != null && v > 0) vals.add(v);
      } else if (_selectedMetric == 'Velocity SD (m/s)') {
        final sd = double.tryParse(r.velSD);
        if (sd != null && sd > 0) {
          vals.add(sd);
        } else if (r.epvatVelRounds.isNotEmpty) {
          final parts = r.epvatVelRounds.split(RegExp(r'[,;\s]+'));
          final rounds = <double>[];
          for (var p in parts) {
            final d = double.tryParse(p.trim());
            if (d != null && d > 0) rounds.add(d);
          }
          if (rounds.length > 1) {
            final mean = rounds.reduce((a, b) => a + b) / rounds.length;
            final variance = rounds.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / (rounds.length - 1);
            vals.add(math.sqrt(variance));
          }
        }
      } else if (_selectedMetric == 'Pressure SD (bar)') {
        final sd = double.tryParse(r.epvatSDPressure);
        if (sd != null && sd > 0) {
          vals.add(sd);
        } else if (r.epvatPressureRounds.isNotEmpty) {
          final parts = r.epvatPressureRounds.split(RegExp(r'[,;\s]+'));
          final rounds = <double>[];
          for (var p in parts) {
            final d = double.tryParse(p.trim());
            if (d != null && d > 0) rounds.add(d);
          }
          if (rounds.length > 1) {
            final mean = rounds.reduce((a, b) => a + b) / rounds.length;
            final variance = rounds.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / (rounds.length - 1);
            vals.add(math.sqrt(variance));
          }
        }
      }

      if (vals.isNotEmpty) {
        lotValues.putIfAbsent(lot, () => []).addAll(vals);
      }
    }

    final List<BoxPlotStats> result = [];
    final lots = lotValues.keys.toList();
    final displayLots = lots.length > 7 ? lots.sublist(lots.length - 7) : lots;

    for (var lot in displayLots) {
      final values = lotValues[lot]!;
      values.sort();
      final n = values.length;
      final min = values.first;
      final max = values.last;

      double getMedian(List<double> list) {
        if (list.isEmpty) return 0.0;
        final int mid = list.length ~/ 2;
        return (list.length % 2 == 1) ? list[mid] : ((list[mid - 1] + list[mid]) / 2.0);
      }

      final double median = getMedian(values);
      final List<double> lowerHalf = values.sublist(0, n ~/ 2);
      final List<double> upperHalf = (n % 2 == 0) ? values.sublist(n ~/ 2) : values.sublist(n ~/ 2 + 1);
      final double q1 = lowerHalf.isNotEmpty ? getMedian(lowerHalf) : min;
      final double q3 = upperHalf.isNotEmpty ? getMedian(upperHalf) : max;

      result.add(BoxPlotStats(
        label: lot,
        min: min,
        q1: q1,
        median: median,
        q3: q3,
        max: max,
        sampleCount: n,
      ));
    }

    return result;
  }
}

class _BoxPlotPainter extends CustomPainter {
  final List<BoxPlotStats> statsList;
  final String metricName;

  _BoxPlotPainter({required this.statsList, required this.metricName});

  @override
  void paint(Canvas canvas, Size size) {
    if (statsList.isEmpty) return;

    final double paddingLeft = 55.0;
    final double paddingRight = 20.0;
    final double paddingTop = 30.0;
    final double paddingBottom = 40.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    double globalMin = statsList.first.min;
    double globalMax = statsList.first.max;
    for (var s in statsList) {
      if (s.min < globalMin) globalMin = s.min;
      if (s.max > globalMax) globalMax = s.max;
    }

    if ((globalMax - globalMin).abs() < 1e-6) {
      globalMin -= 10.0;
      globalMax += 10.0;
    }

    final double margin = (globalMax - globalMin) * 0.15;
    final double axisMin = (globalMin - margin).floorToDouble();
    final double axisMax = (globalMax + margin).ceilToDouble();
    final double axisRange = axisMax - axisMin;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFF64748B), fontSize: 10.0, fontFamily: 'Outfit');

    final int divisions = 5;
    for (int i = 0; i <= divisions; i++) {
      final double y = paddingTop + chartHeight - (i * chartHeight / divisions);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final double val = axisMin + (i * axisRange / divisions);
      final textPainter = TextPainter(
        text: TextSpan(text: val.toStringAsFixed(1), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2));
    }

    final double slotWidth = chartWidth / statsList.length;
    final double boxWidth = (slotWidth * 0.45).clamp(16.0, 50.0);

    double toY(double val) {
      return paddingTop + chartHeight - (((val - axisMin) / axisRange) * chartHeight).clamp(0.0, chartHeight);
    }

    for (int i = 0; i < statsList.length; i++) {
      final s = statsList[i];
      final double centerX = paddingLeft + (i * slotWidth) + (slotWidth / 2);

      final double yMin = toY(s.min);
      final double yQ1 = toY(s.q1);
      final double yMedian = toY(s.median);
      final double yQ3 = toY(s.q3);
      final double yMax = toY(s.max);

      final whiskerPaint = Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 2.0;

      // Whiskers
      canvas.drawLine(Offset(centerX, yMin), Offset(centerX, yQ1), whiskerPaint);
      canvas.drawLine(Offset(centerX, yQ3), Offset(centerX, yMax), whiskerPaint);

      // Whisker caps
      final double capWidth = boxWidth * 0.5;
      canvas.drawLine(Offset(centerX - capWidth / 2, yMin), Offset(centerX + capWidth / 2, yMin), whiskerPaint);
      canvas.drawLine(Offset(centerX - capWidth / 2, yMax), Offset(centerX + capWidth / 2, yMax), whiskerPaint);

      // Box
      final boxRect = Rect.fromLTRB(centerX - boxWidth / 2, yQ3, centerX + boxWidth / 2, yQ1);
      final boxFill = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
        ).createShader(boxRect)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(4.0)), boxFill);

      final boxBorder = Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(4.0)), boxBorder);

      // Median Line
      final medianPaint = Paint()
        ..color = const Color(0xFF0369A1)
        ..strokeWidth = 3.0;
      canvas.drawLine(Offset(centerX - boxWidth / 2, yMedian), Offset(centerX + boxWidth / 2, yMedian), medianPaint);

      // Median label
      final medPainter = TextPainter(
        text: TextSpan(
          text: s.median.toStringAsFixed(1),
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 9.0, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      medPainter.paint(canvas, Offset(centerX - medPainter.width / 2, yMedian - medPainter.height / 2));

      // X Axis Lot Label
      final String lotStr = s.label.length > 7 ? s.label.substring(s.label.length - 7) : s.label;
      final labelPainter = TextPainter(
        text: TextSpan(
          text: 'Lot $lotStr',
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(centerX - labelPainter.width / 2, paddingTop + chartHeight + 6));

      // Sample count badge
      final nPainter = TextPainter(
        text: TextSpan(
          text: 'n=${s.sampleCount}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 8.5, fontFamily: 'Outfit'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      nPainter.paint(canvas, Offset(centerX - nPainter.width / 2, paddingTop + chartHeight + 20));
    }
  }

  @override
  bool shouldRepaint(covariant _BoxPlotPainter oldDelegate) => true;
}

