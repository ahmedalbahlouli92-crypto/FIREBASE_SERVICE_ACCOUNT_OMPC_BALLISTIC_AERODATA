import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/report_helper.dart';
import '../services/supabase_service.dart';

class EquipmentReportTab extends StatefulWidget {
  final String loggedInUser;
  final bool isAdmin;

  const EquipmentReportTab({
    Key? key,
    required this.loggedInUser,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  State<EquipmentReportTab> createState() => _EquipmentReportTabState();
}

class _EquipmentReportTabState extends State<EquipmentReportTab> {
  final StorageService _storageService = StorageService();

  static const List<String> equipmentList = [
    'B590 Optical Target System',
    'B216 Data Recorder',
    'B472 Precision Light Screen',
    'B617 Muzzle Flash Detector',
    'Machine Rest Type B299',
    'B202 Calibration Set',
    'B630 Calibration Unit',
    'B180T HPI Closed Vessels',
    'Extraction Fore Tester',
    'Primer Sensitivity Tester',
    'weapon repair',
  ];

  String _selectedEquipment = equipmentList.first;
  String _selectedSeverity = 'Operational Impact';
  String _selectedStatus = 'Open / Reported';

  final TextEditingController _reporterController = TextEditingController();
  final TextEditingController _issueTitleController = TextEditingController();
  final TextEditingController _issueDescController = TextEditingController();
  final TextEditingController _actionTakenController = TextEditingController();

  List<Map<String, dynamic>> _reportedIssues = [];
  bool _isLoading = true;
  String _filterEquipment = 'All Equipment';

  @override
  void initState() {
    super.initState();
    _reporterController.text = widget.loggedInUser;
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);
    final localIssues = await _storageService.loadEquipmentIssues();
    List<Map<String, dynamic>> issues = localIssues;
    try {
      final cloudIssues = await SupabaseService.loadEquipmentIssues();
      if (cloudIssues.isNotEmpty) {
        final Map<String, Map<String, dynamic>> merged = {};
        for (var i in localIssues) {
          merged[i['id'].toString()] = i;
        }
        for (var i in cloudIssues) {
          merged[i['id'].toString()] = i;
        }
        issues = merged.values.toList();
        await _storageService.saveEquipmentIssues(issues);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _reportedIssues = issues;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitIssue() async {
    final title = _issueTitleController.text.trim();
    final desc = _issueDescController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an issue summary or title.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newIssue = {
      'id': 'EQ-${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'equipment': _selectedEquipment,
      'title': title,
      'description': desc,
      'severity': _selectedSeverity,
      'status': _selectedStatus,
      'actionTaken': _actionTakenController.text.trim(),
      'reporter': _reporterController.text.trim().isNotEmpty ? _reporterController.text.trim() : widget.loggedInUser,
    };

    await _storageService.addEquipmentIssue(newIssue);
    _reportedIssues.insert(0, newIssue);
    SupabaseService.saveEquipmentIssues(_reportedIssues);

    _issueTitleController.clear();
    _issueDescController.clear();
    _actionTakenController.clear();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Issue reported for $_selectedEquipment successfully.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateIssueStatus(Map<String, dynamic> issue, String newStatus) async {
    final idx = _reportedIssues.indexWhere((i) => i['id'] == issue['id']);
    if (idx != -1) {
      final updated = Map<String, dynamic>.from(_reportedIssues[idx]);
      updated['status'] = newStatus;
      _reportedIssues[idx] = updated;
      await _storageService.saveEquipmentIssues(_reportedIssues);
      SupabaseService.saveEquipmentIssues(_reportedIssues);
      setState(() {});
    }
  }

  Future<void> _deleteIssue(Map<String, dynamic> issue) async {
    _reportedIssues.removeWhere((i) => i['id'] == issue['id']);
    await _storageService.saveEquipmentIssues(_reportedIssues);
    SupabaseService.saveEquipmentIssues(_reportedIssues);
    setState(() {});
  }

  Future<void> _exportEquipmentReport() async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final filtered = _filterEquipment == 'All Equipment'
        ? _reportedIssues
        : _reportedIssues.where((i) => i['equipment'] == _filterEquipment).toList();

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Equipment Maintenance & Issue Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; color: #0f172a; font-size: 12px; }
    .header { text-align: center; border-bottom: 2px solid #0284c7; padding-bottom: 12px; margin-bottom: 20px; }
    .header h2 { margin: 0; color: #0284c7; font-size: 18px; }
    .header .subtitle { color: #64748b; font-size: 11px; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; margin-top: 15px; }
    th { background-color: #f1f5f9; color: #334155; padding: 8px 10px; border: 1px solid #cbd5e1; text-align: left; font-size: 11px; }
    td { padding: 8px 10px; border: 1px solid #cbd5e1; font-size: 11px; }
    .badge { display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 10px; font-weight: bold; }
    .badge-open { background-color: #fef3c7; color: #b45309; }
    .badge-repair { background-color: #e0f2fe; color: #0369a1; }
    .badge-resolved { background-color: #dcfce7; color: #15803d; }
    .footer { margin-top: 30px; text-align: right; font-size: 10px; color: #94a3b8; }
  </style>
</head>
<body>
  <div class="header">
    <h2>OMPC BALLISTIC AERODATA - EQUIPMENT FLEET REPORT</h2>
    <div class="subtitle">Generated on $now | Reporter: ${widget.loggedInUser}</div>
  </div>
  <table>
    <thead>
      <tr>
        <th>Date & Time</th>
        <th>Equipment Name</th>
        <th>Issue Summary</th>
        <th>Details</th>
        <th>Severity</th>
        <th>Status</th>
        <th>Reported By</th>
        <th>Action Taken</th>
      </tr>
    </thead>
    <tbody>
      ${filtered.isEmpty ? '<tr><td colspan="8" style="text-align: center; color: #64748b;">No equipment issues logged.</td></tr>' : filtered.map((i) {
        final st = (i['status'] ?? '').toString();
        final badgeClass = st.contains('Resolved') ? 'badge-resolved' : (st.contains('Repair') ? 'badge-repair' : 'badge-open');
        return '''
        <tr>
          <td>${i['timestamp']}</td>
          <td><strong>${i['equipment']}</strong></td>
          <td>${i['title']}</td>
          <td>${i['description'] ?? '-'}</td>
          <td>${i['severity']}</td>
          <td><span class="badge $badgeClass">$st</span></td>
          <td>${i['reporter']}</td>
          <td>${i['actionTaken'] ?? '-'}</td>
        </tr>
        ''';
      }).join('')}
    </tbody>
  </table>
  <div class="footer">Confidential Ballistic Lab Technical Document</div>
</body>
</html>
''';

    await ReportHelper.instance.printHtml(htmlContent: html);
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _reportedIssues.where((i) => (i['status'] ?? '').toString().contains('Open')).length;
    final repairCount = _reportedIssues.where((i) => (i['status'] ?? '').toString().contains('Repair')).length;
    final resolvedCount = _reportedIssues.where((i) => (i['status'] ?? '').toString().contains('Resolved')).length;

    final filteredList = _filterEquipment == 'All Equipment'
        ? _reportedIssues
        : _reportedIssues.where((i) => i['equipment'] == _filterEquipment).toList();

    return Container(
      color: const Color(0xFFC4D6EC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Equipment Report & Fault Registry',
                          style: TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Log issues, maintenance requests, and downtime across test instrumentation fleet',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _exportEquipmentReport,
                  icon: const Icon(Icons.picture_as_pdf, size: 16.0),
                  label: const Text('Export Equipment Report', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),

            // Summary Stats Cards
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              children: [
                _buildStatCard('TOTAL LOGGED ISSUES', '${_reportedIssues.length}', const Color(0xFF0284C7), Icons.format_list_bulleted),
                _buildStatCard('OPEN ISSUES', '$openCount', const Color(0xFFEF4444), Icons.error_outline),
                _buildStatCard('UNDER REPAIR', '$repairCount', const Color(0xFFF59E0B), Icons.build_circle_outlined),
                _buildStatCard('RESOLVED / CALIBRATED', '$resolvedCount', const Color(0xFF10B981), Icons.check_circle_outline),
              ],
            ),
            const SizedBox(height: 20.0),

            // Main Log Form & Table Layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return Column(
                  children: [
                    // Report Form Card
                    Container(
                      padding: const EdgeInsets.all(20.0),
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
                            children: const [
                              Icon(Icons.report_problem_outlined, color: Color(0xFFF59E0B), size: 20.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Submit Equipment Fault / Maintenance Report',
                                style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Wrap(
                            spacing: 16.0,
                            runSpacing: 14.0,
                            children: [
                              // Equipment Selection Dropdown (Requirement 9)
                              SizedBox(
                                width: isWide ? (constraints.maxWidth - 80) / 3 : constraints.maxWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('EQUIPMENT INSTRUMENT *', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6.0),
                                    DropdownButtonFormField<String>(
                                      value: _selectedEquipment,
                                      isExpanded: true,
                                      decoration: _inputDecoration(),
                                      items: equipmentList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12.5)))).toList(),
                                      onChanged: (v) => setState(() => _selectedEquipment = v!),
                                    ),
                                  ],
                                ),
                              ),
                              // Severity Level
                              SizedBox(
                                width: isWide ? (constraints.maxWidth - 80) / 3 : constraints.maxWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SEVERITY / PRIORITY', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6.0),
                                    DropdownButtonFormField<String>(
                                      value: _selectedSeverity,
                                      isExpanded: true,
                                      decoration: _inputDecoration(),
                                      items: const [
                                        DropdownMenuItem(value: 'Minor Concern', child: Text('Minor Concern')),
                                        DropdownMenuItem(value: 'Operational Impact', child: Text('Operational Impact')),
                                        DropdownMenuItem(value: 'Critical / Out of Service', child: Text('Critical / Out of Service')),
                                        DropdownMenuItem(value: 'Calibration Needed', child: Text('Calibration Needed')),
                                      ],
                                      onChanged: (v) => setState(() => _selectedSeverity = v!),
                                    ),
                                  ],
                                ),
                              ),
                              // Initial Status
                              SizedBox(
                                width: isWide ? (constraints.maxWidth - 80) / 3 : constraints.maxWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CURRENT STATUS', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6.0),
                                    DropdownButtonFormField<String>(
                                      value: _selectedStatus,
                                      isExpanded: true,
                                      decoration: _inputDecoration(),
                                      items: const [
                                        DropdownMenuItem(value: 'Open / Reported', child: Text('Open / Reported')),
                                        DropdownMenuItem(value: 'Under Repair', child: Text('Under Repair')),
                                        DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                                        DropdownMenuItem(value: 'Calibrated', child: Text('Calibrated')),
                                      ],
                                      onChanged: (v) => setState(() => _selectedStatus = v!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14.0),
                          Wrap(
                            spacing: 16.0,
                            runSpacing: 14.0,
                            children: [
                              // Reporter Name
                              SizedBox(
                                width: isWide ? (constraints.maxWidth - 80) / 3 : constraints.maxWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('REPORTED BY (OPERATOR / TECHNICIAN)', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6.0),
                                    TextField(controller: _reporterController, decoration: _inputDecoration()),
                                  ],
                                ),
                              ),
                              // Issue Summary / Title
                              SizedBox(
                                width: isWide ? ((constraints.maxWidth - 80) * 2 / 3) + 16 : constraints.maxWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ISSUE SUMMARY / PROBLEM TITLE *', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6.0),
                                    TextField(controller: _issueTitleController, decoration: _inputDecoration(hint: 'e.g. Optical sensor beam misalignment / Calibration drift')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14.0),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('DETAILED SYMPTOMS / NOTES', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6.0),
                                    TextField(controller: _issueDescController, maxLines: 2, decoration: _inputDecoration(hint: 'Describe symptoms, error codes, readings or circumstances observed...')),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ACTION TAKEN / PROPOSED REPAIR', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6.0),
                                    TextField(controller: _actionTakenController, maxLines: 2, decoration: _inputDecoration(hint: 'Action taken or required vendor service / parts...')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _submitIssue,
                              icon: const Icon(Icons.send_rounded, size: 16.0),
                              label: const Text('Submit Equipment Issue Report', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Issue Registry Table Container
                    Container(
                      padding: const EdgeInsets.all(20.0),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.history_rounded, color: Color(0xFF0284C7), size: 20.0),
                                  SizedBox(width: 8.0),
                                  Text(
                                    'Logged Equipment Faults & Maintenance Log',
                                    style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              // Filter by Equipment
                              Row(
                                children: [
                                  const Text('Filter: ', style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8.0),
                                  DropdownButton<String>(
                                    value: _filterEquipment,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.0, fontWeight: FontWeight.w600),
                                    underline: const SizedBox(),
                                    items: ['All Equipment', ...equipmentList].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: (v) => setState(() => _filterEquipment = v!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          if (_isLoading)
                            const Center(child: Padding(padding: EdgeInsets.all(30.0), child: CircularProgressIndicator()))
                          else if (filteredList.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32.0),
                              alignment: Alignment.center,
                              child: Column(
                                children: const [
                                  Icon(Icons.check_circle_outline, size: 42.0, color: Color(0xFF10B981)),
                                  SizedBox(height: 8.0),
                                  Text('No reported equipment issues found. All systems operational.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13.0)),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredList.length,
                              separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0)),
                              itemBuilder: (context, idx) {
                                final issue = filteredList[idx];
                                final status = (issue['status'] ?? 'Open').toString();
                                final isResolved = status.contains('Resolved') || status.contains('Calibrated');
                                final isRepair = status.contains('Repair');

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          color: isResolved
                                              ? const Color(0xFFDCFCE7)
                                              : (isRepair ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7)),
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        child: Icon(
                                          isResolved
                                              ? Icons.check_circle_outline
                                              : (isRepair ? Icons.build_circle_outlined : Icons.error_outline),
                                          color: isResolved
                                              ? const Color(0xFF15803D)
                                              : (isRepair ? const Color(0xFF0369A1) : const Color(0xFFB45309)),
                                          size: 20.0,
                                        ),
                                      ),
                                      const SizedBox(width: 14.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  issue['equipment'] ?? '',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0284C7)),
                                                ),
                                                const SizedBox(width: 8.0),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4.0),
                                                  ),
                                                  child: Text(
                                                    issue['severity'] ?? '',
                                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  issue['timestamp'] ?? '',
                                                  style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4.0),
                                            Text(
                                              issue['title'] ?? '',
                                              style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            ),
                                            if ((issue['description'] ?? '').toString().isNotEmpty) ...[
                                              const SizedBox(height: 2.0),
                                              Text(
                                                issue['description'],
                                                style: const TextStyle(fontSize: 12.0, color: Color(0xFF475569)),
                                              ),
                                            ],
                                            if ((issue['actionTaken'] ?? '').toString().isNotEmpty) ...[
                                              const SizedBox(height: 4.0),
                                              Text(
                                                'Action: ${issue['actionTaken']}',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                            const SizedBox(height: 6.0),
                                            Row(
                                              children: [
                                                Text(
                                                  'Reported by: ${issue['reporter'] ?? 'Technician'}',
                                                  style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                                                ),
                                                const Spacer(),
                                                DropdownButton<String>(
                                                  value: ['Open / Reported', 'Under Repair', 'Resolved', 'Calibrated'].contains(status) ? status : 'Open / Reported',
                                                  underline: const SizedBox(),
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                                  items: const [
                                                    DropdownMenuItem(value: 'Open / Reported', child: Text('Open / Reported')),
                                                    DropdownMenuItem(value: 'Under Repair', child: Text('Under Repair')),
                                                    DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                                                    DropdownMenuItem(value: 'Calibrated', child: Text('Calibrated')),
                                                  ],
                                                  onChanged: (newSt) {
                                                    if (newSt != null) _updateIssueStatus(issue, newSt);
                                                  },
                                                ),
                                                if (widget.isAdmin) ...[
                                                  const SizedBox(width: 8.0),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 16.0, color: Color(0xFFEF4444)),
                                                    tooltip: 'Delete Log',
                                                    onPressed: () => _deleteIssue(issue),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, Color color, IconData icon) {
    return Container(
      width: 220.0,
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
              Text(title, style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 2.0),
              Text(val, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
    );
  }
}
