import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import '../services/storage_service.dart';
import '../services/report_helper.dart';

class ExecutiveReportsTab extends StatefulWidget {
  final List<BallisticRecord> lotAcceptanceRecords;
  final List<BallisticRecord> dailyTestRecords;
  final List<BallisticRecord> componentTestRecords;
  final String base64Logo;
  final String loggedInUser;

  const ExecutiveReportsTab({
    Key? key,
    required this.lotAcceptanceRecords,
    required this.dailyTestRecords,
    required this.componentTestRecords,
    required this.base64Logo,
    required this.loggedInUser,
  }) : super(key: key);

  @override
  State<ExecutiveReportsTab> createState() => _ExecutiveReportsTabState();
}

class _ExecutiveReportsTabState extends State<ExecutiveReportsTab> {
  final StorageService _storageService = StorageService();

  // Period mode: 'daily', 'monthly', 'yearly'
  String _periodType = 'daily';
  DateTime _selectedDate = DateTime.now();

  // Module inclusion checkboxes
  bool _includeLotAcceptance = true;
  bool _includeDailyTest = true;
  bool _includeComponentTest = true;
  bool _includeConsumables = true;

  List<Map<String, dynamic>> _consumables = [];

  @override
  void initState() {
    super.initState();
    _loadConsumables();
  }

  Future<void> _loadConsumables() async {
    try {
      final items = await _storageService.loadConsumables();
      if (mounted) {
        setState(() {
          _consumables = items;
        });
      }
    } catch (_) {}
  }

  // Filter helper for records
  bool _matchesPeriod(String timestamp) {
    if (timestamp.trim().isEmpty) return false;
    DateTime? dt;
    try {
      dt = DateTime.tryParse(timestamp.trim().split(' ')[0]);
    } catch (_) {}
    if (dt == null) return false;

    if (_periodType == 'daily') {
      return dt.year == _selectedDate.year &&
          dt.month == _selectedDate.month &&
          dt.day == _selectedDate.day;
    } else if (_periodType == 'monthly') {
      return dt.year == _selectedDate.year && dt.month == _selectedDate.month;
    } else {
      return dt.year == _selectedDate.year;
    }
  }

  String get _periodLabel {
    if (_periodType == 'daily') {
      return DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
    } else if (_periodType == 'monthly') {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    } else {
      return DateFormat('yyyy').format(_selectedDate);
    }
  }

  List<Map<String, dynamic>> _getFilteredInspectionRecords() {
    final List<Map<String, dynamic>> list = [];

    if (_includeLotAcceptance) {
      for (var r in widget.lotAcceptanceRecords) {
        if (_matchesPeriod(r.timestamp)) {
          list.add({'module': 'Lot Acceptance', 'record': r});
        }
      }
    }

    if (_includeDailyTest) {
      for (var r in widget.dailyTestRecords) {
        if (_matchesPeriod(r.timestamp)) {
          list.add({'module': 'Daily Test', 'record': r});
        }
      }
    }

    if (_includeComponentTest) {
      for (var r in widget.componentTestRecords) {
        if (_matchesPeriod(r.timestamp)) {
          list.add({'module': 'Component Test', 'record': r});
        }
      }
    }

    // Sort newest first
    list.sort((a, b) {
      final rA = a['record'] as BallisticRecord;
      final rB = b['record'] as BallisticRecord;
      return rB.timestamp.compareTo(rA.timestamp);
    });

    return list;
  }

