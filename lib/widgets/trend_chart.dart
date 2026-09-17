import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/ballistic_record.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrendLineChart
//   SPC and Trend Analysis for Quality Inspection:
//   Extracts and displays Min, Max, Mean, and SD readings grouped by
//   Lot Number or Hopper No. across all ballistic records.
// ─────────────────────────────────────────────────────────────────────────────
class TrendLineChart extends StatefulWidget {
  final List<BallisticRecord> records;

  const TrendLineChart({Key? key, required this.records}) : super(key: key);

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  String _selectedCaliber = 'All';
  String _selectedGroupBy = 'By Lot Number'; // 'By Lot Number' | 'By Hopper No.' | 'By Individual Test'
  String _selectedParam = 'Mean Velocity (m/s)';

  bool _showMean = true;
  bool _showMax = true;
  bool _showMin = true;
  bool _showSD = true;

  static const List<String> _groupByOptions = [
    'By Lot Number',
    'By Hopper No.',
    'By Individual Test',
  ];

  static const List<String> _paramOptions = [
    'Mean Velocity (m/s)',
    'P1 Chamber Pressure',
    'P2 Port Pressure',
    'Action Time (ms)',
    'Extraction Force (N)',
    'Mean Radius (mm)',
    'Defect Rate (%)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.records.any((r) => double.tryParse(r.velMean) != null)) {
      _selectedParam = 'Mean Velocity (m/s)';
    } else {
      _selectedParam = 'Defect Rate (%)';
    }
  }

  _RecordMetric? _extractRecordMetric(BallisticRecord r) {
    switch (_selectedParam) {
      case 'Mean Velocity (m/s)':
        final mean = double.tryParse(r.velMean);
        if (mean == null) return null;
        final min = double.tryParse(r.velMin) ?? mean;
        final max = double.tryParse(r.velMax) ?? mean;
        final sd = double.tryParse(r.velSD) ?? 0.0;
        return _RecordMetric(mean: mean, min: min, max: max, sd: sd);

      case 'P1 Chamber Pressure':
        final mean = double.tryParse(r.epvatMeanPressure);
        if (mean == null) return null;
        final min = double.tryParse(r.epvatMinPressure) ?? mean;
        final max = double.tryParse(r.epvatMaxPressure) ?? mean;
        final sd = double.tryParse(r.epvatSDPressure) ?? 0.0;
        return _RecordMetric(mean: mean, min: min, max: max, sd: sd);

      case 'P2 Port Pressure':
        final mean = double.tryParse(r.epvatP2MeanPressure);
        if (mean == null) return null;
        final min = double.tryParse(r.epvatP2MinPressure) ?? mean;
        final max = double.tryParse(r.epvatP2MaxPressure) ?? mean;
        final sd = double.tryParse(r.epvatP2SDPressure) ?? 0.0;
        return _RecordMetric(mean: mean, min: min, max: max, sd: sd);

      case 'Action Time (ms)':
        final mean = double.tryParse(r.actionTimeMean);
        if (mean == null) return null;
        final min = double.tryParse(r.actionTimeMin) ?? mean;
        final max = double.tryParse(r.actionTimeMax) ?? mean;
        final sd = double.tryParse(r.actionTimeSD) ?? 0.0;
        return _RecordMetric(mean: mean, min: min, max: max, sd: sd);

      case 'Extraction Force (N)':
        final min = double.tryParse(r.accMinX);
        final max = double.tryParse(r.accMaxX);
        final mean = double.tryParse(r.accMeanX);
        if (min == null && max == null && mean == null) return null;
        final effMean = mean ?? min ?? max!;
        final effMin = min ?? effMean;
        final effMax = max ?? effMean;
        final effSD = double.tryParse(r.accSDX) ?? 0.0;
        return _RecordMetric(mean: effMean, min: effMin, max: effMax, sd: effSD);

      case 'Mean Radius (mm)':
        final mean = double.tryParse(r.accMeanRadius);
        if (mean == null) return null;
        final sd = double.tryParse(r.accSDX) ?? 0.0;
        return _RecordMetric(mean: mean, min: mean, max: mean, sd: sd);

      case 'Defect Rate (%)':
        if (r.produced <= 0) return null;
        final rate = (r.defects / r.produced) * 100.0;
        return _RecordMetric(mean: rate, min: rate, max: rate, sd: 0.0);

      default:
        return null;
    }
  }

  List<_TrendGroupPoint> _buildGroupPoints(List<BallisticRecord> filtered) {
    if (_selectedGroupBy == 'By Individual Test') {
      final List<_TrendGroupPoint> pts = [];
      int testIndex = 1;
      for (int i = 0; i < filtered.length; i++) {
        final metric = _extractRecordMetric(filtered[i]);
        if (metric != null) {
          final lot = filtered[i].lotNo.trim();
          pts.add(_TrendGroupPoint(
            index: pts.length,
            label: 'Test $testIndex',
            subLabel: lot.isNotEmpty ? 'Lot $lot' : filtered[i].timestamp.split(' ')[0],
            min: metric.min,
            max: metric.max,
            mean: metric.mean,
            sd: metric.sd,
            recordCount: 1,
          ));
          testIndex++;
        }
      }
      return pts;
    }

    // Grouping by Lot Number or Hopper No.
    final Map<String, List<_RecordMetric>> groups = {};
    for (var r in filtered) {
      final key = _selectedGroupBy == 'By Hopper No.'
          ? (r.hopperNo.trim().isNotEmpty ? r.hopperNo.trim() : (r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : 'N/A'))
          : (r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : 'Lot N/A');

      final metric = _extractRecordMetric(r);
      if (metric != null) {
        groups.putIfAbsent(key, () => []).add(metric);
      }
    }

    final List<_TrendGroupPoint> pts = [];
    int idx = 0;
    groups.forEach((groupKey, metricsList) {
      if (metricsList.isEmpty) return;

      final double overallMin = metricsList.map((m) => m.min).reduce(math.min);
      final double overallMax = metricsList.map((m) => m.max).reduce(math.max);
      final double overallMean = metricsList.map((m) => m.mean).reduce((a, b) => a + b) / metricsList.length;
      final double overallSD = metricsList.map((m) => m.sd).reduce((a, b) => a + b) / metricsList.length;

      final prefix = _selectedGroupBy == 'By Hopper No.' ? 'Hop ' : 'Lot ';

      pts.add(_TrendGroupPoint(
        index: idx++,
        label: '$prefix$groupKey',
        subLabel: '${metricsList.length} test${metricsList.length > 1 ? 's' : ''}',
        min: overallMin,
        max: overallMax,
        mean: overallMean,
        sd: overallSD,
        recordCount: metricsList.length,
      ));
    });

    return pts;
  }

  @override
  Widget build(BuildContext context) {
    // Caliber filter list
    final calibers = ['All', ...widget.records.map((r) => r.caliber).where((c) => c.isNotEmpty).toSet().toList()..sort()];
    if (!calibers.contains(_selectedCaliber)) _selectedCaliber = 'All';

    // Filter + extract data points
    final filtered = _selectedCaliber == 'All'
        ? widget.records
        : widget.records.where((r) => r.caliber == _selectedCaliber).toList();

    final points = _buildGroupPoints(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header & Description ────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF06B6D4), size: 20.0),
            const SizedBox(width: 8.0),
            const Expanded(
              child: Text(
                'Lot & Hopper Statistical Trend Analysis (SPC)',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              ),
              child: Text(
                '${points.length} Groups Evaluated',
                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        const Text(
          'Statistical process control chart displaying Min, Max, Mean, and SD readings from each lot or hopper.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF8E96A3)),
        ),
        const SizedBox(height: 14.0),

        // ─── Filter row & Group By ───────────────────────────────────
        Wrap(
          spacing: 12.0,
          runSpacing: 10.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildDropdown(
              label: 'CALIBER SPECIFICATION',
              value: _selectedCaliber,
              items: calibers,
              onChanged: (v) => setState(() => _selectedCaliber = v!),
            ),
            _buildDropdown(
              label: 'GROUP READINGS BY',
              value: _selectedGroupBy,
              items: _groupByOptions,
              onChanged: (v) => setState(() => _selectedGroupBy = v!),
            ),
            _buildDropdown(
              label: 'BALLISTIC PARAMETER',
              value: _selectedParam,
              items: _paramOptions,
              onChanged: (v) => setState(() => _selectedParam = v!),
            ),
            // Metric toggle pills
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMetricChip('Mean', _showMean, const Color(0xFF06B6D4), () => setState(() => _showMean = !_showMean)),
                  const SizedBox(width: 6.0),
                  _buildMetricChip('Max', _showMax, const Color(0xFFF59E0B), () => setState(() => _showMax = !_showMax)),
                  const SizedBox(width: 6.0),
                  _buildMetricChip('Min', _showMin, const Color(0xFF10B981), () => setState(() => _showMin = !_showMin)),
                  const SizedBox(width: 6.0),
                  _buildMetricChip('SD', _showSD, const Color(0xFFA855F7), () => setState(() => _showSD = !_showSD)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),

        // ─── Chart area ───────────────────────────────────────────────
        Expanded(
          child: points.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.query_stats_outlined,
                          color: Colors.white.withOpacity(0.15), size: 48.0),
                      const SizedBox(height: 12.0),
                      Text(
                        'No readings available for "$_selectedParam"\nunder $_selectedGroupBy ($selectedCaliberLabel)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (ctx, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _MultiMetricTrendPainter(
                        points: points,
                        paramLabel: _selectedParam,
                        showMean: _showMean,
                        showMax: _showMax,
                        showMin: _showMin,
                        showSD: _showSD,
                      ),
                    );
                  },
                ),
        ),

        // ─── Bottom Legend ────────────────────────────────────────────
        const SizedBox(height: 8.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Mean Reading', const Color(0xFF06B6D4)),
            const SizedBox(width: 16.0),
            _buildLegendItem('Max Reading', const Color(0xFFF59E0B)),
            const SizedBox(width: 16.0),
            _buildLegendItem('Min Reading', const Color(0xFF10B981)),
            const SizedBox(width: 16.0),
            _buildLegendItem('Std Deviation (SD)', const Color(0xFFA855F7)),
          ],
        ),
      ],
    );
  }

  String get selectedCaliberLabel => _selectedCaliber == 'All' ? 'All Calibers' : _selectedCaliber;

  Widget _buildMetricChip(String label, bool isSelected, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7.0,
              height: 7.0,
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8E96A3),
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.0,
          height: 3.0,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 5.0),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 10.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E96A3),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(7.0),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              dropdownColor: const Color(0xFF111524),
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              isDense: true,
              items: items
                  .map((i) => DropdownMenuItem<String>(
                        value: i,
                        child: Text(i, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _RecordMetric {
  final double mean;
  final double min;
  final double max;
  final double sd;

  _RecordMetric({
    required this.mean,
    required this.min,
    required this.max,
    required this.sd,
  });
}

class _TrendGroupPoint {
  final int index;
  final String label;
  final String subLabel;
  final double min;
  final double max;
  final double mean;
  final double sd;
  final int recordCount;

  _TrendGroupPoint({
    required this.index,
    required this.label,
    required this.subLabel,
    required this.min,
    required this.max,
    required this.mean,
    required this.sd,
    required this.recordCount,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-Metric CustomPainter (Min, Max, Mean, SD)
// ─────────────────────────────────────────────────────────────────────────────
class _MultiMetricTrendPainter extends CustomPainter {
  final List<_TrendGroupPoint> points;
  final String paramLabel;
  final bool showMean;
  final bool showMax;
  final bool showMin;
  final bool showSD;

  _MultiMetricTrendPainter({
    required this.points,
    required this.paramLabel,
    required this.showMean,
    required this.showMax,
    required this.showMin,
    required this.showSD,
  });

  static const _padding = EdgeInsets.fromLTRB(48.0, 24.0, 24.0, 42.0);
  static const _gridColor = Color(0xFF1F293D);
  static const _labelColor = Color(0xFF8E96A3);

  static const _colorMean = Color(0xFF06B6D4); // Cyan
  static const _colorMax = Color(0xFFF59E0B);  // Amber
  static const _colorMin = Color(0xFF10B981);  // Emerald
  static const _colorSD = Color(0xFFA855F7);   // Purple

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chartRect = Rect.fromLTRB(
      _padding.left,
      _padding.top,
      size.width - _padding.right,
      size.height - _padding.bottom,
    );
    if (chartRect.width <= 0 || chartRect.height <= 0) return;

    // ─── Compute Global Range across all active series ───────────────
    final List<double> allActiveValues = [];
    for (var p in points) {
      if (showMean) allActiveValues.add(p.mean);
      if (showMax) allActiveValues.add(p.max);
      if (showMin) allActiveValues.add(p.min);
      if (showSD) allActiveValues.add(p.sd);
    }
    if (allActiveValues.isEmpty) {
      for (var p in points) {
        allActiveValues.add(p.mean);
      }
    }

    double minVal = allActiveValues.reduce(math.min);
    double maxVal = allActiveValues.reduce(math.max);
    if ((maxVal - minVal).abs() < 1e-6) {
      minVal -= 1.0;
      maxVal += 1.0;
    }
    final valRange = maxVal - minVal;
    final paddedMin = minVal - valRange * 0.15;
    final paddedMax = maxVal + valRange * 0.20;
    final paddedRange = paddedMax - paddedMin;

    double toY(double v) =>
        chartRect.bottom - ((v - paddedMin) / paddedRange) * chartRect.height;
    double toX(int i) => points.length == 1
        ? chartRect.center.dx
        : chartRect.left + (i / (points.length - 1)) * chartRect.width;

    // ─── Grid lines & Y-axis labels ──────────────────────────────────
    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1.0;
    const gridLines = 5;
    final textStyle = const TextStyle(
        color: _labelColor, fontSize: 9.0, fontFamily: 'JetBrainsMono');
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int g = 0; g <= gridLines; g++) {
      final frac = g / gridLines;
      final y = chartRect.top + frac * chartRect.height;
      canvas.drawLine(
          Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
      final labelVal = paddedMax - frac * paddedRange;
      tp.text = TextSpan(text: _formatVal(labelVal), style: textStyle);
      tp.layout();
      tp.paint(canvas, Offset(chartRect.left - tp.width - 6.0, y - tp.height / 2));
    }

    // ─── Dispersion Band (Between Min and Max) ─────────────────────────
    if (showMin && showMax && points.length > 1) {
      final bandPath = Path();
      // Forward along Max
      for (int i = 0; i < points.length; i++) {
        final pt = Offset(toX(i), toY(points[i].max));
        if (i == 0) {
          bandPath.moveTo(pt.dx, pt.dy);
        } else {
          final prev = Offset(toX(i - 1), toY(points[i - 1].max));
          final cp1 = Offset(prev.dx + (pt.dx - prev.dx) / 3, prev.dy);
          final cp2 = Offset(pt.dx - (pt.dx - prev.dx) / 3, pt.dy);
          bandPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pt.dx, pt.dy);
        }
      }
      // Backward along Min
      for (int i = points.length - 1; i >= 0; i--) {
        final pt = Offset(toX(i), toY(points[i].min));
        if (i == points.length - 1) {
          bandPath.lineTo(pt.dx, pt.dy);
        } else {
          final prev = Offset(toX(i + 1), toY(points[i + 1].min));
          final cp1 = Offset(prev.dx + (pt.dx - prev.dx) / 3, prev.dy);
          final cp2 = Offset(pt.dx - (pt.dx - prev.dx) / 3, pt.dy);
          bandPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pt.dx, pt.dy);
        }
      }
      bandPath.close();
      canvas.drawPath(
        bandPath,
        Paint()..color = const Color(0xFF06B6D4).withOpacity(0.06),
      );
    }

    // ─── Draw Series Lines ────────────────────────────────────────────
    void drawSeries(
      List<double> values,
      Color color, {
      bool drawBadges = false,
      String prefix = '',
    }) {
      if (values.isEmpty) return;

      final pts = [for (int i = 0; i < values.length; i++) Offset(toX(i), toY(values[i]))];

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final linePath = Path();
      for (int i = 0; i < pts.length; i++) {
        if (i == 0) {
          linePath.moveTo(pts[0].dx, pts[0].dy);
        } else {
          final prev = pts[i - 1];
          final curr = pts[i];
          final cp1 = Offset(prev.dx + (curr.dx - prev.dx) / 3, prev.dy);
          final cp2 = Offset(curr.dx - (curr.dx - prev.dx) / 3, curr.dy);
          linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
        }
      }
      canvas.drawPath(linePath, linePaint);

      // Dots & Badges
      final dotPaint = Paint()..color = color;
      final dotBgPaint = Paint()..color = const Color(0xFF090C15);

      for (int i = 0; i < pts.length; i++) {
        final pt = pts[i];
        canvas.drawCircle(pt, 4.5, dotBgPaint);
        canvas.drawCircle(pt, 3.0, dotPaint);

        if (drawBadges) {
          final valText = prefix.isNotEmpty ? '$prefix ${_formatVal(values[i])}' : _formatVal(values[i]);
          final tpVal = TextPainter(
            text: TextSpan(
              text: valText,
              style: TextStyle(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final pillRect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(pt.dx, pt.dy - 13.0),
              width: tpVal.width + 6.0,
              height: tpVal.height + 3.0,
            ),
            const Radius.circular(3.0),
          );
          canvas.drawRRect(pillRect, Paint()..color = const Color(0xFF0D1527));
          canvas.drawRRect(
            pillRect,
            Paint()
              ..color = color.withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.7,
          );
          tpVal.paint(canvas, Offset(pt.dx - tpVal.width / 2, pt.dy - 13.0 - tpVal.height / 2));
        }
      }
    }

    if (showMin) {
      drawSeries(points.map((p) => p.min).toList(), _colorMin, drawBadges: !showMean && !showMax, prefix: 'Min');
    }
    if (showMax) {
      drawSeries(points.map((p) => p.max).toList(), _colorMax, drawBadges: !showMean, prefix: 'Max');
    }
    if (showSD) {
      drawSeries(points.map((p) => p.sd).toList(), _colorSD, drawBadges: !showMean && !showMax && !showMin, prefix: 'SD');
    }
    if (showMean) {
      drawSeries(points.map((p) => p.mean).toList(), _colorMean, drawBadges: true);
    }

    // ─── X-axis Labels (Lot / Hopper / Test) ───────────────────────────
    final step = math.max(1, (points.length / 10).ceil());
    for (int i = 0; i < points.length; i += step) {
      final x = toX(i);
      final pt = points[i];

      // Primary label: Lot 24-001, Hop 1, Test 1...
      tp.text = TextSpan(
        text: pt.label,
        style: textStyle.copyWith(
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFE2E8F0),
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartRect.bottom + 4.0));

      // Sub-label: e.g. "3 tests" or timestamp
      tp.text = TextSpan(
        text: pt.subLabel,
        style: textStyle.copyWith(fontSize: 8.0, color: const Color(0xFF64748B)),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartRect.bottom + 16.0));
    }
  }

  String _formatVal(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant _MultiMetricTrendPainter old) =>
      old.points != points ||
      old.paramLabel != paramLabel ||
      old.showMean != showMean ||
      old.showMax != showMax ||
      old.showMin != showMin ||
      old.showSD != showSD;
}
