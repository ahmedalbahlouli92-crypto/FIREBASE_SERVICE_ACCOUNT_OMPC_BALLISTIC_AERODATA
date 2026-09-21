import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/ballistic_record.dart';
import '../services/report_helper.dart';
import '../services/report_generator.dart';
import '../services/ai_analysis_service.dart';

class HistoryTab extends StatefulWidget {
  final String currentModule;
  final List<BallisticRecord> records;
  final VoidCallback onOpenFolder;
  final bool isAdmin;
  final bool canEditRecords;
  final bool canDeleteRecords;
  final bool canExportReports;
  final Function(BallisticRecord) onDeleteRecord;
  final Future<void> Function(BallisticRecord original, BallisticRecord updated)? onEditRecord;
  final String base64Logo;
  final Map<String, dynamic> adminRules;
  final VoidCallback? onClearDailyTestLogs;

  const HistoryTab({
    Key? key,
    required this.currentModule,
    required this.records,
    required this.onOpenFolder,
    required this.isAdmin,
    this.canEditRecords = false,
    this.canDeleteRecords = false,
    this.canExportReports = true,
    required this.onDeleteRecord,
    this.onEditRecord,
    required this.base64Logo,
    this.adminRules = const {},
    this.onClearDailyTestLogs,
  }) : super(key: key);

  @override
  _HistoryTabState createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _caliberFilter = 'All';
  String _testNameFilter = 'All';
  String _statusFilter = 'All';
  String _lotFilter = 'All';
  String _hopperFilter = 'All';

