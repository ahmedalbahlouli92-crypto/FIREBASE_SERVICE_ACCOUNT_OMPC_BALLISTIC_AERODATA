import 'package:flutter/material.dart';

/// Modern intelligent dashboard component featuring:
/// - Soft icy-blue tinted surface background (#edf4fc)
/// - Sans-serif typography
/// - Vibrant sky blue accents (#4d99db) for interactive buttons, status badges, and structural highlights
/// - Clean card containers and analytical metric boxes
/// - Prominent action button to export caliber volume alone
class ModernAnalyticsOverviewCard extends StatelessWidget {
  final int totalRounds;
  final int totalInspections;
  final int passCount;
  final int rejectCount;
  final int retestCount;
  final double yieldRate;
  final int activeCalibersCount;
  final String topCaliber;
  final int topCaliberRounds;
  final String currentModule;
  final VoidCallback onExportCaliberVolume;
  final VoidCallback? onQuickPrint;

  const ModernAnalyticsOverviewCard({
    Key? key,
    required this.totalRounds,
    required this.totalInspections,
    required this.passCount,
    required this.rejectCount,
    required this.retestCount,
    required this.yieldRate,
    required this.activeCalibersCount,
    required this.topCaliber,
    required this.topCaliberRounds,
    required this.currentModule,
    required this.onExportCaliberVolume,
    this.onQuickPrint,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4FC), // Soft icy-blue surface background
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFCBE2F8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141E3A8A),
            blurRadius: 18.0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Action Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFD6E8FB), width: 1.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Structural highlight badge
                      Container(
                        width: 4.0,
                        height: 38.0,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4D99DB), // Vibrant sky blue structural highlight
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Ballistic Analytics & Fleet Volume',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'sans-serif',
                                    color: Color(0xFF0C2A4D),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                // Sky blue status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4D99DB).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: const Color(0xFF4D99DB), width: 1.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6.0,
                                        height: 6.0,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4D99DB),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5.0),
                                      Text(
                                        currentModule.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'sans-serif',
                                          color: Color(0xFF1E6091),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3.0),
                            const Text(
                              'Intelligent quality evaluation throughput and caliber distribution metrics',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontFamily: 'sans-serif',
                                color: Color(0xFF47617D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                // Prominent Action Button & Interactive Controls
                Wrap(
                  spacing: 10.0,
                  runSpacing: 8.0,
                  children: [
                    if (onQuickPrint != null)
                      OutlinedButton.icon(
                        onPressed: onQuickPrint,
                        icon: const Icon(Icons.print_outlined, size: 15.0, color: Color(0xFF1E6091)),
                        label: const Text(
                          'Print Preview',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'sans-serif',
                            color: Color(0xFF1E6091),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4D99DB), width: 1.2),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: onExportCaliberVolume,
                      icon: const Icon(Icons.bar_chart_rounded, size: 16.0, color: Colors.white),
                      label: const Text(
                        'Export Caliber Volume Alone',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'sans-serif',
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4D99DB), // Vibrant sky blue accent
                        elevation: 2,
                        shadowColor: const Color(0x664D99DB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 13.0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Clean Analytical Metric Boxes Grid ──────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 900;
                final bool isTablet = constraints.maxWidth > 550 && !isDesktop;
                final double boxWidth = isDesktop
                    ? (constraints.maxWidth - 48.0) / 4.0
                    : isTablet
                        ? (constraints.maxWidth - 16.0) / 2.0
                        : constraints.maxWidth;

                return Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  children: [
                    _buildMetricBox(
                      title: 'TOTAL TEST VOLUME',
                      value: '$totalRounds',
                      unit: 'rounds',
                      subtitle: topCaliber.isNotEmpty ? 'Top: $topCaliber' : 'All monitored calibers',
                      badgeText: topCaliberRounds > 0 ? '$topCaliberRounds in lead' : 'Active',
                      icon: Icons.layers_rounded,
                      width: boxWidth,
                    ),
                    _buildMetricBox(
                      title: 'QUALITY CONFORMANCE',
                      value: '${yieldRate.toStringAsFixed(1)}%',
                      unit: 'yield',
                      subtitle: '$passCount Approved • $rejectCount Rejected',
                      badgeText: yieldRate >= 95.0 ? 'Optimal' : (yieldRate >= 80.0 ? 'Acceptable' : 'Attention'),
                      badgeColor: yieldRate >= 95.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      icon: Icons.verified_outlined,
                      width: boxWidth,
                    ),
                    _buildMetricBox(
                      title: 'INSPECTIONS LOGGED',
                      value: '$totalInspections',
                      unit: 'tests',
                      subtitle: totalInspections > 0
                          ? 'Avg ${(totalRounds / totalInspections).toStringAsFixed(0)} rds / inspection'
                          : 'No tests recorded yet',
                      badgeText: '$retestCount Retests',
                      icon: Icons.speed_rounded,
                      width: boxWidth,
                    ),
                    _buildMetricBox(
                      title: 'ACTIVE CALIBERS',
                      value: '$activeCalibersCount',
                      unit: 'calibers',
                      subtitle: 'Specifications currently tested',
                      badgeText: 'Surveillance Active',
                      icon: Icons.track_changes_rounded,
                      width: boxWidth,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required String badgeText,
    Color? badgeColor,
    required IconData icon,
    required double width,
  }) {
    final effectiveBadgeColor = badgeColor ?? const Color(0xFF4D99DB);
    return Container(
      width: width,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFDCEAF7), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0C2A4D),
            blurRadius: 8.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'sans-serif',
                  color: Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FC),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Icon(icon, size: 15.0, color: const Color(0xFF4D99DB)),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'sans-serif',
                  color: Color(0xFF0C2A4D),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'sans-serif',
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.0,
                    fontFamily: 'sans-serif',
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: effectiveBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: effectiveBadgeColor.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'sans-serif',
                    color: effectiveBadgeColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
