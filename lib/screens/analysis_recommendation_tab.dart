import 'package:flutter/material.dart';
import '../models/ballistic_record.dart';
import '../services/ai_analysis_service.dart';

class AnalysisRecommendationTab extends StatefulWidget {
  final List<BallisticRecord> records;
  final String currentModule;
  final Map<String, dynamic> adminRules;

  const AnalysisRecommendationTab({
    Key? key,
    required this.records,
    this.currentModule = 'Lot Acceptance Test',
    this.adminRules = const {},
  }) : super(key: key);

  @override
  _AnalysisRecommendationTabState createState() => _AnalysisRecommendationTabState();
}

class _AnalysisRecommendationTabState extends State<AnalysisRecommendationTab> {
  String _selectedLot = 'All Lots';
  String _selectedTestName = 'All Tests';
  BallisticRecord? _selectedRecord;

  @override
  void initState() {
    super.initState();
    if (widget.records.isNotEmpty) {
      _selectedRecord = widget.records.first;
    }
  }

  @override
  void didUpdateWidget(covariant AnalysisRecommendationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedRecord == null && widget.records.isNotEmpty) {
      setState(() {
        _selectedRecord = widget.records.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final weeklyReport = AiAnalysisService.instance.analyzeWeeklyStability(widget.records);
    final activeRecord = _selectedRecord ?? (widget.records.isNotEmpty ? widget.records.first : null);
    final testAdvisory = activeRecord != null
        ? AiAnalysisService.instance.analyzeRecord(activeRecord, adminRules: widget.adminRules)
        : null;

    final availableLots = {'All Lots', ...widget.records.map((r) => r.lotNo)}.toList();
    final availableTests = {'All Tests', ...widget.records.map((r) => r.testName)}.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 64.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C415E),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: const Color(0xFF1E3A8A)),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 24.0),
                      ),
                      const SizedBox(width: 12.0),
                      const Text(
                        'AI Analysis & Recommendations',
                        style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  const Text(
                    'Automated 1-week stability diagnostics, leak drift detection, and per-test ballistic engineering recommendations',
                    style: TextStyle(fontSize: 13.0, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: weeklyReport.ratingColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: weeklyReport.ratingColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: weeklyReport.ratingColor, size: 18.0),
                    const SizedBox(width: 8.0),
                    Text(
                      '${weeklyReport.stabilityScore}% • ${weeklyReport.stabilityRating}',
                      style: TextStyle(color: weeklyReport.ratingColor, fontWeight: FontWeight.bold, fontSize: 13.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),

          // 1-Week Stability Alert Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 10.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      weeklyReport.isLeaksIncreasing || weeklyReport.isPressureUnstable
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: weeklyReport.ratingColor,
                      size: 22.0,
                    ),
                    const SizedBox(width: 10.0),
                    const Text(
                      '1-Week Ballistic Quality & Stability Executive Summary',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      'Analyzed ${weeklyReport.totalTests} tests (${weeklyReport.totalSampleRounds} total sample rounds)',
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const Divider(color: Color(0xFF1E3A8A), height: 1.0),
                const SizedBox(height: 14.0),

                // Critical alerts list
                ...weeklyReport.criticalAlerts.map((alert) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_right, color: Color(0xFF38BDF8), size: 18.0),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            alert,
                            style: const TextStyle(fontSize: 13.0, color: Colors.white, height: 1.4, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 8.0),
                const Text(
                  'Recommended Quality Control Actions:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 6.0),
                ...weeklyReport.actionableAdvice.map((advice) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16.0),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            advice,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 24.0),

          // Daily Tracking Cards (Leaks Trend & Pressure Stability)
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 750
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                children: [
                  // Daily Leaks Trend Card
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF344D6E),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: weeklyReport.isLeaksIncreasing ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF1E3A8A),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 8.0,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                color: (weeklyReport.isLeaksIncreasing ? const Color(0xFFEF4444) : const Color(0xFF0284C7)).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Icon(
                                Icons.water_drop_outlined,
                                color: weeklyReport.isLeaksIncreasing ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                                size: 18.0,
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            const Expanded(
                              child: Text(
                                'Daily Waterproof Leak Trend',
                                style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                              decoration: BoxDecoration(
                                color: (weeklyReport.isLeaksIncreasing ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                weeklyReport.isLeaksIncreasing ? 'LEAKS RISING ⚠' : 'STABLE LEAK RATE',
                                style: TextStyle(
                                  color: weeklyReport.isLeaksIncreasing ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          weeklyReport.leakTrendSummary,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
                        ),
                        const SizedBox(height: 16.0),

                        // Day by day leak table
                        if (weeklyReport.dailyLeaks.isEmpty)
                          const Text('No waterproof logs in the last 7 days.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0))
                        else
                          Column(
                            children: weeklyReport.dailyLeaks.entries.map((e) {
                              final count = e.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Text(e.key, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.0, color: Color(0xFF94A3B8))),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: count > 0 ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        '$count ${count == 1 ? "leak" : "leaks"}',
                                        style: TextStyle(
                                          color: count > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  // Daily Chamber Pressure Stability Card
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF344D6E),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: weeklyReport.isPressureUnstable ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF1E3A8A),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 8.0,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                color: (weeklyReport.isPressureUnstable ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9)).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Icon(
                                Icons.speed_rounded,
                                color: weeklyReport.isPressureUnstable ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                                size: 18.0,
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            const Expanded(
                              child: Text(
                                'EPVAT Chamber Pressure Stability',
                                style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                              decoration: BoxDecoration(
                                color: (weeklyReport.isPressureUnstable ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                weeklyReport.isPressureUnstable ? 'PRESSURE UNSTABLE ⚠' : 'PRESSURE OPTIMAL',
                                style: TextStyle(
                                  color: weeklyReport.isPressureUnstable ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          weeklyReport.pressureTrendSummary,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
                        ),
                        const SizedBox(height: 16.0),

                        // Day by day pressure table
                        if (weeklyReport.dailyMeanPressure.isEmpty)
                          const Text('No EPVAT logs in the last 7 days.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0))
                        else
                          Column(
                            children: weeklyReport.dailyMeanPressure.entries.map((e) {
                              final mean = e.value;
                              final sd = weeklyReport.dailyPressureSD[e.key] ?? 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Text(e.key, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.0, color: Color(0xFF94A3B8))),
                                    const Spacer(),
                                    Text(
                                      'Mean: ${mean.toStringAsFixed(0)} bar',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: sd > 90.0 ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF0284C7).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        'SD: ${sd.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          color: sd > 90.0 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28.0),

          // Per-Test AI Advisory Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF344D6E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 10.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C415E),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF1E3A8A)),
                          ),
                          child: const Icon(Icons.biotech_outlined, color: Color(0xFF38BDF8), size: 20.0),
                        ),
                        const SizedBox(width: 12.0),
                        const Text(
                          'Individual Test AI Diagnostic & Root-Cause Advisory',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    // Test Record Selector
                    if (widget.records.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C415E),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFF1E3A8A)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BallisticRecord>(
                            value: activeRecord,
                            dropdownColor: const Color(0xFF344D6E),
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                            onChanged: (rec) {
                              if (rec != null) setState(() => _selectedRecord = rec);
                            },
                            items: widget.records.map((r) {
                              return DropdownMenuItem<BallisticRecord>(
                                value: r,
                                child: Text('${r.testName} • ${r.lotNo} (${r.timestamp})'),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16.0),
                const Divider(color: Color(0xFF1E3A8A), height: 1.0),
                const SizedBox(height: 16.0),

                if (testAdvisory != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: testAdvisory.statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: testAdvisory.statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          testAdvisory.status.toUpperCase(),
                          style: TextStyle(color: testAdvisory.statusColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Text(
                        testAdvisory.summary,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Key Metrics Chips
                  Wrap(
                    spacing: 10.0,
                    runSpacing: 8.0,
                    children: testAdvisory.keyMetrics.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C415E),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFF1E3A8A)),
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: '${e.key}: ', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                              TextSpan(text: e.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.0)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20.0),

                  // Findings & Action Recommendations Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Findings
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C415E),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF1E3A8A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Engineered Findings:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF38BDF8)),
                              ),
                              const SizedBox(height: 8.0),
                              ...testAdvisory.findings.map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.circle, size: 6.0, color: Color(0xFF38BDF8)),
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: Text(f, style: const TextStyle(fontSize: 12.5, color: Color(0xFFE2E8F0), height: 1.35)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16.0),

                      // Recommendations
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C415E),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF1E3A8A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI Corrective Recommendations:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(height: 8.0),
                              ...testAdvisory.recommendations.map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.lightbulb_outline, size: 14.0, color: Color(0xFF10B981)),
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: Text(r, style: const TextStyle(fontSize: 12.5, color: Color(0xFFE2E8F0), height: 1.35)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'No inspection record selected. Select a ballistic trial above to view automated AI engineering recommendations.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.0),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