  List<Map<String, dynamic>> _getFilteredConsumableLogs() {
    if (!_includeConsumables) return [];
    final List<Map<String, dynamic>> logs = [];

    for (var item in _consumables) {
      final history = List<dynamic>.from(item['history'] ?? []);
      for (var h in history) {
        if (h is Map) {
          final dateStr = (h['date'] ?? '').toString();
          if (_matchesPeriod(dateStr)) {
            logs.add({
              'itemName': item['name'] ?? '',
              'serial': item['serial'] ?? 'N/A',
              'unit': item['unit'] ?? 'pcs',
              'category': item['category'] ?? '',
              ...Map<String, dynamic>.from(h),
            });
          }
        }
      }
    }

    logs.sort((a, b) => (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    return logs;
  }

  @override
  Widget build(BuildContext context) {
    final inspectionEntries = _getFilteredInspectionRecords();
    final consumableEntries = _getFilteredConsumableLogs();

    int totalTests = inspectionEntries.length;
    int approved = 0;
    int rejected = 0;
    int retest = 0;

    for (var entry in inspectionEntries) {
      final r = entry['record'] as BallisticRecord;
      final status = r.status.toLowerCase();
      if (status.contains('approved') || status.contains('pass')) {
        approved++;
      } else if (status.contains('reject') || status.contains('fail')) {
        rejected++;
      } else if (status.contains('retest')) {
        retest++;
      }
    }

    num totalConsumablesUsed = 0;
    for (var c in consumableEntries) {
      if (c['type'] == 'CONSUMED' || c['type'] == 'DISPENSED') {
        totalConsumablesUsed += (c['quantity'] ?? 0) as num;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E223D),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(inspectionEntries, consumableEntries),
            const SizedBox(height: 16.0),

            // Controls: Period Selector & Date Picker & Module Checkboxes
            _buildConfigurationCard(),
            const SizedBox(height: 16.0),

            // Executive Summary KPIs
            _buildSummaryKpis(
              totalTests: totalTests,
              approved: approved,
              rejected: rejected,
              retest: retest,
              consumablesUsed: totalConsumablesUsed,
            ),
            const SizedBox(height: 20.0),

            // Inspection Logs Section
            _buildInspectionPreviewTable(inspectionEntries),
            const SizedBox(height: 20.0),

            // Consumables Activity Section
            if (_includeConsumables) ...[
              _buildConsumablesPreviewTable(consumableEntries),
              const SizedBox(height: 20.0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    List<Map<String, dynamic>> inspections,
    List<Map<String, dynamic>> consumables,
  ) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
            ),
            child: const Icon(Icons.summarize_outlined, color: Color(0xFFA78BFA), size: 28.0),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Executive Quality & Operations Reports',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Consolidated executive intelligence covering Daily, Monthly, and Yearly ballistics testing & inventory metrics.',
                  style: TextStyle(fontSize: 12.0, color: const Color(0xFFE2E8F0).withOpacity(0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 8.0,
            children: [
              ElevatedButton.icon(
                onPressed: () => _exportCsv(inspections, consumables),
                icon: const Icon(Icons.download, size: 16.0),
                label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportExecutiveHtml(inspections, consumables),
                icon: const Icon(Icons.print, size: 16.0),
                label: const Text('Print / PDF Report', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Period Mode Switcher (Daily, Monthly, Yearly)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E223D),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF1E3A8A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPeriodBtn('daily', 'Daily Report', Icons.today),
                    _buildPeriodBtn('monthly', 'Monthly Report', Icons.calendar_view_month),
                    _buildPeriodBtn('yearly', 'Yearly Report', Icons.date_range),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),

              // Date Picker Button
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.edit_calendar, color: Color(0xFF38BDF8), size: 16.0),
                label: Text(
                  _periodLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          const Divider(color: Color(0xFF1E3A8A), height: 1.0),
          const SizedBox(height: 12.0),

          // Checkboxes Row
          Row(
            children: [
              const Text(
                'MODULES TO INCLUDE:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(width: 16.0),
              _buildCheckbox(
                label: 'Lot Acceptance Test',
                value: _includeLotAcceptance,
                onChanged: (v) => setState(() => _includeLotAcceptance = v ?? true),
              ),
              const SizedBox(width: 16.0),
              _buildCheckbox(
                label: 'Daily Test',
                value: _includeDailyTest,
                onChanged: (v) => setState(() => _includeDailyTest = v ?? true),
              ),
              const SizedBox(width: 16.0),
              _buildCheckbox(
                label: 'Component Test',
                value: _includeComponentTest,
                onChanged: (v) => setState(() => _includeComponentTest = v ?? true),
              ),
              const SizedBox(width: 16.0),
              _buildCheckbox(
                label: 'Consumable Items',
                value: _includeConsumables,
                onChanged: (v) => setState(() => _includeConsumables = v ?? true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodBtn(String key, String label, IconData icon) {
    final isSelected = _periodType == key;
    return InkWell(
      onTap: () => setState(() => _periodType = key),
      borderRadius: BorderRadius.circular(7.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(7.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14.0, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox({required String label, required bool value, required ValueChanged<bool?> onChanged}) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            activeColor: const Color(0xFF8B5CF6),
            checkColor: Colors.white,
            side: const BorderSide(color: Color(0xFF94A3B8)),
            onChanged: onChanged,
          ),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              surface: Color(0xFF1C3351),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildSummaryKpis({
    required int totalTests,
    required int approved,
    required int rejected,
    required int retest,
    required num consumablesUsed,
  }) {
    final passRate = totalTests > 0 ? ((approved / totalTests) * 100).toStringAsFixed(1) : '0.0';

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: 'TOTAL TESTS',
            value: '$totalTests',
            subtitle: 'Across selected modules',
            icon: Icons.biotech_outlined,
            color: const Color(0xFF38BDF8),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: _buildKpiCard(
            title: 'PASS RATE',
            value: '$passRate%',
            subtitle: '$approved of $totalTests tests approved',
            icon: Icons.check_circle_outline,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: _buildKpiCard(
            title: 'REJECTED / RETEST',
            value: '$rejected / $retest',
            subtitle: 'Flagged quality deviations',
            icon: Icons.highlight_off_outlined,
            color: rejected > 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: _buildKpiCard(
            title: 'CONSUMABLES CONSUMED',
            value: '$consumablesUsed',
            subtitle: 'Total units dispensed',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFFA855F7),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(icon, color: color, size: 22.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10.0, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 20.0, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionPreviewTable(List<Map<String, dynamic>> entries) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0E223D),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
              border: Border(bottom: BorderSide(color: const Color(0xFF1E3A8A))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BALLISTIC INSPECTION LOGS (${entries.length} RECORDS)',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12.0, letterSpacing: 0.5),
                ),
                Text(
                  'PERIOD: ${_periodLabel.toUpperCase()}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('No inspection records found for the selected period and modules.', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF0E223D).withOpacity(0.5)),
                headingTextStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
                columns: const [
                  DataColumn(label: Text('MODULE')),
                  DataColumn(label: Text('DATE & TIME')),
                  DataColumn(label: Text('INSPECTOR')),
                  DataColumn(label: Text('TEST NAME')),
                  DataColumn(label: Text('CALIBER')),
                  DataColumn(label: Text('HOPPER / LOT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('REMARKS / NOTE')),
                ],
                rows: entries.map((entry) {
                  final module = entry['module'] as String;
                  final r = entry['record'] as BallisticRecord;
                  final status = r.status.trim();
                  Color statusColor = const Color(0xFF10B981);
                  if (status.toLowerCase().contains('reject') || status.toLowerCase().contains('fail')) {
                    statusColor = const Color(0xFFEF4444);
                  } else if (status.toLowerCase().contains('retest')) {
                    statusColor = const Color(0xFFF59E0B);
                  }

                  final lotOrHopper = module == 'Daily Test'
                      ? (r.hopperNo.isNotEmpty ? r.hopperNo : 'N/A')
                      : (r.lotNo.isNotEmpty ? r.lotNo : 'N/A');

                  return DataRow(cells: [
                    DataCell(Text(module, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold))),
                    DataCell(Text(r.testTime.isNotEmpty ? r.testTime : r.timestamp)),
                    DataCell(Text(r.operators)),
                    DataCell(Text(r.testName, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(r.caliber)),
                    DataCell(Text(lotOrHopper)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(Text(r.notes.isNotEmpty ? r.notes : '-')),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConsumablesPreviewTable(List<Map<String, dynamic>> entries) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0E223D),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
              border: Border(bottom: BorderSide(color: const Color(0xFF1E3A8A))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CONSUMABLE INVENTORY TRANSACTIONS (${entries.length} ACTIVITIES)',
                  style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold, fontSize: 12.0, letterSpacing: 0.5),
                ),
                Text(
                  'PERIOD: ${_periodLabel.toUpperCase()}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('No consumable items activity recorded for this period.', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF0E223D).withOpacity(0.5)),
                headingTextStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
                columns: const [
                  DataColumn(label: Text('DATE & TIME')),
                  DataColumn(label: Text('ACTION TYPE')),
                  DataColumn(label: Text('ITEM NAME')),
                  DataColumn(label: Text('SERIAL NO.')),
                  DataColumn(label: Text('QUANTITY')),
                  DataColumn(label: Text('DETAILS / PURPOSE')),
                  DataColumn(label: Text('OPERATOR')),
                  DataColumn(label: Text('REMAINING STOCK')),
                ],
                rows: entries.map((c) {
                  final type = (c['type'] ?? '').toString();
                  final isReceived = type == 'RECEIVED';
                  final color = isReceived ? const Color(0xFF10B981) : const Color(0xFF38BDF8);

                  return DataRow(cells: [
                    DataCell(Text(c['date']?.toString() ?? '')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: color),
                        ),
                        child: Text(type, style: TextStyle(color: color, fontSize: 10.0, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(Text(c['itemName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(c['serial']?.toString() ?? '')),
                    DataCell(Text('${isReceived ? '+' : '-'}${c['quantity']} ${c['unit']}', style: TextStyle(color: color, fontWeight: FontWeight.bold))),
                    DataCell(Text(c['purpose']?.toString() ?? '')),
                    DataCell(Text(c['user']?.toString() ?? '')),
                    DataCell(Text('${c['remaining']} ${c['unit']}')),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    List<Map<String, dynamic>> inspections,
    List<Map<String, dynamic>> consumables,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('OMPC BALLISTIC AERODATA - EXECUTIVE REPORT');
    buffer.writeln('Period:,$_periodLabel');
    buffer.writeln('Export Date:,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('Generated By:,${widget.loggedInUser}');
    buffer.writeln('');

    buffer.writeln('SECTION 1: BALLISTIC INSPECTIONS');
    buffer.writeln('Module,Timestamp,Inspector,Test Name,Caliber,Lot/Hopper,Status,Sample Size,Notes');
    for (var entry in inspections) {
      final m = entry['module'] as String;
      final r = entry['record'] as BallisticRecord;
      final lotOrHopper = m == 'Daily Test' ? r.hopperNo : r.lotNo;
      buffer.writeln('"$m","${r.timestamp}","${r.operators}","${r.testName}","${r.caliber}","$lotOrHopper","${r.status}","${r.produced}","${r.notes.replaceAll('"', '""')}"');
    }
    buffer.writeln('');

    if (_includeConsumables) {
      buffer.writeln('SECTION 2: CONSUMABLE INVENTORY ACTIVITY');
      buffer.writeln('Date,Type,Item Name,Serial Number,Quantity,Unit,Details,Operator,Remaining Stock');
      for (var c in consumables) {
        buffer.writeln('"${c['date']}","${c['type']}","${c['itemName']}","${c['serial']}","${c['quantity']}","${c['unit']}","${(c['purpose'] ?? '').toString().replaceAll('"', '""')}","${c['user']}","${c['remaining']}"');
      }
    }

    final filename = 'OMPC_Executive_Report_${_periodType}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    await ReportHelper.instance.downloadCsv(content: buffer.toString(), filename: filename);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Executive CSV report exported: $filename'), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }

  Future<void> _exportExecutiveHtml(
    List<Map<String, dynamic>> inspections,
    List<Map<String, dynamic>> consumables,
  ) async {
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    int totalTests = inspections.length;
    int approved = 0;
    int rejected = 0;
    int retest = 0;

    for (var entry in inspections) {
      final r = entry['record'] as BallisticRecord;
      final s = r.status.toLowerCase();
      if (s.contains('approved') || s.contains('pass')) {
        approved++;
      } else if (s.contains('reject') || s.contains('fail')) {
        rejected++;
      } else if (s.contains('retest')) {
        retest++;
      }
    }

    final passRate = totalTests > 0 ? ((approved / totalTests) * 100).toStringAsFixed(1) : '0.0';

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>OMPC Executive Quality Report - $_periodLabel</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 30px; color: #1e293b; background: #fff; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #0284c7; padding-bottom: 15px; margin-bottom: 20px; }
    .title { font-size: 24px; font-weight: bold; color: #0f172a; }
    .subtitle { font-size: 13px; color: #64748b; margin-top: 4px; }
    .meta-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px; margin-bottom: 20px; font-size: 12px; }
    .kpi-row { display: flex; gap: 15px; margin-bottom: 25px; }
    .kpi-card { flex: 1; border: 1px solid #cbd5e1; border-radius: 8px; padding: 12px; text-align: center; }
    .kpi-val { font-size: 22px; font-weight: bold; margin-top: 5px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 30px; font-size: 12px; }
    th { background: #0f172a; color: #fff; text-align: left; padding: 8px 10px; font-size: 11px; text-transform: uppercase; }
    td { padding: 8px 10px; border-bottom: 1px solid #e2e8f0; }
    tr:nth-child(even) { background: #f8fafc; }
    .badge-approved { background: #dcfce7; color: #15803d; padding: 2px 6px; border-radius: 4px; font-weight: bold; }
    .badge-rejected { background: #fee2e2; color: #b91c1c; padding: 2px 6px; border-radius: 4px; font-weight: bold; }
    .badge-retest { background: #fef3c7; color: #b45309; padding: 2px 6px; border-radius: 4px; font-weight: bold; }
    .footer { text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #e2e8f0; padding-top: 15px; margin-top: 30px; }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <div class="title">OMPC BALLISTIC AERODATA - EXECUTIVE QUALITY REPORT</div>
      <div class="subtitle">PERIOD: <strong>$_periodLabel</strong> | Generated: $now | Inspector: ${widget.loggedInUser}</div>
    </div>
  </div>

  <div class="kpi-row">
    <div class="kpi-card" style="border-top: 4px solid #0284c7;">
      <div style="font-size: 11px; color: #64748b; font-weight: bold;">TOTAL TESTS</div>
      <div class="kpi-val" style="color: #0284c7;">$totalTests</div>
    </div>
    <div class="kpi-card" style="border-top: 4px solid #10b981;">
      <div style="font-size: 11px; color: #64748b; font-weight: bold;">PASS / APPROVAL RATE</div>
      <div class="kpi-val" style="color: #10b981;">$passRate%</div>
    </div>
    <div class="kpi-card" style="border-top: 4px solid #ef4444;">
      <div style="font-size: 11px; color: #64748b; font-weight: bold;">REJECTIONS</div>
      <div class="kpi-val" style="color: #ef4444;">$rejected</div>
    </div>
    <div class="kpi-card" style="border-top: 4px solid #f59e0b;">
      <div style="font-size: 11px; color: #64748b; font-weight: bold;">RETESTS PENDING</div>
      <div class="kpi-val" style="color: #f59e0b;">$retest</div>
    </div>
  </div>

  <h3>1. Inspection Quality Logs</h3>
  <table>
    <thead>
      <tr>
        <th>Module</th>
        <th>Date & Time</th>
        <th>Inspector</th>
        <th>Test Name</th>
        <th>Caliber</th>
        <th>Lot / Hopper</th>
        <th>Status</th>
        <th>Remarks</th>
      </tr>
    </thead>
    <tbody>
      ${inspections.isEmpty ? '<tr><td colspan="8" style="text-align: center; color: #64748b;">No inspection logs recorded in this period.</td></tr>' : inspections.map((entry) {
        final m = entry['module'] as String;
        final r = entry['record'] as BallisticRecord;
        final statusClass = r.status.toLowerCase().contains('approved') ? 'badge-approved' : (r.status.toLowerCase().contains('reject') ? 'badge-rejected' : 'badge-retest');
        final lotOrHop = m == 'Daily Test' ? r.hopperNo : r.lotNo;
        return '<tr>'
            '<td><strong>$m</strong></td>'
            '<td>${r.testTime.isNotEmpty ? r.testTime : r.timestamp}</td>'
            '<td>${r.operators}</td>'
            '<td>${r.testName}</td>'
            '<td>${r.caliber}</td>'
            '<td>$lotOrHop</td>'
            '<td><span class="$statusClass">${r.status.toUpperCase()}</span></td>'
            '<td>${r.notes}</td>'
            '</tr>';
      }).join('')}
    </tbody>
  </table>

  ${_includeConsumables ? '''
  <h3>2. Consumable Inventory Activity</h3>
  <table>
    <thead>
      <tr>
        <th>Date & Time</th>
        <th>Action</th>
        <th>Item Name</th>
        <th>Serial</th>
        <th>Quantity</th>
        <th>Details / Purpose</th>
        <th>Operator</th>
        <th>Stock After</th>
      </tr>
    </thead>
    <tbody>
      ${consumables.isEmpty ? '<tr><td colspan="8" style="text-align: center; color: #64748b;">No consumable item activity recorded in this period.</td></tr>' : consumables.map((c) {
        final isRec = c['type'] == 'RECEIVED';
        final col = isRec ? '#10b981' : '#0284c7';
        return '<tr>'
            '<td>${c['date']}</td>'
            '<td style="color: $col; font-weight: bold;">${c['type']}</td>'
            '<td><strong>${c['itemName']}</strong></td>'
            '<td>${c['serial']}</td>'
            '<td style="color: $col; font-weight: bold;">${isRec ? '+' : '-'}${c['quantity']} ${c['unit']}</td>'
            '<td>${c['purpose'] ?? ''}</td>'
            '<td>${c['user'] ?? ''}</td>'
            '<td>${c['remaining']} ${c['unit']}</td>'
            '</tr>';
      }).join('')}
    </tbody>
  </table>
  ''' : ''}

  <div class="footer">
    OMPC Ballistic AeroData System &copy; ${DateTime.now().year} | Confidential Executive Document
  </div>
</body>
</html>
''';

    await ReportHelper.instance.printHtml(htmlContent: html);
  }
}
