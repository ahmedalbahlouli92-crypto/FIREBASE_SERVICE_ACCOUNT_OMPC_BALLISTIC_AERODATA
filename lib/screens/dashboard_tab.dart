import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import '../widgets/custom_dashboard_charts.dart';
import '../widgets/trend_chart.dart';
import '../services/report_helper.dart';
import '../services/svg_chart_generator.dart';

class DashboardTab extends StatefulWidget {
  final String currentModule;
  final List<BallisticRecord> records;
  final VoidCallback onGoToLogs;
  final Future<void> Function(String scope)? onClearAllRecords;

  const DashboardTab({
    Key? key,
    required this.currentModule,
    required this.records,
    required this.onGoToLogs,
    this.onClearAllRecords,
  }) : super(key: key);

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _dashboardViewMode = 'Overall'; // 'Overall' | 'By Test Type' | 'By Caliber'
  String _selectedTime = 'Overall';
  String _selectedShift = 'All Shifts';
  DateTimeRange? _customDateRange;
  String _selectedLot = 'Overall';
  String _selectedCaliber = 'All';
  String _selectedTestName = 'All';

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime? parseTimestamp(String timestamp) {
    final t = timestamp.trim();
    if (t.isEmpty) return null;
    try {
      if (t.contains('/')) {
        final parts = t.split(' ');
        final dateParts = parts[0].split('/');
        final month = int.parse(dateParts[0]);
        final day = int.parse(dateParts[1]);
        final year = int.parse(dateParts[2]);
        return DateTime(year, month, day);
      }
      if (t.contains('-')) {
        final parts = t.split(' ');
        final dateParts = parts[0].split('-');
        if (dateParts.length >= 3) {
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2].substring(0, 2));
          return DateTime(year, month, day);
        }
      }
      if (t.toLowerCase().contains('am') || t.toLowerCase().contains('pm') || t.contains(':')) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique lots and calibers from widget.records
    final uniqueLots = widget.records
        .expand((r) => [r.lotNo.trim(), r.primerLot.trim(), r.propellantLot.trim(), r.hopperNo.trim()])
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    uniqueLots.sort();

    final uniqueCalibers = widget.currentModule == 'Component Test'
        ? widget.records.map((r) => r.caliber.trim()).where((c) => c.isNotEmpty).toSet().toList()
        : {
            ...widget.records.map((r) => r.caliber).where((c) => c.isNotEmpty),
            ...allCaliberSpecifications,
          }.toList();
    if (widget.currentModule == 'Component Test' && uniqueCalibers.isEmpty) {
      uniqueCalibers.addAll(['9x19 mm', '5.56x45 mm', '7.62x39 mm', '7.62x51 mm', '12.7x99 mm']);
    }
    uniqueCalibers.sort();

    final List<String> availableTestTypes = widget.currentModule == 'Component Test'
        ? (() {
            final fromRecords = widget.records.map((r) => r.testName.trim()).where((t) => t.isNotEmpty).toSet().toList();
            if (fromRecords.isNotEmpty) {
              fromRecords.sort();
              return fromRecords;
            }
            return ['Primer Sensitivity Test', 'Propellant Test'];
          })()
        : [
            'EPVAT test',
            'Accuracy Test',
            'Function Test',
            'Waterproof Test',
            'Residual Stress Test',
            'Firing Rate Cycle Test',
            'Terminal Effect Test',
          ];

    // Dynamically adjust dropdown selections if values are no longer in list
    if (_selectedLot != 'Overall' && !uniqueLots.contains(_selectedLot)) {
      _selectedLot = 'Overall';
    }
    if (_selectedCaliber != 'All' && !uniqueCalibers.contains(_selectedCaliber)) {
      _selectedCaliber = 'All';
    }
    if (_selectedTestName != 'All' && !availableTestTypes.contains(_selectedTestName)) {
      _selectedTestName = 'All';
    }

    const timeOptions = [
      'Overall',
      'Daily',
      'Weekly',
      'Monthly',
      'Yearly',
      'Custom Range',
    ];

    const shiftOptions = [
      'All Shifts',
      'Day Shift',
      'Night Shift',
    ];

    if (!timeOptions.contains(_selectedTime)) {
      _selectedTime = 'Overall';
    }
    if (!shiftOptions.contains(_selectedShift)) {
      _selectedShift = 'All Shifts';
    }

    // Filter records
    List<BallisticRecord> filtered = widget.records;

    // 1. Shift Filter
    if (_selectedShift == 'Day Shift') {
      filtered = filtered.where((r) => r.shift.trim().toLowerCase() == 'day').toList();
    } else if (_selectedShift == 'Night Shift') {
      filtered = filtered.where((r) => r.shift.trim().toLowerCase() == 'night').toList();
    }

