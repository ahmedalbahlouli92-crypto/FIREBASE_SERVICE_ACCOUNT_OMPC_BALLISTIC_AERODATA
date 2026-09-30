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
  final String loggedInUser;

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
    this.loggedInUser = '',
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
    'Primer Sensitivity Test',
    'Propellant Test',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _showRetestDialog(BallisticRecord r) {
    final bool canPerformRetest = widget.isAdmin ||
        widget.loggedInUser.isEmpty ||
        r.operators.toLowerCase().contains(widget.loggedInUser.toLowerCase()) ||
        widget.loggedInUser.toLowerCase().contains(r.operators.toLowerCase());

    if (!canPerformRetest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access restricted: Only the original submitter (${r.operators}) or an Admin can perform this retest.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final retestOpCtrl = TextEditingController(text: widget.loggedInUser.isNotEmpty ? widget.loggedInUser : r.operators);
    final retestShiftCtrl = TextEditingController(text: r.shift);
    final retestProducedCtrl = TextEditingController(text: '${r.produced}');
    final retestDefectsCtrl = TextEditingController(text: '${r.defects}');
    final retestNotesCtrl = TextEditingController();
    String selectedOutcome = 'Approved';

    // Test-specific parameter controllers pre-filled from r:
    final mouthSlowCtrl = TextEditingController(text: '${r.mouthSlow}');
    final mouthFastCtrl = TextEditingController(text: '${r.mouthFast}');
    final primerSlowCtrl = TextEditingController(text: '${r.primerSlow}');
    final primerFastCtrl = TextEditingController(text: '${r.primerFast}');

    final neckSlowCtrl = TextEditingController(text: '${r.neckSlow}');
    final neckFastCtrl = TextEditingController(text: '${r.neckFast}');
    final shoulderSlowCtrl = TextEditingController(text: '${r.shoulderSlow}');
    final shoulderFastCtrl = TextEditingController(text: '${r.shoulderFast}');
    final bodySlowCtrl = TextEditingController(text: '${r.bodySlow}');
    final bodyFastCtrl = TextEditingController(text: '${r.bodyFast}');
    final headSlowCtrl = TextEditingController(text: '${r.headSlow}');
    final headFastCtrl = TextEditingController(text: '${r.headFast}');
    final roomTempCtrl = TextEditingController(text: r.roomTemp);

    final extMinForceCtrl = TextEditingController(text: r.accMinX.isNotEmpty ? r.accMinX : (r.pressureBar.isNotEmpty ? r.pressureBar : ''));
    final extTypeCtrl = TextEditingController(text: r.extractionForceType);

    final accRadiusCtrl = TextEditingController(text: r.accMeanRadius);
    final accSDXCtrl = TextEditingController(text: r.accSDX);
    final accSDYCtrl = TextEditingController(text: r.accSDY);
    final accMaxDistCtrl = TextEditingController(text: r.accLargestDistance);
    final velMeanCtrl = TextEditingController(text: r.velMean);
    final velMinCtrl = TextEditingController(text: r.velMin);
    final velMaxCtrl = TextEditingController(text: r.velMax);
    final velSDCtrl = TextEditingController(text: r.velSD);

    final epvCartridgeTempCtrl = TextEditingController(text: r.cartridgeTemp);
    final epvMeanP1Ctrl = TextEditingController(text: r.epvatMeanPressure);
    final epvMaxP1Ctrl = TextEditingController(text: r.epvatMaxPressure);
    final epvMinP1Ctrl = TextEditingController(text: r.epvatMinPressure);
    final epvSDP1Ctrl = TextEditingController(text: r.epvatSDPressure);
    final epvMeanP2Ctrl = TextEditingController(text: r.epvatP2MeanPressure);
    final epvMaxP2Ctrl = TextEditingController(text: r.epvatP2MaxPressure);
    final epvActionTimeMeanCtrl = TextEditingController(text: r.actionTimeMean);

    final funcL1Ctrl = TextEditingController(text: '${r.functionLevel1}');
    final funcL2Ctrl = TextEditingController(text: '${r.functionLevel2}');
    final funcL3Ctrl = TextEditingController(text: '${r.functionLevel3}');
    final funcL4Ctrl = TextEditingController(text: '${r.functionLevel4}');
    final funcDetailsCtrl = TextEditingController(text: r.functionDefectDetails);

    final primerHbarCtrl = TextEditingController(text: r.primerHbar);
    final primerSDCtrl = TextEditingController(text: r.primerSD);
    final primerAllFireCtrl = TextEditingController(text: r.primerAllFireH);
    final primerNoFireCtrl = TextEditingController(text: r.primerNoFireH);

    final cyclicWeaponCtrl = TextEditingController(text: r.cyclicRateWeaponType);
    final cyclicRateValCtrl = TextEditingController(text: r.cyclicRateValue);

    final termHoleCtrl = TextEditingController(text: r.terminalHoleDiameter);
    final termSteelCtrl = TextEditingController(text: r.terminalSteelPenetration);
    final termVelCtrl = TextEditingController(text: r.terminalVelocity);

    Widget buildParamField(String label, TextEditingController ctrl, {bool isNumber = true, int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
          child: TextFormField(
            controller: ctrl,
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono'),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Color outcomeColor = const Color(0xFF10B981);
            if (selectedOutcome == 'Rejected') outcomeColor = const Color(0xFFEF4444);
            if (selectedOutcome == 'Approved with condition') outcomeColor = const Color(0xFF0284C7);

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(Icons.replay_circle_filled_rounded, color: Color(0xFFF59E0B), size: 24.0),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Execute Retest Verification',
                          style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Original Test: ${r.testName} | ${r.caliber} | Lot: ${r.lotNo}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 640.0,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Original Summary Box
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 16.0),
                                SizedBox(width: 6.0),
                                Text(
                                  'ORIGINAL INSPECTION SUMMARY',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              children: [
                                Expanded(child: Text('Submitter: ${r.operators}', style: const TextStyle(color: Colors.white70, fontSize: 12.0))),
                                Expanded(child: Text('Date: ${r.timestamp}', style: const TextStyle(color: Colors.white70, fontSize: 12.0))),
                              ],
                            ),
                            const SizedBox(height: 4.0),
                            Row(
                              children: [
                                Expanded(child: Text('Original Qty: ${r.produced} rounds', style: const TextStyle(color: Colors.white70, fontSize: 12.0))),
                                Expanded(child: Text('Original Defects: ${r.defects}', style: const TextStyle(color: Colors.white70, fontSize: 12.0))),
                              ],
                            ),
                            Builder(
                              builder: (_) {
                                final origRemarks = ReportGenerator.cleanRemarks(r.notes);
                                if (origRemarks.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text('Original Remarks: $origRemarks', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11.5)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // 2. Pre-filled Parameters Card
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'RETEST PARAMETERS (PRE-FILLED)',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Adjust if retest measurements differ', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10.0),

                            // Fields according to test type
                            if (r.testName == 'Waterproof Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Total Leaks / Defects', retestDefectsCtrl),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('Mouth Slow', mouthSlowCtrl),
                                  buildParamField('Mouth Fast', mouthFastCtrl),
                                  buildParamField('Primer Slow', primerSlowCtrl),
                                  buildParamField('Primer Fast', primerFastCtrl),
                                ],
                              ),
                            ] else if (r.testName == 'Residual Stress Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Total Cracks / Splits', retestDefectsCtrl),
                                  buildParamField('Room Temp °C', roomTempCtrl, isNumber: false),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('Neck Slow', neckSlowCtrl),
                                  buildParamField('Neck Fast', neckFastCtrl),
                                  buildParamField('Shoulder Slow', shoulderSlowCtrl),
                                  buildParamField('Shoulder Fast', shoulderFastCtrl),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('Body Slow', bodySlowCtrl),
                                  buildParamField('Body Fast', bodyFastCtrl),
                                  buildParamField('Head Slow', headSlowCtrl),
                                  buildParamField('Head Fast', headFastCtrl),
                                ],
                              ),
                            ] else if (r.testName == 'Extraction Force Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Min Extraction Force (N)', extMinForceCtrl),
                                  buildParamField('Force Type', extTypeCtrl, isNumber: false),
                                ],
                              ),
                            ] else if (r.testName == 'Accuracy Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Mean Radius (mm)', accRadiusCtrl),
                                  buildParamField('Largest Distance (mm)', accMaxDistCtrl),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('SD X (mm)', accSDXCtrl),
                                  buildParamField('SD Y (mm)', accSDYCtrl),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('Mean Velocity (m/s)', velMeanCtrl),
                                  buildParamField('Min Velocity (m/s)', velMinCtrl),
                                  buildParamField('Max Velocity (m/s)', velMaxCtrl),
                                  buildParamField('SD Velocity (m/s)', velSDCtrl),
                                ],
                              ),
                            ] else if (r.testName == 'EPVAT test' || r.testName == 'Propellant Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Cartridge Temp °C', epvCartridgeTempCtrl, isNumber: false),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('P1 Mean (bar)', epvMeanP1Ctrl),
                                  buildParamField('P1 Max (bar)', epvMaxP1Ctrl),
                                  buildParamField('P1 Min (bar)', epvMinP1Ctrl),
                                  buildParamField('P1 SD (bar)', epvSDP1Ctrl),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('P2 Mean (bar)', epvMeanP2Ctrl),
                                  buildParamField('P2 Max (bar)', epvMaxP2Ctrl),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('Action Time Mean (ms)', epvActionTimeMeanCtrl),
                                  buildParamField('Mean Vel (m/s)', velMeanCtrl),
                                  buildParamField('SD Vel (m/s)', velSDCtrl),
                                ],
                              ),
                            ] else if (r.testName == 'Function Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Cartridge Temp °C', epvCartridgeTempCtrl, isNumber: false),
                                  buildParamField('Defect Details', funcDetailsCtrl, isNumber: false, flex: 2),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('Level 1 Critical', funcL1Ctrl),
                                  buildParamField('Level 2 Major', funcL2Ctrl),
                                  buildParamField('Level 3 Minor', funcL3Ctrl),
                                  buildParamField('Level 4 Minor', funcL4Ctrl),
                                ],
                              ),
                            ] else if (r.testName == 'Primer Sensitivity Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Mean Height H̄ (mm)', primerHbarCtrl),
                                  buildParamField('SD S (mm)', primerSDCtrl),
                                ],
                              ),
                              Row(
                                children: [
                                  buildParamField('Min All-Fire H (mm)', primerAllFireCtrl),
                                  buildParamField('Max No-Fire H (mm)', primerNoFireCtrl),
                                ],
                              ),
                            ] else if (r.testName == 'Firing Rate Cycle Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Weapon Category', cyclicWeaponCtrl, isNumber: false),
                                  buildParamField('Cyclic Rate (rpm)', cyclicRateValCtrl),
                                ],
                              ),
                            ] else if (r.testName == 'Terminal Effect Test') ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Hole Diameter (mm)', termHoleCtrl, isNumber: false),
                                  buildParamField('Steel Penetration', termSteelCtrl, isNumber: false),
                                  buildParamField('Terminal Vel (m/s)', termVelCtrl),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  buildParamField('Retest Sample Qty', retestProducedCtrl),
                                  buildParamField('Defects Count', retestDefectsCtrl),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // 3. Retest Inspector & Outcome
                      const Text(
                        'RETEST VERIFICATION & DISPOSITION',
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10.0),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: retestOpCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13.0),
                              decoration: InputDecoration(
                                labelText: 'Retest Inspector',
                                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: retestShiftCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13.0),
                              decoration: InputDecoration(
                                labelText: 'Shift',
                                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),

                      // Retest Outcome Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: outcomeColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedOutcome,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: TextStyle(
                              color: outcomeColor,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Approved',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18.0),
                                    SizedBox(width: 8.0),
                                    Text('Approved (Retest Passed)', style: TextStyle(color: Color(0xFF10B981))),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Approved with condition',
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 18.0),
                                    SizedBox(width: 8.0),
                                    Text('Approved with condition', style: TextStyle(color: Color(0xFF0284C7))),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Rejected',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18.0),
                                    SizedBox(width: 8.0),
                                    Text('Rejected (Retest Failed)', style: TextStyle(color: Color(0xFFEF4444))),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedOutcome = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // 4. Retest Findings & Remarks
                      TextFormField(
                        controller: retestNotesCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        decoration: InputDecoration(
                          labelText: 'Retest Findings & Remarks',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                          hintText: 'Enter specific retest measurements, conditions observed, and reason for disposition...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final op = retestOpCtrl.text.trim().isNotEmpty ? retestOpCtrl.text.trim() : r.operators;
                    final shift = retestShiftCtrl.text.trim().isNotEmpty ? retestShiftCtrl.text.trim() : r.shift;
                    final newRemarks = retestNotesCtrl.text.trim();
                    final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

                    String finalStatus;
                    if (selectedOutcome == 'Approved') {
                      finalStatus = 'Approved (Retest Passed)';
                    } else if (selectedOutcome == 'Approved with condition') {
                      finalStatus = 'Approved with condition';
                    } else {
                      finalStatus = 'Rejected (Retest Failed)';
                    }

                    final remarksHeader = '[RETEST by $op on $timestamp - Outcome: $finalStatus]';
                    final updatedNotes = r.notes.isNotEmpty
                        ? (newRemarks.isNotEmpty ? '${r.notes}\n$remarksHeader: $newRemarks' : '${r.notes}\n$remarksHeader')
                        : (newRemarks.isNotEmpty ? '$remarksHeader: $newRemarks' : remarksHeader);

                    final retestMetricsMap = <String, dynamic>{
                      if (r.testName == 'Waterproof Test') ...{
                        'mouthSlow': int.tryParse(mouthSlowCtrl.text.trim()) ?? 0,
                        'mouthFast': int.tryParse(mouthFastCtrl.text.trim()) ?? 0,
                        'primerSlow': int.tryParse(primerSlowCtrl.text.trim()) ?? 0,
                        'primerFast': int.tryParse(primerFastCtrl.text.trim()) ?? 0,
                      } else if (r.testName == 'Function Test') ...{
                        'functionLevel1': int.tryParse(funcL1Ctrl.text.trim()) ?? 0,
                        'functionLevel2': int.tryParse(funcL2Ctrl.text.trim()) ?? 0,
                        'functionLevel3': int.tryParse(funcL3Ctrl.text.trim()) ?? 0,
                        'functionLevel4': int.tryParse(funcL4Ctrl.text.trim()) ?? 0,
                        'functionDefectDetails': funcDetailsCtrl.text.trim(),
                        'cartridgeTemp': epvCartridgeTempCtrl.text.trim(),
                      } else if (r.testName == 'Residual Stress Test') ...{
                        'neckSlow': int.tryParse(neckSlowCtrl.text.trim()) ?? 0,
                        'neckFast': int.tryParse(neckFastCtrl.text.trim()) ?? 0,
                        'shoulderSlow': int.tryParse(shoulderSlowCtrl.text.trim()) ?? 0,
                        'shoulderFast': int.tryParse(shoulderFastCtrl.text.trim()) ?? 0,
                        'bodySlow': int.tryParse(bodySlowCtrl.text.trim()) ?? 0,
                        'bodyFast': int.tryParse(bodyFastCtrl.text.trim()) ?? 0,
                        'headSlow': int.tryParse(headSlowCtrl.text.trim()) ?? 0,
                        'headFast': int.tryParse(headFastCtrl.text.trim()) ?? 0,
                        'roomTemp': roomTempCtrl.text.trim(),
                      } else if (r.testName == 'Accuracy Test') ...{
                        'accMeanRadius': accRadiusCtrl.text.trim(),
                        'accSDX': accSDXCtrl.text.trim(),
                        'accSDY': accSDYCtrl.text.trim(),
                        'accLargestDistance': accMaxDistCtrl.text.trim(),
                        'velMean': velMeanCtrl.text.trim(),
                        'velMin': velMinCtrl.text.trim(),
                        'velMax': velMaxCtrl.text.trim(),
                        'velSD': velSDCtrl.text.trim(),
                      } else if (r.testName == 'EPVAT test' || r.testName == 'Propellant Test') ...{
                        'epvatMeanPressure': epvMeanP1Ctrl.text.trim(),
                        'epvatMaxPressure': epvMaxP1Ctrl.text.trim(),
                        'epvatMinPressure': epvMinP1Ctrl.text.trim(),
                        'epvatSDPressure': epvSDP1Ctrl.text.trim(),
                        'epvatP2MeanPressure': epvMeanP2Ctrl.text.trim(),
                        'epvatP2MaxPressure': epvMaxP2Ctrl.text.trim(),
                        'actionTimeMean': epvActionTimeMeanCtrl.text.trim(),
                        'velMean': velMeanCtrl.text.trim(),
                        'velSD': velSDCtrl.text.trim(),
                        'cartridgeTemp': epvCartridgeTempCtrl.text.trim(),
                      } else if (r.testName == 'Primer Sensitivity Test') ...{
                        'primerHbar': primerHbarCtrl.text.trim(),
                        'primerSD': primerSDCtrl.text.trim(),
                        'primerAllFireH': primerAllFireCtrl.text.trim(),
                        'primerNoFireH': primerNoFireCtrl.text.trim(),
                      } else if (r.testName == 'Extraction Force Test') ...{
                        'accMinX': extMinForceCtrl.text.trim(),
                        'extractionForceType': extTypeCtrl.text.trim(),
                      } else if (r.testName == 'Firing Rate Cycle Test') ...{
                        'cyclicRateWeaponType': cyclicWeaponCtrl.text.trim(),
                        'cyclicRateValue': cyclicRateValCtrl.text.trim(),
                      } else if (r.testName == 'Terminal Effect Test') ...{
                        'terminalHoleDiameter': termHoleCtrl.text.trim(),
                        'terminalSteelPenetration': termSteelCtrl.text.trim(),
                        'terminalVelocity': termVelCtrl.text.trim(),
                      }
                    };
                    final retestMetricsJson = jsonEncode(retestMetricsMap);

                    final parsedRetestProduced = int.tryParse(retestProducedCtrl.text.trim()) ?? (r.retestProduced > 0 ? r.retestProduced : r.produced);
                    final int calculatedRetestDefects;
                    if (r.testName == 'Waterproof Test') {
                      calculatedRetestDefects = (retestMetricsMap['mouthSlow'] as int? ?? 0) +
                          (retestMetricsMap['mouthFast'] as int? ?? 0) +
                          (retestMetricsMap['primerSlow'] as int? ?? 0) +
                          (retestMetricsMap['primerFast'] as int? ?? 0);
                    } else if (r.testName == 'Function Test') {
                      calculatedRetestDefects = (retestMetricsMap['functionLevel1'] as int? ?? 0) +
                          (retestMetricsMap['functionLevel2'] as int? ?? 0) +
                          (retestMetricsMap['functionLevel3'] as int? ?? 0) +
                          (retestMetricsMap['functionLevel4'] as int? ?? 0);
                    } else if (r.testName == 'Residual Stress Test') {
                      calculatedRetestDefects = (retestMetricsMap['neckSlow'] as int? ?? 0) +
                          (retestMetricsMap['neckFast'] as int? ?? 0) +
                          (retestMetricsMap['shoulderSlow'] as int? ?? 0) +
                          (retestMetricsMap['shoulderFast'] as int? ?? 0) +
                          (retestMetricsMap['bodySlow'] as int? ?? 0) +
                          (retestMetricsMap['bodyFast'] as int? ?? 0) +
                          (retestMetricsMap['headSlow'] as int? ?? 0) +
                          (retestMetricsMap['headFast'] as int? ?? 0);
                    } else {
                      calculatedRetestDefects = int.tryParse(retestDefectsCtrl.text.trim()) ?? 0;
                    }

                    final updatedRecord = r.copyWith(
                      isRetest: true,
                      retestTimestamp: timestamp,
                      retestOperator: op,
                      retestNotes: newRemarks,
                      retestStatus: selectedOutcome,
                      originalStatus: r.originalStatus.isNotEmpty ? r.originalStatus : r.status,
                      status: finalStatus,
                      notes: updatedNotes,
                      retestProduced: parsedRetestProduced,
                      retestDefects: calculatedRetestDefects,
                      retestMetrics: retestMetricsJson,
                    );

                    Navigator.of(ctx).pop();

                    if (widget.onEditRecord != null) {
                      await widget.onEditRecord!(r, updatedRecord);
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Retest submitted successfully for lot "${r.lotNo}". Final status: $finalStatus'),
                          backgroundColor: selectedOutcome == 'Rejected' ? const Color(0xFFEF4444) : (selectedOutcome == 'Approved with condition' ? const Color(0xFF0284C7) : const Color(0xFF10B981)),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 16.0),
                  label: const Text('Save Retest Report', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
    // 1. Basic Metadata Controllers
    final operatorsController = TextEditingController(text: r.operators);
    final lotNoController = TextEditingController(text: r.lotNo);
    final producedController = TextEditingController(text: '${r.produced}');
    final defectsController = TextEditingController(text: '${r.defects}');
    final notesController = TextEditingController(text: ReportGenerator.cleanRemarks(r.notes));

    // 2. Waterproof Test
    final pressureController = TextEditingController(text: r.pressureBar);
    final viscosityController = TextEditingController(text: r.viscosity);
    final locationController = TextEditingController(text: r.samplingLocation);
    final mouthSlowController = TextEditingController(text: '${r.mouthSlow}');
    final mouthFastController = TextEditingController(text: '${r.mouthFast}');
    final primerSlowController = TextEditingController(text: '${r.primerSlow}');
    final primerFastController = TextEditingController(text: '${r.primerFast}');

    // 3. Residual Stress Test
    final roomTempController = TextEditingController(text: r.roomTemp);
    final neckSlowController = TextEditingController(text: '${r.neckSlow}');
    final neckFastController = TextEditingController(text: '${r.neckFast}');
    final shoulderSlowController = TextEditingController(text: '${r.shoulderSlow}');
    final shoulderFastController = TextEditingController(text: '${r.shoulderFast}');
    final bodySlowController = TextEditingController(text: '${r.bodySlow}');
    final bodyFastController = TextEditingController(text: '${r.bodyFast}');
    final headSlowController = TextEditingController(text: '${r.headSlow}');
    final headFastController = TextEditingController(text: '${r.headFast}');

    // 4. Accuracy Test
    final barrelSNController = TextEditingController(text: r.barrelSN);
    final barrelTypeController = TextEditingController(text: r.barrelType);
    final velocityDistanceController = TextEditingController(text: r.velocityDistance);
    final accRadiusController = TextEditingController(text: r.accMeanRadius);
    final accMaxDistController = TextEditingController(text: r.accLargestDistance);
    final accSDXController = TextEditingController(text: r.accSDX);
    final accSDYController = TextEditingController(text: r.accSDY);
    final accMeanXController = TextEditingController(text: r.accMeanX);
    final accMeanYController = TextEditingController(text: r.accMeanY);
    final velMeanController = TextEditingController(text: r.velMean);
    final velMinController = TextEditingController(text: r.velMin);
    final velMaxController = TextEditingController(text: r.velMax);
    final velSDController = TextEditingController(text: r.velSD);

    // 5. EPVAT Test
    final epvCartridgeTempController = TextEditingController(text: r.cartridgeTemp);
    final epvPressureUnitController = TextEditingController(text: r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'bar');
    final epvPressureTypeController = TextEditingController(text: r.epvatPressureType);
    final epvMeanP1Controller = TextEditingController(text: r.epvatMeanPressure);
    final epvMaxP1Controller = TextEditingController(text: r.epvatMaxPressure);
    final epvMinP1Controller = TextEditingController(text: r.epvatMinPressure);
    final epvSDP1Controller = TextEditingController(text: r.epvatSDPressure);
    final epvMeanP2Controller = TextEditingController(text: r.epvatP2MeanPressure);
    final epvMaxP2Controller = TextEditingController(text: r.epvatP2MaxPressure);
    final epvMinP2Controller = TextEditingController(text: r.epvatP2MinPressure);
    final epvSDP2Controller = TextEditingController(text: r.epvatP2SDPressure);
    final epvActionTimeMeanController = TextEditingController(text: r.actionTimeMean);
    final epvActionTimeSDController = TextEditingController(text: r.actionTimeSD);
    final epvSensor1Controller = TextEditingController(text: r.epvatSensor1);
    final epvSensor2Controller = TextEditingController(text: r.epvatSensor2);

    // 6. Function Test
    final funcL1Controller = TextEditingController(text: '${r.functionLevel1}');
    final funcL2Controller = TextEditingController(text: '${r.functionLevel2}');
    final funcL3Controller = TextEditingController(text: '${r.functionLevel3}');
    final funcL4Controller = TextEditingController(text: '${r.functionLevel4}');
    final funcDetailsController = TextEditingController(text: r.functionDefectDetails);

    // 7. Extraction Force Test
    final extTypeController = TextEditingController(text: r.extractionForceType.isNotEmpty ? r.extractionForceType : 'Bullet');
    final extMinForceController = TextEditingController(text: r.accMinX);
    final extMeanForceController = TextEditingController(text: r.accMeanX);
    final extMaxForceController = TextEditingController(text: r.accMaxX);
    final extSDForceController = TextEditingController(text: r.accSDX);

    // 8. Primer Sensitivity Test
    final primerLotController = TextEditingController(text: r.primerLot);
    final primerSupplierController = TextEditingController(text: r.primerSupplier);
    final primerInsertionDepthController = TextEditingController(text: r.primerInsertionDepth);
    final primerHbarController = TextEditingController(text: r.primerHbar);
    final primerSDController = TextEditingController(text: r.primerSD);
    final primerAllFireController = TextEditingController(text: r.primerAllFireH);
    final primerNoFireController = TextEditingController(text: r.primerNoFireH);

    // 9. Propellant Test
    final propellantLotController = TextEditingController(text: r.propellantLot);
    final propellantSupplierController = TextEditingController(text: r.propellantSupplier);
    final propellantCodeController = TextEditingController(text: r.propellantCode);
    final propellantChargeController = TextEditingController(text: r.propellantCharge);

    // 10. Cyclic Rate Test
    final cyclicWeaponController = TextEditingController(text: r.cyclicRateWeaponType);
    final cyclicAmmoController = TextEditingController(text: r.cyclicRateAmmoType.isNotEmpty ? r.cyclicRateAmmoType : 'Linked');
    final cyclicRateValController = TextEditingController(text: r.cyclicRateValue);
    final cyclicMinController = TextEditingController(text: r.cyclicRateMin);
    final cyclicMaxController = TextEditingController(text: r.cyclicRateMax);

    // 11. Terminal Effect Test
    final termHoleController = TextEditingController(text: r.terminalHoleDiameter);
    final termSteelController = TextEditingController(text: r.terminalSteelPenetration);
    final termAlumController = TextEditingController(text: r.terminalAluminumPenetration);
    final termVelController = TextEditingController(text: r.terminalVelocity);

    // 12. Retest Fields
    final retestOpController = TextEditingController(text: r.retestOperator);
    final retestNotesController = TextEditingController(text: ReportGenerator.cleanRemarks(r.retestNotes));
    final retestProducedController = TextEditingController(text: '${r.retestProduced > 0 ? r.retestProduced : r.produced}');
    final retestDefectsController = TextEditingController(text: '${r.retestDefects}');
    String editRetestStatus = r.retestStatus.isNotEmpty ? r.retestStatus : 'Approved';

    String editShift = r.shift;
    String editStatus = r.status;
    String editCaliber = r.caliber;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMobile = MediaQuery.of(context).size.width < 600;

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
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 24.0),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Inspection Report Entry',
                          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${r.testName} • ${r.timestamp} • Admin Authority',
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Container(
                width: math.min(700.0, MediaQuery.of(context).size.width * 0.95),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Inspector & Shift
                      if (isMobile) ...[
                        _buildDialogField(
                          label: 'Operators / Inspectors',
                          child: _buildDialogTextField(controller: operatorsController),
                        ),
                        const SizedBox(height: 12.0),
                        _buildDialogField(
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
                      ] else ...[
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
                      ],
                      const SizedBox(height: 12.0),

                      // Section 2: Caliber & Lot / Hopper
                      if (isMobile) ...[
                        _buildDialogField(
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
                        const SizedBox(height: 12.0),
                        _buildDialogField(
                          label: widget.currentModule == 'Daily Test' ? 'Hopper No. / Production Date' : 'Lot Number',
                          child: _buildDialogTextField(controller: lotNoController),
                        ),
                      ] else ...[
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
                      ],
                      const SizedBox(height: 12.0),

                      // Section 3: Quantity Tested, Defects, Status
                      if (isMobile) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildDialogField(
                                label: 'Quantity Tested',
                                child: _buildDialogTextField(controller: producedController, keyboardType: TextInputType.number),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: _buildDialogField(
                                label: 'Defects',
                                child: _buildDialogTextField(controller: defectsController, keyboardType: TextInputType.number),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        _buildDialogField(
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
                      ] else ...[
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
                      ],
                      const SizedBox(height: 12.0),

                      // Section 4: Remarks / Notes
                      _buildDialogField(
                        label: 'Remarks / Notes',
                        child: _buildDialogTextField(controller: notesController, maxLines: 2),
                      ),

                      // Section 5: Comprehensive Test Parameters & Values (Admin Override)
                      const SizedBox(height: 16.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 16.0),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                '${r.testName.toUpperCase()} — MEASUREMENT PARAMETERS',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      if (r.testName == 'Waterproof Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Pressure (Bar)', child: _buildDialogTextField(controller: pressureController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Viscosity', child: _buildDialogTextField(controller: viscosityController))),
                            const SizedBox(width: 10.0),
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
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Room Temperature (°C)', child: _buildDialogTextField(controller: roomTempController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Sampling Location', child: _buildDialogTextField(controller: locationController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Neck Slow', child: _buildDialogTextField(controller: neckSlowController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Neck Fast', child: _buildDialogTextField(controller: neckFastController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Shoulder Slow', child: _buildDialogTextField(controller: shoulderSlowController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Shoulder Fast', child: _buildDialogTextField(controller: shoulderFastController, keyboardType: TextInputType.number))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Body Slow', child: _buildDialogTextField(controller: bodySlowController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Body Fast', child: _buildDialogTextField(controller: bodyFastController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Head Slow', child: _buildDialogTextField(controller: headSlowController, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Head Fast', child: _buildDialogTextField(controller: headFastController, keyboardType: TextInputType.number))),
                          ],
                        ),
                      ] else if (r.testName == 'Accuracy Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Barrel S.N.', child: _buildDialogTextField(controller: barrelSNController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Barrel Type', child: _buildDialogTextField(controller: barrelTypeController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Distance (m)', child: _buildDialogTextField(controller: velocityDistanceController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Mean Radius (MR mm)', child: _buildDialogTextField(controller: accRadiusController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Largest Dist (ES mm)', child: _buildDialogTextField(controller: accMaxDistController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'SD X (mm)', child: _buildDialogTextField(controller: accSDXController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'SD Y (mm)', child: _buildDialogTextField(controller: accSDYController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Mean Vel (m/s)', child: _buildDialogTextField(controller: velMeanController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Min Vel (m/s)', child: _buildDialogTextField(controller: velMinController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Max Vel (m/s)', child: _buildDialogTextField(controller: velMaxController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Vel SD (m/s)', child: _buildDialogTextField(controller: velSDController))),
                          ],
                        ),
                      ] else if (r.testName == 'EPVAT test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Barrel S.N.', child: _buildDialogTextField(controller: barrelSNController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Cartridge Temp (°C)', child: _buildDialogTextField(controller: epvCartridgeTempController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Pressure Unit', child: _buildDialogTextField(controller: epvPressureUnitController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Test Regimen / Type', child: _buildDialogTextField(controller: epvPressureTypeController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Mean P1 Chamber', child: _buildDialogTextField(controller: epvMeanP1Controller))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Max P1', child: _buildDialogTextField(controller: epvMaxP1Controller))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Min P1', child: _buildDialogTextField(controller: epvMinP1Controller))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'SD P1', child: _buildDialogTextField(controller: epvSDP1Controller))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Mean P2 Port', child: _buildDialogTextField(controller: epvMeanP2Controller))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Max P2 Port', child: _buildDialogTextField(controller: epvMaxP2Controller))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Min P2 Port', child: _buildDialogTextField(controller: epvMinP2Controller))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'SD P2 Port', child: _buildDialogTextField(controller: epvSDP2Controller))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Action Time Mean (ms)', child: _buildDialogTextField(controller: epvActionTimeMeanController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Action Time SD (ms)', child: _buildDialogTextField(controller: epvActionTimeSDController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Mean Velocity (m/s)', child: _buildDialogTextField(controller: velMeanController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Velocity SD (m/s)', child: _buildDialogTextField(controller: velSDController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Sensor 1 S.N.', child: _buildDialogTextField(controller: epvSensor1Controller))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Sensor 2 S.N.', child: _buildDialogTextField(controller: epvSensor2Controller))),
                          ],
                        ),
                      ] else if (r.testName == 'Function Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Weapons / Barrel S.N.', child: _buildDialogTextField(controller: barrelSNController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Cartridge Temp (°C)', child: _buildDialogTextField(controller: epvCartridgeTempController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Level 1 (Critical)', child: _buildDialogTextField(controller: funcL1Controller, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Level 2 (Major)', child: _buildDialogTextField(controller: funcL2Controller, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Level 3 (Minor)', child: _buildDialogTextField(controller: funcL3Controller, keyboardType: TextInputType.number))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Level 4', child: _buildDialogTextField(controller: funcL4Controller, keyboardType: TextInputType.number))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        _buildDialogField(label: 'Specific Defect Details', child: _buildDialogTextField(controller: funcDetailsController)),
                      ] else if (r.testName == 'Extraction Force Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Force Mode / Type', child: _buildDialogTextField(controller: extTypeController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Min Extraction Force (N)', child: _buildDialogTextField(controller: extMinForceController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Mean Extraction Force (N)', child: _buildDialogTextField(controller: extMeanForceController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Max Extraction Force (N)', child: _buildDialogTextField(controller: extMaxForceController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Force SD (N)', child: _buildDialogTextField(controller: extSDForceController))),
                          ],
                        ),
                      ] else if (r.testName == 'Primer Sensitivity Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Primer Lot', child: _buildDialogTextField(controller: primerLotController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Supplier', child: _buildDialogTextField(controller: primerSupplierController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Avg Insertion Depth (mm)', child: _buildDialogTextField(controller: primerInsertionDepthController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Mean Fire Height H̄ (cm)', child: _buildDialogTextField(controller: primerHbarController))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'Standard Dev SD (cm)', child: _buildDialogTextField(controller: primerSDController))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'All-Fire H̄+5SD (cm)', child: _buildDialogTextField(controller: primerAllFireController))),
                            const SizedBox(width: 8.0),
                            Expanded(child: _buildDialogField(label: 'No-Fire H̄-2SD (cm)', child: _buildDialogTextField(controller: primerNoFireController))),
                          ],
                        ),
                      ] else if (r.testName == 'Propellant Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Propellant Lot', child: _buildDialogTextField(controller: propellantLotController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Supplier', child: _buildDialogTextField(controller: propellantSupplierController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Code', child: _buildDialogTextField(controller: propellantCodeController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Charge (g)', child: _buildDialogTextField(controller: propellantChargeController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Chamber Press P1', child: _buildDialogTextField(controller: epvMeanP1Controller))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Port Press P2', child: _buildDialogTextField(controller: epvMeanP2Controller))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Mean Velocity (m/s)', child: _buildDialogTextField(controller: velMeanController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Velocity SD (m/s)', child: _buildDialogTextField(controller: velSDController))),
                          ],
                        ),
                      ] else if (r.testName == 'Firing Rate Cycle Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Weapon Model', child: _buildDialogTextField(controller: cyclicWeaponController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Ammo Feed Type', child: _buildDialogTextField(controller: cyclicAmmoController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Measured Rate (RPM)', child: _buildDialogTextField(controller: cyclicRateValController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Min Allowed (RPM)', child: _buildDialogTextField(controller: cyclicMinController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Max Allowed (RPM)', child: _buildDialogTextField(controller: cyclicMaxController))),
                          ],
                        ),
                      ] else if (r.testName == 'Terminal Effect Test') ...[
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Target Distance (m)', child: _buildDialogTextField(controller: velocityDistanceController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Hole Diameter', child: _buildDialogTextField(controller: termHoleController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Steel Penetration', child: _buildDialogTextField(controller: termSteelController))),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField(label: 'Aluminum Penetration', child: _buildDialogTextField(controller: termAlumController))),
                            const SizedBox(width: 10.0),
                            Expanded(child: _buildDialogField(label: 'Terminal Velocity (m/s)', child: _buildDialogTextField(controller: termVelController))),
                          ],
                        ),
                      ],

                      // Section 6: Retest Overrides (if record is a retest)
                      if (r.isRetest) ...[
                        const SizedBox(height: 16.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.replay_circle_filled_rounded, color: Color(0xFFF59E0B), size: 16.0),
                              SizedBox(width: 8.0),
                              Text(
                                'RETEST VERIFICATION METRICS (ADMIN OVERRIDE)',
                                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildDialogField(label: 'Retest Operator', child: _buildDialogTextField(controller: retestOpController)),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              flex: 2,
                              child: _buildDialogField(
                                label: 'Retest Status',
                                child: DropdownButtonFormField<String>(
                                  value: ['Approved', 'Rejected', 'Retest', 'Approved with condition'].contains(editRetestStatus) ? editRetestStatus : 'Approved',
                                  dropdownColor: const Color(0xFF1A2035),
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                  decoration: _dialogInputDecoration(),
                                  items: ['Approved', 'Rejected', 'Retest', 'Approved with condition'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (v) => setDialogState(() => editRetestStatus = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDialogField(label: 'Retest Quantity Tested', child: _buildDialogTextField(controller: retestProducedController, keyboardType: TextInputType.number)),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: _buildDialogField(label: 'Retest Defects Found', child: _buildDialogTextField(controller: retestDefectsController, keyboardType: TextInputType.number)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        _buildDialogField(label: 'Retest Notes / Remarks', child: _buildDialogTextField(controller: retestNotesController, maxLines: 2)),
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
                    int defects = int.tryParse(defectsController.text.trim()) ?? r.defects;

                    final int mouthSlow = int.tryParse(mouthSlowController.text.trim()) ?? r.mouthSlow;
                    final int mouthFast = int.tryParse(mouthFastController.text.trim()) ?? r.mouthFast;
                    final int primerSlow = int.tryParse(primerSlowController.text.trim()) ?? r.primerSlow;
                    final int primerFast = int.tryParse(primerFastController.text.trim()) ?? r.primerFast;

                    final int neckSlow = int.tryParse(neckSlowController.text.trim()) ?? r.neckSlow;
                    final int neckFast = int.tryParse(neckFastController.text.trim()) ?? r.neckFast;
                    final int shoulderSlow = int.tryParse(shoulderSlowController.text.trim()) ?? r.shoulderSlow;
                    final int shoulderFast = int.tryParse(shoulderFastController.text.trim()) ?? r.shoulderFast;
                    final int bodySlow = int.tryParse(bodySlowController.text.trim()) ?? r.bodySlow;
                    final int bodyFast = int.tryParse(bodyFastController.text.trim()) ?? r.bodyFast;
                    final int headSlow = int.tryParse(headSlowController.text.trim()) ?? r.headSlow;
                    final int headFast = int.tryParse(headFastController.text.trim()) ?? r.headFast;

                    final int funcL1 = int.tryParse(funcL1Controller.text.trim()) ?? r.functionLevel1;
                    final int funcL2 = int.tryParse(funcL2Controller.text.trim()) ?? r.functionLevel2;
                    final int funcL3 = int.tryParse(funcL3Controller.text.trim()) ?? r.functionLevel3;
                    final int funcL4 = int.tryParse(funcL4Controller.text.trim()) ?? r.functionLevel4;

                    final String savedNotes = notesController.text.trim();

                    final updated = r.copyWith(
                      operators: operatorsController.text.trim(),
                      shift: editShift,
                      caliber: editCaliber,
                      lotNo: lotNoController.text.trim(),
                      produced: produced,
                      defects: defects,
                      status: editStatus,
                      notes: savedNotes,
                      // Waterproof
                      pressureBar: pressureController.text.trim(),
                      viscosity: viscosityController.text.trim(),
                      samplingLocation: locationController.text.trim(),
                      mouthSlow: mouthSlow,
                      mouthFast: mouthFast,
                      primerSlow: primerSlow,
                      primerFast: primerFast,
                      // Residual Stress
                      roomTemp: roomTempController.text.trim(),
                      neckSlow: neckSlow,
                      neckFast: neckFast,
                      shoulderSlow: shoulderSlow,
                      shoulderFast: shoulderFast,
                      bodySlow: bodySlow,
                      bodyFast: bodyFast,
                      headSlow: headSlow,
                      headFast: headFast,
                      // Accuracy & Extraction
                      barrelSN: barrelSNController.text.trim(),
                      barrelType: barrelTypeController.text.trim(),
                      velocityDistance: velocityDistanceController.text.trim(),
                      accMeanRadius: accRadiusController.text.trim(),
                      accLargestDistance: accMaxDistController.text.trim(),
                      accSDX: r.testName == 'Extraction Force Test' ? extSDForceController.text.trim() : accSDXController.text.trim(),
                      accSDY: accSDYController.text.trim(),
                      accMeanX: r.testName == 'Extraction Force Test' ? extMeanForceController.text.trim() : accMeanXController.text.trim(),
                      accMeanY: accMeanYController.text.trim(),
                      accMinX: r.testName == 'Extraction Force Test' ? extMinForceController.text.trim() : r.accMinX,
                      accMaxX: r.testName == 'Extraction Force Test' ? extMaxForceController.text.trim() : r.accMaxX,
                      velMean: velMeanController.text.trim(),
                      velMin: velMinController.text.trim(),
                      velMax: velMaxController.text.trim(),
                      velSD: velSDController.text.trim(),
                      // EPVAT
                      cartridgeTemp: epvCartridgeTempController.text.trim(),
                      epvatPressureUnit: epvPressureUnitController.text.trim(),
                      epvatPressureType: epvPressureTypeController.text.trim(),
                      epvatMeanPressure: epvMeanP1Controller.text.trim(),
                      epvatMaxPressure: epvMaxP1Controller.text.trim(),
                      epvatMinPressure: epvMinP1Controller.text.trim(),
                      epvatSDPressure: epvSDP1Controller.text.trim(),
                      epvatP2MeanPressure: epvMeanP2Controller.text.trim(),
                      epvatP2MaxPressure: epvMaxP2Controller.text.trim(),
                      epvatP2MinPressure: epvMinP2Controller.text.trim(),
                      epvatP2SDPressure: epvSDP2Controller.text.trim(),
                      actionTimeMean: epvActionTimeMeanController.text.trim(),
                      actionTimeSD: epvActionTimeSDController.text.trim(),
                      epvatSensor1: epvSensor1Controller.text.trim(),
                      epvatSensor2: epvSensor2Controller.text.trim(),
                      // Function
                      functionLevel1: funcL1,
                      functionLevel2: funcL2,
                      functionLevel3: funcL3,
                      functionLevel4: funcL4,
                      functionDefectDetails: funcDetailsController.text.trim(),
                      // Extraction Force
                      extractionForceType: extTypeController.text.trim(),
                      // Primer
                      primerLot: primerLotController.text.trim(),
                      primerSupplier: primerSupplierController.text.trim(),
                      primerInsertionDepth: primerInsertionDepthController.text.trim(),
                      primerHbar: primerHbarController.text.trim(),
                      primerSD: primerSDController.text.trim(),
                      primerAllFireH: primerAllFireController.text.trim(),
                      primerNoFireH: primerNoFireController.text.trim(),
                      // Propellant
                      propellantLot: propellantLotController.text.trim(),
                      propellantSupplier: propellantSupplierController.text.trim(),
                      propellantCode: propellantCodeController.text.trim(),
                      propellantCharge: propellantChargeController.text.trim(),
                      // Cyclic Rate
                      cyclicRateWeaponType: cyclicWeaponController.text.trim(),
                      cyclicRateAmmoType: cyclicAmmoController.text.trim(),
                      cyclicRateValue: cyclicRateValController.text.trim(),
                      cyclicRateMin: cyclicMinController.text.trim(),
                      cyclicRateMax: cyclicMaxController.text.trim(),
                      // Terminal Effect
                      terminalHoleDiameter: termHoleController.text.trim(),
                      terminalSteelPenetration: termSteelController.text.trim(),
                      terminalAluminumPenetration: termAlumController.text.trim(),
                      terminalVelocity: termVelController.text.trim(),
                      // Retest fields
                      retestOperator: r.isRetest ? retestOpController.text.trim() : r.retestOperator,
                      retestStatus: r.isRetest ? editRetestStatus : r.retestStatus,
                      retestNotes: r.isRetest ? retestNotesController.text.trim() : r.retestNotes,
                      retestProduced: r.isRetest ? (int.tryParse(retestProducedController.text.trim()) ?? r.retestProduced) : r.retestProduced,
                      retestDefects: r.isRetest ? (int.tryParse(retestDefectsController.text.trim()) ?? r.retestDefects) : r.retestDefects,
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

  Widget _buildParamValueSpan(String label, String value, {Color labelColor = const Color(0xFF0F172A), Color valueColor = const Color(0xFF334155)}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: labelColor),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.normal, color: valueColor),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildResultCell(BallisticRecord r) {
    final m = r.parsedRetestMetrics;
    Widget content;

    if (r.testName == 'Waterproof Test') {
      final totalLeaks = r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast;
      final testStr = totalLeaks == 0 ? '0 leaks' : '$totalLeaks leaks';
      if (r.isRetest) {
        final retLeaks = m.isNotEmpty
            ? ((m['mouthSlow'] as int? ?? 0) + (m['mouthFast'] as int? ?? 0) + (m['primerSlow'] as int? ?? 0) + (m['primerFast'] as int? ?? 0))
            : r.retestDefects;
        final retStr = retLeaks == 0 ? '0 leak' : '$retLeaks leaks';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test', testStr, valueColor: totalLeaks > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
            _buildParamValueSpan('Retest', retStr, valueColor: retLeaks > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
          ],
        );
      } else {
        content = _buildParamValueSpan(
          'Leaks',
          testStr,
          valueColor: totalLeaks > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        );
      }
    } else if (r.testName == 'Function Test') {
      final l1 = r.functionLevel1;
      final l2 = r.functionLevel2;
      final l3 = r.functionLevel3;
      final l4 = r.functionLevel4;
      final totalDefects = l1 + l2 + l3 + l4;
      final testStr = totalDefects == 0 ? '0 defect' : '$totalDefects defect${totalDefects == 1 ? '' : 's'}';
      if (r.isRetest) {
        final rL1 = m['functionLevel1'] as int? ?? 0;
        final rL2 = m['functionLevel2'] as int? ?? 0;
        final rL3 = m['functionLevel3'] as int? ?? 0;
        final rL4 = m['functionLevel4'] as int? ?? 0;
        final retDef = m.isNotEmpty ? (rL1 + rL2 + rL3 + rL4) : r.retestDefects;
        final retStr = retDef == 0 ? '0 defect' : '$retDef defect${retDef == 1 ? '' : 's'}';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test', testStr, valueColor: totalDefects > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
            _buildParamValueSpan('Retest', retStr, valueColor: retDef > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
          ],
        );
      } else {
        if (totalDefects == 0) {
          content = _buildParamValueSpan('Defects', '0 defect', valueColor: const Color(0xFF10B981));
        } else {
          final levels = <String>[];
          if (l1 > 0) levels.add('L1: $l1');
          if (l2 > 0) levels.add('L2: $l2');
          if (l3 > 0) levels.add('L3: $l3');
          if (l4 > 0) levels.add('L4: $l4');
          content = _buildParamValueSpan('Defects', '$totalDefects (${levels.join(", ")})', valueColor: const Color(0xFFEF4444));
        }
      }
    } else if (r.testName == 'Accuracy Test') {
      final calLower = r.caliber.toLowerCase();
      final isM193 = calLower.contains('m193');
      if (r.isRetest) {
        final retRadius = m['accMeanRadius']?.toString() ?? '';
        final retSDX = m['accSDX']?.toString() ?? '';
        final retSDY = m['accSDY']?.toString() ?? '';
        if (isM193 && (r.accMeanRadius.isNotEmpty || retRadius.isNotEmpty)) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildParamValueSpan('Test MR', '${r.accMeanRadius.isNotEmpty ? r.accMeanRadius : "-"} mm'),
              _buildParamValueSpan('Retest MR', '${retRadius.isNotEmpty ? retRadius : "-"} mm'),
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildParamValueSpan('Test SD', 'X:${r.accSDX.isNotEmpty ? r.accSDX : "-"} Y:${r.accSDY.isNotEmpty ? r.accSDY : "-"}'),
              _buildParamValueSpan('Retest SD', 'X:${retSDX.isNotEmpty ? retSDX : "-"} Y:${retSDY.isNotEmpty ? retSDY : "-"}'),
            ],
          );
        }
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isM193 && r.accMeanRadius.isNotEmpty)
              _buildParamValueSpan('Mean Radius', '${r.accMeanRadius} mm (SD X: ${r.accSDX.isNotEmpty ? r.accSDX : "-"} mm)')
            else
              _buildParamValueSpan('SD X', '${r.accSDX.isNotEmpty ? r.accSDX : "-"} mm'),
            _buildParamValueSpan('SD Y', '${r.accSDY.isNotEmpty ? r.accSDY : "-"} mm'),
            _buildParamValueSpan('Mean Velocity', '${r.velMean.isNotEmpty ? r.velMean : "-"} m/s'),
          ],
        );
      }
    } else if (r.testName == 'EPVAT test' || r.testName == 'Propellant Test') {
      final unit = r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'bar';
      if (r.isRetest) {
        final retP1 = m['epvatMeanPressure']?.toString() ?? '';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test P1', '${r.epvatMeanPressure.isNotEmpty ? r.epvatMeanPressure : "-"} $unit'),
            _buildParamValueSpan('Retest P1', '${retP1.isNotEmpty ? retP1 : "-"} $unit'),
          ],
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Mean Chamber', '${r.epvatMeanPressure.isNotEmpty ? r.epvatMeanPressure : "-"} $unit'),
            _buildParamValueSpan('Mean Port', '${r.epvatP2MeanPressure.isNotEmpty ? r.epvatP2MeanPressure : "-"} $unit'),
            _buildParamValueSpan('Mean Velocity', '${r.velMean.isNotEmpty ? r.velMean : "-"} m/s'),
          ],
        );
      }
    } else if (r.testName == 'Extraction Force Test') {
      if (r.isRetest) {
        final retMin = m['accMinX']?.toString() ?? '';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test Min', '${r.accMinX.isNotEmpty ? r.accMinX : "-"} N'),
            _buildParamValueSpan('Retest Min', '${retMin.isNotEmpty ? retMin : "-"} N'),
          ],
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Min Force', '${r.accMinX.isNotEmpty ? r.accMinX : "-"} N'),
            _buildParamValueSpan('Max Force', '${r.accMaxX.isNotEmpty ? r.accMaxX : "-"} N'),
          ],
        );
      }
    } else if (r.testName == 'Residual Stress Test') {
      final neck = r.neckSlow + r.neckFast;
      final shoulder = r.shoulderSlow + r.shoulderFast;
      final body = r.bodySlow + r.bodyFast;
      final head = r.headSlow + r.headFast;
      final total = neck + shoulder + body + head;
      final testStr = total == 0 ? '0 crack' : '$total crack${total == 1 ? '' : 's'}';
      if (r.isRetest) {
        final retCracks = m.isNotEmpty
            ? ((m['neckSlow'] as int? ?? 0) + (m['neckFast'] as int? ?? 0) + (m['shoulderSlow'] as int? ?? 0) + (m['shoulderFast'] as int? ?? 0) + (m['bodySlow'] as int? ?? 0) + (m['bodyFast'] as int? ?? 0) + (m['headSlow'] as int? ?? 0) + (m['headFast'] as int? ?? 0))
            : r.retestDefects;
        final retStr = retCracks == 0 ? '0 crack' : '$retCracks crack${retCracks == 1 ? '' : 's'}';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test', testStr, valueColor: total > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
            _buildParamValueSpan('Retest', retStr, valueColor: retCracks > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
          ],
        );
      } else {
        if (total == 0) {
          content = _buildParamValueSpan('Cracks', '0 crack', valueColor: const Color(0xFF10B981));
        } else {
          final zones = <String>[];
          if (neck > 0) zones.add('Neck: $neck');
          if (shoulder > 0) zones.add('Shoulder: $shoulder');
          if (body > 0) zones.add('Body: $body');
          if (head > 0) zones.add('Head: $head');
          content = _buildParamValueSpan('Cracks', '$total (${zones.join(", ")})', valueColor: const Color(0xFFEF4444));
        }
      }
    } else if (r.testName == 'Primer Sensitivity Test') {
      if (r.isRetest) {
        final retH = m['primerHbar']?.toString() ?? '';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test H̄', '${r.primerHbar.isNotEmpty ? r.primerHbar : "-"} cm'),
            _buildParamValueSpan('Retest H̄', '${retH.isNotEmpty ? retH : "-"} cm'),
          ],
        );
      } else {
        final hm = double.tryParse(r.primerHbar) ?? 0;
        final sd = double.tryParse(r.primerSD) ?? 0;
        final plus5 = r.primerAllFireH.isNotEmpty ? r.primerAllFireH : (hm > 0 ? (hm + 5 * sd).toStringAsFixed(1) : "-");
        final minus2 = r.primerNoFireH.isNotEmpty ? r.primerNoFireH : (hm > 0 ? (hm - 2 * sd).toStringAsFixed(1) : "-");
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('H̄+5SD', '$plus5 cm'),
            _buildParamValueSpan('H̄-2SD', '$minus2 cm'),
          ],
        );
      }
    } else if (r.testName == 'Firing Rate Cycle Test') {
      if (r.isRetest) {
        final retVal = m['cyclicRateValue']?.toString() ?? '';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test Rate', '${r.cyclicRateValue.isNotEmpty ? r.cyclicRateValue : "-"} RPM'),
            _buildParamValueSpan('Retest Rate', '${retVal.isNotEmpty ? retVal : "-"} RPM'),
          ],
        );
      } else {
        content = _buildParamValueSpan('Rate', '${r.cyclicRateValue.isNotEmpty ? r.cyclicRateValue : "-"} RPM');
      }
    } else if (r.testName == 'Terminal Effect Test') {
      if (r.isRetest) {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Test Hole', '${r.terminalHoleDiameter.isNotEmpty ? r.terminalHoleDiameter : "-"}'),
            _buildParamValueSpan('Retest Hole', '${m['terminalHoleDiameter']?.toString() ?? "-"}'),
          ],
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildParamValueSpan('Distance', '${r.velocityDistance.isNotEmpty ? r.velocityDistance : "-"} m'),
            _buildParamValueSpan('Hole Diam', '${r.terminalHoleDiameter.isNotEmpty ? r.terminalHoleDiameter : "-"}'),
          ],
        );
      }
    } else {
      final clean = ReportGenerator.cleanRemarks(r.notes);
      content = Text(
        clean.isNotEmpty ? clean : '-',
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 320.0),
      child: content,
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
      final matchesStatus = _statusFilter == 'All' || r.status.trim().toLowerCase() == _statusFilter.trim().toLowerCase();
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
                      color: Color(0xFF0F172A),
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
                      color: Color(0xFF475569),
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
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFB8CEE5)),
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
        Builder(
          builder: (context) {
            final isSmallScreen = MediaQuery.of(context).size.width < 750;

            final searchField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SEARCH LOT / HOPPER / INSPECTOR', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6.0),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.0),
                  decoration: InputDecoration(
                    hintText: 'Type to filter logs...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.0),
                    prefixIcon: const Icon(Icons.search, size: 18.0, color: Color(0xFF0284C7)),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF1F6FB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF4D99DB), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ],
            );

            final caliberField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CALIBER', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6.0),
                _buildDropdown(
                  value: _caliberFilter,
                  items: ['All', ...calibers],
                  onChanged: (v) => setState(() => _caliberFilter = v!),
                ),
              ],
            );

            final testNameField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TEST NAME', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6.0),
                _buildDropdown(
                  value: _testNameFilter,
                  items: ['All', ...testNames],
                  onChanged: (v) => setState(() => _testNameFilter = v!),
                ),
              ],
            );

            final lotField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LOT NUMBER', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6.0),
                _buildDropdown(
                  value: _lotFilter,
                  items: availableLots,
                  onChanged: (v) => setState(() => _lotFilter = v!),
                ),
              ],
            );

            final hopperField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HOPPER NO.', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6.0),
                _buildDropdown(
                  value: _hopperFilter,
                  items: availableHoppers,
                  onChanged: (v) => setState(() => _hopperFilter = v!),
                ),
              ],
            );

            final statusField = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('STATUS', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6.0),
                _buildDropdown(
                  value: _statusFilter,
                  items: const ['All', 'Approved', 'Pending Review', 'Rejected', 'Retest', 'Approved with condition'],
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
              ],
            );

            return Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: const Color(0xFFB8CEE5)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 14, offset: Offset(0, 3)),
                ],
              ),
              child: isSmallScreen
                  ? Column(
                      children: [
                        searchField,
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: caliberField),
                            const SizedBox(width: 10.0),
                            Expanded(child: testNameField),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(child: lotField),
                            const SizedBox(width: 10.0),
                            Expanded(child: hopperField),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        statusField,
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 2, child: searchField),
                            const SizedBox(width: 14.0),
                            Expanded(flex: 1, child: caliberField),
                            const SizedBox(width: 14.0),
                            Expanded(flex: 1, child: testNameField),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            Expanded(child: lotField),
                            const SizedBox(width: 14.0),
                            Expanded(child: hopperField),
                            const SizedBox(width: 14.0),
                            Expanded(child: statusField),
                          ],
                        ),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 20.0),

        // Logs table card (Full width to right side)
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFFB8CEE5)),
              boxShadow: const [
                BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 14, offset: Offset(0, 3)),
              ],
            ),
            child: displayRecords.isEmpty
                ? const Center(
                    child: Text(
                      'No inspection logs match the active filters.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 13.5),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      if (availableWidth < 768.0) {
                        return Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 768.0,
                              child: _buildInspectionLogTable(displayRecords),
                            ),
                          ),
                        );
                      }
                      return _buildInspectionLogTable(displayRecords);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  static const int _flexTime = 8;
  static const int _flexInspector = 9;
  static const int _flexTestName = 11;
  static const int _flexCaliber = 8;
  static const int _flexLot = 9;
  static const int _flexStatus = 9;
  static const int _flexSample = 6;
  static const int _flexResults = 16;
  static const int _flexRemarks = 9;
  static const int _flexActions = 15;

  Widget _buildInspectionLogTable(List<BallisticRecord> displayRecords) {
    return Column(
      children: [
        // Pinned Header
        Container(
          height: 42.0,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F6FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(13.0)),
            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Row(
            children: [
              _buildHeaderCell('TIME', flex: _flexTime),
              _buildHeaderCell('INSPECTOR', flex: _flexInspector),
              _buildHeaderCell('TEST NAME', flex: _flexTestName),
              _buildHeaderCell('CALIBER', flex: _flexCaliber),
              _buildHeaderCell(
                widget.currentModule == 'Daily Test'
                    ? 'HOPPER NO.'
                    : (widget.currentModule == 'Component Test' ? 'COMPONENT LOT' : 'LOT NO.'),
                flex: _flexLot,
              ),
              _buildHeaderCell('STATUS', flex: _flexStatus),
              _buildHeaderCell('QTY', flex: _flexSample),
              _buildHeaderCell('RESULTS', flex: _flexResults),
              _buildHeaderCell('REMARKS', flex: _flexRemarks),
              _buildHeaderCell('ACTIONS', flex: _flexActions, align: TextAlign.end),
            ],
          ),
        ),
        // Scrollable Log Rows
        Expanded(
          child: Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: ListView.builder(
              controller: _verticalScrollController,
              itemCount: displayRecords.length,
              itemBuilder: (context, index) {
                final r = displayRecords[index];
                return _buildTableRow(r, index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String label, {required int flex, TextAlign align = TextAlign.start}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          label,
          textAlign: align,
          style: const TextStyle(
            color: Color(0xFF0284C7),
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4.0),
          hoverColor: color.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: Icon(icon, color: color, size: 16.0),
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(BallisticRecord r, int index) {
    final st = r.status.toLowerCase();
    Color? rowBg;
    if (st.contains('condition')) {
      rowBg = const Color(0xFF0284C7).withOpacity(0.06);
    } else if (st.contains('approved')) {
      rowBg = const Color(0xFF10B981).withOpacity(0.05);
    } else if (st.contains('reject') || st.contains('fail')) {
      rowBg = const Color(0xFFEF4444).withOpacity(0.08);
    } else if (st.contains('retest') || st.contains('pending')) {
      rowBg = const Color(0xFFF59E0B).withOpacity(0.08);
    } else if (index.isEven) {
      rowBg = const Color(0xFFFAFCFF);
    }

    String timePart = r.testTime.isNotEmpty ? r.testTime : '';
    String datePart = '';
    if (r.timestamp.contains(' ')) {
      final parts = r.timestamp.split(' ');
      datePart = parts[0];
      if (timePart.isEmpty && parts.length > 1) {
        timePart = parts.sublist(1).join(' ');
      }
    } else {
      datePart = r.timestamp;
    }
    if (timePart.isEmpty) timePart = datePart;

    final String lotPrimary;
    final String lotSecondary;
    if (widget.currentModule == 'Daily Test') {
      lotPrimary = r.lotNo;
      lotSecondary = '';
    } else if (widget.currentModule == 'Component Test') {
      lotPrimary = r.primerLot.isNotEmpty ? r.primerLot : (r.propellantLot.isNotEmpty ? r.propellantLot : r.lotNo);
      lotSecondary = '';
    } else {
      lotPrimary = r.lotNo;
      if (r.hopperNo.isNotEmpty || r.boxNo.isNotEmpty) {
        lotSecondary = 'H:${r.hopperNo.isNotEmpty ? r.hopperNo : "-"} B:${r.boxNo.isNotEmpty ? r.boxNo : "-"}';
      } else {
        lotSecondary = '';
      }
    }

    final cleanNotes = ReportGenerator.cleanRemarks(r.notes);
    final hasNotes = cleanNotes.isNotEmpty;
    Widget remarksWidget = Text(
      hasNotes ? cleanNotes : '-',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10.5,
        color: hasNotes ? const Color(0xFF334155) : const Color(0xFF94A3B8),
      ),
    );
    if (hasNotes) {
      remarksWidget = Tooltip(
        message: cleanNotes,
        preferBelow: false,
        child: remarksWidget,
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 52.0),
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. TIME
          Expanded(
            flex: _flexTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timePart,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (datePart.isNotEmpty && datePart != timePart)
                    Text(
                      datePart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9.0,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 2. INSPECTOR
          Expanded(
            flex: _flexInspector,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    r.operators,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: Color(0xFF0F172A)),
                  ),
                  if (r.shift.isNotEmpty)
                    Text(
                      'Shift: ${r.shift}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.0, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
          ),
          // 3. TEST NAME
          Expanded(
            flex: _flexTestName,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF4FC),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: const Color(0xFFB8CEE5)),
                  ),
                  child: Text(
                    r.testName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          // 4. CALIBER
          Expanded(
            flex: _flexCaliber,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F6FB),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    r.caliber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'JetBrainsMono', fontSize: 10.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          // 5. LOT NO
          Expanded(
            flex: _flexLot,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Tooltip(
                message: lotSecondary.isNotEmpty ? '$lotPrimary ($lotSecondary)' : lotPrimary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lotPrimary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.0, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    ),
                    if (lotSecondary.isNotEmpty)
                      Text(
                        lotSecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.0, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 6. STATUS
          Expanded(
            flex: _flexStatus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(r.status),
              ),
            ),
          ),
          // 7. QTY
          Expanded(
            flex: _flexSample,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F6FB),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '${r.produced} rds',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 8. RESULTS
          Expanded(
            flex: _flexResults,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildResultCell(r),
            ),
          ),
          // 9. REMARKS
          Expanded(
            flex: _flexRemarks,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: remarksWidget,
            ),
          ),
          // 10. ACTIONS
          Expanded(
            flex: _flexActions,
            child: Padding(
              padding: const EdgeInsets.only(left: 2.0, right: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (r.status.toLowerCase().contains('retest'))
                    _buildActionIcon(
                      icon: Icons.replay_circle_filled_rounded,
                      color: const Color(0xFFF59E0B),
                      tooltip: 'Perform Retest Inspection',
                      onPressed: () => _showRetestDialog(r),
                    ),
                  _buildActionIcon(
                    icon: Icons.auto_awesome,
                    color: const Color(0xFF0284C7),
                    tooltip: 'AI Analysis & Recommendations',
                    onPressed: () => _showAiAnalysisDialog(r),
                  ),
                  if (r.attachmentBase64.isNotEmpty)
                    _buildActionIcon(
                      icon: Icons.attach_file,
                      color: const Color(0xFF0284C7),
                      tooltip: 'View Attachment (${r.attachmentName})',
                      onPressed: () => _showAttachmentDialog(r),
                    ),
                  _buildActionIcon(
                    icon: Icons.picture_as_pdf,
                    color: const Color(0xFF0284C7),
                    tooltip: 'Generate Individual Report',
                    onPressed: () => _showReportGenerationDialog([r], singleRecord: r),
                  ),
                  if (widget.isAdmin || widget.canEditRecords)
                    _buildActionIcon(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF0284C7),
                      tooltip: 'Edit Entry',
                      onPressed: () => _showEditRecordDialog(r),
                    ),
                  if (widget.isAdmin || widget.canDeleteRecords)
                    _buildActionIcon(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFEF4444),
                      tooltip: 'Delete Entry',
                      onPressed: () => _confirmDelete(r),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.0, fontWeight: FontWeight.w500),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF1F6FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFF4D99DB), width: 1.5),
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

    final st = status.trim().toLowerCase();
    if (st.contains('condition')) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0284C7);
      border = const Color(0xFF0284C7).withOpacity(0.4);
    } else if (st.contains('pending')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFF59E0B).withOpacity(0.25);
    } else if (st.contains('reject') || st.contains('fail')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFEF4444);
      border = const Color(0xFFEF4444).withOpacity(0.25);
    } else if (st.contains('retest')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFF59E0B).withOpacity(0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: border),
      ),
      child: Text(
        status.toUpperCase(),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
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
                horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 30.0,
                vertical: 20.0,
              ),
              child: Container(
                width: math.min(1080.0, MediaQuery.of(context).size.width * 0.95),
                height: math.min(720.0, MediaQuery.of(context).size.height * 0.88),
                padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 14.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                singleRecord != null ? 'Individual Report Generator' : 'Quality Report Generator',
                                style: const TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                singleRecord != null
                                    ? 'Generate and download quality log sheets for this specific test entry'
                                    : 'Review and download quality log sheets for tests',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E3A8A), height: 24.0),

                    Builder(
                      builder: (context) {
                        final isMobileDialog = MediaQuery.of(context).size.width < 650;

                        final testSelectorWidget = singleRecord != null
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
                              );

                        final statsBoxWidget = Container(
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
                        );

                        if (isMobileDialog) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              testSelectorWidget,
                              const SizedBox(height: 12.0),
                              statsBoxWidget,
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(flex: 2, child: testSelectorWidget),
                              const SizedBox(width: 24.0),
                              Expanded(flex: 3, child: statsBoxWidget),
                            ],
                          );
                        }
                      },
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
                            : singleRecord != null
                                ? _buildIndividualReportPreview(singleRecord)
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
                                      columnSpacing: 14.0,
                                      horizontalMargin: 12.0,
                                      dataRowMinHeight: 52.0,
                                      dataRowMaxHeight: 76.0,
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
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'Waterproof Test') ...[
                                          const DataColumn(label: Text('PRESSURE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('VISCOSITY', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('TEST TIME', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('LOCATION', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('MOUTH LEAKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('PRIMER LEAKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
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
                                        ] else if (selectedReportTest == 'Primer Sensitivity Test') ...[
                                          const DataColumn(label: Text('PRIMER LOT', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('SUPPLIER', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('INSERTION DEPTH', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('MEAN H̄', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('SD', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else if (selectedReportTest == 'Propellant Test') ...[
                                          const DataColumn(label: Text('PROPELLANT LOT', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('SUPPLIER', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('CODE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('MEAN PRESS (P1/P2)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('VEL MEAN', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ] else ...[
                                          const DataColumn(label: Text('REMARKS', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontWeight: FontWeight.bold))),
                                        ],
                                      ],
                                      rows: reportRecords.map((r) {
                                        final cleanedNotes = ReportGenerator.cleanRemarks(r.notes);
                                        final notesWidget = Container(
                                          constraints: const BoxConstraints(maxWidth: 240.0),
                                          child: Text(
                                            cleanedNotes.isNotEmpty ? cleanedNotes : '-',
                                            style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );

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
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'Waterproof Test') ...[
                                              DataCell(Text(r.pressureBar.isEmpty ? '-' : '${r.pressureBar} bar', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.viscosity.isEmpty ? '-' : r.viscosity, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.testTime.isEmpty ? '-' : r.testTime, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.samplingLocation.isEmpty ? '-' : r.samplingLocation, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('S: ${r.mouthSlow} | F: ${r.mouthFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('S: ${r.primerSlow} | F: ${r.primerFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'Residual Stress Test') ...[
                                              DataCell(Text(r.roomTemp.isEmpty ? '-' : '${r.roomTemp} °C', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.neckSlow} | Maj: ${r.neckFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.shoulderSlow} | Maj: ${r.shoulderFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.bodySlow} | Maj: ${r.bodyFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('Min: ${r.headSlow} | Maj: ${r.headFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text('${r.neckSlow + r.neckFast + r.shoulderSlow + r.shoulderFast + r.bodySlow + r.bodyFast + r.headSlow + r.headFast}', style: const TextStyle(color: Colors.white))),
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'Accuracy Test') ...[
                                              DataCell(Text(r.barrelSN.isEmpty ? '-' : r.barrelSN, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.velMean.isEmpty ? '-' : '${r.velMean} m/s', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accSDX.isEmpty ? '-' : r.accSDX, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accSDY.isEmpty ? '-' : r.accSDY, style: const TextStyle(color: Colors.white))),
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'EPVAT test') ...[
                                              DataCell(Text(r.barrelSN.isEmpty ? '-' : r.barrelSN, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.cartridgeTemp.isEmpty ? '-' : '${r.cartridgeTemp} °C', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.epvatMeanPressure.isEmpty ? '-' : 'P1: ${r.epvatMeanPressure} / P2: ${r.epvatP2MeanPressure.isEmpty ? "-" : r.epvatP2MeanPressure} ${r.epvatPressureUnit}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.velMean.isEmpty ? '-' : '${r.velMean} m/s', style: const TextStyle(color: Colors.white))),
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'Extraction Force Test') ...[
                                              DataCell(Text(r.extractionForceType.isEmpty ? '-' : r.extractionForceType, style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accMinX.isEmpty ? '-' : '${r.accMinX} N', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.accMeanX.isEmpty ? '-' : '${r.accMeanX} N', style: const TextStyle(color: Colors.white))),
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'Function Test') ...[
                                              DataCell(Text(r.cyclicRateWeaponType.isEmpty ? '-' : r.cyclicRateWeaponType, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: Colors.white))),
                                              DataCell(Text(r.cartridgeTemp.isEmpty ? '-' : r.cartridgeTemp, style: const TextStyle(fontSize: 11.0, fontFamily: 'JetBrainsMono', color: Colors.white))),
                                              DataCell(Text('${r.functionLevel1}', style: TextStyle(fontWeight: r.functionLevel1 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel1 > 0 ? const Color(0xFFEF4444) : Colors.white))),
                                              DataCell(Text('${r.functionLevel2}', style: TextStyle(fontWeight: r.functionLevel2 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel2 > 0 ? const Color(0xFFF97316) : Colors.white))),
                                              DataCell(Text('${r.functionLevel3}', style: TextStyle(fontWeight: r.functionLevel3 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel3 > 0 ? const Color(0xFFFBBF24) : Colors.white))),
                                              DataCell(Text('${r.functionLevel4}', style: TextStyle(fontWeight: r.functionLevel4 > 0 ? FontWeight.bold : FontWeight.normal, color: r.functionLevel4 > 0 ? const Color(0xFF38BDF8) : Colors.white))),
                                              DataCell(Text('${r.defects}', style: TextStyle(fontWeight: FontWeight.bold, color: r.defects > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)))),
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'Primer Sensitivity Test') ...[
                                              DataCell(Text(r.primerLot.isNotEmpty ? r.primerLot : (r.lotNo.isNotEmpty ? r.lotNo : '-'), style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.primerSupplier.isNotEmpty ? r.primerSupplier : '-', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.primerInsertionDepth.isNotEmpty ? '${r.primerInsertionDepth} mm' : '-', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.primerHbar.isNotEmpty ? '${r.primerHbar} cm' : '-', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.primerSD.isNotEmpty ? '${r.primerSD} cm' : '-', style: const TextStyle(color: Colors.white))),
                                              DataCell(notesWidget),
                                            ] else if (selectedReportTest == 'Propellant Test') ...[
                                              DataCell(Text(r.propellantLot.isNotEmpty ? r.propellantLot : (r.lotNo.isNotEmpty ? r.lotNo : '-'), style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.propellantSupplier.isNotEmpty ? r.propellantSupplier : '-', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.propellantCode.isNotEmpty ? r.propellantCode : '-', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.epvatMeanPressure.isEmpty ? '-' : 'P1: ${r.epvatMeanPressure} / P2: ${r.epvatP2MeanPressure.isEmpty ? "-" : r.epvatP2MeanPressure} ${r.epvatPressureUnit}', style: const TextStyle(color: Colors.white))),
                                              DataCell(Text(r.velMean.isEmpty ? '-' : '${r.velMean} m/s', style: const TextStyle(color: Colors.white))),
                                              DataCell(notesWidget),
                                            ] else ...[
                                              DataCell(notesWidget),
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

                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10.0,
                      runSpacing: 10.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                        ElevatedButton.icon(
                          onPressed: reportRecords.isEmpty ? null : () async {
                            final csvContent = ReportGenerator.generateCsv(reportRecords, selectedReportTest, widget.currentModule);
                            final repCaliber = (singleRecord?.caliber ?? (reportRecords.isNotEmpty ? reportRecords.first.caliber : 'Caliber')).replaceAll(';', ' ').trim();
                            final repTestName = selectedReportTest == 'All' ? 'Final_Lot_Acceptance_Certificate' : (singleRecord?.testName ?? selectedReportTest);
                            final repLotNo = singleRecord?.lotNo ?? (reportRecords.isNotEmpty ? reportRecords.first.lotNo : 'Batch');
                            final exportFilename = '${repCaliber}_${repTestName}_$repLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                            await ReportHelper.instance.downloadCsv(
                              content: csvContent, 
                              filename: '$exportFilename.csv'
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quality Excel report downloaded: $exportFilename.csv'),
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
                        ElevatedButton.icon(
                          onPressed: reportRecords.isEmpty ? null : () async {
                            final docContent = ReportGenerator.generateWordHtml(
                              reportRecords, 
                              selectedReportTest,
                              widget.currentModule,
                              base64Logo: widget.base64Logo,
                              adminRules: widget.adminRules,
                            );
                            final repCaliber = (singleRecord?.caliber ?? (reportRecords.isNotEmpty ? reportRecords.first.caliber : 'Caliber')).replaceAll(';', ' ').trim();
                            final repTestName = selectedReportTest == 'All' ? 'Final_Lot_Acceptance_Certificate' : (singleRecord?.testName ?? selectedReportTest);
                            final repLotNo = singleRecord?.lotNo ?? (reportRecords.isNotEmpty ? reportRecords.first.lotNo : 'Batch');
                            final exportFilename = '${repCaliber}_${repTestName}_$repLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                            await ReportHelper.instance.downloadDoc(
                              content: docContent, 
                              filename: '$exportFilename.doc'
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quality Word document downloaded: $exportFilename.doc'),
                                backgroundColor: const Color(0xFF0284C7),
                              ),
                            );
                          },
                          icon: const Icon(Icons.description, size: 16.0),
                          label: Text(selectedReportTest == 'All' ? 'Export Certificate (Word)' : 'Export Word'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: reportRecords.isEmpty ? null : () async {
                            final htmlContent = ReportGenerator.generateHtml(
                              reportRecords, 
                              selectedReportTest,
                              widget.currentModule,
                              base64Logo: widget.base64Logo,
                              adminRules: widget.adminRules,
                            );
                            final repCaliber = (singleRecord?.caliber ?? (reportRecords.isNotEmpty ? reportRecords.first.caliber : 'Caliber')).replaceAll(';', ' ').trim();
                            final repTestName = selectedReportTest == 'All' ? 'Final_Lot_Acceptance_Certificate' : (singleRecord?.testName ?? selectedReportTest);
                            final repLotNo = singleRecord?.lotNo ?? (reportRecords.isNotEmpty ? reportRecords.first.lotNo : 'Batch');
                            final exportFilename = '${repCaliber}_${repTestName}_$repLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                            await ReportHelper.instance.printHtml(
                              htmlContent: htmlContent,
                              filename: exportFilename,
                            );
                          },
                          icon: const Icon(Icons.print_outlined, size: 16.0),
                          label: Text(selectedReportTest == 'All' ? 'Certificate (PDF / Print)' : 'Download / Print PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          ),
                        ),
                        if (selectedReportTest == 'All' && reportRecords.length > 1) ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              final docContent = ReportGenerator.generateLotDossierWord(
                                reportRecords, 
                                widget.currentModule,
                                base64Logo: widget.base64Logo,
                                adminRules: widget.adminRules,
                              );
                              final repCaliber = (reportRecords.first.caliber).replaceAll(';', ' ').trim();
                              final repLotNo = reportRecords.first.lotNo;
                              final exportFilename = '${repCaliber}_Complete_Lot_Dossier_$repLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                              await ReportHelper.instance.downloadDoc(
                                content: docContent, 
                                filename: '$exportFilename.doc'
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Complete Lot Dossier Word document downloaded: $exportFilename.doc'),
                                  backgroundColor: const Color(0xFF8B5CF6),
                                ),
                              );
                            },
                            icon: const Icon(Icons.auto_stories_outlined, size: 16.0),
                            label: const Text('Complete Dossier (Word)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final htmlContent = ReportGenerator.generateLotDossierHtml(
                                reportRecords, 
                                widget.currentModule,
                                base64Logo: widget.base64Logo,
                                adminRules: widget.adminRules,
                              );
                              final repCaliber = (reportRecords.first.caliber).replaceAll(';', ' ').trim();
                              final repLotNo = reportRecords.first.lotNo;
                              final exportFilename = '${repCaliber}_Complete_Lot_Dossier_$repLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                              await ReportHelper.instance.printHtml(
                                htmlContent: htmlContent,
                                filename: exportFilename,
                              );
                            },
                            icon: const Icon(Icons.collections_bookmark_outlined, size: 16.0),
                            label: const Text('Complete Dossier (PDF)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9333EA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            ),
                          ),
                        ],
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

  Widget _buildIndividualReportPreview(BallisticRecord r) {
    final cleanedNotes = ReportGenerator.cleanRemarks(r.notes);
    final hasNotes = cleanedNotes.trim().isNotEmpty && cleanedNotes.trim().toLowerCase() != 'clear';

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Identification Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
            ),
            child: Wrap(
              spacing: 16.0,
              runSpacing: 10.0,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.testName,
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 16.0, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10.0),
                        _buildStatusBadge(r.status),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Caliber: ${r.caliber} | Lot: ${r.lotNo}${r.hopperNo.isNotEmpty ? " (Hopper: ${r.hopperNo})" : ""}${r.boxNo.isNotEmpty ? " (Box: ${r.boxNo})" : ""}',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 14.0,
                  runSpacing: 6.0,
                  children: [
                    _buildCompactMeta('INSPECTOR', r.operators),
                    if (r.shift.isNotEmpty) _buildCompactMeta('SHIFT', r.shift),
                    _buildCompactMeta('TIME', r.testTime.isNotEmpty ? r.testTime : r.timestamp),
                    _buildCompactMeta('TESTED', '${r.produced} rounds'),
                    _buildCompactMeta('DEFECTS', '${r.defects}', valColor: r.defects > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // 2. Test Measurements & Specifications
          const Text(
            'TEST MEASUREMENTS & SPECIFICATION PARAMETERS',
            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: _buildTestMetricTiles(r),
          ),
          if (r.isRetest) ...[
            const SizedBox(height: 14.0),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.7), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.replay_circle_filled_rounded, color: Color(0xFFF59E0B), size: 18.0),
                      const SizedBox(width: 8.0),
                      const Text(
                        'RETEST VERIFICATION INSPECTION RESULTS',
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      if (r.retestStatus.isNotEmpty) _buildStatusBadge(r.retestStatus),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Wrap(
                    spacing: 14.0,
                    runSpacing: 6.0,
                    children: [
                      _buildCompactMeta('RETEST OPERATOR', r.retestOperator.isNotEmpty ? r.retestOperator : r.operators),
                      if (r.retestTimestamp.isNotEmpty) _buildCompactMeta('RETEST TIME', r.retestTimestamp),
                      _buildCompactMeta('RETEST SAMPLE', '${r.retestProduced > 0 ? r.retestProduced : r.produced} rounds'),
                      _buildCompactMeta('RETEST DEFECTS', '${r.retestDefects}', valColor: r.retestDefects > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: _buildRetestMetricTiles(r),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16.0),

          // 3. REMARKS & OBSERVATIONS SECTION (Always completely visible on screen)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6), width: 1.2),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.notes_rounded, color: Color(0xFF38BDF8), size: 18.0),
                    SizedBox(width: 8.0),
                    Text(
                      'INSPECTOR REMARKS & OBSERVATIONS',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  hasNotes ? cleanedNotes.trim() : 'No specific inspector remarks recorded for this test.',
                  style: TextStyle(
                    color: hasNotes ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 13.0,
                    height: 1.45,
                    fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                if (r.functionDefectDetails.isNotEmpty) ...[
                  const SizedBox(height: 10.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.0),
                        children: [
                          const TextSpan(text: 'Specific Defects: ', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                          TextSpan(text: r.functionDefectDetails, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (r.isRetest || r.retestNotes.isNotEmpty) ...[
                  const SizedBox(height: 10.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                    ),
                    child: Text(
                      'Retest Verification: ${r.retestNotes} (by ${r.retestOperator} on ${r.retestTimestamp})',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12.0),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // 4. RECOMMENDATION / DISPOSITION SECTION
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RECOMMENDATION',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4.0),
                Text(
                  _getRecommendationSentence(r),
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.0, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTestMetricTiles(BallisticRecord r) {
    final tName = r.testName;
    if (tName == 'Waterproof Test') {
      final totalLeaks = r.mouthSlow + r.mouthFast + r.primerSlow + r.primerFast;
      return [
        _buildMetricTile('Test Pressure', r.pressureBar.isNotEmpty ? '${r.pressureBar} bar' : '-'),
        _buildMetricTile('Viscosity', r.viscosity.isNotEmpty ? r.viscosity : '-'),
        _buildMetricTile('Test Time', r.testTime.isNotEmpty ? r.testTime : '-'),
        _buildMetricTile('Sampling Location', r.samplingLocation.isNotEmpty ? r.samplingLocation : '-'),
        _buildMetricTile('Mouth Leaks (Slow / Fast)', '${r.mouthSlow} / ${r.mouthFast}'),
        _buildMetricTile('Primer Leaks (Slow / Fast)', '${r.primerSlow} / ${r.primerFast}'),
        _buildMetricTile('Total Leaks Found', '$totalLeaks', valueColor: totalLeaks > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
      ];
    } else if (tName == 'Residual Stress Test') {
      final neck = r.neckSlow + r.neckFast;
      final shoulder = r.shoulderSlow + r.shoulderFast;
      final body = r.bodySlow + r.bodyFast;
      final head = r.headSlow + r.headFast;
      final total = neck + shoulder + body + head;
      return [
        _buildMetricTile('Room Temperature', r.roomTemp.isNotEmpty ? '${r.roomTemp} °C' : '-'),
        _buildMetricTile('Sampling Location', r.samplingLocation.isNotEmpty ? r.samplingLocation : '-'),
        _buildMetricTile('Neck Splits (Zone I)', 'Min: ${r.neckSlow} | Maj: ${r.neckFast}'),
        _buildMetricTile('Shoulder Splits (Zone S)', 'Min: ${r.shoulderSlow} | Maj: ${r.shoulderFast}'),
        _buildMetricTile('Body Splits (Zone J/K)', 'Min: ${r.bodySlow} | Maj: ${r.bodyFast}'),
        _buildMetricTile('Head Splits (Zone L/M)', 'Min: ${r.headSlow} | Maj: ${r.headFast}'),
        _buildMetricTile('Total Splits Found', '$total', valueColor: total > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
      ];
    } else if (tName == 'Accuracy Test') {
      return [
        _buildMetricTile('Barrel S.N.', r.barrelSN.isNotEmpty ? r.barrelSN : '-'),
        _buildMetricTile('Velocity Distance', r.velocityDistance.isNotEmpty ? '${r.velocityDistance} m' : '-'),
        _buildMetricTile('Mean Velocity', r.velMean.isNotEmpty ? '${r.velMean} m/s' : '-'),
        _buildMetricTile('Velocity Range (Min / Max / SD)', 'Min: ${r.velMin.isNotEmpty ? r.velMin : "-"} | Max: ${r.velMax.isNotEmpty ? r.velMax : "-"} | SD: ${r.velSD.isNotEmpty ? r.velSD : "-"}'),
        _buildMetricTile('Accuracy SD X', r.accSDX.isNotEmpty ? '${r.accSDX} mm' : '-'),
        _buildMetricTile('Accuracy SD Y', r.accSDY.isNotEmpty ? '${r.accSDY} mm' : '-'),
        _buildMetricTile('Mean Radius (MR)', r.accMeanRadius.isNotEmpty ? '${r.accMeanRadius} mm' : '-'),
        _buildMetricTile('Largest Distance', r.accLargestDistance.isNotEmpty ? '${r.accLargestDistance} mm' : '-'),
      ];
    } else if (tName == 'EPVAT test') {
      final unit = r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'bar';
      return [
        _buildMetricTile('Barrel S.N.', r.barrelSN.isNotEmpty ? r.barrelSN : '-'),
        _buildMetricTile('Velocity Distance', r.velocityDistance.isNotEmpty ? '${r.velocityDistance} m' : '-'),
        _buildMetricTile('Cartridge Temperature', r.cartridgeTemp.isNotEmpty ? r.cartridgeTemp : '-'),
        _buildMetricTile('Chamber Press P1 (Mean)', r.epvatMeanPressure.isNotEmpty ? '${r.epvatMeanPressure} $unit' : '-'),
        _buildMetricTile('P1 (Min / Max / SD)', 'Min: ${r.epvatMinPressure.isNotEmpty ? r.epvatMinPressure : "-"} | Max: ${r.epvatMaxPressure.isNotEmpty ? r.epvatMaxPressure : "-"} | SD: ${r.epvatSDPressure.isNotEmpty ? r.epvatSDPressure : "-"}'),
        _buildMetricTile('Port Press P2 (Mean / Max)', 'Mean: ${r.epvatP2MeanPressure.isNotEmpty ? r.epvatP2MeanPressure : "-"} | Max: ${r.epvatP2MaxPressure.isNotEmpty ? r.epvatP2MaxPressure : "-"} $unit'),
        _buildMetricTile('Action Time (Mean)', r.actionTimeMean.isNotEmpty ? '${r.actionTimeMean} ms' : '-'),
        _buildMetricTile('Mean Velocity (+21°C)', r.velMean.isNotEmpty ? '${r.velMean} m/s' : '-'),
      ];
    } else if (tName == 'Function Test') {
      return [
        _buildMetricTile('Rifles / Weapons', r.cyclicRateWeaponType.isNotEmpty ? r.cyclicRateWeaponType : '-'),
        _buildMetricTile('Cartridge Temperature', r.cartridgeTemp.isNotEmpty ? r.cartridgeTemp : '-'),
        _buildMetricTile('Level 1 (Critical)', '${r.functionLevel1}', valueColor: r.functionLevel1 > 0 ? const Color(0xFFEF4444) : Colors.white),
        _buildMetricTile('Level 2 (Major)', '${r.functionLevel2}', valueColor: r.functionLevel2 > 0 ? const Color(0xFFF97316) : Colors.white),
        _buildMetricTile('Level 3 (Minor)', '${r.functionLevel3}', valueColor: r.functionLevel3 > 0 ? const Color(0xFFFBBF24) : Colors.white),
        _buildMetricTile('Level 4', '${r.functionLevel4}', valueColor: const Color(0xFF38BDF8)),
        _buildMetricTile('Total Defects', '${r.defects}', valueColor: r.defects > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
      ];
    } else if (tName == 'Extraction Force Test') {
      return [
        _buildMetricTile('Test Mode / Type', r.extractionForceType.isNotEmpty ? r.extractionForceType : '-'),
        _buildMetricTile('Min Extraction Force', r.accMinX.isNotEmpty ? '${r.accMinX} N' : '-'),
        _buildMetricTile('Mean Extraction Force', r.accMeanX.isNotEmpty ? '${r.accMeanX} N' : '-'),
        _buildMetricTile('Max Extraction Force', r.accMaxX.isNotEmpty ? '${r.accMaxX} N' : '-'),
      ];
    } else if (tName == 'Primer Sensitivity Test') {
      return [
        _buildMetricTile('Primer Lot', r.primerLot.isNotEmpty ? r.primerLot : (r.lotNo.isNotEmpty ? r.lotNo : '-')),
        _buildMetricTile('Primer Supplier', r.primerSupplier.isNotEmpty ? r.primerSupplier : '-'),
        _buildMetricTile('Avg Insertion Depth', r.primerInsertionDepth.isNotEmpty ? '${r.primerInsertionDepth} mm' : '-'),
        _buildMetricTile('Mean Height (H̄)', r.primerHbar.isNotEmpty ? '${r.primerHbar} cm' : '-'),
        _buildMetricTile('Standard Deviation (SD)', r.primerSD.isNotEmpty ? '${r.primerSD} cm' : '-'),
        _buildMetricTile('All-Fire (H̄+5SD)', r.primerAllFireH.isNotEmpty ? '${r.primerAllFireH} cm' : '-'),
        _buildMetricTile('No-Fire (H̄-2SD)', r.primerNoFireH.isNotEmpty ? '${r.primerNoFireH} cm' : '-'),
      ];
    } else if (tName == 'Propellant Test') {
      final unit = r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'bar';
      return [
        _buildMetricTile('Propellant Lot', r.propellantLot.isNotEmpty ? r.propellantLot : (r.lotNo.isNotEmpty ? r.lotNo : '-')),
        _buildMetricTile('Propellant Supplier', r.propellantSupplier.isNotEmpty ? r.propellantSupplier : '-'),
        _buildMetricTile('Propellant Code', r.propellantCode.isNotEmpty ? r.propellantCode : '-'),
        _buildMetricTile('Chamber Press (P1)', r.epvatMeanPressure.isNotEmpty ? '${r.epvatMeanPressure} $unit' : '-'),
        _buildMetricTile('Port Pressure (P2)', r.epvatP2MeanPressure.isNotEmpty ? '${r.epvatP2MeanPressure} $unit' : '-'),
        _buildMetricTile('Mean Velocity', r.velMean.isNotEmpty ? '${r.velMean} m/s' : '-'),
      ];
    } else if (tName == 'Firing Rate Cycle Test') {
      return [
        _buildMetricTile('Weapon Model', r.cyclicRateWeaponType.isNotEmpty ? r.cyclicRateWeaponType : '-'),
        _buildMetricTile('Ammunition Type', r.cyclicRateAmmoType.isNotEmpty ? r.cyclicRateAmmoType : '-'),
        _buildMetricTile('Measured Firing Rate', r.cyclicRateValue.isNotEmpty ? '${r.cyclicRateValue} RPM' : '-'),
        _buildMetricTile('Allowed Rate Range', 'Min: ${r.cyclicRateMin.isNotEmpty ? r.cyclicRateMin : "-"} RPM | Max: ${r.cyclicRateMax.isNotEmpty ? r.cyclicRateMax : "No limit"}'),
      ];
    } else if (tName == 'Terminal Effect Test') {
      return [
        _buildMetricTile('Barrel S.N.', r.barrelSN.isNotEmpty ? r.barrelSN : '-'),
        _buildMetricTile('Velocity Distance', r.velocityDistance.isNotEmpty ? '${r.velocityDistance} m' : '-'),
        _buildMetricTile('Terminal Velocity', r.terminalVelocity.isNotEmpty ? '${r.terminalVelocity} m/s' : (r.velMean.isNotEmpty ? '${r.velMean} m/s' : '-')),
        _buildMetricTile('Target Hole Diameter', r.terminalHoleDiameter.isNotEmpty ? r.terminalHoleDiameter : '-'),
        _buildMetricTile('Steel Plate Penetration', r.terminalSteelPenetration.isNotEmpty ? r.terminalSteelPenetration : '-'),
      ];
    }
    return [
      _buildMetricTile('Test Parameters', ReportGenerator.cleanRemarks(r.notes).isNotEmpty ? ReportGenerator.cleanRemarks(r.notes) : '-'),
    ];
  }

  List<Widget> _buildRetestMetricTiles(BallisticRecord r) {
    final m = r.parsedRetestMetrics;
    final tName = r.testName;
    if (tName == 'Waterproof Test') {
      final ms = m['mouthSlow'] as int? ?? 0;
      final mf = m['mouthFast'] as int? ?? 0;
      final ps = m['primerSlow'] as int? ?? 0;
      final pf = m['primerFast'] as int? ?? 0;
      final total = ms + mf + ps + pf;
      return [
        _buildMetricTile('Mouth Leaks (Slow / Fast)', '$ms / $mf'),
        _buildMetricTile('Primer Leaks (Slow / Fast)', '$ps / $pf'),
        _buildMetricTile('Retest Total Leaks', '$total', valueColor: total > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
      ];
    } else if (tName == 'Residual Stress Test') {
      final ns = m['neckSlow'] as int? ?? 0;
      final nf = m['neckFast'] as int? ?? 0;
      final ss = m['shoulderSlow'] as int? ?? 0;
      final sf = m['shoulderFast'] as int? ?? 0;
      final bs = m['bodySlow'] as int? ?? 0;
      final bf = m['bodyFast'] as int? ?? 0;
      final hs = m['headSlow'] as int? ?? 0;
      final hf = m['headFast'] as int? ?? 0;
      final total = ns + nf + ss + sf + bs + bf + hs + hf;
      return [
        _buildMetricTile('Neck Splits', 'Min: $ns | Maj: $nf'),
        _buildMetricTile('Shoulder Splits', 'Min: $ss | Maj: $sf'),
        _buildMetricTile('Body Splits', 'Min: $bs | Maj: $bf'),
        _buildMetricTile('Head Splits', 'Min: $hs | Maj: $hf'),
        _buildMetricTile('Retest Total Splits', '$total', valueColor: total > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
      ];
    } else if (tName == 'Accuracy Test') {
      return [
        _buildMetricTile('Retest Mean Radius (MR)', m['accMeanRadius'] != null && m['accMeanRadius'].toString().isNotEmpty ? '${m['accMeanRadius']} mm' : '-'),
        _buildMetricTile('Retest Largest Dist (ES)', m['accLargestDistance'] != null && m['accLargestDistance'].toString().isNotEmpty ? '${m['accLargestDistance']} mm' : '-'),
        _buildMetricTile('Retest SD X', m['accSDX'] != null && m['accSDX'].toString().isNotEmpty ? '${m['accSDX']} mm' : '-'),
        _buildMetricTile('Retest SD Y', m['accSDY'] != null && m['accSDY'].toString().isNotEmpty ? '${m['accSDY']} mm' : '-'),
        _buildMetricTile('Retest Mean Vel', m['velMean'] != null && m['velMean'].toString().isNotEmpty ? '${m['velMean']} m/s' : '-'),
      ];
    } else if (tName == 'EPVAT test' || tName == 'Propellant Test') {
      final unit = r.epvatPressureUnit.isNotEmpty ? r.epvatPressureUnit : 'bar';
      return [
        _buildMetricTile('Retest Chamber P1 (Mean)', m['epvatMeanPressure'] != null && m['epvatMeanPressure'].toString().isNotEmpty ? '${m['epvatMeanPressure']} $unit' : '-'),
        _buildMetricTile('Retest P1 Max', m['epvatMaxPressure'] != null && m['epvatMaxPressure'].toString().isNotEmpty ? '${m['epvatMaxPressure']} $unit' : '-'),
        _buildMetricTile('Retest Port P2 (Mean)', m['epvatP2MeanPressure'] != null && m['epvatP2MeanPressure'].toString().isNotEmpty ? '${m['epvatP2MeanPressure']} $unit' : '-'),
        _buildMetricTile('Retest Action Time', m['actionTimeMean'] != null && m['actionTimeMean'].toString().isNotEmpty ? '${m['actionTimeMean']} ms' : '-'),
        _buildMetricTile('Retest Mean Vel', m['velMean'] != null && m['velMean'].toString().isNotEmpty ? '${m['velMean']} m/s' : '-'),
      ];
    } else if (tName == 'Function Test') {
      final l1 = m['functionLevel1'] as int? ?? 0;
      final l2 = m['functionLevel2'] as int? ?? 0;
      final l3 = m['functionLevel3'] as int? ?? 0;
      final l4 = m['functionLevel4'] as int? ?? 0;
      final total = l1 + l2 + l3 + l4;
      return [
        _buildMetricTile('Retest L1 (Critical)', '$l1', valueColor: l1 > 0 ? const Color(0xFFEF4444) : Colors.white),
        _buildMetricTile('Retest L2 (Major)', '$l2', valueColor: l2 > 0 ? const Color(0xFFF97316) : Colors.white),
        _buildMetricTile('Retest L3 (Minor)', '$l3', valueColor: l3 > 0 ? const Color(0xFFFBBF24) : Colors.white),
        _buildMetricTile('Retest Level 4', '$l4', valueColor: const Color(0xFF38BDF8)),
        _buildMetricTile('Retest Total Defects', '$total', valueColor: total > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
      ];
    } else if (tName == 'Extraction Force Test') {
      return [
        _buildMetricTile('Retest Min Force', m['accMinX'] != null && m['accMinX'].toString().isNotEmpty ? '${m['accMinX']} N' : '-'),
        _buildMetricTile('Retest Force Type', m['extractionForceType'] != null && m['extractionForceType'].toString().isNotEmpty ? '${m['extractionForceType']}' : '-'),
      ];
    } else if (tName == 'Primer Sensitivity Test') {
      return [
        _buildMetricTile('Retest Mean Height (H̄)', m['primerHbar'] != null && m['primerHbar'].toString().isNotEmpty ? '${m['primerHbar']} cm' : '-'),
        _buildMetricTile('Retest SD', m['primerSD'] != null && m['primerSD'].toString().isNotEmpty ? '${m['primerSD']} cm' : '-'),
        _buildMetricTile('Retest All-Fire', m['primerAllFireH'] != null && m['primerAllFireH'].toString().isNotEmpty ? '${m['primerAllFireH']} cm' : '-'),
        _buildMetricTile('Retest No-Fire', m['primerNoFireH'] != null && m['primerNoFireH'].toString().isNotEmpty ? '${m['primerNoFireH']} cm' : '-'),
      ];
    }
    return [
      _buildMetricTile('Retest Details', r.retestNotes.isNotEmpty ? r.retestNotes : '-'),
    ];
  }

  Widget _buildMetricTile(String label, String value, {Color? valueColor}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3.0),
          Text(
            value.isNotEmpty ? value : '-',
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMeta(String label, String val, {Color? valColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2.0),
        Text(
          val.isNotEmpty ? val : '-',
          style: TextStyle(
            color: valColor ?? Colors.white,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ],
    );
  }

  String _getRecommendationSentence(BallisticRecord r) {
    final st = r.status.toLowerCase();
    if (st == 'rejected' || st == 'failed') {
      return 'The inspected lot fails to satisfy quality and ballistic specification criteria. The lot is officially REJECTED and quarantined.';
    } else if (st.contains('retest')) {
      return 'Test results indicate marginal quality tolerances. The lot is sentenced to a mandatory RETEST under supervision.';
    } else if (st.contains('pending')) {
      return 'Evaluation in progress. The batch status remains PENDING REVIEW until supervisor verification is complete.';
    } else if (st.contains('condition')) {
      return 'The inspected lot meets operational parameters with accepted variances. The lot is officially APPROVED WITH CONDITION.';
    } else {
      return 'The lot meets all quality and ballistic specifications and is approved for final packaging and shipment.';
    }
  }
}
