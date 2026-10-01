import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import '../services/storage_service.dart';
import '../services/report_helper.dart';
import '../services/report_generator.dart';
import '../services/supabase_service.dart';

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
  bool _includeEquipmentIssues = true;
  bool _includeWitnessStorage = true;

  List<Map<String, dynamic>> _consumables = [];
  List<Map<String, dynamic>> _witnessLots = [];
  List<Map<String, dynamic>> _witnessConsumptions = [];
  List<Map<String, dynamic>> _equipmentIssues = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final consumables = await _storageService.loadConsumables();
      final witnessLots = await _storageService.loadWitnessStorageLots();
      final witnessConsumptions = await _storageService.loadWitnessStorageConsumptions();
      var equipmentIssues = await _storageService.loadEquipmentIssues();

      try {
        final cloudIssues = await SupabaseService.loadEquipmentIssues();
        if (cloudIssues.isNotEmpty) {
          final Map<String, Map<String, dynamic>> merged = {};
          for (var i in equipmentIssues) {
            merged[i['id'].toString()] = i;
          }
          for (var i in cloudIssues) {
            merged[i['id'].toString()] = i;
          }
          equipmentIssues = merged.values.toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _consumables = consumables;
          _witnessLots = witnessLots;
          _witnessConsumptions = witnessConsumptions;
          _equipmentIssues = equipmentIssues;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Filter helper for records (supports both YYYY-MM-DD, M/D/YYYY, D/M/YYYY formats)
  bool _matchesPeriod(String rawTimestamp) {
    if (rawTimestamp.trim().isEmpty) return false;
    DateTime? dt;
    final s = rawTimestamp.trim();
    try {
      if (s.contains('/')) {
        final datePart = s.split(' ')[0];
        final parts = datePart.split('/');
        if (parts.length == 3) {
          final p0 = int.tryParse(parts[0]) ?? 1;
          final p1 = int.tryParse(parts[1]) ?? 1;
          final p2 = int.tryParse(parts[2]) ?? 2026;
          if (p0 > 1000) {
            dt = DateTime(p0, p1, p2);
          } else if (p2 > 1000) {
            if (p0 > 12) {
              dt = DateTime(p2, p1, p0);
            } else {
              dt = DateTime(p2, p0, p1);
            }
          }
        }
      } else if (s.contains('-')) {
        final datePart = s.split(' ')[0];
        final parts = datePart.split('-');
        if (parts.length == 3) {
          final p0 = int.tryParse(parts[0]) ?? 2026;
          final p1 = int.tryParse(parts[1]) ?? 1;
          final p2 = int.tryParse(parts[2]) ?? 1;
          if (p0 > 1000) {
            dt = DateTime(p0, p1, p2);
          } else if (p2 > 1000) {
            dt = DateTime(p2, p1, p0);
          }
        }
      } else {
        dt = DateTime.tryParse(s.split(' ')[0]);
      }
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

  // Strictly check actual testTime if present, only fallback to timestamp if testTime is blank
  bool _recordMatchesPeriod(BallisticRecord r) {
    if (r.testTime.trim().isNotEmpty) {
      return _matchesPeriod(r.testTime);
    }
    return _matchesPeriod(r.timestamp);
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
        if (_recordMatchesPeriod(r)) {
          list.add({'module': 'Lot Acceptance', 'record': r});
        }
      }
    }

    if (_includeDailyTest) {
      for (var r in widget.dailyTestRecords) {
        if (_recordMatchesPeriod(r)) {
          list.add({'module': 'Daily Test', 'record': r});
        }
      }
    }

    if (_includeComponentTest) {
      for (var r in widget.componentTestRecords) {
        if (_recordMatchesPeriod(r)) {
          list.add({'module': 'Component Test', 'record': r});
        }
      }
    }

    return list;
  }

  List<Map<String, dynamic>> _getFilteredEquipmentIssues() {
    return _equipmentIssues.where((issue) {
      final ts = (issue['timestamp'] ?? issue['date'] ?? '').toString();
      return _matchesPeriod(ts);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredConsumables() {
    return _consumables.where((item) {
      final ts = (item['date'] ?? item['timestamp'] ?? '').toString();
      return _matchesPeriod(ts);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredWitnessConsumptions() {
    return _witnessConsumptions.where((item) {
      final ts = (item['date'] ?? item['timestamp'] ?? '').toString();
      return _matchesPeriod(ts);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredWitnessAdditions() {
    return _witnessLots.where((lot) {
      final ts = (lot['registeredAt'] ?? lot['date'] ?? lot['timestamp'] ?? '').toString();
      return _matchesPeriod(ts);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final inspections = _getFilteredInspectionRecords();
    final equipmentIssues = _getFilteredEquipmentIssues();
    final consumables = _getFilteredConsumables();
    final witnessConsumptions = _getFilteredWitnessConsumptions();
    final witnessAdditions = _getFilteredWitnessAdditions();

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

    return Container(
      color: const Color(0xFFC4D6EC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Executive Quality Report',
                          style: TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Comprehensive daily inspection logs, equipment fault incidents, and witness inventory activity',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10.0,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _exportCsv(
                        inspections,
                        equipmentIssues,
                        consumables,
                        witnessConsumptions,
                        witnessAdditions,
                      ),
                      icon: const Icon(Icons.table_chart_outlined, size: 16.0),
                      label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _exportExecutiveHtml(
                        inspections,
                        equipmentIssues,
                        consumables,
                        witnessConsumptions,
                        witnessAdditions,
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 16.0),
                      label: const Text('Export Executive Report', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20.0),

            // Period Selector & Filter Controls Container
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: const Color(0xFFD6E4F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10.0, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Period Mode Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPeriodButton('daily', 'Daily'),
                            _buildPeriodButton('monthly', 'Monthly'),
                            _buildPeriodButton('yearly', 'Yearly'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      // Date Picker Button
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8.0),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 16.0, color: Color(0xFF0284C7)),
                              const SizedBox(width: 8.0),
                              Text(
                                _periodLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 4.0),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8.0),
                  // Checkboxes for Inclusion
                  Wrap(
                    spacing: 20.0,
                    runSpacing: 8.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Report Modules:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF64748B))),
                      _buildCheckbox('Lot Acceptance', _includeLotAcceptance, (v) => setState(() => _includeLotAcceptance = v!)),
                      _buildCheckbox('Daily Test', _includeDailyTest, (v) => setState(() => _includeDailyTest = v!)),
                      _buildCheckbox('Component Test', _includeComponentTest, (v) => setState(() => _includeComponentTest = v!)),
                      _buildCheckbox('Equipment Issues', _includeEquipmentIssues, (v) => setState(() => _includeEquipmentIssues = v!)),
                      _buildCheckbox('Consumables', _includeConsumables, (v) => setState(() => _includeConsumables = v!)),
                      _buildCheckbox('Witness Storage', _includeWitnessStorage, (v) => setState(() => _includeWitnessStorage = v!)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),

            // Top KPI Cards
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              children: [
                _buildKpiCard('TOTAL INSPECTIONS', '$totalTests', const Color(0xFF0284C7), Icons.biotech_outlined),
                _buildKpiCard('APPROVAL RATE', '$passRate%', const Color(0xFF10B981), Icons.verified_outlined),
                _buildKpiCard('REJECTIONS', '$rejected', const Color(0xFFEF4444), Icons.cancel_outlined),
                _buildKpiCard('RETESTS REQUIRED', '$retest', const Color(0xFFF59E0B), Icons.replay_circle_filled_rounded),
                _buildKpiCard('EQUIPMENT ISSUES', '${equipmentIssues.length}', const Color(0xFF8B5CF6), Icons.construction_outlined),
              ],
            ),
            const SizedBox(height: 24.0),

            // Section 1: Inspection Logs Table
            _buildInspectionLogsTable(inspections),
            const SizedBox(height: 24.0),

            // Section 2: Equipment Issues Table (Requirement 8 & 9)
            if (_includeEquipmentIssues) ...[
              _buildEquipmentIssuesTable(equipmentIssues),
              const SizedBox(height: 24.0),
            ],

            // Section 3: Consumables & Witness Storage Withdrawals (Requirement 8)
            if (_includeConsumables || _includeWitnessStorage) ...[
              _buildConsumptionsTable(consumables, witnessConsumptions),
              const SizedBox(height: 24.0),
            ],

            // Section 4: Witness Storage Additions (Requirement 8)
            if (_includeWitnessStorage) ...[
              _buildWitnessAdditionsTable(witnessAdditions),
              const SizedBox(height: 24.0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String type, String label) {
    final active = _periodType == type;
    return InkWell(
      onTap: () => setState(() => _periodType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF0284C7),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label, style: const TextStyle(fontSize: 12.0, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildKpiCard(String title, String val, Color color, IconData icon) {
    return Container(
      width: 200.0,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFFD6E4F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x081E3A8A), blurRadius: 6.0, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(icon, color: color, size: 20.0),
          ),
          const SizedBox(width: 12.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 2.0),
              Text(val, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
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
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildInspectionLogsTable(List<Map<String, dynamic>> inspections) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFD6E4F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10.0, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.0)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.biotech_outlined, color: Color(0xFF0284C7), size: 18.0),
                    const SizedBox(width: 8.0),
                    Text(
                      '1. BALLISTIC INSPECTION LOGS (${inspections.length} RECORDS)',
                      style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
                Text('PERIOD: ${_periodLabel.toUpperCase()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (inspections.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No ballistic inspection tests logged on this date.', style: TextStyle(color: Color(0xFF64748B)))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                headingTextStyle: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5),
                columns: const [
                  DataColumn(label: Text('MODULE')),
                  DataColumn(label: Text('DATE & TIME')),
                  DataColumn(label: Text('INSPECTOR')),
                  DataColumn(label: Text('TEST NAME')),
                  DataColumn(label: Text('CALIBER')),
                  DataColumn(label: Text('LOT / HOPPER')),
                  DataColumn(label: Text('QTY TESTED')),
                  DataColumn(label: Text('DEFECTS')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('REMARKS')),
                ],
                rows: inspections.map((entry) {
                  final m = entry['module'] as String;
                  final r = entry['record'] as BallisticRecord;
                  final status = r.status;
                  final isPass = status.toLowerCase().contains('approved');
                  final isReject = status.toLowerCase().contains('reject');
                  final statusColor = isPass ? const Color(0xFF10B981) : (isReject ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
                  final lotOrHopper = m == 'Daily Test' ? (r.hopperNo.isNotEmpty ? r.hopperNo : 'N/A') : (r.lotNo.isNotEmpty ? r.lotNo : 'N/A');

                  return DataRow(cells: [
                    DataCell(Text(m, style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold))),
                    DataCell(Text(r.testTime.isNotEmpty ? r.testTime : r.timestamp)),
                    DataCell(Text(r.operators)),
                    DataCell(Text(r.testName, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(r.caliber)),
                    DataCell(Text(lotOrHopper)),
                    DataCell(Text('${r.produced} rds')),
                    DataCell(Text('${r.defects}')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10.0, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(Text(ReportGenerator.cleanRemarks(r.notes).isNotEmpty ? ReportGenerator.cleanRemarks(r.notes) : '-')),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEquipmentIssuesTable(List<Map<String, dynamic>> equipmentIssues) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFD6E4F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10.0, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.0)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.construction_outlined, color: Color(0xFFF59E0B), size: 18.0),
                    const SizedBox(width: 8.0),
                    Text(
                      '2. REPORTED EQUIPMENT ISSUES & DOWNTIME (${equipmentIssues.length} INCIDENTS)',
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
                Text('PERIOD: ${_periodLabel.toUpperCase()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (equipmentIssues.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No equipment issues reported for this date.', style: TextStyle(color: Color(0xFF64748B)))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                headingTextStyle: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5),
                columns: const [
                  DataColumn(label: Text('DATE & TIME')),
                  DataColumn(label: Text('EQUIPMENT INSTRUMENT')),
                  DataColumn(label: Text('FAULT SUMMARY')),
                  DataColumn(label: Text('SEVERITY')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('REPORTED BY')),
                  DataColumn(label: Text('ACTION TAKEN')),
                ],
                rows: equipmentIssues.map((issue) {
                  final status = (issue['status'] ?? 'Open').toString();
                  final isResolved = status.contains('Resolved') || status.contains('Calibrated');
                  final statusColor = isResolved ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                  return DataRow(cells: [
                    DataCell(Text(issue['timestamp'] ?? issue['date'] ?? '')),
                    DataCell(Text(issue['equipment'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)))),
                    DataCell(Text(issue['title'] ?? '')),
                    DataCell(Text(issue['severity'] ?? '')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10.0, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(Text(issue['reporter'] ?? '')),
                    DataCell(Text(issue['actionTaken']?.toString().isNotEmpty == true ? issue['actionTaken'] : '-')),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConsumptionsTable(List<Map<String, dynamic>> consumables, List<Map<String, dynamic>> witnessConsumptions) {
    final List<Map<String, dynamic>> combined = [];

    for (var c in consumables) {
      if (c['type'] != 'RECEIVED') {
        combined.add({
          'source': 'Consumables',
          'date': c['date'] ?? '',
          'item': c['itemName'] ?? '',
          'spec': c['serial'] ?? '-',
          'qty': '${c['quantity']} ${c['unit'] ?? ''}',
          'purpose': c['purpose'] ?? '',
          'user': c['user'] ?? '',
        });
      }
    }

    for (var w in witnessConsumptions) {
      combined.add({
        'source': 'Witness Storage',
        'date': w['date'] ?? w['timestamp'] ?? '',
        'item': 'Lot ${w['lotNo'] ?? ''}',
        'spec': w['caliber'] ?? 'Rounds',
        'qty': '${w['quantity']} rounds',
        'purpose': w['purpose'] ?? '',
        'user': w['requestedBy'] ?? w['approvedBy'] ?? '',
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFD6E4F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10.0, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.0)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Color(0xFF0284C7), size: 18.0),
                    const SizedBox(width: 8.0),
                    Text(
                      '3. CONSUMED ITEMS ACTIVITY & WITNESS WITHDRAWALS (${combined.length} ITEMS)',
                      style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
                Text('PERIOD: ${_periodLabel.toUpperCase()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (combined.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No consumed items or witness storage withdrawals on this date.', style: TextStyle(color: Color(0xFF64748B)))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                headingTextStyle: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5),
                columns: const [
                  DataColumn(label: Text('DATE & TIME')),
                  DataColumn(label: Text('INVENTORY SOURCE')),
                  DataColumn(label: Text('ITEM / LOT NUMBER')),
                  DataColumn(label: Text('SPECIFICATION / CALIBER')),
                  DataColumn(label: Text('QTY CONSUMED')),
                  DataColumn(label: Text('PURPOSE / TRIAL DETAILS')),
                  DataColumn(label: Text('REQUESTER / OPERATOR')),
                ],
                rows: combined.map((c) {
                  final isWitness = c['source'] == 'Witness Storage';
                  return DataRow(cells: [
                    DataCell(Text(c['date'])),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: isWitness ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(c['source'], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isWitness ? const Color(0xFF0284C7) : const Color(0xFF475569))),
                      ),
                    ),
                    DataCell(Text(c['item'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(c['spec'])),
                    DataCell(Text(c['qty'], style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold))),
                    DataCell(Text(c['purpose'])),
                    DataCell(Text(c['user'])),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWitnessAdditionsTable(List<Map<String, dynamic>> additions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFD6E4F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10.0, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.0)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.archive_outlined, color: Color(0xFF10B981), size: 18.0),
                    const SizedBox(width: 8.0),
                    Text(
                      '4. QUANTITY ADDED TO WITNESS STORAGE (${additions.length} LOTS REGISTERED)',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
                Text('PERIOD: ${_periodLabel.toUpperCase()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (additions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No new witness lots registered or added into storage on this date.', style: TextStyle(color: Color(0xFF64748B)))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                headingTextStyle: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5),
                columns: const [
                  DataColumn(label: Text('DATE & TIME')),
                  DataColumn(label: Text('LOT NUMBER')),
                  DataColumn(label: Text('CALIBER')),
                  DataColumn(label: Text('INITIAL QUANTITY ADDED')),
                  DataColumn(label: Text('STORAGE LOCATION')),
                  DataColumn(label: Text('STORAGE CONDITION')),
                  DataColumn(label: Text('REGISTERED BY')),
                ],
                rows: additions.map((l) {
                  return DataRow(cells: [
                    DataCell(Text(l['registeredAt'] ?? l['date'] ?? l['timestamp'] ?? '')),
                    DataCell(Text(l['lotNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)))),
                    DataCell(Text(l['caliber'] ?? '')),
                    DataCell(Text('+${l['initialQty'] ?? 0} rounds', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
                    DataCell(Text(l['location'] ?? 'Pallet / Storage')),
                    DataCell(Text(l['storageCondition'] ?? 'Air Conditioned')),
                    DataCell(Text(l['registeredBy'] ?? l['operator'] ?? 'Technician')),
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
    List<Map<String, dynamic>> equipmentIssues,
    List<Map<String, dynamic>> consumables,
    List<Map<String, dynamic>> witnessConsumptions,
    List<Map<String, dynamic>> witnessAdditions,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('OMPC BALLISTIC AERODATA - EXECUTIVE QUALITY REPORT');
    buffer.writeln('Period:,$_periodLabel');
    buffer.writeln('Export Date:,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('Generated By:,${widget.loggedInUser}');
    buffer.writeln('');

    buffer.writeln('SECTION 1: BALLISTIC INSPECTIONS');
    buffer.writeln('Module,Timestamp,Inspector,Test Name,Caliber,Lot/Hopper,Quantity Tested,Defects,Status,Remarks');
    for (var entry in inspections) {
      final m = entry['module'] as String;
      final r = entry['record'] as BallisticRecord;
      final lotOrHopper = m == 'Daily Test' ? r.hopperNo : r.lotNo;
      final cleanNotes = ReportGenerator.cleanRemarks(r.notes);
      buffer.writeln('"$m","${r.timestamp}","${r.operators}","${r.testName}","${r.caliber}","$lotOrHopper","${r.produced}","${r.defects}","${r.status}","${cleanNotes.replaceAll('"', '""')}"');
    }
    buffer.writeln('');

    buffer.writeln('SECTION 2: REPORTED EQUIPMENT ISSUES');
    buffer.writeln('Timestamp,Equipment,Fault Summary,Severity,Status,Reported By,Action Taken');
    for (var issue in equipmentIssues) {
      buffer.writeln('"${issue['timestamp']}","${issue['equipment']}","${issue['title']}","${issue['severity']}","${issue['status']}","${issue['reporter']}","${issue['actionTaken'] ?? ''}"');
    }
    buffer.writeln('');

    buffer.writeln('SECTION 3: CONSUMED ITEMS (CONSUMABLES & WITNESS WITHDRAWALS)');
    buffer.writeln('Date,Source,Item/Lot,Specification,Quantity,Purpose,User');
    for (var c in consumables) {
      if (c['type'] != 'RECEIVED') {
        buffer.writeln('"${c['date']}","Consumables","${c['itemName']}","${c['serial']}","${c['quantity']} ${c['unit']}","${c['purpose']}","${c['user']}"');
      }
    }
    for (var w in witnessConsumptions) {
      buffer.writeln('"${w['date'] ?? w['timestamp']}","Witness Storage","Lot ${w['lotNo']}","${w['caliber']}","${w['quantity']} rounds","${w['purpose']}","${w['requestedBy'] ?? w['approvedBy']}"');
    }
    buffer.writeln('');

    buffer.writeln('SECTION 4: QUANTITY ADDED TO WITNESS STORAGE');
    buffer.writeln('Date,Lot Number,Caliber,Quantity Added,Location,Condition,Registered By');
    for (var a in witnessAdditions) {
      buffer.writeln('"${a['registeredAt'] ?? a['date']}","${a['lotNo']}","${a['caliber']}","${a['initialQty']} rounds","${a['location']}","${a['storageCondition']}","${a['registeredBy'] ?? ''}"');
    }

    final filename = 'OMPC_Executive_Quality_Report_${_periodType}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    await ReportHelper.instance.downloadCsv(content: buffer.toString(), filename: filename);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Executive CSV report exported: $filename'), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }

  Future<void> _exportExecutiveHtml(
    List<Map<String, dynamic>> inspections,
    List<Map<String, dynamic>> equipmentIssues,
    List<Map<String, dynamic>> consumables,
    List<Map<String, dynamic>> witnessConsumptions,
    List<Map<String, dynamic>> witnessAdditions,
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

    final lotAcceptanceList = inspections.where((e) => e['module'] == 'Lot Acceptance').toList();
    final dailyTestList = inspections.where((e) => e['module'] == 'Daily Test').toList();
    final componentTestList = inspections.where((e) => e['module'] == 'Component Test').toList();

    String renderInspectionTable(List<Map<String, dynamic>> items, String idColName) {
      if (items.isEmpty) {
        return '<table><thead><tr><th>Date & Time</th><th>Inspector</th><th>Test Name</th><th>Caliber</th><th>$idColName</th><th>Qty Tested</th><th>Defects</th><th>Status</th><th>Remarks</th></tr></thead><tbody><tr><td colspan="9" style="text-align: center; color: #64748b;">No inspection logs recorded for this module in this period.</td></tr></tbody></table>';
      }
      return '<table><thead><tr><th>Date & Time</th><th>Inspector</th><th>Test Name</th><th>Caliber</th><th>$idColName</th><th>Qty Tested</th><th>Defects</th><th>Status</th><th>Remarks</th></tr></thead><tbody>' +
        items.map((entry) {
          final m = entry['module'] as String;
          final r = entry['record'] as BallisticRecord;
          final statusClass = r.status.toLowerCase().contains('approved') ? 'badge-approved' : (r.status.toLowerCase().contains('reject') ? 'badge-rejected' : 'badge-retest');
          final idVal = m == 'Daily Test' ? (r.hopperNo.isNotEmpty ? r.hopperNo : r.lotNo) : r.lotNo;
          return '<tr>'
              '<td>${r.testTime.isNotEmpty ? r.testTime : r.timestamp}</td>'
              '<td>${r.operators}</td>'
              '<td>${r.testName}</td>'
              '<td>${r.caliber}</td>'
              '<td>$idVal</td>'
              '<td>${r.produced} rds</td>'
              '<td>${r.defects}</td>'
              '<td><span class="$statusClass">${r.status.toUpperCase()}</span></td>'
              '<td>${ReportGenerator.cleanRemarks(r.notes)}</td>'
              '</tr>';
        }).join('') +
        '</tbody></table>';
    }

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>OMPC Executive Quality Report - $_periodLabel</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 30px; color: #1e293b; background: #fff; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #0284c7; padding-bottom: 12px; margin-bottom: 20px; }
    .title { font-size: 22px; font-weight: bold; color: #0f172a; }
    .subtitle { font-size: 13px; color: #64748b; margin-top: 4px; }
    .kpi-row { display: flex; gap: 12px; margin-bottom: 25px; }
    .kpi-card { flex: 1; border: 1px solid #cbd5e1; border-radius: 8px; padding: 10px; text-align: center; }
    .kpi-val { font-size: 20px; font-weight: bold; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 24px; font-size: 11px; }
    th { background: #0f172a; color: #fff; text-align: left; padding: 8px 10px; font-size: 11px; text-transform: uppercase; }
    td { padding: 8px 10px; border-bottom: 1px solid #e2e8f0; }
    tr:nth-child(even) { background: #f8fafc; }
    .badge-approved { background: #dcfce7; color: #15803d; padding: 2px 6px; border-radius: 4px; font-weight: bold; }
    .badge-rejected { background: #fee2e2; color: #b91c1c; padding: 2px 6px; border-radius: 4px; font-weight: bold; }
    .badge-retest { background: #fef3c7; color: #b45309; padding: 2px 6px; border-radius: 4px; font-weight: bold; }
    .footer { text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #e2e8f0; padding-top: 15px; margin-top: 30px; }
    .module-badge { display: inline-block; background-color: #0284c7; color: #fff; padding: 3px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; margin-bottom: 8px; }
    
    @media print {
      body { margin: 12mm 15mm; }
      .page-break {
        page-break-before: always !important;
        break-before: page !important;
        display: block;
        height: 0;
        margin: 0;
        padding: 0;
        border: none;
      }
    }
    .page-break {
      page-break-before: always;
      break-before: page;
      margin-top: 35px;
      margin-bottom: 25px;
      border-top: 2px dashed #cbd5e1;
    }
  </style>
</head>
<body>
  <!-- PAGE 1: EXECUTIVE KPI SUMMARY & LOT ACCEPTANCE MODULE -->
  <div class="report-page">
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
      <div class="kpi-card" style="border-top: 4px solid #8b5cf6;">
        <div style="font-size: 11px; color: #64748b; font-weight: bold;">EQUIPMENT ISSUES</div>
        <div class="kpi-val" style="color: #8b5cf6;">${equipmentIssues.length}</div>
      </div>
    </div>

    <span class="module-badge">MODULE 1</span>
    <h3 style="margin-top: 4px; margin-bottom: 12px; color: #0f172a;">1. Lot Acceptance Inspection Results</h3>
    ${renderInspectionTable(lotAcceptanceList, 'Lot Number')}
  </div>

  <!-- PAGE 2: DAILY TEST MODULE -->
  <div class="page-break"></div>
  <div class="report-page">
    <div class="header">
      <div>
        <div class="title">OMPC BALLISTIC AERODATA - EXECUTIVE QUALITY REPORT</div>
        <div class="subtitle">DAILY TEST INSPECTION RESULTS | PERIOD: <strong>$_periodLabel</strong> | Generated: $now | Inspector: ${widget.loggedInUser}</div>
      </div>
    </div>

    <span class="module-badge" style="background-color: #059669;">MODULE 2</span>
    <h3 style="margin-top: 4px; margin-bottom: 12px; color: #0f172a;">2. Daily Test Inspection Results</h3>
    ${renderInspectionTable(dailyTestList, 'Hopper / Lot')}
  </div>

  <!-- PAGE 3: COMPONENT TEST MODULE -->
  <div class="page-break"></div>
  <div class="report-page">
    <div class="header">
      <div>
        <div class="title">OMPC BALLISTIC AERODATA - EXECUTIVE QUALITY REPORT</div>
        <div class="subtitle">COMPONENT TEST INSPECTION RESULTS | PERIOD: <strong>$_periodLabel</strong> | Generated: $now | Inspector: ${widget.loggedInUser}</div>
      </div>
    </div>

    <span class="module-badge" style="background-color: #d97706;">MODULE 3</span>
    <h3 style="margin-top: 4px; margin-bottom: 12px; color: #0f172a;">3. Component Test Inspection Results</h3>
    ${renderInspectionTable(componentTestList, 'Batch / Lot')}
  </div>

  <!-- PAGE 4: FACILITY, EQUIPMENT & WITNESS STORAGE ACTIVITY -->
  <div class="page-break"></div>
  <div class="report-page">
    <div class="header">
      <div>
        <div class="title">OMPC BALLISTIC AERODATA - EXECUTIVE QUALITY REPORT</div>
        <div class="subtitle">FACILITY & INVENTORY LOGS | PERIOD: <strong>$_periodLabel</strong> | Generated: $now | Inspector: ${widget.loggedInUser}</div>
      </div>
    </div>

    <h3 style="margin-top: 4px; margin-bottom: 12px; color: #0f172a;">4. Reported Equipment Issues</h3>
    <table>
      <thead>
        <tr>
          <th>Date & Time</th>
          <th>Equipment Instrument</th>
          <th>Fault Summary</th>
          <th>Severity</th>
          <th>Status</th>
          <th>Reported By</th>
          <th>Action Taken</th>
        </tr>
      </thead>
      <tbody>
        ${equipmentIssues.isEmpty ? '<tr><td colspan="7" style="text-align: center; color: #64748b;">No equipment issues reported for this period.</td></tr>' : equipmentIssues.map((issue) {
          final st = (issue['status'] ?? '').toString();
          return '<tr>'
              '<td>${issue['timestamp'] ?? issue['date'] ?? ''}</td>'
              '<td><strong>${issue['equipment'] ?? ''}</strong></td>'
              '<td>${issue['title'] ?? ''}</td>'
              '<td>${issue['severity'] ?? ''}</td>'
              '<td><strong>$st</strong></td>'
              '<td>${issue['reporter'] ?? ''}</td>'
              '<td>${issue['actionTaken'] ?? '-'}</td>'
              '</tr>';
        }).join('')}
      </tbody>
    </table>

    <h3 style="margin-top: 20px; margin-bottom: 12px; color: #0f172a;">5. Consumed Items Activity (Consumables & Witness Storage Withdrawals)</h3>
    <table>
      <thead>
        <tr>
          <th>Date & Time</th>
          <th>Source</th>
          <th>Item / Lot</th>
          <th>Specification</th>
          <th>Qty Consumed</th>
          <th>Purpose / Trial Details</th>
          <th>User / Requester</th>
        </tr>
      </thead>
      <tbody>
        ${(consumables.isEmpty && witnessConsumptions.isEmpty) ? '<tr><td colspan="7" style="text-align: center; color: #64748b;">No items consumed in this period.</td></tr>' : [
          ...consumables.where((c) => c['type'] != 'RECEIVED').map((c) => '<tr><td>${c['date']}</td><td>Consumables</td><td><strong>${c['itemName']}</strong></td><td>${c['serial']}</td><td style="color: #ef4444; font-weight: bold;">-${c['quantity']} ${c['unit']}</td><td>${c['purpose'] ?? ''}</td><td>${c['user'] ?? ''}</td></tr>'),
          ...witnessConsumptions.map((w) => '<tr><td>${w['date'] ?? w['timestamp']}</td><td>Witness Storage</td><td><strong>Lot ${w['lotNo']}</strong></td><td>${w['caliber']}</td><td style="color: #ef4444; font-weight: bold;">-${w['quantity']} rounds</td><td>${w['purpose'] ?? ''}</td><td>${w['requestedBy'] ?? w['approvedBy'] ?? ''}</td></tr>')
        ].join('')}
      </tbody>
    </table>

    <h3 style="margin-top: 20px; margin-bottom: 12px; color: #0f172a;">6. Quantity Added to Witness Storage</h3>
    <table>
      <thead>
        <tr>
          <th>Date & Time</th>
          <th>Lot Number</th>
          <th>Caliber</th>
          <th>Quantity Added</th>
          <th>Storage Location</th>
          <th>Condition</th>
          <th>Registered By</th>
        </tr>
      </thead>
      <tbody>
        ${witnessAdditions.isEmpty ? '<tr><td colspan="7" style="text-align: center; color: #64748b;">No new witness lots registered in this period.</td></tr>' : witnessAdditions.map((a) {
          return '<tr>'
              '<td>${a['registeredAt'] ?? a['date'] ?? a['timestamp'] ?? ''}</td>'
              '<td><strong>${a['lotNo']}</strong></td>'
              '<td>${a['caliber']}</td>'
              '<td style="color: #10b981; font-weight: bold;">+${a['initialQty']} rounds</td>'
              '<td>${a['location'] ?? 'Pallet / Storage'}</td>'
              '<td>${a['storageCondition'] ?? 'Air Conditioned'}</td>'
              '<td>${a['registeredBy'] ?? a['operator'] ?? 'Technician'}</td>'
              '</tr>';
        }).join('')}
      </tbody>
    </table>

    <div class="footer">
      OMPC Ballistic AeroData System &copy; ${DateTime.now().year} | Confidential Executive Document
    </div>
  </div>
</body>
</html>
''';

    await ReportHelper.instance.printHtml(htmlContent: html);
  }
}
