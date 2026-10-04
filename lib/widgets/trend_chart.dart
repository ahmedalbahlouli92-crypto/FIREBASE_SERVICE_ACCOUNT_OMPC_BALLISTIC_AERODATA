import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/ballistic_record.dart';
import '../services/report_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrendLineChart
//   SPC and Trend Analysis for Quality Inspection:
//   Extracts and displays Min, Max, Mean, and SD readings grouped by
//   Lot Number or Hopper No. across all ballistic records.
// ─────────────────────────────────────────────────────────────────────────────
class TrendLineChart extends StatefulWidget {
  final List<BallisticRecord> records;
  final String? selectedTestType;

  const TrendLineChart({Key? key, required this.records, this.selectedTestType}) : super(key: key);

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  String _selectedCaliber = 'All';
  String _selectedTestType = 'Select Test Type';
  String _selectedGroupBy = 'By Lot Number'; // 'By Lot Number' | 'By Hopper No.' | 'By Individual Test'
  String _selectedParam = '';
  String _selectedTimeRange = 'All Time';

  bool _showMean = true;
  bool _showMax = true;
  bool _showMin = true;
  bool _showSD = true;

  bool _showFourCharts = true;

  List<String> _selectedMultiParams = [];

  bool get _isTestChosen =>
      _selectedTestType.isNotEmpty &&
      _selectedTestType != 'Select Test Type' &&
      _selectedTestType != 'All';

  void _initMultiParamsForTest(String testType) {
    if (testType.isEmpty || testType == 'Select Test Type' || testType == 'All') {
      _selectedMultiParams = [];
      _selectedParam = '';
      return;
    }

    final available = _getParamsForTestType(testType);
    final default4 = _get4ParamsForTestType(testType);
    _selectedMultiParams = default4.where((p) => available.contains(p)).take(4).toList();
    if (_selectedMultiParams.isEmpty && available.isNotEmpty) {
      _selectedMultiParams = available.take(math.min(4, available.length)).toList();
    }
    if (!available.contains(_selectedParam)) {
      _selectedParam = available.isNotEmpty ? available.first : '';
    }
    _showFourCharts = _selectedMultiParams.length > 1;
    _showMean = true;
    _showMax = true;
    _showMin = true;
    _showSD = true;
  }

  static const List<String> _timeRangeOptions = [
    'All Time',
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'This Year',
  ];

  static const List<String> _groupByOptions = [
    'By Lot Number',
    'By Hopper No.',
    'By Individual Test',
  ];

  List<String> _get4ParamsForTestType(String testType) {
    final lower = testType.toLowerCase();
    if (lower.contains('waterproof')) {
      return [
        'Total Fast Leaks',
        'Total Slow Leaks',
        'Total Leaks',
      ];
    } else if (lower.contains('accuracy')) {
      return [
        'Average SD (X & Y)',
        'Mean Radius (mm)',
        'SD X (mm)',
        'SD Y (mm)',
      ];
    } else if (lower.contains('epvat')) {
      return [
        'Mean Velocity (m/s)',
        'P1 Chamber Pressure (bar)',
        'P2 Port Pressure (bar)',
        'Action Time (ms)',
      ];
    } else if (lower.contains('stress')) {
      return [
        'Number of Cracks (Total Splits)',
        'Neck Splits',
        'Shoulder Splits',
        'Body Splits',
      ];
    } else if (lower.contains('primer')) {
      return [
        'HM + 5SD (All Fire, mm)',
        'HM - 2SD (No Fire, mm)',
        'Mean Height H̄ (mm)',
        'Std Deviation S (mm)',
      ];
    } else if (lower.contains('function')) {
      return [
        'Total Defects',
        'Level 1 Critical Defects',
        'Level 2 Major Defects',
        'Level 3 Minor Defects',
      ];
    } else if (lower.contains('extraction')) {
      return [
        'Extraction Force (N)',
        'Min Force (N)',
        'Max Force (N)',
      ];
    } else if (lower.contains('firing rate') || lower.contains('cyclic')) {
      return [
        'Cyclic Rate (RPM)',
      ];
    } else if (lower.contains('terminal')) {
      return [
        'Terminal Velocity (m/s)',
      ];
    }
    return [];
  }