    // 2. Time Filter
    final now = DateTime.now();
    if (_selectedTime == 'Daily') {
      filtered = filtered.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();
    } else if (_selectedTime == 'Weekly') {
      filtered = filtered.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return now.difference(d).inDays <= 7;
      }).toList();
    } else if (_selectedTime == 'Monthly') {
      filtered = filtered.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return now.difference(d).inDays <= 30;
      }).toList();
    } else if (_selectedTime == 'Yearly') {
      filtered = filtered.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return d.year == now.year;
      }).toList();
    } else if (_selectedTime == 'Custom Range' && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      filtered = filtered.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
               (d.isBefore(end) || d.isAtSameMomentAs(end));
      }).toList();
    }

    // 3. Lot Filter
    if (_selectedLot != 'Overall') {
      filtered = filtered.where((r) =>
        r.lotNo.trim() == _selectedLot ||
        r.primerLot.trim() == _selectedLot ||
        r.propellantLot.trim() == _selectedLot ||
        r.hopperNo.trim() == _selectedLot
      ).toList();
    }

    // 4. Caliber Filter
    if (_selectedCaliber != 'All') {
      filtered = filtered.where((r) => r.caliber == _selectedCaliber).toList();
    }

    // 5. Test Name Filter
    if (_selectedTestName != 'All') {
      filtered = filtered.where((r) => r.testName == _selectedTestName).toList();
    }

    // Calculate metrics
    int totalRounds = 0;
    int totalDefects = 0;
    int passCount = 0;
    int rejectCount = 0;
    int retestCount = 0;
    final Map<String, int> caliberCounts = {};
    final Map<String, int> statusCounts = {
      'Approved': 0,
      'Pending Review': 0,
      'Rejected': 0,
      'Retest': 0,
      'Approved with condition': 0,
    };

    for (var r in filtered) {
      totalRounds += r.produced;
      totalDefects += r.defects;

      caliberCounts[r.caliber] = (caliberCounts[r.caliber] ?? 0) + r.produced;

      if (statusCounts.containsKey(r.status)) {
        statusCounts[r.status] = (statusCounts[r.status] ?? 0) + 1;
      } else {
        statusCounts[r.status] = 1;
      }

      if (r.status == 'Approved' || r.status == 'Approved with condition') {
        passCount++;
      } else if (r.status == 'Rejected') {
        rejectCount++;
      } else if (r.status == 'Retest') {
        retestCount++;
      }
    }

    final double yieldRate = totalRounds > 0
        ? (((totalRounds - totalDefects) / totalRounds) * 100.0)
        : 100.0;

    // Instruction 15: Lot Acceptance tests done based on lot numbers
    final lotAcceptanceRecords = widget.records
        .where((r) => r.module == 'Lot Acceptance Test' || r.lotNo.trim().isNotEmpty)
        .toList();
    final Set<String> lotAcceptanceLots = lotAcceptanceRecords
        .map((r) => r.lotNo.trim())
        .where((l) => l.isNotEmpty)
        .toSet();
    final int lotAcceptanceTestsCount = lotAcceptanceRecords.length;
    final int lotAcceptanceLotsCount = lotAcceptanceLots.length;

    // Recent logs for table (show all matched logs if a lot is selected, otherwise limit to 5, sorted newest first)
    final sortedFiltered = List<BallisticRecord>.from(filtered)
      ..sort((a, b) {
        try {
          final da = DateFormat('M/d/yyyy h:mm:ss a').parse(a.timestamp);
          final db = DateFormat('M/d/yyyy h:mm:ss a').parse(b.timestamp);
          return db.compareTo(da);
        } catch (_) {
          return b.timestamp.compareTo(a.timestamp);
        }
      });
    final recentRecords = _selectedLot != 'Overall'
        ? sortedFiltered
        : sortedFiltered.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Export Dashboard button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.currentModule == 'Daily Test'
                          ? 'Daily Test Dashboard'
                          : (widget.currentModule == 'Component Test'
                              ? 'Component Test Dashboard'
                              : 'Lot Acceptance Dashboard'),
                      style: const TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4.0),
                    const Text(
                      'Real-time statistics for ballistic quality evaluations',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Wrap(
                spacing: 10.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showClearAllConfirmationDialog(context),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16.0, color: Color(0xFFEF4444)),
                    label: const Text('Clear All Tests', style: TextStyle(color: Color(0xFFEF4444))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.5)),
                      backgroundColor: const Color(0xFFEF4444).withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showExportScopeDialog(context, widget.records, uniqueCalibers),
                    icon: const Icon(Icons.download, size: 16.0),
                    label: const Text('Export Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // View Mode Selector: Overall | By Test Type | By Caliber
          Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 10.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: [
                _buildViewModeButton('Overall', 'Overall Overview', Icons.dashboard_outlined),
                _buildViewModeButton('By Test Type', 'By Test Type Individually', Icons.biotech_outlined),
                _buildViewModeButton('By Caliber', 'By Caliber Individually', Icons.adjust_outlined),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Sub-chips when 'By Test Type' is selected
          if (_dashboardViewMode == 'By Test Type') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF344D6E),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Test Type to Inspect:', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: availableTestTypes.map((t) {
                      final isSelected = _selectedTestName == t;
                      return ChoiceChip(
                        label: Text(t),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedTestName = t),
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFF2C415E),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12.0,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
          ],

          // Sub-chips when 'By Caliber' is selected
          if (_dashboardViewMode == 'By Caliber') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF344D6E),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Caliber Specification to Inspect:', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: uniqueCalibers.map((c) {
                      final isSelected = _selectedCaliber == c;
                      return ChoiceChip(
                        label: Text(c),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCaliber = c),
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFF2C415E),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12.0,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
          ],

          // Filters Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 10.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _buildFilterDropdown(
                  label: 'SHIFT',
                  value: _selectedShift,
                  items: shiftOptions,
                  onChanged: (val) {
                    setState(() {
                      _selectedShift = val!;
                    });
                  },
                ),
                _buildFilterDropdown(
                  label: 'TIME RANGE',
                  value: _selectedTime,
                  items: timeOptions,
                  onChanged: (val) {
                    setState(() {
                      _selectedTime = val!;
                    });
                  },
                ),
                if (_selectedTime == 'Custom Range')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DATE RANGE',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      InkWell(
                        onTap: () async {
                          final initialRange = _customDateRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 7)),
                                end: DateTime.now(),
                              );
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            initialDateRange: initialRange,
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF0284C7),
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF344D6E),
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: const Color(0xFF344D6E),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _customDateRange = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C415E),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF1E3A8A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.date_range, size: 16.0, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 8.0),
                              Text(
                                _customDateRange != null
                                    ? '${_formatDate(_customDateRange!.start)} to ${_formatDate(_customDateRange!.end)}'
                                    : 'Select Dates',
                                style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                if (widget.currentModule == 'Lot Acceptance Test' || widget.currentModule == 'Component Test')
                  _buildFilterDropdown(
                    label: widget.currentModule == 'Component Test' ? 'COMPONENT LOT NUMBER' : 'LOT NUMBER',
                    value: _selectedLot,
                    items: ['Overall', ...uniqueLots],
                    onChanged: (val) {
                      setState(() {
                        _selectedLot = val!;
                      });
                    },
                  ),
                _buildFilterDropdown(
                  label: 'CALIBER SPECIFICATION',
                  value: _selectedCaliber,
                  items: ['All', ...uniqueCalibers],
                  onChanged: (val) {
                    setState(() {
                      _selectedCaliber = val!;
                    });
                  },
                ),
                _buildFilterDropdown(
                  label: 'TEST TYPE',
                  value: _selectedTestName,
                  items: ['All', ...availableTestTypes],
                  onChanged: (val) {
                    setState(() {
                      _selectedTestName = val!;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 1200
                  ? (constraints.maxWidth - 80) / 6
                  : constraints.maxWidth > 900
                      ? (constraints.maxWidth - 48) / 3
                      : constraints.maxWidth > 600
                          ? (constraints.maxWidth - 32) / 2
                          : constraints.maxWidth;

              return Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  _buildKpiCard(
                    title: 'QUANTITY TESTED',
                    value: totalRounds.toString(),
                    desc: _selectedTime == 'Overall' ? 'Total rounds logged' : 'Rounds in this period',
                    accentColor: const Color(0xFF0284C7),
                    width: cardWidth,
                    icon: Icons.flash_on,
                  ),
                  _buildKpiCard(
                    title: 'PASSED TESTS',
                    value: passCount.toString(),
                    desc: 'Tests approved & conforming',
                    accentColor: const Color(0xFF10B981),
                    width: cardWidth,
                    icon: Icons.check_circle_outline,
                  ),
                  _buildKpiCard(
                    title: 'REJECTED TESTS',
                    value: rejectCount.toString(),
                    desc: 'Failed evaluations',
                    accentColor: const Color(0xFFEF4444),
                    width: cardWidth,
                    icon: Icons.cancel_outlined,
                  ),
                  _buildKpiCard(
                    title: 'RETEST REQUIRED',
                    value: retestCount.toString(),
                    desc: 'Need new inspections',
                    accentColor: const Color(0xFFF59E0B),
                    width: cardWidth,
                    icon: Icons.sync_problem_outlined,
                  ),
                  _buildKpiCard(
                    title: 'YIELD RATE',
                    value: '${yieldRate.toStringAsFixed(2)}%',
                    desc: 'Percent within specifications',
                    accentColor: const Color(0xFF0EA5E9),
                    width: cardWidth,
                    icon: Icons.trending_up,
                  ),
                  _buildKpiCard(
                    title: widget.currentModule == 'Component Test' ? 'COMPONENT TESTS' : 'LOT ACCEPTANCE TESTS',
                    value: widget.currentModule == 'Component Test'
                        ? '${widget.records.length} Tests'
                        : '$lotAcceptanceTestsCount Tests',
                    desc: widget.currentModule == 'Component Test'
                        ? '${uniqueLots.length} unique component lots'
                        : '$lotAcceptanceLotsCount unique lots tested',
                    accentColor: const Color(0xFF0284C7),
                    width: cardWidth,
                    icon: Icons.fact_check_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28.0),

          // Charts Card
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              final charts = [
                _buildChartCard(
                  title: _dashboardViewMode == 'By Caliber'
                      ? (_selectedCaliber == 'All' ? 'All Calibers Performance' : '$_selectedCaliber Test Breakdown')
                      : (_selectedTestName == 'All' ? 'General Defects Trend' : '$_selectedTestName Metrics'),
                  child: _dashboardViewMode == 'By Caliber'
                      ? CaliberIndividualChart(records: widget.records, caliber: _selectedCaliber)
                      : TestMetricChart(filteredRecords: filtered, selectedTestName: _selectedTestName),
                  width: isDesktop ? (constraints.maxWidth - 40) * 0.45 : constraints.maxWidth,
                ),
                _buildChartCard(
                  title: 'Tested Caliber Volume',
                  child: SingleChildScrollView(
                    child: CaliberVolumeList(caliberCounts: caliberCounts),
                  ),
                  width: isDesktop ? (constraints.maxWidth - 40) * 0.28 : constraints.maxWidth,
                ),
                _buildChartCard(
                  title: 'Status Distribution',
                  child: StatusDoughnutChart(statusCounts: statusCounts, yieldRate: yieldRate),
                  width: isDesktop ? (constraints.maxWidth - 40) * 0.27 : constraints.maxWidth,
                ),
              ];

              return isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: charts,
                    )
                  : Column(
                      children: [
                        charts[0],
                        const SizedBox(height: 20.0),
                        charts[1],
                        const SizedBox(height: 20.0),
                        charts[2],
                      ],
                    );
            },
          ),
          const SizedBox(height: 28.0),

          // ── Trend Line Chart (full width) ──────────────────────────────
          Container(
            width: double.infinity,
            height: 460.0,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 16.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TrendLineChart(records: filtered),
          ),
          const SizedBox(height: 28.0),

          // ── Box & Whisker Distribution Chart (Instruction 14) ───────────
          Container(
            width: double.infinity,
            height: 380.0,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 16.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: BoxPlotChart(records: filtered),
          ),
          const SizedBox(height: 28.0),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 16.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLot != 'Overall'
                              ? 'Submitted Reports for Lot: $_selectedLot'
                              : 'Recent Lab Logs',
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      TextButton(
                        onPressed: widget.onGoToLogs,
                        child: const Text(
                          'View All Logs →',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1.0, color: Color(0xFF1E3A8A)),
                if (recentRecords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(
                      child: Text(
                        'No test entries matched the current filters.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF2C415E)),
                      columns: [
                        const DataColumn(label: Text('TIME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('INSPECTORS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('SHIFT', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('CALIBER', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                        DataColumn(
                          label: Text(
                            widget.currentModule == 'Daily Test' ? 'HOPPER NO. / PRODUCTION DATE' : 'LOT',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const DataColumn(label: Text('TESTED', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('DEFECTS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('STATUS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                      ],
                      rows: recentRecords.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(Text(r.timestamp.split(' ').length > 1 ? r.timestamp.split(' ')[1] : r.timestamp, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.5, color: Color(0xFF94A3B8)))),
                            DataCell(Text(r.operators, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white))),
                            DataCell(Text(r.shift, style: const TextStyle(fontSize: 12.0, color: Color(0xFF94A3B8)))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C415E),
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(color: const Color(0xFF1E3A8A)),
                                ),
                                child: Text(
                                  r.caliber.replaceAll(' NATO', '').replaceAll(' Parabellum', ''),
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'JetBrainsMono', fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DataCell(Text(r.lotNo, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.0, color: Colors.white))),
                            DataCell(Text(r.produced.toString(), style: const TextStyle(fontSize: 12.5, color: Colors.white))),
                            DataCell(
                              Text(
                                r.defects.toString(),
                                style: TextStyle(
                                  color: r.defects > 0 ? const Color(0xFFEF4444) : Colors.white,
                                  fontWeight: r.defects > 0 ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataCell(_buildStatusBadge(r.status)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(String mode, String label, IconData icon) {
    final bool isSelected = _dashboardViewMode == mode;
    return InkWell(
      onTap: () => setState(() => _dashboardViewMode = mode),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.25), blurRadius: 8.0, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15.0, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 8.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final safeValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6.0),
        Container(
          width: 200.0,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: const Color(0xFF2C415E),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: const Color(0xFF1E3A8A)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              dropdownColor: const Color(0xFF344D6E),
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String desc,
    required Color accentColor,
    required double width,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      width: width,
      height: 96.0,
      decoration: BoxDecoration(
        color: const Color(0xFF344D6E),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 10.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4.0,
              child: Container(color: accentColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 16.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: valueColor ?? Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(icon, color: accentColor.withOpacity(0.85), size: 28.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget child,
    required double width,
  }) {
    return Container(
      width: width,
      height: 310.0,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF344D6E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 12.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20.0),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFF10B981).withOpacity(0.12);
    Color fg = const Color(0xFF10B981);
    Color border = const Color(0xFF10B981).withOpacity(0.25);

    if (status == 'Pending Review') {
      bg = const Color(0xFFF59E0B).withOpacity(0.12);
      fg = const Color(0xFFF59E0B);
      border = const Color(0xFFF59E0B).withOpacity(0.25);
    } else if (status == 'Rejected') {
      bg = const Color(0xFFEF4444).withOpacity(0.12);
      fg = const Color(0xFFEF4444);
      border = const Color(0xFFEF4444).withOpacity(0.25);
    } else if (status == 'Retest') {
      bg = const Color(0xFFF59E0B).withOpacity(0.12);
      fg = const Color(0xFFF59E0B);
      border = const Color(0xFFF59E0B).withOpacity(0.25);
    } else if (status == 'Approved with condition') {
      bg = const Color(0xFF06B6D4).withOpacity(0.12);
      fg = const Color(0xFF06B6D4);
      border = const Color(0xFF06B6D4).withOpacity(0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: border),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _buildParameterTrendAnalysisHtml(String testName, String caliber, List<BallisticRecord> records) {
    if (records.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('''
      <div style="margin-top: 25px; margin-bottom: 25px; padding: 16px; background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; border-bottom: 1px solid #cbd5e1; padding-bottom: 8px;">
          <div style="font-size: 13px; font-weight: 700; color: #0f172a; text-transform: uppercase; letter-spacing: 0.5px;">
            📈 Parameters Trend Analysis: $caliber — $testName
          </div>
          <div style="font-size: 10.5px; color: #64748b; font-weight: 600;">
            Total Records Analyzed: ${records.length}
          </div>
        </div>
    ''');

    double avg(List<double> list) => list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
    double minV(List<double> list) => list.isEmpty ? 0.0 : list.reduce((a, b) => a < b ? a : b);
    double maxV(List<double> list) => list.isEmpty ? 0.0 : list.reduce((a, b) => a > b ? a : b);

    if (testName == 'EPVAT test') {
      final p1Means = records.map((r) => double.tryParse(r.epvatMeanPressure)).whereType<double>().toList();
      final p1Maxs = records.map((r) => double.tryParse(r.epvatMaxPressure)).whereType<double>().toList();
      final p1Mins = records.map((r) => double.tryParse(r.epvatMinPressure)).whereType<double>().toList();
      final p1Sds = records.map((r) => double.tryParse(r.epvatSDPressure)).whereType<double>().toList();

      final p2Means = records.map((r) => double.tryParse(r.epvatP2MeanPressure)).whereType<double>().toList();
      final p2Maxs = records.map((r) => double.tryParse(r.epvatP2MaxPressure)).whereType<double>().toList();
      final p2Mins = records.map((r) => double.tryParse(r.epvatP2MinPressure)).whereType<double>().toList();
      final p2Sds = records.map((r) => double.tryParse(r.epvatP2SDPressure)).whereType<double>().toList();

      final vMeans = records.map((r) => double.tryParse(r.velMean)).whereType<double>().toList();
      final vMaxs = records.map((r) => double.tryParse(r.velMax)).whereType<double>().toList();
      final vMins = records.map((r) => double.tryParse(r.velMin)).whereType<double>().toList();
      final vSds = records.map((r) => double.tryParse(r.velSD)).whereType<double>().toList();

      final unit = records.firstWhere((r) => r.epvatPressureUnit.isNotEmpty, orElse: () => records[0]).epvatPressureUnit;
      final pUnit = unit.isNotEmpty ? unit : 'bar';

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Parameter</th>
              <th>Unit</th>
              <th>Trend Average (Mean)</th>
              <th>Lowest Recorded (Min)</th>
              <th>Highest Recorded (Max)</th>
              <th>Avg SD</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Chamber Pressure (P1)</td>
              <td>$pUnit</td>
              <td style="font-weight: bold; color: #0284c7;">${avg(p1Means).toStringAsFixed(2)}</td>
              <td>${minV(p1Mins).toStringAsFixed(2)}</td>
              <td style="color: #b91c1c; font-weight: 600;">${maxV(p1Maxs).toStringAsFixed(2)}</td>
              <td>${avg(p1Sds).toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Port Pressure (P2)</td>
              <td>$pUnit</td>
              <td style="font-weight: bold; color: #0284c7;">${avg(p2Means).toStringAsFixed(2)}</td>
              <td>${minV(p2Mins).toStringAsFixed(2)}</td>
              <td>${maxV(p2Maxs).toStringAsFixed(2)}</td>
              <td>${avg(p2Sds).toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Muzzle Velocity</td>
              <td>m/s</td>
              <td style="font-weight: bold; color: #15803d;">${avg(vMeans).toStringAsFixed(2)}</td>
              <td>${minV(vMins).toStringAsFixed(2)}</td>
              <td>${maxV(vMaxs).toStringAsFixed(2)}</td>
              <td>${avg(vSds).toStringAsFixed(2)}</td>
            </tr>
          </tbody>
        </table>

        <div style="margin-top: 14px;">
          <div style="font-size: 11px; font-weight: bold; color: #475569; margin-bottom: 6px;">Test-by-Test Parameter Progression:</div>
          <table class="data-table" style="font-size: 11px; margin-bottom: 0;">
            <thead>
              <tr style="background-color: #f1f5f9;">
                <th>Trial #</th>
                <th>Lot / Projectile</th>
                <th>Cartridge Temp</th>
                <th>Chamber P1 (bar)</th>
                <th>Port P2 (bar)</th>
                <th>Velocity (m/s)</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
      ''');
      for (int tIdx = 0; tIdx < records.length; tIdx++) {
        final r = records[tIdx];
        buffer.writeln('''
              <tr>
                <td style="font-weight: bold; color: #0f172a;">Test ${tIdx + 1}</td>
                <td>${r.lotNo.isNotEmpty ? r.lotNo : '-'}</td>
                <td>${r.cartridgeTemp.isNotEmpty ? r.cartridgeTemp : '+21°C'}</td>
                <td style="font-family: monospace; font-weight: 600; color: #0284c7;">${r.epvatMeanPressure.isNotEmpty ? r.epvatMeanPressure : '-'}</td>
                <td style="font-family: monospace; color: #0284c7;">${r.epvatP2MeanPressure.isNotEmpty ? r.epvatP2MeanPressure : '-'}</td>
                <td style="font-family: monospace; font-weight: bold; color: #15803d;">${r.velMean.isNotEmpty ? '${r.velMean} m/s' : '-'}</td>
                <td><span class="badge badge-${r.status.toLowerCase() == 'passed' ? 'passed' : 'failed'}">${r.status}</span></td>
              </tr>
        ''');
      }
      buffer.writeln('''
            </tbody>
          </table>
        </div>
      ''');
    } else if (testName == 'Accuracy Test') {
      final vMeans = records.map((r) => double.tryParse(r.velMean)).whereType<double>().toList();
      final vMaxs = records.map((r) => double.tryParse(r.velMax)).whereType<double>().toList();
      final vMins = records.map((r) => double.tryParse(r.velMin)).whereType<double>().toList();
      final vSds = records.map((r) => double.tryParse(r.velSD)).whereType<double>().toList();

      final sdXs = records.map((r) => double.tryParse(r.accSDX)).whereType<double>().toList();
      final sdYs = records.map((r) => double.tryParse(r.accSDY)).whereType<double>().toList();
      final meanRadii = records.map((r) => double.tryParse(r.accMeanRadius)).whereType<double>().toList();

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Ballistic Parameter</th>
              <th>Unit</th>
              <th>Trend Average</th>
              <th>Min Recorded</th>
              <th>Max Recorded</th>
              <th>Avg SD</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Mean Velocity</td>
              <td>m/s</td>
              <td style="font-weight: bold; color: #15803d;">${avg(vMeans).toStringAsFixed(2)}</td>
              <td>${minV(vMins).toStringAsFixed(2)}</td>
              <td>${maxV(vMaxs).toStringAsFixed(2)}</td>
              <td>${avg(vSds).toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Horizontal Dispersion (SD X)</td>
              <td>mm</td>
              <td style="font-weight: bold; color: #0284c7;">${avg(sdXs).toStringAsFixed(2)}</td>
              <td>${minV(sdXs).toStringAsFixed(2)}</td>
              <td>${maxV(sdXs).toStringAsFixed(2)}</td>
              <td>-</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Vertical Dispersion (SD Y)</td>
              <td>mm</td>
              <td style="font-weight: bold; color: #0284c7;">${avg(sdYs).toStringAsFixed(2)}</td>
              <td>${minV(sdYs).toStringAsFixed(2)}</td>
              <td>${maxV(sdYs).toStringAsFixed(2)}</td>
              <td>-</td>
            </tr>
            ${meanRadii.isNotEmpty ? '''
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Mean Radius</td>
              <td>mm</td>
              <td style="font-weight: bold; color: #4f46e5;">${avg(meanRadii).toStringAsFixed(2)}</td>
              <td>${minV(meanRadii).toStringAsFixed(2)}</td>
              <td>${maxV(meanRadii).toStringAsFixed(2)}</td>
              <td>-</td>
            </tr>''' : ''}
          </tbody>
        </table>

        <div style="margin-top: 14px;">
          <div style="font-size: 11px; font-weight: bold; color: #475569; margin-bottom: 6px;">Test-by-Test Accuracy Progression:</div>
          <table class="data-table" style="font-size: 11px; margin-bottom: 0;">
            <thead>
              <tr style="background-color: #f1f5f9;">
                <th>Trial #</th>
                <th>Lot / Projectile</th>
                <th>Velocity (m/s)</th>
                <th>SD X (mm)</th>
                <th>SD Y (mm)</th>
                <th>Mean Radius (mm)</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
      ''');
      for (int tIdx = 0; tIdx < records.length; tIdx++) {
        final r = records[tIdx];
        buffer.writeln('''
              <tr>
                <td style="font-weight: bold; color: #0f172a;">Test ${tIdx + 1}</td>
                <td>${r.lotNo.isNotEmpty ? r.lotNo : '-'}</td>
                <td style="font-family: monospace; font-weight: bold; color: #15803d;">${r.velMean.isNotEmpty ? '${r.velMean} m/s' : '-'}</td>
                <td style="font-family: monospace; color: #0284c7;">${r.accSDX.isNotEmpty ? r.accSDX : '-'}</td>
                <td style="font-family: monospace; color: #0284c7;">${r.accSDY.isNotEmpty ? r.accSDY : '-'}</td>
                <td style="font-family: monospace; font-weight: 600; color: #4f46e5;">${r.accMeanRadius.isNotEmpty ? r.accMeanRadius : '-'}</td>
                <td><span class="badge badge-${r.status.toLowerCase() == 'passed' ? 'passed' : 'failed'}">${r.status}</span></td>
              </tr>
        ''');
      }
      buffer.writeln('''
            </tbody>
          </table>
        </div>
      ''');
    } else if (testName == 'Waterproof Test') {
      int totalMouthSlow = 0;
      int totalMouthFast = 0;
      int totalPrimerSlow = 0;
      int totalPrimerFast = 0;
      final pressures = <double>[];

      for (var r in records) {
        totalMouthSlow += r.mouthSlow;
        totalMouthFast += r.mouthFast;
        totalPrimerSlow += r.primerSlow;
        totalPrimerFast += r.primerFast;
        final p = double.tryParse(r.pressureBar);
        if (p != null) pressures.add(p);
      }
      final totalMouth = totalMouthSlow + totalMouthFast;
      final totalPrimer = totalPrimerSlow + totalPrimerFast;
      final totalLeaks = totalMouth + totalPrimer;
      final avgPressure = pressures.isEmpty ? 0.0 : pressures.reduce((a, b) => a + b) / pressures.length;

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Inspection Area</th>
              <th>Slow Leaks</th>
              <th>Fast Leaks</th>
              <th>Total Leaks</th>
              <th>Avg Test Pressure</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Mouth Seal</td>
              <td>$totalMouthSlow</td>
              <td>$totalMouthFast</td>
              <td style="font-weight: bold; color: ${totalMouth > 0 ? '#b91c1c' : '#15803d'};">$totalMouth</td>
              <td rowspan="2" style="vertical-align: middle; font-weight: bold;">${avgPressure.toStringAsFixed(2)} bar</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Primer Seal</td>
              <td>$totalPrimerSlow</td>
              <td>$totalPrimerFast</td>
              <td style="font-weight: bold; color: ${totalPrimer > 0 ? '#b91c1c' : '#15803d'};">$totalPrimer</td>
            </tr>
            <tr style="background-color: #f1f5f9; font-weight: bold;">
              <td>Cumulative Total Leaks</td>
              <td>${totalMouthSlow + totalPrimerSlow}</td>
              <td>${totalMouthFast + totalPrimerFast}</td>
              <td style="color: ${totalLeaks > 0 ? '#b91c1c' : '#15803d'}; font-size: 12px;">$totalLeaks leaks</td>
              <td>-</td>
            </tr>
          </tbody>
        </table>
      ''');
    } else if (testName == 'Extraction Force Test') {
      final forces = records.map((r) => double.tryParse(r.accMeanX)).whereType<double>().toList();
      final minForces = records.map((r) => double.tryParse(r.accMinX)).whereType<double>().toList();
      final maxForces = records.map((r) => double.tryParse(r.accMaxX)).whereType<double>().toList();
      final sds = records.map((r) => double.tryParse(r.accSDX)).whereType<double>().toList();

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Parameter</th>
              <th>Unit</th>
              <th>Trend Average</th>
              <th>Min Recorded</th>
              <th>Max Recorded</th>
              <th>Avg SD</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">Extraction Force</td>
              <td>N (Newtons)</td>
              <td style="font-weight: bold; color: #0284c7;">${avg(forces).toStringAsFixed(2)}</td>
              <td>${minV(minForces).toStringAsFixed(2)}</td>
              <td>${maxV(maxForces).toStringAsFixed(2)}</td>
              <td>${avg(sds).toStringAsFixed(2)}</td>
            </tr>
          </tbody>
        </table>
      ''');
    } else if (testName == 'Residual Stress Test') {
      int totalNeck = 0;
      int totalShoulder = 0;
      int totalBody = 0;
      int totalHead = 0;

      for (var r in records) {
        totalNeck += (r.neckSlow + r.neckFast);
        totalShoulder += (r.shoulderSlow + r.shoulderFast);
        totalBody += (r.bodySlow + r.bodyFast);
        totalHead += (r.headSlow + r.headFast);
      }
      final grandTotal = totalNeck + totalShoulder + totalBody + totalHead;

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Zone Examined</th>
              <th>Total Splits / Cracks</th>
              <th>Assessment Status</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Neck (Zone I)</td>
              <td style="font-weight: bold; color: ${totalNeck > 0 ? '#b91c1c' : '#15803d'};">$totalNeck</td>
              <td>${totalNeck == 0 ? 'No Defects' : '$totalNeck splits detected'}</td>
            </tr>
            <tr>
              <td>Shoulder (Zone S)</td>
              <td style="font-weight: bold; color: ${totalShoulder > 0 ? '#b91c1c' : '#15803d'};">$totalShoulder</td>
              <td>${totalShoulder == 0 ? 'No Defects' : '$totalShoulder splits detected'}</td>
            </tr>
            <tr>
              <td>Body (Zones J & K)</td>
              <td style="font-weight: bold; color: ${totalBody > 0 ? '#b91c1c' : '#15803d'};">$totalBody</td>
              <td>${totalBody == 0 ? 'No Defects' : '$totalBody splits detected'}</td>
            </tr>
            <tr>
              <td>Head (Zones L & M)</td>
              <td style="font-weight: bold; color: ${totalHead > 0 ? '#b91c1c' : '#15803d'};">$totalHead</td>
              <td>${totalHead == 0 ? 'No Defects' : '$totalHead splits detected'}</td>
            </tr>
            <tr style="background-color: #f1f5f9; font-weight: bold;">
              <td>Cumulative Splits Across All Zones</td>
              <td style="color: ${grandTotal > 0 ? '#b91c1c' : '#15803d'}; font-size: 12px;">$grandTotal</td>
              <td>${grandTotal == 0 ? 'PASSED (Zero Cracks)' : 'Cracks Observed'}</td>
            </tr>
          </tbody>
        </table>
      ''');
    } else if (testName == 'Firing Rate Cycle Test') {
      final rpms = records.map((r) => double.tryParse(r.cyclicRateValue)).whereType<double>().toList();
      final weapons = records.map((r) => r.cyclicRateWeaponType).where((w) => w.isNotEmpty).toSet().join(', ');

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Weapon(s) Tested</th>
              <th>Trend Average RPM</th>
              <th>Min Measured RPM</th>
              <th>Max Measured RPM</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="font-weight: bold; color: #0f172a;">${weapons.isNotEmpty ? weapons : '-'}</td>
              <td style="font-weight: bold; color: #0284c7;">${avg(rpms).toStringAsFixed(1)} RPM</td>
              <td>${minV(rpms).toStringAsFixed(1)} RPM</td>
              <td>${maxV(rpms).toStringAsFixed(1)} RPM</td>
            </tr>
          </tbody>
        </table>
      ''');
    } else if (testName == 'Terminal Effect Test') {
      int steelPass = records.where((r) => r.terminalSteelPenetration == 'Yes').length;
      int alumPass = records.where((r) => r.terminalAluminumPenetration == 'Yes').length;
      int holePass = records.where((r) => r.terminalHoleDiameter == 'Yes').length;
      final vels = records.map((r) => double.tryParse(r.terminalVelocity)).whereType<double>().toList();

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Criteria / Metric</th>
              <th>Pass Count</th>
              <th>Pass Rate (%)</th>
              <th>Avg Impact Velocity</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Steel Plate Penetration</td>
              <td>$steelPass / ${records.length}</td>
              <td style="font-weight: bold; color: #0284c7;">${(steelPass / records.length * 100).toStringAsFixed(1)}%</td>
              <td rowspan="3" style="vertical-align: middle; font-weight: bold;">${vels.isNotEmpty ? '${avg(vels).toStringAsFixed(1)} m/s' : 'N/A'}</td>
            </tr>
            <tr>
              <td>Aluminum Plate Penetration</td>
              <td>$alumPass / ${records.length}</td>
              <td style="font-weight: bold; color: #0284c7;">${(alumPass / records.length * 100).toStringAsFixed(1)}%</td>
            </tr>
            <tr>
              <td>Hole Diameter Check</td>
              <td>$holePass / ${records.length}</td>
              <td style="font-weight: bold; color: #0284c7;">${(holePass / records.length * 100).toStringAsFixed(1)}%</td>
            </tr>
          </tbody>
        </table>
      ''');
    } else if (testName == 'Function Test') {
      int totalL1 = 0;
      int totalL2 = 0;
      int totalL3 = 0;
      int totalL4 = 0;
      int totalDefects = 0;
      int totalProduced = 0;

      for (var r in records) {
        totalL1 += r.functionLevel1;
        totalL2 += r.functionLevel2;
        totalL3 += r.functionLevel3;
        totalL4 += r.functionLevel4;
        totalDefects += r.defects;
        totalProduced += r.produced;
      }

      final defectRate = totalProduced > 0 ? (totalDefects / totalProduced * 100.0) : 0.0;

      buffer.writeln('''
        <table class="data-table" style="margin-bottom: 0;">
          <thead>
            <tr>
              <th>Defect Classification Level</th>
              <th>Severity Description</th>
              <th>Total Count</th>
              <th>Acceptance Threshold & Status</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="font-weight: bold; color: #ef4444;">Level 1 Defect</td>
              <td>Critical (Hazardous / Inoperable)</td>
              <td style="font-weight: bold; color: ${totalL1 > 0 ? '#b91c1c' : '#15803d'}; font-size: 13px;">$totalL1</td>
              <td>${totalL1 == 0 ? '<span style="color:#15803d; font-weight:bold;">PASSED (Zero Tolerance: 0)</span>' : '<span style="color:#b91c1c; font-weight:bold;">REJECTED ($totalL1 Critical Defects)</span>'}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #f59e0b;">Level 2 Defect</td>
              <td>Major (Failure to Feed/Extract/Stop)</td>
              <td style="font-weight: bold; color: ${totalL2 > 0 ? '#b91c1c' : '#15803d'}; font-size: 13px;">$totalL2</td>
              <td>${totalL2 == 0 ? '<span style="color:#15803d; font-weight:bold;">PASSED (Zero Allowed: 0)</span>' : '<span style="color:#b91c1c; font-weight:bold;">REJECTED ($totalL2 Major Defects)</span>'}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #3b82f6;">Level 3 Defect</td>
              <td>Minor (Sluggish action / minor denting)</td>
              <td style="font-weight: bold; color: ${totalL3 > 2 ? '#b45309' : '#15803d'}; font-size: 13px;">$totalL3</td>
              <td>${totalL3 <= 2 ? '<span style="color:#15803d; font-weight:bold;">PASSED (Within limit <= 2)</span>' : '<span style="color:#b45309; font-weight:bold;">RETEST REQUIRED (> 2 defects)</span>'}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #10b981;">Level 4 Defect</td>
              <td>Level 4 (Cosmetic / slight marking)</td>
              <td style="font-weight: bold; color: ${totalL4 > 5 ? '#b45309' : '#15803d'}; font-size: 13px;">$totalL4</td>
              <td>${totalL4 <= 5 ? '<span style="color:#15803d; font-weight:bold;">PASSED (Within limit <= 5)</span>' : '<span style="color:#b45309; font-weight:bold;">RETEST REQUIRED (> 5 defects)</span>'}</td>
            </tr>
            <tr style="background-color: #f1f5f9; font-weight: bold;">
              <td>Cumulative Defect Assessment</td>
              <td colspan="2" style="font-size: 12px; color: ${totalDefects > 0 ? '#b91c1c' : '#15803d'};">$totalDefects defects across $totalProduced rounds (${defectRate.toStringAsFixed(2)}% defect rate)</td>
              <td>${(totalL1 == 0 && totalL2 == 0 && totalL3 <= 2 && totalL4 <= 5) ? '<span style="color:#15803d; font-weight:bold;">CONFORMING</span>' : '<span style="color:#b91c1c; font-weight:bold;">NON-CONFORMING</span>'}</td>
            </tr>
          </tbody>
        </table>
      ''');
    }

    buffer.writeln('</div>');
    return buffer.toString();
  }

  void _showClearAllConfirmationDialog(BuildContext context) {
    String clearScope = 'current'; // 'current' or 'all'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF344D6E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
            side: const BorderSide(color: Color(0xFF1E3A8A)),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24.0),
              SizedBox(width: 10.0),
              Text(
                'Clear All Test Records',
                style: TextStyle(color: Colors.white, fontSize: 17.0, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to clear test records? This will make the app completely empty so you can input new test data.',
                  style: TextStyle(color: Color(0xFF8E96A3), fontSize: 13.0),
                ),
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'current',
                        groupValue: clearScope,
                        onChanged: (v) => setDialogState(() => clearScope = v!),
                        activeColor: const Color(0xFFEF4444),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Clear Current Module (${widget.currentModule})',
                          style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Empties only records logged under this module.',
                          style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5),
                        ),
                      ),
                      const Divider(color: Colors.white10),
                      RadioListTile<String>(
                        value: 'all',
                        groupValue: clearScope,
                        onChanged: (v) => setDialogState(() => clearScope = v!),
                        activeColor: const Color(0xFFEF4444),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Clear All Modules (Lot Acceptance + Daily Test)',
                          style: TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Completely empties all records in the application.',
                          style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E96A3))),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                if (widget.onClearAllRecords != null) {
                  await widget.onClearAllRecords!(clearScope);
                }
              },
              icon: const Icon(Icons.delete_forever, size: 16.0),
              label: const Text('Clear & Empty App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportScopeDialog(BuildContext context, List<BallisticRecord> recordsToExport, List<String> uniqueCalibers) {
    String exportScope = 'All'; // 'All' | 'TestType' | 'Caliber' | 'Lot'
    String targetTest = _selectedTestName != 'All' ? _selectedTestName : 'EPVAT test';
    String targetCaliber = _selectedCaliber != 'All' ? _selectedCaliber : (uniqueCalibers.isNotEmpty ? uniqueCalibers.first : '5.56x45 M193');
    final uniqueLots = widget.records
        .map((r) => r.lotNo.trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    uniqueLots.sort();
    String targetLot = _selectedLot != 'Overall' && _selectedLot.isNotEmpty
        ? _selectedLot
        : (uniqueLots.isNotEmpty ? uniqueLots.first : '');
    String exportTime = _selectedTime;
    DateTimeRange? exportDateRange = _customDateRange;
    String exportShift = _selectedShift;
    String exportFormat = 'pdf'; // 'pdf' | 'doc' | 'excel'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF344D6E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
            side: const BorderSide(color: Color(0xFF1E3A8A)),
          ),
          title: Row(
            children: const [
              Icon(Icons.download_for_offline_outlined, color: Color(0xFF10B981)),
              SizedBox(width: 10.0),
              Text(
                'Export Quality Report',
                style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure export parameters, time & shift filters, and select output format (Word, Excel, or PDF).',
                    style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5),
                  ),
                  const SizedBox(height: 16.0),

                  // Section 1: Scope
                  const Text('1. REPORT SCOPE', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8.0),
                  _buildExportScopeTile(
                    title: '📊 Comprehensive Report (All Tests & Calibers)',
                    subtitle: 'Consolidates charts, statistics, and results for all test types and calibers.',
                    value: 'All',
                    groupValue: exportScope,
                    onChanged: (v) => setDialogState(() => exportScope = v!),
                  ),
                  const SizedBox(height: 8.0),
                  _buildExportScopeTile(
                    title: '📦 Consolidated Lot Acceptance Dossier (By Lot Number)',
                    subtitle: 'Consolidates all tests sharing the same Lot Number into a unified acceptance dossier.',
                    value: 'Lot',
                    groupValue: exportScope,
                    onChanged: (v) => setDialogState(() => exportScope = v!),
                  ),
                  if (exportScope == 'Lot') ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 36.0, top: 8.0, bottom: 8.0),
                      child: DropdownButtonFormField<String>(
                        value: uniqueLots.contains(targetLot) ? targetLot : (uniqueLots.isNotEmpty ? uniqueLots.first : null),
                        dropdownColor: const Color(0xFF1A1F36),
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        decoration: InputDecoration(
                          labelText: 'Select Lot Number to Consolidate',
                          labelStyle: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        ),
                        items: uniqueLots.map((l) => DropdownMenuItem(value: l, child: Text('Lot # $l'))).toList(),
                        onChanged: (v) => setDialogState(() => targetLot = v ?? ''),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8.0),
                  _buildExportScopeTile(
                    title: '🔬 Individual Test Type Report',
                    subtitle: 'Export charts, statistics, and results for a single specific test type.',
                    value: 'TestType',
                    groupValue: exportScope,
                    onChanged: (v) => setDialogState(() => exportScope = v!),
                  ),
                  if (exportScope == 'TestType') ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 36.0, top: 8.0, bottom: 8.0),
                      child: DropdownButtonFormField<String>(
                        value: targetTest,
                        dropdownColor: const Color(0xFF1A1F36),
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        decoration: InputDecoration(
                          labelText: 'Select Test Type to Export',
                          labelStyle: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        ),
                        items: const [
                          'EPVAT test',
                          'Accuracy Test',
                          'Function Test',
                          'Waterproof Test',
                          'Residual Stress Test',
                          'Extraction Force Test',
                          'Firing Rate Cycle Test',
                          'Terminal Effect Test',
                          'Primer Sensitivity Test',
                        ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setDialogState(() => targetTest = v!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8.0),
                  _buildExportScopeTile(
                    title: '🎯 Individual Caliber Report',
                    subtitle: 'Export performance charts, test breakdown, and results for a single caliber.',
                    value: 'Caliber',
                    groupValue: exportScope,
                    onChanged: (v) => setDialogState(() => exportScope = v!),
                  ),
                  if (exportScope == 'Caliber') ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 36.0, top: 8.0, bottom: 8.0),
                      child: DropdownButtonFormField<String>(
                        value: targetCaliber,
                        dropdownColor: const Color(0xFF1A1F36),
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        decoration: InputDecoration(
                          labelText: 'Select Caliber to Export',
                          labelStyle: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        ),
                        items: uniqueCalibers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setDialogState(() => targetCaliber = v!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18.0),

                  // Section 2: Time & Shift Filter
                  const Text('2. TIME RANGE & SHIFT FILTER', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8.0),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: exportTime,
                                dropdownColor: const Color(0xFF1A1F36),
                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                decoration: InputDecoration(
                                  labelText: 'Time Period',
                                  labelStyle: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Overall', child: Text('Overall (All Time)')),
                                  DropdownMenuItem(value: 'Daily', child: Text('Daily (Today)')),
                                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly (Last 7 Days)')),
                                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly (Last 30 Days)')),
                                  DropdownMenuItem(value: 'Yearly', child: Text('Yearly (Current Year)')),
                                  DropdownMenuItem(value: 'Custom Range', child: Text('Custom Day-to-Day Range')),
                                ],
                                onChanged: (v) => setDialogState(() => exportTime = v!),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: exportShift,
                                dropdownColor: const Color(0xFF1A1F36),
                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                decoration: InputDecoration(
                                  labelText: 'Shift Filter',
                                  labelStyle: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'All Shifts', child: Text('All Shifts')),
                                  DropdownMenuItem(value: 'Day Shift', child: Text('Day Shift')),
                                  DropdownMenuItem(value: 'Night Shift', child: Text('Night Shift')),
                                ],
                                onChanged: (v) => setDialogState(() => exportShift = v!),
                              ),
                            ),
                          ],
                        ),
                        if (exportTime == 'Custom Range') ...[
                          const SizedBox(height: 10.0),
                          InkWell(
                            onTap: () async {
                              final initial = exportDateRange ??
                                  DateTimeRange(
                                    start: DateTime.now().subtract(const Duration(days: 7)),
                                    end: DateTime.now(),
                                  );
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                initialDateRange: initial,
                                builder: (context, child) => Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFF10B981),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF344D6E),
                                      onSurface: Colors.white,
                                    ),
                                    dialogBackgroundColor: const Color(0xFF344D6E),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() => exportDateRange = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C415E),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(color: const Color(0xFF1E3A8A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month, size: 16.0, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    exportDateRange != null
                                        ? '${_formatDate(exportDateRange!.start)} to ${_formatDate(exportDateRange!.end)}'
                                        : 'Click to select Day-to-Day Date Range',
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                  ),
                                  const Spacer(),
                                  const Text('Change', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18.0),

                  // Section 3: File Format
                  const Text('3. EXPORT FILE FORMAT', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExportFormatTile(
                          icon: Icons.description_outlined,
                          title: 'Word (.doc)',
                          subtitle: 'Formatted Doc',
                          format: 'doc',
                          selectedFormat: exportFormat,
                          onSelect: (f) => setDialogState(() => exportFormat = f),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildExportFormatTile(
                          icon: Icons.table_chart_outlined,
                          title: 'Excel (.csv)',
                          subtitle: 'Spreadsheet',
                          format: 'excel',
                          selectedFormat: exportFormat,
                          onSelect: (f) => setDialogState(() => exportFormat = f),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildExportFormatTile(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'PDF (.pdf)',
                          subtitle: 'Print / PDF Preview',
                          format: 'pdf',
                          selectedFormat: exportFormat,
                          onSelect: (f) => setDialogState(() => exportFormat = f),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E96A3))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _exportDashboardWithScope(
                  records: recordsToExport,
                  scope: exportScope,
                  timePeriod: exportTime,
                  customRange: exportDateRange,
                  shift: exportShift,
                  format: exportFormat,
                  selectedTest: targetTest,
                  selectedCaliber: targetCaliber,
                  selectedLot: targetLot,
                );
              },
              icon: Icon(
                exportFormat == 'doc'
                    ? Icons.description
                    : exportFormat == 'excel'
                        ? Icons.table_chart
                        : Icons.print,
                size: 16.0,
              ),
              label: Text(
                exportFormat == 'doc'
                    ? 'Export to Word (.doc)'
                    : exportFormat == 'excel'
                        ? 'Export to Excel (.csv)'
                        : 'Generate PDF Report',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: exportFormat == 'doc'
                    ? const Color(0xFF2563EB)
                    : exportFormat == 'excel'
                        ? const Color(0xFF059669)
                        : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportFormatTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String format,
    required String selectedFormat,
    required ValueChanged<String> onSelect,
  }) {
    final isSelected = format == selectedFormat;
    final color = format == 'pdf'
        ? const Color(0xFF10B981)
        : format == 'doc'
            ? const Color(0xFF3B82F6)
            : const Color(0xFF059669);

    return InkWell(
      onTap: () => onSelect(format),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.08), width: isSelected ? 1.5 : 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF8E96A3), size: 24.0),
            const SizedBox(height: 6.0),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8E96A3),
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF64748B),
                fontSize: 10.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportScopeTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withOpacity(0.1) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: isSelected ? const Color(0xFF10B981) : Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF10B981),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3.0),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportDashboardWithScope({
    required List<BallisticRecord> records,
    required String scope,
    String timePeriod = 'Overall',
    DateTimeRange? customRange,
    String shift = 'All Shifts',
    String format = 'pdf', // 'pdf' | 'doc' | 'excel'
    String? selectedTest,
    String? selectedCaliber,
    String? selectedLot,
  }) async {
    List<BallisticRecord> exportRecords = records;

    // 1. Shift Filter
    if (shift == 'Day Shift') {
      exportRecords = exportRecords.where((r) => r.shift.trim().toLowerCase() == 'day').toList();
    } else if (shift == 'Night Shift') {
      exportRecords = exportRecords.where((r) => r.shift.trim().toLowerCase() == 'night').toList();
    }

    // 2. Time Filter
    final now = DateTime.now();
    String timeLabel = 'All Time (Overall)';
    if (timePeriod == 'Daily') {
      timeLabel = 'Daily (${_formatDate(now)})';
      exportRecords = exportRecords.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();
    } else if (timePeriod == 'Weekly') {
      timeLabel = 'Weekly (Last 7 Days)';
      exportRecords = exportRecords.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return now.difference(d).inDays <= 7;
      }).toList();
    } else if (timePeriod == 'Monthly') {
      timeLabel = 'Monthly (Last 30 Days)';
      exportRecords = exportRecords.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return now.difference(d).inDays <= 30;
      }).toList();
    } else if (timePeriod == 'Yearly') {
      timeLabel = 'Yearly (${now.year})';
      exportRecords = exportRecords.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return d.year == now.year;
      }).toList();
    } else if (timePeriod == 'Custom Range' && customRange != null) {
      final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
      final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
      timeLabel = '${_formatDate(start)} to ${_formatDate(end)}';
      exportRecords = exportRecords.where((r) {
        final d = parseTimestamp(r.timestamp);
        if (d == null) return false;
        return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
               (d.isBefore(end) || d.isAtSameMomentAs(end));
      }).toList();
    }

    // 3. Scope Filter
    String reportTitle = '${widget.currentModule} Quality Dashboard Report';
    String scopeLabel = 'All Tests & All Calibers';

    if (scope == 'TestType' && selectedTest != null) {
      exportRecords = records.where((r) => r.testName == selectedTest).toList();
      reportTitle = '$selectedTest Report';
      scopeLabel = 'Individual Test: $selectedTest';
    } else if (scope == 'Caliber' && selectedCaliber != null) {
      exportRecords = records.where((r) => r.caliber == selectedCaliber).toList();
      reportTitle = '$selectedCaliber Performance Report';
      scopeLabel = 'Individual Caliber: $selectedCaliber';
    } else if (scope == 'Lot' && selectedLot != null) {
      exportRecords = widget.records.where((r) => r.lotNo.trim() == selectedLot.trim()).toList();
      reportTitle = 'Lot $selectedLot Acceptance Dossier';
      scopeLabel = 'Consolidated Lot: $selectedLot (${exportRecords.length} Tests)';
    }

    final buffer = StringBuffer();

    // Summary calculations
    int totalRounds = 0;
    int totalDefects = 0;
    int passCount = 0;
    int rejectCount = 0;
    int retestCount = 0;
    final Map<String, int> caliberCounts = {};
    final Map<String, int> statusCounts = {
      'Approved': 0,
      'Pending Review': 0,
      'Rejected': 0,
      'Retest': 0,
      'Approved with condition': 0,
    };

    for (var r in exportRecords) {
      totalRounds += r.produced;
      totalDefects += r.defects;
      caliberCounts[r.caliber] = (caliberCounts[r.caliber] ?? 0) + r.produced;
      statusCounts[r.status] = (statusCounts[r.status] ?? 0) + 1;

      if (r.status == 'Approved' || r.status == 'Approved with condition') {
        passCount++;
      } else if (r.status == 'Rejected') {
        rejectCount++;
      } else if (r.status == 'Retest') {
        retestCount++;
      }
    }

    final double yieldRate = totalRounds > 0
        ? (((totalRounds - totalDefects) / totalRounds) * 100.0)
        : 100.0;

    // Handle Excel (.csv) export immediately
    if (format == 'excel') {
      final csvContent = _buildDashboardCsvContent(
        title: reportTitle,
        scopeLabel: scopeLabel,
        timeLabel: timeLabel,
        shiftLabel: shift,
        records: exportRecords,
        totalRounds: totalRounds,
        totalDefects: totalDefects,
        yieldRate: yieldRate,
        passCount: passCount,
        rejectCount: rejectCount,
        retestCount: retestCount,
      );
      final filename = '${reportTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      await ReportHelper.instance.downloadCsv(content: csvContent, filename: filename);
      return;
    }

    // SVG Charts
    final donutSvg = SvgChartGenerator.generateStatusDonutSvg(statusCounts, yieldRate, width: 340, height: 210);
    final caliberVolumeSvg = SvgChartGenerator.generateCaliberVolumeSvg(caliberCounts, width: 440, height: 210);
    final trendLineSvg = SvgChartGenerator.generateTrendLineSvg(exportRecords, width: 800, height: 180);
    final velocityTrendSvg = SvgChartGenerator.generateVelocityTrendSvg(exportRecords, width: 800, height: 240);

    final bool includeEpvatChart = scope == 'All' || scope == 'Lot' || (scope == 'TestType' && selectedTest == 'EPVAT test') || (scope == 'Caliber' && exportRecords.any((r) => r.testName == 'EPVAT test'));
    final String epvatChartSvg = includeEpvatChart ? SvgChartGenerator.generateEpvatChartSvg(exportRecords, width: 800, height: 210) : '';

    final bool includeFnChart = scope == 'All' || scope == 'Lot' || (scope == 'TestType' && selectedTest == 'Function Test') || (scope == 'Caliber' && exportRecords.any((r) => r.testName == 'Function Test'));
    final String fnChartSvg = includeFnChart ? SvgChartGenerator.generateFunctionTestChartSvg(exportRecords, width: 800, height: 210) : '';

    buffer.writeln('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$reportTitle</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1e293b;
      padding: 30px 40px;
      margin: 0;
      background-color: #ffffff;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
      border-bottom: 3px solid #06b6d4;
      padding-bottom: 12px;
    }
    .header-table td {
      border: none !important;
      background: none !important;
      padding: 0 !important;
    }
    .title-section {
      text-align: center;
      margin-top: 10px;
      margin-bottom: 20px;
    }
    .title-section h2 {
      margin: 0;
      font-size: 19px;
      font-weight: 700;
      color: #0f172a;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .title-line {
      height: 2px;
      width: 100%;
      background-color: #06b6d4;
      margin-top: 8px;
    }
    .summary-grid {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 22px;
      flex-wrap: wrap;
    }
    .summary-card {
      flex: 1;
      min-width: 110px;
      background-color: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 10px 14px;
      text-align: center;
    }
    .summary-card .label {
      font-size: 9.5px;
      font-weight: 700;
      color: #64748b;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .summary-card .val {
      font-size: 17px;
      font-weight: 700;
      color: #0f172a;
      margin-top: 4px;
    }
    .section-title {
      font-size: 12.5px;
      font-weight: 700;
      color: #0f172a;
      border-bottom: 2px solid #cbd5e1;
      padding-bottom: 5px;
      margin-top: 24px;
      margin-bottom: 14px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .charts-grid {
      display: flex;
      gap: 16px;
      margin-bottom: 22px;
      flex-wrap: wrap;
    }
    .chart-box {
      flex: 1;
      min-width: 320px;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 12px;
      box-sizing: border-box;
    }
    .chart-box h4 {
      margin: 0 0 10px 0;
      font-size: 11px;
      font-weight: 700;
      color: #334155;
      text-transform: uppercase;
    }
    table.data-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 11px;
      margin-top: 10px;
      margin-bottom: 18px;
    }
    table.data-table th {
      background-color: #f1f5f9;
      color: #334155;
      font-weight: 600;
      text-align: left;
      padding: 7px 10px;
      border: 1px solid #cbd5e1;
      text-transform: uppercase;
      font-size: 10px;
      letter-spacing: 0.3px;
    }
    table.data-table td {
      padding: 6px 10px;
      border: 1px solid #e2e8f0;
      color: #334155;
    }
    table.data-table tr:nth-child(even) {
      background-color: #f8fafc;
    }
    .badge {
      display: inline-block;
      padding: 2px 7px;
      border-radius: 4px;
      font-size: 9px;
      font-weight: 700;
      text-transform: uppercase;
    }
    .badge-approved { background-color: #dcfce7; color: #15803d; }
    .badge-rejected { background-color: #fee2e2; color: #b91c1c; }
    .badge-retest { background-color: #fef3c7; color: #b45309; }
    .badge-pending-review { background-color: #e0e7ff; color: #4338ca; }
    .badge-approved-with-condition { background-color: #cffafe; color: #0e7490; }
    .page-break { page-break-after: always; }
    @media print {
      @page { margin: 10mm; }
      body { padding: 0; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <!-- Header -->
  <table class="header-table">
    <tr>
      <td style="width: 70%; text-align: left; vertical-align: middle;">
        <div style="font-size: 16px; font-weight: bold; color: #0f172a; font-family: Arial, sans-serif;">Oman Munition Production Company</div>
        <div style="font-size: 12px; font-weight: bold; color: #475569; margin-top: 2px;">QC And Engineering Department</div>
        <div style="font-size: 11px; color: #64748b; margin-top: 1px;">Ballistic Lab Section</div>
        <div style="font-size: 11px; font-style: italic; color: #64748b; margin-top: 1px;">Quality Dashboard Export: ${widget.currentModule}</div>
      </td>
      <td style="width: 30%; text-align: right; vertical-align: middle;">
        <div style="display: inline-block; background: #f0fdf4; border: 1px solid #86efac; border-radius: 6px; padding: 6px 12px; text-align: right;">
          <div style="font-size: 9.5px; font-weight: bold; color: #166534; text-transform: uppercase;">Export Scope</div>
          <div style="font-size: 11.5px; font-weight: bold; color: #15803d;">$scopeLabel</div>
        </div>
      </td>
    </tr>
  </table>

  <div class="title-section">
    <h2>$reportTitle</h2>
    <div style="font-size: 11px; color: #06b6d4; margin-top: 4px; font-weight: bold;">
      Scope: [$scopeLabel] | Period: [$timeLabel] | Shift: [$shift] | Records: [${exportRecords.length}]
    </div>
    <div class="title-line"></div>
  </div>

  <!-- Executive KPIs -->
  <div class="summary-grid">
    <div class="summary-card">
      <div class="label">Total Rounds Tested</div>
      <div class="val">$totalRounds</div>
    </div>
    <div class="summary-card">
      <div class="label">Defects Found</div>
      <div class="val" style="color: ${totalDefects > 0 ? '#ef4444' : '#10b981'};">$totalDefects</div>
    </div>
    <div class="summary-card">
      <div class="label">Conforming Tests</div>
      <div class="val" style="color: #10b981;">$passCount</div>
    </div>
    <div class="summary-card">
      <div class="label">Retest Required</div>
      <div class="val" style="color: #f59e0b;">$retestCount</div>
    </div>
    <div class="summary-card">
      <div class="label">Rejected Tests</div>
      <div class="val" style="color: #ef4444;">$rejectCount</div>
    </div>
    <div class="summary-card">
      <div class="label">Overall Yield Rate</div>
      <div class="val" style="color: #6366f1;">${yieldRate.toStringAsFixed(2)}%</div>
    </div>
  </div>

  <!-- Visual Charts Section -->
  <h3 class="section-title">Visual Performance & Analytics Charts</h3>
  <div class="charts-grid">
    <div class="chart-box">
      <h4>Quality Status & Yield Distribution</h4>
      $donutSvg
    </div>
    <div class="chart-box">
      <h4>Tested Caliber Volume Breakdown</h4>
      $caliberVolumeSvg
    </div>
  </div>

  <div class="chart-box" style="margin-bottom: 22px;">
    <h4>Chronological Yield Rate Trend Line</h4>
    $trendLineSvg
  </div>

  <div class="chart-box" style="margin-bottom: 22px;">
    <h4>Muzzle Velocity Trend Across Tests (m/s) — Test 1, Test 2, Test 3...</h4>
    $velocityTrendSvg
  </div>
''');

    if (includeEpvatChart && epvatChartSvg.isNotEmpty) {
      buffer.writeln('''
  <div class="chart-box" style="margin-bottom: 22px;">
    <h4>EPVAT Ballistic Parameters (Chamber P1, Port P2, Velocity)</h4>
    $epvatChartSvg
  </div>
''');
    }

    if (includeFnChart && fnChartSvg.isNotEmpty) {
      buffer.writeln('''
  <div class="chart-box" style="margin-bottom: 22px;">
    <h4>Function Test Defect Breakdown (4 Severity Levels)</h4>
    $fnChartSvg
  </div>
''');
    }

    // Grouping by Caliber and Test Type
    final Map<String, List<BallisticRecord>> groups = {};
    for (var r in exportRecords) {
      final key = '${r.caliber} - ${r.testName}';
      groups.putIfAbsent(key, () => []).add(r);
    }

    final sortedKeys = groups.keys.toList()..sort();

    buffer.writeln('<h3 class="section-title">Detailed Evaluations By Test & Caliber</h3>');

    for (int i = 0; i < sortedKeys.length; i++) {
      final keyName = sortedKeys[i];
      final list = groups[keyName]!;
      final parts = keyName.split(' - ');
      final caliberName = parts[0];
      final testTypeName = parts.length > 1 ? parts[1] : 'Unknown Test';

      int grpRounds = 0;
      int grpDefects = 0;
      final Map<String, int> grpStatusCounts = {
        'Approved': 0,
        'Pending Review': 0,
        'Rejected': 0,
        'Retest': 0,
        'Approved with condition': 0,
      };

      for (var r in list) {
        grpRounds += r.produced;
        grpDefects += r.defects;
        grpStatusCounts[r.status] = (grpStatusCounts[r.status] ?? 0) + 1;
      }

      final double grpYield = grpRounds > 0 ? (((grpRounds - grpDefects) / grpRounds) * 100.0) : 100.0;
      final totalGrpStatus = grpStatusCounts.values.fold<int>(0, (sum, val) => sum + val);
      final approvedPct = totalGrpStatus > 0 ? (grpStatusCounts['Approved']! / totalGrpStatus) * 100 : 0.0;
      final retestPct = totalGrpStatus > 0 ? (grpStatusCounts['Retest']! / totalGrpStatus) * 100 : 0.0;
      final rejectedPct = totalGrpStatus > 0 ? (grpStatusCounts['Rejected']! / totalGrpStatus) * 100 : 0.0;
      final condPct = totalGrpStatus > 0 ? (grpStatusCounts['Approved with condition']! / totalGrpStatus) * 100 : 0.0;

      final statusGraphRow = StringBuffer();
      if (approvedPct > 0) {
        statusGraphRow.write('<td style="width: ${approvedPct.toStringAsFixed(1)}%; background-color: #10b981; color: white; text-align: center; font-size: 10px; font-weight: bold; height: 22px;">Approved (${approvedPct.toStringAsFixed(0)}%)</td>');
      }
      if (condPct > 0) {
        statusGraphRow.write('<td style="width: ${condPct.toStringAsFixed(1)}%; background-color: #06b6d4; color: white; text-align: center; font-size: 10px; font-weight: bold; height: 22px;">Cond. (${condPct.toStringAsFixed(0)}%)</td>');
      }
      if (retestPct > 0) {
        statusGraphRow.write('<td style="width: ${retestPct.toStringAsFixed(1)}%; background-color: #f59e0b; color: white; text-align: center; font-size: 10px; font-weight: bold; height: 22px;">Retest (${retestPct.toStringAsFixed(0)}%)</td>');
      }
      if (rejectedPct > 0) {
        statusGraphRow.write('<td style="width: ${rejectedPct.toStringAsFixed(1)}%; background-color: #ef4444; color: white; text-align: center; font-size: 10px; font-weight: bold; height: 22px;">Rejected (${rejectedPct.toStringAsFixed(0)}%)</td>');
      }

      buffer.writeln('''
  <div style="margin-top: 24px; padding: 16px; border: 1px solid #e2e8f0; border-radius: 8px; background: #ffffff;">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
      <div>
        <span style="font-size: 15px; font-weight: bold; color: #0f172a;">$caliberName &nbsp;—&nbsp; <span style="color: #6366f1;">$testTypeName</span></span>
      </div>
      <div style="font-size: 12px; color: #64748b;">
        Tested: <strong>$grpRounds rounds</strong> &nbsp;|&nbsp; Defects: <strong>$grpDefects</strong> &nbsp;|&nbsp; Yield: <strong style="color: #10b981;">${grpYield.toStringAsFixed(1)}%</strong>
      </div>
    </div>

    <!-- Status Bar -->
    <table style="width: 100%; height: 22px; border-collapse: collapse; border: 1px solid #cbd5e1; border-radius: 4px; overflow: hidden; margin-bottom: 14px;">
      <tr>
        ${statusGraphRow.toString()}
      </tr>
    </table>

    <!-- Submitted Records Table -->
    <table class="data-table">
      <thead>
        <tr>
          <th>Timestamp</th>
          <th>Inspectors</th>
          <th>Shift</th>
          <th>Lot No / Hopper</th>
          <th>Qty</th>
          <th>Defects</th>
          <th>Quality Status</th>
        </tr>
      </thead>
      <tbody>
''');

      for (var r in list) {
        final statusClass = r.status.toLowerCase().replaceAll(' ', '-');
        buffer.writeln('''
        <tr>
          <td>${r.timestamp}</td>
          <td>${r.operators}</td>
          <td>${r.shift}</td>
          <td>${r.lotNo}</td>
          <td>${r.produced}</td>
          <td style="color: ${r.defects > 0 ? '#b91c1c' : '#334155'}; font-weight: ${r.defects > 0 ? 'bold' : 'normal'};">${r.defects}</td>
          <td><span class="badge badge-$statusClass">${r.status.toUpperCase()}</span></td>
        </tr>
''');
      }

      buffer.writeln('''
      </tbody>
    </table>
''');

      // Parameter Trend Analysis section (EPVAT, Function Test, Waterproof, etc.)
      buffer.writeln(_buildParameterTrendAnalysisHtml(testTypeName, caliberName, list));

      buffer.writeln('  </div>');
    }

    buffer.writeln('''
</body>
</html>
''');

    if (format == 'doc') {
      final filename = '${reportTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.doc';
      await ReportHelper.instance.downloadDoc(content: buffer.toString(), filename: filename);
    } else {
      await ReportHelper.instance.printHtml(htmlContent: buffer.toString());
    }
  }

  String _csvEscape(dynamic val) {
    if (val == null) return '';
    final s = val.toString().replaceAll('"', '""');
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"$s"';
    }
    return s;
  }

  String _buildDashboardCsvContent({
    required String title,
    required String scopeLabel,
    required String timeLabel,
    required String shiftLabel,
    required List<BallisticRecord> records,
    required int totalRounds,
    required int totalDefects,
    required double yieldRate,
    required int passCount,
    required int rejectCount,
    required int retestCount,
  }) {
    final buffer = StringBuffer();
    final nowStr = DateTime.now().toString().split('.')[0];

    buffer.writeln('QUALITY DASHBOARD REPORT - EXCEL DATA EXPORT');
    buffer.writeln('Report Title,${_csvEscape(title)}');
    buffer.writeln('Module,${_csvEscape(widget.currentModule)}');
    buffer.writeln('Generated At,${_csvEscape(nowStr)}');
    buffer.writeln('Scope,${_csvEscape(scopeLabel)}');
    buffer.writeln('Time Range,${_csvEscape(timeLabel)}');
    buffer.writeln('Shift,${_csvEscape(shiftLabel)}');
    buffer.writeln('');
    buffer.writeln('EXECUTIVE SUMMARY METRICS');
    buffer.writeln('Total Rounds Tested,Total Defects,Quality Yield Rate,Approved / Passed,Rejected,Pending / Retest');
    buffer.writeln('$totalRounds,$totalDefects,${yieldRate.toStringAsFixed(1)}%,$passCount,$rejectCount,$retestCount');
    buffer.writeln('');
    buffer.writeln('DETAILED TEST RECORDS');
    buffer.writeln('Timestamp,Operator,Shift,Caliber,Lot Number,Test Type,Tested Rounds,Defects,Quality Status,Pressure (Bar),Viscosity,Test Time,Location,EPVAT Chamber P1 Mean,EPVAT P1 Max,EPVAT P1 Min,EPVAT P1 SD,EPVAT Port P2 Mean,EPVAT Temp,Mean Velocity (m/s),Min Velocity,Max Velocity,SD Velocity,Mean Radius (mm),Terminal Hole,Terminal Steel,Cyclic Rate Weapon,Cyclic RPM,Notes / Remarks');

    for (var r in records) {
      buffer.writeln([
        _csvEscape(r.timestamp),
        _csvEscape(r.operators),
        _csvEscape(r.shift),
        _csvEscape(r.caliber),
        _csvEscape(r.lotNo),
        _csvEscape(r.testName),
        r.produced,
        r.defects,
        _csvEscape(r.status),
        _csvEscape(r.pressureBar),
        _csvEscape(r.viscosity),
        _csvEscape(r.testTime),
        _csvEscape(r.samplingLocation),
        _csvEscape(r.epvatMeanPressure),
        _csvEscape(r.epvatMaxPressure),
        _csvEscape(r.epvatMinPressure),
        _csvEscape(r.epvatSDPressure),
        _csvEscape(r.epvatP2MeanPressure),
        _csvEscape(r.cartridgeTemp),
        _csvEscape(r.velMean),
        _csvEscape(r.velMin),
        _csvEscape(r.velMax),
        _csvEscape(r.velSD),
        _csvEscape(r.accMeanRadius),
        _csvEscape(r.terminalHoleDiameter),
        _csvEscape(r.terminalSteelPenetration),
        _csvEscape(r.cyclicRateWeaponType),
        _csvEscape(r.cyclicRateValue),
        _csvEscape(r.notes),
      ].join(','));
    }

    return buffer.toString();
  }
}