  static const List<String> calibers = [
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

  static const List<String> testNames = [
    'Waterproof Test',
    'Extraction Force Test',
    'Accuracy Test',
    'EPVAT test',
    'Function Test',
    'Residual Stress Test',
    'Terminal Effect Test',
    'Firing Rate Cycle Test',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _showAiAnalysisDialog(BallisticRecord r) {
    final rec = AiAnalysisService.instance.analyzeRecord(r, adminRules: widget.adminRules);

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF0284C7), size: 22.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Advisory: ${rec.testName}',
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Lot: ${r.lotNo} • Caliber: ${r.caliber} • ${r.timestamp}',
                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: rec.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: rec.statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  rec.status,
                  style: TextStyle(color: rec.statusColor, fontSize: 11.0, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620.0, maxHeight: 520.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Summary Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      rec.summary,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.0, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Key Metrics
                  if (rec.keyMetrics.isNotEmpty) ...[
                    const Text('KEY METRICS', style: TextStyle(color: Color(0xFF0369A1), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 8.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: rec.keyMetrics.entries.map((e) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 11.5),
                              children: [
                                TextSpan(text: '${e.key}: ', style: const TextStyle(color: Color(0xFF64748B))),
                                TextSpan(text: e.value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono')),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16.0),
                  ],

                  // Diagnostic Findings
                  const Text('DIAGNOSTIC FINDINGS', style: TextStyle(color: Color(0xFF0369A1), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8.0),
                  ...rec.findings.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.fiber_manual_record, color: Color(0xFF0284C7), size: 8.0),
                        const SizedBox(width: 8.0),
                        Expanded(child: Text(f, style: const TextStyle(color: Color(0xFF334155), fontSize: 12.0, height: 1.35))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16.0),

                  // Actionable Recommendations
                  const Text('RECOMMENDATIONS', style: TextStyle(color: Color(0xFF059669), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8.0),
                  ...rec.recommendations.map((rc) => Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 15.0),
                        const SizedBox(width: 8.0),
                        Expanded(child: Text(rc, style: const TextStyle(color: Color(0xFF065F46), fontSize: 12.0, height: 1.35))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BallisticRecord record) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF344D6E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: const BorderSide(color: Color(0xFF1E3A8A)),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8.0),
              Text('Confirm Deletion', style: TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete the inspection entry for lot "${record.lotNumber}"?',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.0),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onDeleteRecord(record);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEditRecordDialog(BallisticRecord r) {
    final operatorsController = TextEditingController(text: r.operators);
    final lotNoController = TextEditingController(text: r.lotNo);
    final producedController = TextEditingController(text: '${r.produced}');
    final defectsController = TextEditingController(text: '${r.defects}');
    final notesController = TextEditingController(text: r.notes);
    final pressureController = TextEditingController(text: r.pressureBar);
    final viscosityController = TextEditingController(text: r.viscosity);
    final testTimeController = TextEditingController(text: r.testTime);
    final locationController = TextEditingController(text: r.samplingLocation);
    final mouthSlowController = TextEditingController(text: '${r.mouthSlow}');
    final mouthFastController = TextEditingController(text: '${r.mouthFast}');
    final primerSlowController = TextEditingController(text: '${r.primerSlow}');
    final primerFastController = TextEditingController(text: '${r.primerFast}');
    final velMeanController = TextEditingController(text: r.velMean);
    final barrelSNController = TextEditingController(text: r.barrelSN);
    final roomTempController = TextEditingController(text: r.roomTemp);

    String editShift = r.shift;
    String editStatus = r.status;
    String editCaliber = r.caliber;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF344D6E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C415E),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8), size: 22.0),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Inspection Log Entry',
                          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${r.testName} • ${r.timestamp}',
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: math.min(650.0, MediaQuery.of(context).size.width * 0.94),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Inspector & Shift
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildDialogField(
                              label: 'Operators / Inspectors',
                              child: _buildDialogTextField(controller: operatorsController),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            flex: 1,
                            child: _buildDialogField(
                              label: 'Shift Time',
                              child: DropdownButtonFormField<String>(
                                value: ['Day', 'Night'].contains(editShift) ? editShift : 'Day',
                                dropdownColor: const Color(0xFF1A2035),
                                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                                decoration: _dialogInputDecoration(),
                                items: ['Day', 'Night'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (v) => setDialogState(() => editShift = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),

                      // Section 2: Caliber & Lot / Hopper
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildDialogField(
                              label: 'Caliber Specification',
                              child: DropdownButtonFormField<String>(
                                value: calibers.contains(editCaliber) ? editCaliber : calibers.first,
                                dropdownColor: const Color(0xFF1A2035),
                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                decoration: _dialogInputDecoration(),
                                items: calibers.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) => setDialogState(() => editCaliber = v!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            flex: 2,
                            child: _buildDialogField(
                              label: widget.currentModule == 'Daily Test' ? 'Hopper No. / Production Date' : 'Lot Number',
                              child: _buildDialogTextField(controller: lotNoController),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),

                      // Section 3: Quantity Tested, Defects, Status
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildDialogField(
                              label: 'Quantity Tested',
                              child: _buildDialogTextField(controller: producedController, keyboardType: TextInputType.number),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            flex: 1,
                            child: _buildDialogField(
                              label: 'Defects',
                              child: _buildDialogTextField(controller: defectsController, keyboardType: TextInputType.number),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            flex: 2,
                            child: _buildDialogField(
                              label: 'Quality Sentencing Status',
                              child: DropdownButtonFormField<String>(
                                value: ['Approved', 'Rejected', 'Retest', 'Approved with condition'].contains(editStatus) ? editStatus : 'Approved',
                                dropdownColor: const Color(0xFF1A2035),
                                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                decoration: _dialogInputDecoration(),
                                items: ['Approved', 'Rejected', 'Retest', 'Approved with condition'].map((s) {
                                  final col = s == 'Approved'
                                      ? const Color(0xFF10B981)
                                      : s == 'Rejected'
                                          ? const Color(0xFFEF4444)
                                          : s == 'Retest'
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF06B6D4);
                                  return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: col)));
                                }).toList(),
                                onChanged: (v) => setDialogState(() => editStatus = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),

                      // Section 4: Remarks / Notes
                      _buildDialogField(
                        label: 'Remarks / Notes',
                        child: _buildDialogTextField(controller: notesController, maxLines: 2),
                      ),

                      // Test-specific quick edits
                      if (r.testName == 'Waterproof Test') ...[
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Pressure (Bar)', child: _buildDialogTextField(controller: pressureController))),
                            const SizedBox(width: 12.0),
                            Expanded(child: _buildDialogField(label: 'Viscosity', child: _buildDialogTextField(controller: viscosityController))),
                            const SizedBox(width: 12.0),
                            Expanded(child: _buildDialogField(label: 'Location', child: _buildDialogTextField(controller: locationController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Mouth Slow', child: _buildDialogTextField(controller: mouthSlowController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Mouth Fast', child: _buildDialogTextField(controller: mouthFastController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Primer Slow', child: _buildDialogTextField(controller: primerSlowController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Primer Fast', child: _buildDialogTextField(controller: primerFastController, keyboardType: TextInputType.number))),
                          ],
                        ),
                      ] else if (r.testName == 'Residual Stress Test') ...[
                        const SizedBox(height: 12.0),
                        _buildDialogField(label: 'Room Temperature (°C)', child: _buildDialogTextField(controller: roomTempController)),
                      ] else if (r.testName == 'Accuracy Test' || r.testName == 'EPVAT test') ...[
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Barrel S.N.', child: _buildDialogTextField(controller: barrelSNController))),
                            const SizedBox(width: 12.0),
                            Expanded(child: _buildDialogField(label: 'Mean Velocity (m/s)', child: _buildDialogTextField(controller: velMeanController))),
                          ],
                        ),
                      ],
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
                    final int produced = int.tryParse(producedController.text.trim()) ?? r.produced;
                    final int defects = int.tryParse(defectsController.text.trim()) ?? r.defects;
                    final int mouthSlow = int.tryParse(mouthSlowController.text.trim()) ?? r.mouthSlow;
                    final int mouthFast = int.tryParse(mouthFastController.text.trim()) ?? r.mouthFast;
                    final int primerSlow = int.tryParse(primerSlowController.text.trim()) ?? r.primerSlow;
                    final int primerFast = int.tryParse(primerFastController.text.trim()) ?? r.primerFast;

                    final updated = r.copyWith(
                      operators: operatorsController.text.trim(),
                      shift: editShift,
                      caliber: editCaliber,
                      lotNo: lotNoController.text.trim(),
                      produced: produced,
                      defects: defects,
                      status: editStatus,
                      notes: notesController.text.trim(),
                      pressureBar: pressureController.text.trim(),
                      viscosity: viscosityController.text.trim(),
                      samplingLocation: locationController.text.trim(),
                      mouthSlow: mouthSlow,
                      mouthFast: mouthFast,
                      primerSlow: primerSlow,
                      primerFast: primerFast,
                      barrelSN: barrelSNController.text.trim(),
                      velMean: velMeanController.text.trim(),
                      roomTemp: roomTempController.text.trim(),
                    );
                    Navigator.pop(ctx);
                    widget.onEditRecord?.call(r, updated);
                  },
                  icon: const Icon(Icons.check, size: 16.0),
                  label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6.0),
        child,
      ],
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13.0),
      decoration: _dialogInputDecoration(),
    );
  }

  InputDecoration _dialogInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF2C415E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
    );
  }

  void _copyCsvToClipboard(List<BallisticRecord> displayRecords) {
    if (displayRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No filtered data logs available to copy.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    const headers = 'Timestamp,Operators,Shift,Caliber Specification,Projectile/Lot Number,Quantity Tested,Defects Found,Remarks,Quality Status,Test Name,Pressure (Bar),Viscosity,Time of Test,Sampling Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast,Hopper No,Box No\n';
    final buffer = StringBuffer(headers);
    for (var r in displayRecords) {
      buffer.write(r.toCsvRow());
    }

    Clipboard.setData(ClipboardData(text: buffer.toString())).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily CSV logs copied to clipboard!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    });
  }