  List<String> _getParamsForTestType(String testType) {
    final lower = testType.toLowerCase();
    if (lower.contains('waterproof')) {
      return [
        'Total Fast Leaks',
        'Total Slow Leaks',
        'Total Leaks',
      ];
    } else if (lower.contains('accuracy')) {
      return [
        'Average SD (X & Y)',
        'Mean Radius (mm)',
        'SD X (mm)',
        'SD Y (mm)',
        'Mean Velocity (m/s)',
      ];
    } else if (lower.contains('epvat')) {
      return [
        'Mean Velocity (m/s)',
        'P1 Chamber Pressure (bar)',
        'P1 Max Pressure (bar)',
        'P1 SD Pressure (bar)',
        'P2 Port Pressure (bar)',
        'P2 Max Pressure (bar)',
        'P2 SD Pressure (bar)',
        'Action Time (ms)',
        'Velocity SD (m/s)',
      ];
    } else if (lower.contains('stress')) {
      return [
        'Number of Cracks (Total Splits)',
        'Neck Splits',
        'Shoulder Splits',
        'Body Splits',
        'Head Splits',
      ];
    } else if (lower.contains('primer')) {
      return [
        'HM + 5SD (All Fire, mm)',
        'HM - 2SD (No Fire, mm)',
        'Mean Height H̄ (mm)',
        'Std Deviation S (mm)',
      ];
    } else if (lower.contains('function')) {
      return [
        'Total Defects',
        'Level 1 Critical Defects',
        'Level 2 Major Defects',
        'Level 3 Minor Defects',
        'Level 4 Defects',
        'Defect Rate (%)',
      ];
    } else if (lower.contains('extraction')) {
      return [
        'Extraction Force (N)',
        'Min Force (N)',
        'Max Force (N)',
      ];
    } else if (lower.contains('firing rate') || lower.contains('cyclic')) {
      return [
        'Cyclic Rate (RPM)',
      ];
    } else if (lower.contains('terminal')) {
      return [
        'Terminal Velocity (m/s)',
      ];
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedTestType != null &&
        widget.selectedTestType!.isNotEmpty &&
        widget.selectedTestType != 'All' &&
        widget.selectedTestType != 'Select Test Type') {
      _selectedTestType = widget.selectedTestType!;
    } else {
      _selectedTestType = 'Select Test Type';
    }
    _initMultiParamsForTest(_selectedTestType);
  }

  @override
  void didUpdateWidget(TrendLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTestType != null && widget.selectedTestType != _selectedTestType) {
      final newType = (widget.selectedTestType!.isNotEmpty && widget.selectedTestType != 'All')
          ? widget.selectedTestType!
          : 'Select Test Type';
      if (newType != _selectedTestType) {
        setState(() {
          _selectedTestType = newType;
          _initMultiParamsForTest(_selectedTestType);
        });
      }
    }
  }

  _RecordMetric? _extractRecordMetric(BallisticRecord r, {String? paramOverride}) {
    final param = paramOverride ?? _selectedParam;
    switch (param) {
      case 'Mean Velocity (m/s)':
        final mean = double.tryParse(r.velMean);
        if (mean == null) return null;
        final min = double.tryParse(r.velMin) ?? mean;
        final max = double.tryParse(r.velMax) ?? mean;
        final sd = double.tryParse(r.velSD) ?? 0.0;
        return _RecordMetric(mean: mean, min: min, max: max, sd: sd);

      case 'P1 Chamber Pressure (bar)':
      case 'P1 Chamber Pressure':
        final mean = double.tryParse(r.epvatMeanPressure);
        if (mean == null) return null;
        final min = double.tryParse(r.epvatMinPressure) ?? mean;
        final max = double.tryParse(r.epvatMaxPressure) ?? mean;
        final sd = double.tryParse(r.epvatSDPressure) ?? 0.0;
        return _RecordMetric(mean: mean, min: min, max: max, sd: sd);

      case 'P2 Port Pressure (bar)':
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

      case 'Extreme Spread X (mm)':
        final mean = double.tryParse(r.accMeanX);
        final max = double.tryParse(r.accMaxX);
        final min = double.tryParse(r.accMinX);
        final val = double.tryParse(r.accRangeX) ?? (max != null && min != null ? max - min : mean);
        if (val == null) return null;
        return _RecordMetric(mean: val, min: min ?? val, max: max ?? val, sd: double.tryParse(r.accSDX) ?? 0.0);

      case 'Extreme Spread Y (mm)':
        final mean = double.tryParse(r.accMeanY);
        final max = double.tryParse(r.accMaxY);
        final min = double.tryParse(r.accMinY);
        final val = double.tryParse(r.accRangeY) ?? (max != null && min != null ? max - min : mean);
        if (val == null) return null;
        return _RecordMetric(mean: val, min: min ?? val, max: max ?? val, sd: double.tryParse(r.accSDY) ?? 0.0);

      case 'SD Velocity (m/s)':
        final sd = double.tryParse(r.velSD);
        if (sd == null) return null;
        return _RecordMetric(mean: sd, min: sd, max: sd, sd: 0.0);

      case 'Defect Rate (%)':
        if (r.produced <= 0) return null;
        final rate = (r.defects / r.produced) * 100.0;
        return _RecordMetric(mean: rate, min: rate, max: rate, sd: 0.0);

      case 'Total Defects':
        return _RecordMetric(mean: r.defects.toDouble(), min: r.defects.toDouble(), max: r.defects.toDouble(), sd: 0.0);

      case 'Level 1 Critical Defects':
        final d = r.functionLevel1.toDouble();
        return _RecordMetric(mean: d, min: d, max: d, sd: 0.0);

      case 'Level 2 Major Defects':
        final d = r.functionLevel2.toDouble();
        return _RecordMetric(mean: d, min: d, max: d, sd: 0.0);

      case 'Level 3 Minor Defects':
        final d = r.functionLevel3.toDouble();
        return _RecordMetric(mean: d, min: d, max: d, sd: 0.0);

      case 'Level 4 Defects':
        final d = r.functionLevel4.toDouble();
        return _RecordMetric(mean: d, min: d, max: d, sd: 0.0);

      case 'Total Function Defects':
        final d = (r.functionLevel1 + r.functionLevel2 + r.functionLevel3 + r.functionLevel4).toDouble();
        return _RecordMetric(mean: d, min: d, max: d, sd: 0.0);

      case 'Total Fast Leaks':
        final fast = (r.mouthFast + r.primerFast).toDouble();
        return _RecordMetric(mean: fast, min: fast, max: fast, sd: 0.0);

      case 'Total Slow Leaks':
        final slow = (r.mouthSlow + r.primerSlow).toDouble();
        return _RecordMetric(mean: slow, min: slow, max: slow, sd: 0.0);

      case 'Total Leaks':
        final leaks = (r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast).toDouble();
        return _RecordMetric(mean: leaks, min: leaks, max: leaks, sd: 0.0);

      case 'Average SD (X & Y)':
        final sx = double.tryParse(r.accSDX);
        final sy = double.tryParse(r.accSDY);
        if (sx == null && sy == null) return null;
        final avg = (sx != null && sy != null) ? ((sx + sy) / 2.0) : (sx ?? sy!);
        return _RecordMetric(mean: avg, min: avg, max: avg, sd: 0.0);

      case 'SD X (mm)':
        final sx = double.tryParse(r.accSDX);
        if (sx == null) return null;
        return _RecordMetric(mean: sx, min: sx, max: sx, sd: 0.0);

      case 'SD Y (mm)':
        final sy = double.tryParse(r.accSDY);
        if (sy == null) return null;
        return _RecordMetric(mean: sy, min: sy, max: sy, sd: 0.0);

      case 'P1 Max Pressure (bar)':
        final p1Max = double.tryParse(r.epvatMaxPressure);
        if (p1Max == null) return null;
        return _RecordMetric(mean: p1Max, min: p1Max, max: p1Max, sd: 0.0);

      case 'P1 SD Pressure (bar)':
        final p1Sd = double.tryParse(r.epvatSDPressure);
        if (p1Sd == null) return null;
        return _RecordMetric(mean: p1Sd, min: p1Sd, max: p1Sd, sd: 0.0);

      case 'P2 Max Pressure (bar)':
        final p2Max = double.tryParse(r.epvatP2MaxPressure);
        if (p2Max == null) return null;
        return _RecordMetric(mean: p2Max, min: p2Max, max: p2Max, sd: 0.0);

      case 'P2 SD Pressure (bar)':
        final p2Sd = double.tryParse(r.epvatP2SDPressure);
        if (p2Sd == null) return null;
        return _RecordMetric(mean: p2Sd, min: p2Sd, max: p2Sd, sd: 0.0);

      case 'Velocity SD (m/s)':
      case 'SD Velocity (m/s)':
        final sd = double.tryParse(r.velSD);
        if (sd == null) return null;
        return _RecordMetric(mean: sd, min: sd, max: sd, sd: 0.0);

      case 'Number of Cracks (Total Splits)':
      case 'Total Splits':
        final splits = (r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast).toDouble();
        return _RecordMetric(mean: splits, min: splits, max: splits, sd: 0.0);

      case 'Neck Splits':
        final splits = (r.neckSlow + r.neckFast).toDouble();
        return _RecordMetric(mean: splits, min: splits, max: splits, sd: 0.0);

      case 'Shoulder Splits':
        final splits = (r.shoulderSlow + r.shoulderFast).toDouble();
        return _RecordMetric(mean: splits, min: splits, max: splits, sd: 0.0);

      case 'Body Splits':
        final splits = (r.bodySlow + r.bodyFast).toDouble();
        return _RecordMetric(mean: splits, min: splits, max: splits, sd: 0.0);

      case 'Head Splits':
        final splits = (r.headSlow + r.headFast).toDouble();
        return _RecordMetric(mean: splits, min: splits, max: splits, sd: 0.0);

      case 'HM + 5SD (All Fire, mm)':
      case 'All Fire H̄+5S (mm)':
        double? af = double.tryParse(r.primerAllFireH);
        if (af == null) {
          final hm = double.tryParse(r.primerHbar);
          final sd = double.tryParse(r.primerSD);
          if (hm != null && sd != null) af = hm + (5 * sd);
        }
        if (af == null) return null;
        return _RecordMetric(mean: af, min: af, max: af, sd: 0.0);

      case 'HM - 2SD (No Fire, mm)':
      case 'No Fire H̄-2S (mm)':
        double? nf = double.tryParse(r.primerNoFireH);
        if (nf == null) {
          final hm = double.tryParse(r.primerHbar);
          final sd = double.tryParse(r.primerSD);
          if (hm != null && sd != null) nf = hm - (2 * sd);
        }
        if (nf == null) return null;
        return _RecordMetric(mean: nf, min: nf, max: nf, sd: 0.0);

      case 'Min Force (N)':
        final minF = double.tryParse(r.accMinX);
        if (minF == null) return null;
        return _RecordMetric(mean: minF, min: minF, max: minF, sd: 0.0);

      case 'Max Force (N)':
        final maxF = double.tryParse(r.accMaxX);
        if (maxF == null) return null;
        return _RecordMetric(mean: maxF, min: maxF, max: maxF, sd: 0.0);

      case 'Terminal Velocity (m/s)':
        final tv = double.tryParse(r.terminalVelocity);
        if (tv == null) return null;
        return _RecordMetric(mean: tv, min: tv, max: tv, sd: 0.0);

      default:
        return null;
    }
  }

  List<_TrendGroupPoint> _buildGroupPoints(List<BallisticRecord> filtered, {String? paramOverride}) {
    final activeParam = paramOverride ?? _selectedParam;
    final distinctLots = filtered.map((r) => r.lotNo.trim()).where((l) => l.isNotEmpty).toSet();
    final bool isSingleLot = distinctLots.length <= 1;
    final groupBy = (isSingleLot && _selectedGroupBy == 'By Lot Number') ? 'By Individual Test' : _selectedGroupBy;

    if (groupBy == 'By Individual Test') {
      final List<_TrendGroupPoint> pts = [];
      int testIndex = 1;
      for (int i = 0; i < filtered.length; i++) {
        final metric = _extractRecordMetric(filtered[i], paramOverride: activeParam);
        if (metric != null) {
          final lot = filtered[i].lotNo.trim();
          final temp = filtered[i].cartridgeTemp.trim();
          final sub = temp.isNotEmpty && temp != 'N/A'
              ? temp
              : (lot.isNotEmpty ? 'Lot $lot' : filtered[i].timestamp.split(' ')[0]);
          pts.add(_TrendGroupPoint(
            index: pts.length,
            label: 'Test $testIndex',
            subLabel: sub,
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
      final key = groupBy == 'By Hopper No.'
          ? (r.hopperNo.trim().isNotEmpty ? r.hopperNo.trim() : (r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : 'N/A'))
          : (r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : 'Lot N/A');

      final metric = _extractRecordMetric(r, paramOverride: activeParam);
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

      final prefix = groupBy == 'By Hopper No.' ? 'Hop ' : 'Lot ';

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

    // Test Type filter list
    final testTypes = [
      'Select Test Type',
      'Waterproof Test',
      'Accuracy Test',
      'EPVAT test',
      'Residual Stress Test',
      'Primer Sensitivity Test',
      'Function Test',
      'Extraction Force Test',
      'Firing Rate Cycle Test',
      'Terminal Effect Test',
    ];
    if (!testTypes.contains(_selectedTestType)) {
      _selectedTestType = 'Select Test Type';
    }

    final bool isTestChosen = _selectedTestType.isNotEmpty &&
        _selectedTestType != 'Select Test Type' &&
        _selectedTestType != 'All';

    // Dynamic parameter options based on chosen test type
    final paramOptions = isTestChosen ? _getParamsForTestType(_selectedTestType) : <String>[];
    if (isTestChosen) {
      if (!paramOptions.contains(_selectedParam) && paramOptions.isNotEmpty) {
        _selectedParam = paramOptions.first;
      }
      if (_selectedMultiParams.isEmpty) {
        _initMultiParamsForTest(_selectedTestType);
      } else {
        final valid = _selectedMultiParams.where((p) => paramOptions.contains(p)).toList();
        if (valid.isEmpty && paramOptions.isNotEmpty) {
          _initMultiParamsForTest(_selectedTestType);
        } else if (valid.length != _selectedMultiParams.length) {
          _selectedMultiParams = valid;
        }
      }
    } else {
      _selectedParam = '';
      _selectedMultiParams = [];
    }

    // Filter by caliber, test type, and time range
    final filtered = isTestChosen
        ? widget.records.where((r) {
            final matchesCal = _selectedCaliber == 'All' || r.caliber == _selectedCaliber;
            final rTestLower = r.testName.trim().toLowerCase();
            final sTestLower = _selectedTestType.trim().toLowerCase();
            final matchesTest = rTestLower == sTestLower ||
                (rTestLower.contains('epvat') && sTestLower.contains('epvat')) ||
                (rTestLower.contains('waterproof') && sTestLower.contains('waterproof')) ||
                (rTestLower.contains('accuracy') && sTestLower.contains('accuracy')) ||
                (rTestLower.contains('stress') && sTestLower.contains('stress')) ||
                (rTestLower.contains('primer') && sTestLower.contains('primer')) ||
                (rTestLower.contains('function') && sTestLower.contains('function')) ||
                (rTestLower.contains('extraction') && sTestLower.contains('extraction')) ||
                (rTestLower.contains('terminal') && sTestLower.contains('terminal')) ||
                ((rTestLower.contains('firing rate') || rTestLower.contains('cyclic')) && (sTestLower.contains('firing rate') || sTestLower.contains('cyclic')));

            bool matchesTime = true;
            if (_selectedTimeRange != 'All Time') {
              final now = DateTime.now();
              DateTime? recordDate;
              try {
                final raw = r.timestamp.trim();
                if (raw.isNotEmpty) {
                  recordDate = DateTime.tryParse(raw.split(' ')[0]);
                }
              } catch (_) {}

              if (recordDate != null) {
                switch (_selectedTimeRange) {
                  case 'Today':
                    matchesTime = recordDate.year == now.year && recordDate.month == now.month && recordDate.day == now.day;
                    break;
                  case 'Last 7 Days':
                    final diff = now.difference(recordDate).inDays;
                    matchesTime = diff >= 0 && diff <= 7;
                    break;
                  case 'Last 30 Days':
                    final diff = now.difference(recordDate).inDays;
                    matchesTime = diff >= 0 && diff <= 30;
                    break;
                  case 'This Month':
                    matchesTime = recordDate.year == now.year && recordDate.month == now.month;
                    break;
                  case 'This Year':
                    matchesTime = recordDate.year == now.year;
                    break;
                }
              }
            }
            return matchesCal && matchesTest && matchesTime;
          }).toList()
        : <BallisticRecord>[];

    final points = isTestChosen ? _buildGroupPoints(filtered) : <_TrendGroupPoint>[];
    final selectedCaliberLabel = _selectedCaliber == 'All' ? 'All Calibers' : _selectedCaliber;

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
            // Mode toggle pills: Single SPC vs Multi-SPC Charts Grid (Up to 4)
            if (isTestChosen)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showFourCharts = false),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(5.0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        color: !_showFourCharts ? const Color(0xFF0284C7) : Colors.transparent,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.show_chart_rounded, size: 14.0, color: !_showFourCharts ? Colors.white : const Color(0xFF94A3B8)),
                            const SizedBox(width: 4.0),
                            Text('Single SPC', style: TextStyle(color: !_showFourCharts ? Colors.white : const Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showFourCharts = true),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(5.0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        color: _showFourCharts ? const Color(0xFF0284C7) : Colors.transparent,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grid_view_rounded, size: 14.0, color: _showFourCharts ? Colors.white : const Color(0xFF94A3B8)),
                            const SizedBox(width: 4.0),
                            Text('Multi-SPC (Up to 4)', style: TextStyle(color: _showFourCharts ? Colors.white : const Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8.0),
            ElevatedButton.icon(
              onPressed: points.isEmpty ? null : () => _exportTrendReport(points),
              icon: const Icon(Icons.print_outlined, size: 15.0),
              label: const Text('Export Trend Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
              ),
            ),
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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
              label: 'TEST TYPE',
              value: _selectedTestType,
              items: testTypes,
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedTestType = v;
                    _initMultiParamsForTest(v);
                  });
                }
              },
            ),
            _buildDropdown(
              label: 'GROUP READINGS BY',
              value: _selectedGroupBy,
              items: _groupByOptions,
              onChanged: (v) => setState(() => _selectedGroupBy = v!),
            ),
            if (isTestChosen && !_showFourCharts)
              _buildDropdown(
                label: 'BALLISTIC PARAMETER',
                value: _selectedParam,
                items: paramOptions,
                onChanged: (v) => setState(() => _selectedParam = v!),
              ),
            _buildDropdown(
              label: 'TIME RANGE',
              value: _selectedTimeRange,
              items: _timeRangeOptions,
              onChanged: (v) => setState(() => _selectedTimeRange = v!),
            ),
            // Metric toggle pills
            if (isTestChosen && !_showFourCharts)
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
        const SizedBox(height: 8.0),

        // ─── Parameter Selection Chips (Filtered by Test Type) ─────────
        if (isTestChosen) ...[
          _buildParameterSelectorChips(paramOptions),
          const SizedBox(height: 10.0),
        ],

        // ─── Chart area ───────────────────────────────────────────────
        Expanded(
          child: !isTestChosen
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24.0),
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4), width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 16.0, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 36.0),
                        ),
                        const SizedBox(height: 16.0),
                        const Text(
                          'Select a Test Type to Begin SPC Matrix Analysis',
                          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8.0),
                        const Text(
                          'Choose a test type from the "TEST TYPE" dropdown above.\nParameters tailored to that specific test will appear, allowing you to select up to 4 parameters for simultaneous SPC statistical control tracking.',
                          style: TextStyle(fontSize: 12.0, color: Color(0xFF94A3B8), height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : (_showFourCharts
                  ? _buildFourChartsGrid(filtered)
                  : (points.isEmpty
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
                        ))),
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

  Widget _buildSpcCard(String param, List<BallisticRecord> filtered) {
    if (param.isEmpty) return const SizedBox.shrink();
    final pts = _buildGroupPoints(filtered, paramOverride: param);

    double grandMean = 0;
    double grandSD = 0;
    double ucl = 0;
    double lcl = 0;
    bool isOOC = false;

    if (pts.isNotEmpty) {
      grandMean = pts.map((p) => p.mean).reduce((a, b) => a + b) / pts.length;
      grandSD = pts.map((p) => p.sd).reduce((a, b) => a + b) / pts.length;
      ucl = grandMean + (3 * grandSD);
      lcl = math.max(0.0, grandMean - (3 * grandSD));
      isOOC = pts.any((p) => p.mean > ucl || p.mean < lcl);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isOOC ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF334155),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  param,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isOOC ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  isOOC ? 'OOC' : 'In Control',
                  style: TextStyle(
                    color: isOOC ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Row(
            children: [
              Text(
                'x̄ = ${grandMean.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
              ),
              const SizedBox(width: 8.0),
              Text(
                'UCL: ${ucl.toStringAsFixed(1)}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontFamily: 'JetBrainsMono'),
              ),
              const SizedBox(width: 6.0),
              Text(
                'LCL: ${lcl.toStringAsFixed(1)}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontFamily: 'JetBrainsMono'),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Expanded(
            child: pts.isEmpty
                ? Center(
                    child: Text(
                      'No readings for $param',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                    ),
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _MultiMetricTrendPainter(
                      points: pts,
                      paramLabel: param,
                      showMean: true,
                      showMax: false,
                      showMin: false,
                      showSD: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSelectorChips(List<String> availableParams) {
    if (availableParams.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _showFourCharts ? Icons.view_compact_rounded : Icons.tune_rounded,
                size: 14.0,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 6.0),
              Text(
                _showFourCharts
                    ? 'CHOOSE PARAMETERS TO DISPLAY IN SPC GRID (CHOSEN TEST: $_selectedTestType - SELECT UP TO 4):'
                    : 'CHOOSE PARAMETER TO DISPLAY (CHOSEN TEST: $_selectedTestType):',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: availableParams.map((param) {
              final isSelected = _showFourCharts
                  ? _selectedMultiParams.contains(param)
                  : (_selectedParam == param);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (_showFourCharts) {
                      if (_selectedMultiParams.contains(param)) {
                        if (_selectedMultiParams.length > 1) {
                          _selectedMultiParams.remove(param);
                        }
                      } else {
                        if (_selectedMultiParams.length < 4) {
                          _selectedMultiParams.add(param);
                        } else {
                          _selectedMultiParams.removeLast();
                          _selectedMultiParams.add(param);
                        }
                      }
                    } else {
                      _selectedParam = param;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0284C7).withOpacity(0.25)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF334155),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? (_showFourCharts ? Icons.check_box : Icons.radio_button_checked)
                            : (_showFourCharts ? Icons.check_box_outline_blank : Icons.radio_button_unchecked),
                        size: 13.0,
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5.0),
                      Text(
                        param,
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFourChartsGrid(List<BallisticRecord> filtered) {
    final params = _selectedMultiParams.isNotEmpty
        ? _selectedMultiParams
        : _get4ParamsForTestType(_selectedTestType);

    if (params.isEmpty) {
      return const Center(child: Text('No parameters available', style: TextStyle(color: Color(0xFF8E96A3))));
    }

    if (params.length == 1) {
      return _buildSpcCard(params[0], filtered);
    } else if (params.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildSpcCard(params[0], filtered)),
          const SizedBox(width: 8.0),
          Expanded(child: _buildSpcCard(params[1], filtered)),
        ],
      );
    } else if (params.length == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildSpcCard(params[0], filtered)),
                const SizedBox(width: 8.0),
                Expanded(child: _buildSpcCard(params[1], filtered)),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildSpcCard(params[2], filtered),
          ),
        ],
      );
    }

    final p0 = params[0];
    final p1 = params.length > 1 ? params[1] : '';
    final p2 = params.length > 2 ? params[2] : '';
    final p3 = params.length > 3 ? params[3] : '';

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildSpcCard(p0, filtered)),
              const SizedBox(width: 8.0),
              Expanded(child: p1.isNotEmpty ? _buildSpcCard(p1, filtered) : const SizedBox.shrink()),
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: p2.isNotEmpty ? _buildSpcCard(p2, filtered) : const SizedBox.shrink()),
              const SizedBox(width: 8.0),
              Expanded(child: p3.isNotEmpty ? _buildSpcCard(p3, filtered) : const SizedBox.shrink()),
            ],
          ),
        ),
      ],
    );
  }

  String get selectedCaliberLabel => _selectedCaliber == 'All' ? 'All Calibers' : _selectedCaliber;

  void _exportTrendReport(List<_TrendGroupPoint> points) {
    if (points.isEmpty) return;

    final double overallMin = points.map((p) => p.min).reduce(math.min);
    final double overallMax = points.map((p) => p.max).reduce(math.max);
    final double grandMean = points.map((p) => p.mean).reduce((a, b) => a + b) / points.length;
    final double grandSD = points.map((p) => p.sd).reduce((a, b) => a + b) / points.length;
    final double ucl = grandMean + (3 * grandSD);
    final double lcl = math.max(0.0, grandMean - (3 * grandSD));
    final String genDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final tableRows = StringBuffer();
    for (var p in points) {
      final range = p.max - p.min;
      final bool isOut = p.mean > ucl || p.mean < lcl;
      final statusBadge = isOut
          ? '<span style="color: #ef4444; font-weight: bold; background: #fee2e2; padding: 3px 8px; border-radius: 4px;">OOC (Out of Control)</span>'
          : '<span style="color: #10b981; font-weight: bold; background: #d1fae5; padding: 3px 8px; border-radius: 4px;">Normal (In Control)</span>';

      tableRows.write('''
        <tr>
          <td style="font-weight: bold; color: #1e293b;">${p.label}</td>
          <td>${p.subLabel}</td>
          <td style="font-family: monospace;">${p.min.toStringAsFixed(2)}</td>
          <td style="font-family: monospace;">${p.max.toStringAsFixed(2)}</td>
          <td style="font-family: monospace; font-weight: bold; color: #0284c7;">${p.mean.toStringAsFixed(2)}</td>
          <td style="font-family: monospace;">${range.toStringAsFixed(2)}</td>
          <td style="font-family: monospace; color: #8b5cf6;">${p.sd.toStringAsFixed(2)}</td>
          <td>$statusBadge</td>
        </tr>
      ''');
    }

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>SPC Statistical Trend Report - $_selectedParam</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; margin: 24px; color: #1e293b; background: #ffffff; }
    .header-box { border-bottom: 2px solid #0284c7; padding-bottom: 16px; margin-bottom: 20px; }
    .title { font-size: 22px; font-weight: 800; color: #0f172a; margin: 0; }
    .subtitle { font-size: 13px; color: #64748b; margin-top: 4px; }
    .meta-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 24px; background: #f8fafc; padding: 14px; border-radius: 8px; border: 1px solid #e2e8f0; }
    .meta-item { font-size: 12px; }
    .meta-label { color: #64748b; font-weight: 600; text-transform: uppercase; font-size: 10px; }
    .meta-value { color: #0f172a; font-weight: bold; font-size: 14px; margin-top: 2px; }
    .kpi-cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 24px; }
    .kpi-card { background: #f0f9ff; border: 1px solid #bae6fd; border-radius: 8px; padding: 12px 16px; text-align: center; }
    .kpi-val { font-size: 20px; font-weight: 800; color: #0284c7; }
    .kpi-lbl { font-size: 11px; font-weight: 600; color: #0369a1; text-transform: uppercase; margin-top: 2px; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; margin-top: 10px; }
    th { background: #0f172a; color: #ffffff; text-align: left; padding: 10px 12px; font-weight: 600; font-size: 11px; text-transform: uppercase; }
    td { padding: 8px 12px; border-bottom: 1px solid #e2e8f0; }
    tr:nth-child(even) { background-color: #f8fafc; }
    .footer { margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 12px; font-size: 11px; color: #94a3b8; display: flex; justify-content: space-between; }
    @media print {
      body { margin: 10mm; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <div class="header-box">
    <div class="title">OMPC BALLISTIC AERODATA - STATISTICAL PROCESS CONTROL (SPC)</div>
    <div class="subtitle">Lot & Hopper Trend Analysis Report • Parameter: <strong>$_selectedParam</strong></div>
  </div>

  <div class="meta-grid">
    <div class="meta-item">
      <div class="meta-label">Caliber Specification</div>
      <div class="meta-value">$_selectedCaliber</div>
    </div>
    <div class="meta-item">
      <div class="meta-label">Test Type</div>
      <div class="meta-value">$_selectedTestType</div>
    </div>
    <div class="meta-item">
      <div class="meta-label">Grouping Mode</div>
      <div class="meta-value">$_selectedGroupBy</div>
    </div>
    <div class="meta-item">
      <div class="meta-label">Report Generated</div>
      <div class="meta-value">$genDate</div>
    </div>
  </div>

  <div class="kpi-cards">
    <div class="kpi-card">
      <div class="kpi-val">${grandMean.toStringAsFixed(2)}</div>
      <div class="kpi-lbl">Grand Process Mean</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val">${grandSD.toStringAsFixed(2)}</div>
      <div class="kpi-lbl">Average Std Deviation (SD)</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val">${overallMin.toStringAsFixed(2)} - ${overallMax.toStringAsFixed(2)}</div>
      <div class="kpi-lbl">Extreme Min / Max</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val">${lcl.toStringAsFixed(2)} / ${ucl.toStringAsFixed(2)}</div>
      <div class="kpi-lbl">Control Limits (LCL / UCL)</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Group Identifier</th>
        <th>Sample Detail</th>
        <th>Min</th>
        <th>Max</th>
        <th>Mean</th>
        <th>Range</th>
        <th>SD</th>
        <th>Process State</th>
      </tr>
    </thead>
    <tbody>
      ${tableRows.toString()}
    </tbody>
  </table>

  <div class="footer">
    <span>Confidential Quality Assurance Document • OMPC Ballistic Metrology</span>
    <span>Total Groups Evaluated: ${points.length}</span>
  </div>
</body>
</html>
''';

    ReportHelper.instance.printHtml(htmlContent: html);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported SPC Trend Report for "$_selectedCaliber" - "$_selectedParam" (${points.length} groups).'),
        backgroundColor: const Color(0xFF0284C7),
      ),
    );
  }

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
              dropdownColor: const Color(0xFF344D6E),
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
      final dotBgPaint = Paint()..color = const Color(0xFF242938);

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
          canvas.drawRRect(pillRect, Paint()..color = const Color(0xFF2A364E));
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