  Widget _buildResultCell(BallisticRecord r) {
    if (r.testName == 'Waterproof Test') {
      final totalLeaks = r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$totalLeaks leaks (${totalLeaks == 0 ? "Zero defects" : "M:${r.mouthSlow + r.mouthFast}, P:${r.primerSlow + r.primerFast}"})',
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: totalLeaks > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            ),
          ),
          Text(
            'Pressure: ${r.pressureBar.isNotEmpty ? r.pressureBar : "0.5"} bar',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      );
    } else if (r.testName == 'Function Test') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${r.defects} defects (L1:${r.functionLevel1}, L2:${r.functionLevel2}, L3:${r.functionLevel3}, L4:${r.functionLevel4})',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: r.defects > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            ),
          ),
          if (r.cyclicRateWeaponType.isNotEmpty)
            Text(
              r.cyclicRateWeaponType,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8)),
            ),
        ],
      );
    } else if (r.testName == 'Accuracy Test') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'MR: ${r.accMeanRadius.isNotEmpty ? r.accMeanRadius : "-"} mm | X: ${r.accMeanX} | Y: ${r.accMeanY}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          if ((double.tryParse(r.accLargestDistance) ?? 0) > 0)
            Text(
              'Largest Dist: ${r.accLargestDistance} mm',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
            ),
        ],
      );
    } else if (r.testName == 'EPVAT test') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'P1: ${r.epvatMeanPressure.isNotEmpty ? r.epvatMeanPressure : "-"} ${r.epvatPressureUnit}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          Text(
            'Vel: ${r.velMean.isNotEmpty ? r.velMean : "-"} m/s | Temp: ${r.cartridgeTemp} °C',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      );
    } else if (r.testName == 'Extraction Force Test') {
      return Text(
        'Mean: ${r.accMeanX.isNotEmpty ? r.accMeanX : "-"} N | Min: ${r.accMinX.isNotEmpty ? r.accMinX : "-"} N',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
      );
    } else if (r.testName == 'Residual Stress Test') {
      final total = r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast;
      return Text(
        'Total Splits: $total | Temp: ${r.roomTemp.isNotEmpty ? r.roomTemp : "-"} °C',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: total > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        ),
      );
    } else if (r.testName == 'Firing Rate Cycle Test') {
      return Text(
        'Rate: ${r.cyclicRateValue.isNotEmpty ? r.cyclicRateValue : "-"} RPM',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
      );
    } else if (r.testName == 'Terminal Effect Test') {
      return Text(
        'Dist: ${r.velocityDistance.isNotEmpty ? r.velocityDistance : "-"}m | Hole: ${r.terminalHoleDiameter.isNotEmpty ? r.terminalHoleDiameter : "-"}',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
      );
    }
    return Text(
      r.notes.isNotEmpty ? r.notes : '-',
      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableLots = {'All', ...widget.records.map((r) => r.lotNo.trim()).where((s) => s.isNotEmpty)}.toList()..sort();
    final availableHoppers = {'All', ...widget.records.map((r) => r.hopperNo.trim()).where((s) => s.isNotEmpty)}.toList()..sort();
    if (!availableLots.contains(_lotFilter)) _lotFilter = 'All';
    if (!availableHoppers.contains(_hopperFilter)) _hopperFilter = 'All';

    // Apply filters
    final query = _searchController.text.toLowerCase().trim();
    final filtered = widget.records.where((r) {
      final matchesSearch = r.operators.toLowerCase().contains(query) ||
          r.lotNo.toLowerCase().contains(query) ||
          r.hopperNo.toLowerCase().contains(query) ||
          r.boxNo.toLowerCase().contains(query) ||
          r.notes.toLowerCase().contains(query);

      final matchesCaliber = _caliberFilter == 'All' || r.caliber == _caliberFilter;
      final matchesStatus = _statusFilter == 'All' || r.status == _statusFilter;
      final matchesLot = _lotFilter == 'All' || r.lotNo.trim() == _lotFilter;
      final matchesHopper = _hopperFilter == 'All' || r.hopperNo.trim() == _hopperFilter;
      final matchesTestName = _testNameFilter == 'All' || r.testName == _testNameFilter;

      return matchesSearch && matchesCaliber && matchesStatus && matchesTestName && matchesLot && matchesHopper;
    }).toList();

    // Show newest first (explicitly sorted by timestamp descending)
    final displayRecords = List<BallisticRecord>.from(filtered)
      ..sort((a, b) {
        try {
          final da = DateFormat('M/d/yyyy h:mm:ss a').parse(a.timestamp);
          final db = DateFormat('M/d/yyyy h:mm:ss a').parse(b.timestamp);
          return db.compareTo(da);
        } catch (_) {
          return b.timestamp.compareTo(a.timestamp);
        }
      });
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Daily Inspection Logs',
                    style: TextStyle(
                      fontSize: 26.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4.0),
                  Text(
                    'Complete catalog of ballistic trials logged today',
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
              spacing: 12.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isDesktop && widget.isAdmin)
                  ElevatedButton.icon(
                    onPressed: widget.onOpenFolder,
                    icon: const Icon(Icons.folder_open, size: 16.0),
                    label: const Text('Open Logs Folder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF344D6E),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _showReportGenerationDialog(filtered),
                  icon: const Icon(Icons.picture_as_pdf, size: 16.0),
                  label: const Text('Generate Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copyCsvToClipboard(filtered),
                  icon: const Icon(Icons.copy_all, size: 16.0),
                  label: const Text('Copy CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
                if (widget.currentModule == 'Daily Test' && widget.isAdmin && widget.onClearDailyTestLogs != null)
                  ElevatedButton.icon(
                    onPressed: widget.onClearDailyTestLogs,
                    icon: const Icon(Icons.delete_sweep, size: 16.0),
                    label: const Text('Clear Inspection Log'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20.0),

        // Filters card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF344D6E),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0xFF1E3A8A)),
            boxShadow: const [
              BoxShadow(color: Color(0x20000000), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SEARCH LOT / HOPPER / INSPECTOR', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6.0),
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0),
                          decoration: InputDecoration(
                            hintText: 'Type to filter logs...',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.0),
                            prefixIcon: const Icon(Icons.search, size: 18.0, color: Color(0xFF38BDF8)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF2C415E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CALIBER', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6.0),
                        _buildDropdown(
                          value: _caliberFilter,
                          items: ['All', ...calibers],
                          onChanged: (v) => setState(() => _caliberFilter = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TEST NAME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6.0),
                        _buildDropdown(
                          value: _testNameFilter,
                          items: ['All', ...testNames],
                          onChanged: (v) => setState(() => _testNameFilter = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LOT NUMBER', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6.0),
                        _buildDropdown(
                          value: _lotFilter,
                          items: availableLots,
                          onChanged: (v) => setState(() => _lotFilter = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HOPPER NO.', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6.0),
                        _buildDropdown(
                          value: _hopperFilter,
                          items: availableHoppers,
                          onChanged: (v) => setState(() => _hopperFilter = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('STATUS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6.0),
                        _buildDropdown(
                          value: _statusFilter,
                          items: const ['All', 'Approved', 'Pending Review', 'Rejected', 'Retest', 'Approved with condition'],
                          onChanged: (v) => setState(() => _statusFilter = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20.0),

        // Logs table card (Full width to right side)
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(color: Color(0x20000000), blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            child: displayRecords.isEmpty
                ? const Center(
                    child: Text(
                      'No inspection logs match the active filters.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final double dynamicSpacing = ((availableWidth - 850.0) / 10.0).clamp(14.0, 60.0);

                      return Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(bottom: 48.0),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: availableWidth),
                                child: DataTable(
                                  columnSpacing: dynamicSpacing,
                                  horizontalMargin: 20.0,
                                  headingRowColor: MaterialStateProperty.all(const Color(0xFF2C415E)),
                                  columns: [
                                    const DataColumn(label: Text('TIME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('INSPECTOR', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('SHIFT TIME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('CALIBER', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('TEST NAME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    DataColumn(
                                      label: Text(
                                        widget.currentModule == 'Daily Test' ? 'HOPPER NO. / PROD DATE' : 'LOT NO. (H/B)',
                                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const DataColumn(label: Text('STATUS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('SAMPLE SIZE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('RESULTS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('ACTIONS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold))),
                                  ],
                                  rows: displayRecords.map((r) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(r.timestamp, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.5, color: Color(0xFF94A3B8)))),
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
                                              r.caliber,
                                              style: const TextStyle(color: Colors.white, fontFamily: 'JetBrainsMono', fontSize: 10.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1C3351),
                                              borderRadius: BorderRadius.circular(4.0),
                                              border: Border.all(color: const Color(0xFF1E3A8A)),
                                            ),
                                            child: Text(
                                              r.testName,
                                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            r.hopperNo.isEmpty && r.boxNo.isEmpty
                                                ? r.lotNo
                                                : '${r.lotNo} (H:${r.hopperNo}, B:${r.boxNo})',
                                            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.0, color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        DataCell(_buildStatusBadge(r.status)),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2C415E),
                                              borderRadius: BorderRadius.circular(6.0),
                                              border: Border.all(color: const Color(0xFF1E3A8A)),
                                            ),
                                            child: Text(
                                              '${r.produced} rounds',
                                              style: const TextStyle(
                                                fontFamily: 'JetBrainsMono',
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(_buildResultCell(r)),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18.0),
                                                onPressed: () => _showAiAnalysisDialog(r),
                                                tooltip: 'AI Analysis & Recommendations',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 8.0),
                                              if (r.attachmentBase64.isNotEmpty) ...[
                                                IconButton(
                                                  icon: const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 18.0),
                                                  onPressed: () => _showAttachmentDialog(r),
                                                  tooltip: 'View Attachment (${r.attachmentName})',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 8.0),
                                              ],
                                              IconButton(
                                                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF38BDF8), size: 18.0),
                                                onPressed: () => _showReportGenerationDialog([r], singleRecord: r),
                                                tooltip: 'Generate Individual Report',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              if (widget.isAdmin || widget.canEditRecords) ...[
                                                const SizedBox(width: 8.0),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 18.0),
                                                  onPressed: () => _showEditRecordDialog(r),
                                                  tooltip: 'Edit Entry',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                              if (widget.isAdmin || widget.canDeleteRecords) ...[
                                                const SizedBox(width: 8.0),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18.0),
                                                  onPressed: () => _confirmDelete(r),
                                                  tooltip: 'Delete Entry',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w500),
      dropdownColor: const Color(0xFF344D6E),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF2C415E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
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
    } else if (status == 'Rejected' || status == 'Failed') {
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

  void _showAttachmentDialog(BallisticRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Container(
          width: math.min(550.0, MediaQuery.of(context).size.width * 0.94),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file, color: Color(0xFF06B6D4), size: 20.0),
                      const SizedBox(width: 8.0),
                      Text(
                        record.attachmentName.isNotEmpty ? record.attachmentName : 'Test Attachment',
                        style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8E96A3), size: 18.0),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              if (record.attachmentBase64.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 350.0),
                    width: double.infinity,
                    color: Colors.black.withOpacity(0.3),
                    child: record.attachmentBase64.startsWith('data:image/') || (!record.attachmentName.toLowerCase().endsWith('.pdf') && !record.attachmentName.toLowerCase().endsWith('.doc'))
                        ? Image.memory(
                            base64Decode(record.attachmentBase64.contains(',') ? record.attachmentBase64.split(',')[1] : record.attachmentBase64),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text('File attached (non-image format)', style: TextStyle(color: Color(0xFF8E96A3))),
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.description_outlined, size: 48.0, color: Color(0xFF06B6D4)),
                                  SizedBox(height: 8.0),
                                  Text('Document attached to test record', style: TextStyle(color: Colors.white, fontSize: 13.0)),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Test: ${record.testName} | Lot: ${record.lotNo}',
                    style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close', style: TextStyle(color: Color(0xFF06B6D4))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportGenerationDialog(List<BallisticRecord> initialRecords, {BallisticRecord? singleRecord}) {
    String selectedReportTest = singleRecord != null
        ? singleRecord.testName
        : (_lotFilter != 'All' ? 'All' : _testNameFilter);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final reportRecords = singleRecord != null
                ? [singleRecord]
                : initialRecords.where((r) {
                    return selectedReportTest == 'All' || r.testName == selectedReportTest;
                  }).toList();

            final totalQty = reportRecords.fold<int>(0, (sum, r) => sum + r.produced);
            final totalDefects = reportRecords.fold<int>(0, (sum, r) => sum + r.defects);
            final yieldRate = totalQty > 0 ? (((totalQty - totalDefects) / totalQty) * 100.0) : 100.0;

            return Dialog(
              backgroundColor: const Color(0xFF344D6E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: const BorderSide(color: Color(0xFF1E3A8A)),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 40.0,
                vertical: 24.0,
              ),
              child: Container(
                width: math.min(1000.0, MediaQuery.of(context).size.width * 0.94),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              singleRecord != null ? 'Individual Report Generator' : 'Quality Report Generator',
                              style: const TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              singleRecord != null
                                  ? 'Generate and download quality log sheets for this specific test entry'
                                  : 'Review and download quality log sheets for tests',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E3A8A), height: 24.0),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: singleRecord != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'INDIVIDUAL TEST RECORD',
                                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2C415E),
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: const Color(0xFF1E3A8A)),
                                      ),
                                      child: Text(
                                        '${singleRecord.testName} (Lot: ${singleRecord.lotNo})',
                                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SELECT TEST TYPE',
                                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2C415E),
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: const Color(0xFF1E3A8A)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedReportTest,
                                          isExpanded: true,
                                          dropdownColor: const Color(0xFF344D6E),
                                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
                                          items: ['All', ...testNames].map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            setStateDialog(() {
                                              selectedReportTest = v!;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 24.0),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C415E),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: const Color(0xFF1E3A8A)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildDialogStat('TOTAL LOGS', '${reportRecords.length}'),
                                _buildDialogStat('TOTAL TESTED', '$totalQty rounds'),
                                _buildDialogStat('YIELD RATE', '${yieldRate.toStringAsFixed(2)}%'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),

                    const Text(
                      'REPORT PREVIEW',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),

                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C415E),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFF1E3A8A)),
                        ),
                        child: reportRecords.isEmpty
                            ? const Center(
                                child: Text(
                                  'No inspection logs recorded for this test type today.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.0),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: const Color(0xFF1E3A8A),
                                    ),
                                    child: DataTable(
                                      headingRowColor: MaterialStateProperty.all(const Color(0xFF263852)),
                                      columns: [
                                        const DataColumn(label: Text('TIME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('INSPECTOR', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('SHIFT', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('CALIBER', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        DataColumn(
                                          label: Text(
                                            widget.currentModule == 'Daily Test' ? 'HOPPER NO. / PROD DATE' : 'LOT NUMBER',
                                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const DataColumn(label: Text('RESULT', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('QTY', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        if (selectedReportTest == 'All') ...[
                                          const DataColumn(label: Text('TEST NAME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('DETAILS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'Waterproof Test') ...[
                                          const DataColumn(label: Text('PRESSURE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('VISCOSITY', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('TEST TIME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('LOCATION', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('MOUTH LEAKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('PRIMER LEAKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'Residual Stress Test') ...[
                                          const DataColumn(label: Text('ROOM TEMP', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('NECK (I)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('SHOULDER (S)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('BODY (J/K)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('HEAD (L/M)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('TOTAL SPLITS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'Accuracy Test') ...[
                                          const DataColumn(label: Text('BARREL S.N.', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('VEL MEAN', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('ACC SD X', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('ACC SD Y', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'EPVAT test') ...[
                                          const DataColumn(label: Text('BARREL S.N.', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('TEMP (°C)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('MEAN PRESS (P1/P2)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('VEL MEAN', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'Extraction Force Test') ...[
                                          const DataColumn(label: Text('MODE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('MIN FORCE (N)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('MEAN FORCE (N)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'Function Test') ...[
                                          const DataColumn(label: Text('WEAPON', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('TEMP', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('L1 CRITICAL', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('L2 MAJOR', style: TextStyle(color: Color(0xFFF97316), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('L3 MINOR', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('LEVEL 4', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('TOTAL DEFECTS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else ...[
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ],
                                      ],
                                      rows: reportRecords.map((r) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(r.timestamp, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            DataCell(Text(r.operators, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white))),
                                            DataCell(Text(r.shift, style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            DataCell(Text(r.caliber, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.0, color: Colors.white))),
                                            DataCell(Text(r.lotNo, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.0, color: Colors.white))),
                                            DataCell(_buildStatusBadge(r.status)),
                                            DataCell(Text('${r.produced}', style: const TextStyle(fontSize: 11.5, color: Colors.white))),
                                            if (selectedReportTest == 'All') ...[
                                              DataCell(Text(r.testName, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)))),
                                              DataCell(_buildResultCell(r)),
                                            ] else if (selectedReportTest == 'Waterproof Test') ...[
                                              DataCell(Text(r.pressureBar.isEmpty ? '-' : '${r.pressureBar} bar', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.viscosity.isEmpty ? '-' : r.viscosity, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.testTime.isEmpty ? '-' : r.testTime, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.samplingLocation.isEmpty ? '-' : r.samplingLocation, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('S: ${r.mouthSlow} | F: ${r.mouthFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('S: ${r.primerSlow} | F: ${r.primerFast}', style: const TextStyle(color: Colors.white))),
                                            ] else if (selectedReportTest == 'Residual Stress Test') ...[
                                              DataCell(Text(r.roomTemp.isEmpty ? '-' : '${r.roomTemp} °C', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.neckSlow} | Maj: ${r.neckFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.shoulderSlow} | Maj: ${r.shoulderFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.bodySlow} | Maj: ${r.bodyFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.headSlow} | Maj: ${r.headFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('${r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.notes, style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            ] else if (selectedReportTest == 'Accuracy Test') ...[
                                              DataCell(Text(r.barrelSN.isEmpty ? '-' : r.barrelSN, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.velMean.isEmpty ? '-' : '${r.velMean} m/s', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accSDX.isEmpty ? '-' : r.accSDX, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accSDY.isEmpty ? '-' : r.accSDY, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.notes, style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            ] else if (selectedReportTest == 'EPVAT test') ...[
                                              DataCell(Text(r.barrelSN.isEmpty ? '-' : r.barrelSN, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.cartridgeTemp.isEmpty ? '-' : '${r.cartridgeTemp} °C', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.epvatMeanPressure.isEmpty ? '-' : 'P1: ${r.epvatMeanPressure} / P2: ${r.epvatP2MeanPressure.isEmpty ? "-" : r.epvatP2MeanPressure} ${r.epvatPressureUnit}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.velMean.isEmpty ? '-' : '${r.velMean} m/s', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.notes, style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            ] else if (selectedReportTest == 'Extraction Force Test') ...[
                                              DataCell(Text(r.extractionForceType.isEmpty ? '-' : r.extractionForceType, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accMinX.isEmpty ? '-' : '${r.accMinX} N', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accMeanX.isEmpty ? '-' : '${r.accMeanX} N', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.notes, style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            ] else if (selectedReportTest == 'Function Test') ...[
                                              DataCell(Text(r.cyclicRateWeaponType.isEmpty ? '-' : r.cyclicRateWeaponType, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: Colors.white))),
                                              DataCell(Text(r.cartridgeTemp.isEmpty ? '-' : r.cartridgeTemp, style: const TextStyle(fontSize: 11.0, fontFamily: 'JetBrainsMono', color: Colors.white))),
                                              DataCell(Text('${r.functionLevel1}', style: TextStyle(fontWeight: r.functionLevel1 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel1 > 0 ? const Color(0xFFEF4444) : Colors.white))),
                                              DataCell(Text('${r.functionLevel2}', style: TextStyle(fontWeight: r.functionLevel2 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel2 > 0 ? const Color(0xFFF97316) : Colors.white))),
                                              DataCell(Text('${r.functionLevel3}', style: TextStyle(fontWeight: r.functionLevel3 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel3 > 0 ? const Color(0xFFFBBF24) : Colors.white))),
                                              DataCell(Text('${r.functionLevel4}', style: TextStyle(fontWeight: r.functionLevel4 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel4 > 0 ? const Color(0xFF38BDF8) : Colors.white))),
                                              DataCell(Text('${r.defects}', style: TextStyle(fontWeight: FontWeight.bold, color: r.defects > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)))),
                                              DataCell(Text(r.notes, style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            ] else ...[
                                              DataCell(Text(r.notes, style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)))),
                                            ],
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          ),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 12.0),
                        ElevatedButton.icon(
                          onPressed: reportRecords.isEmpty ? null : () async {
                            final csvContent = ReportGenerator.generateCsv(reportRecords, selectedReportTest, widget.currentModule);
                            final slug = singleRecord != null
                                ? '${singleRecord.lotNo}_${singleRecord.testName.toLowerCase().replaceAll(' ', '_')}'
                                : selectedReportTest.toLowerCase().replaceAll(' ', '_');
                            await ReportHelper.instance.downloadCsv(
                              content: csvContent, 
                              filename: 'ompc_quality_report_${slug}.csv'
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quality Excel report downloaded: ompc_quality_report_${slug}.csv'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          },
                          icon: const Icon(Icons.table_chart, size: 16.0),
                          label: const Text('Export Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        ElevatedButton.icon(
                          onPressed: reportRecords.isEmpty ? null : () async {
                            final docContent = ReportGenerator.generateWordHtml(
                              reportRecords, 
                              selectedReportTest,
                              widget.currentModule,
                              base64Logo: widget.base64Logo,
                              adminRules: widget.adminRules,
                            );
                            final slug = singleRecord != null
                                ? '${singleRecord.lotNo}_${singleRecord.testName.toLowerCase().replaceAll(' ', '_')}'
                                : selectedReportTest.toLowerCase().replaceAll(' ', '_');
                            await ReportHelper.instance.downloadDoc(
                              content: docContent, 
                              filename: 'ompc_quality_report_${slug}.doc'
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quality Word document downloaded: ompc_quality_report_${slug}.doc'),
                                backgroundColor: const Color(0xFF0284C7),
                              ),
                            );
                          },
                          icon: const Icon(Icons.description, size: 16.0),
                          label: const Text('Export Word'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        ElevatedButton.icon(
                          onPressed: reportRecords.isEmpty ? null : () async {
                            final htmlContent = ReportGenerator.generateHtml(
                              reportRecords, 
                              selectedReportTest,
                              widget.currentModule,
                              base64Logo: widget.base64Logo,
                              adminRules: widget.adminRules,
                            );
                            await ReportHelper.instance.printHtml(htmlContent: htmlContent);
                          },
                          icon: const Icon(Icons.print_outlined, size: 16.0),
                          label: const Text('Download / Print PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogStat(String label, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2.0),
        Text(
          val,
          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
