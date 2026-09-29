import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/report_helper.dart';

class WitnessStorageTab extends StatefulWidget {
  final String loggedInUser;
  final String userRole; // 'admin', 'technician', 'operator', etc.

  const WitnessStorageTab({
    Key? key,
    required this.loggedInUser,
    required this.userRole,
  }) : super(key: key);

  @override
  State<WitnessStorageTab> createState() => _WitnessStorageTabState();
}

class _WitnessStorageTabState extends State<WitnessStorageTab> {
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _lots = [];
  List<Map<String, dynamic>> _consumptions = [];

  String _searchQuery = '';
  String _selectedCaliberFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _sortBy = 'Date Desc';

  static const List<String> _standardCalibers = [
    '9mm',
    '5.56x45mm',
    '7.62x39mm',
    '7.62x51mm',
    '12.7x99mm (.50 BMG)',
  ];

  static const List<String> _standardPurposes = [
    'Surveillance Testing',
    'Customer Demonstration & Acceptance',
    'Lot Re-verification Test',
    'EPVAT Velocity & Pressure Verification',
    'Accuracy Verification',
    'Function & Endurance Check',
    'Residual Stress Re-evaluation',
    'Primer Sensitivity Testing',
    'Waterproof Re-test',
    'Extraction Force Re-test',
    'Internal Quality Audit',
    'Other / Custom',
  ];

  bool get _isTechnicianOrAdmin =>
      widget.userRole.toLowerCase() == 'technician' ||
      widget.userRole.toLowerCase() == 'admin' ||
      widget.userRole.toLowerCase() == 'supervisor' ||
      widget.userRole.toLowerCase() == 'manager';

  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load local storage
      final localLots = await _storageService.loadWitnessStorageLots();
      final localConsumptions = await _storageService.loadWitnessStorageConsumptions();

      if (mounted) {
        setState(() {
          _lots = localLots;
          _consumptions = localConsumptions;
          _recalculateBalances();
        });
      }

      // 2. Fetch Supabase cloud in background
      final cloudLots = await SupabaseService.fetchWitnessLotsFromCloud();
      final cloudConsumptions = await SupabaseService.fetchWitnessConsumptionsFromCloud();

      if (mounted) {
        if (cloudLots != null && cloudLots.isNotEmpty) {
          _lots = _mergeLots(localLots, cloudLots);
          await _storageService.saveWitnessStorageLots(_lots);
        }
        if (cloudConsumptions != null && cloudConsumptions.isNotEmpty) {
          _consumptions = _mergeConsumptions(localConsumptions, cloudConsumptions);
          await _storageService.saveWitnessStorageConsumptions(_consumptions);
        }
        _recalculateBalances();
      }
    } catch (e) {
      debugPrint('Error loading witness storage data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _mergeLots(
      List<Map<String, dynamic>> local, List<Map<String, dynamic>> cloud) {
    final Map<String, Map<String, dynamic>> map = {};
    for (final l in local) {
      final key = l['id']?.toString() ?? l['lotNo']?.toString() ?? '';
      if (key.isNotEmpty) map[key] = Map<String, dynamic>.from(l);
    }
    for (final c in cloud) {
      final key = c['id']?.toString() ?? c['lotNo']?.toString() ?? '';
      if (key.isNotEmpty) {
        // Cloud takes precedence or updates existing
        map[key] = Map<String, dynamic>.from(c);
      }
    }
    return map.values.toList();
  }

  List<Map<String, dynamic>> _mergeConsumptions(
      List<Map<String, dynamic>> local, List<Map<String, dynamic>> cloud) {
    final Map<String, Map<String, dynamic>> map = {};
    for (final l in local) {
      final key = l['id']?.toString() ?? '';
      if (key.isNotEmpty) map[key] = Map<String, dynamic>.from(l);
    }
    for (final c in cloud) {
      final key = c['id']?.toString() ?? '';
      if (key.isNotEmpty) map[key] = Map<String, dynamic>.from(c);
    }
    return map.values.toList();
  }

  void _recalculateBalances() {
    // Map consumed sums per lotId or lotNo
    final Map<String, int> consumedSums = {};
    for (final c in _consumptions) {
      final lotId = c['lotId']?.toString() ?? '';
      final lotNo = c['lotNo']?.toString() ?? '';
      final qty = (c['quantity'] is num) ? (c['quantity'] as num).toInt() : int.tryParse(c['quantity']?.toString() ?? '0') ?? 0;

      if (lotId.isNotEmpty) {
        consumedSums[lotId] = (consumedSums[lotId] ?? 0) + qty;
      }
      if (lotNo.isNotEmpty) {
        consumedSums[lotNo] = (consumedSums[lotNo] ?? 0) + qty;
      }
    }

    for (final lot in _lots) {
      final id = lot['id']?.toString() ?? '';
      final lotNo = lot['lotNo']?.toString() ?? '';
      final initial = (lot['initialQty'] is num) ? (lot['initialQty'] as num).toInt() : int.tryParse(lot['initialQty']?.toString() ?? '0') ?? 0;

      final consumed = consumedSums[id] ?? consumedSums[lotNo] ?? (lot['consumedQty'] is num ? (lot['consumedQty'] as num).toInt() : 0);
      final remaining = (initial - consumed) < 0 ? 0 : (initial - consumed);

      lot['consumedQty'] = consumed;
      lot['remainingQty'] = remaining;

      if (remaining == 0) {
        lot['status'] = 'DEPLETED';
      } else if (remaining <= (initial * 0.2).round() || remaining <= 50) {
        lot['status'] = 'LOW STOCK';
      } else {
        lot['status'] = 'ACTIVE';
      }
    }
  }

  Future<void> _saveData() async {
    _recalculateBalances();
    await _storageService.saveWitnessStorageLots(_lots);
    await _storageService.saveWitnessStorageConsumptions(_consumptions);
    // Cloud sync non-blocking
    SupabaseService.saveWitnessLotsToCloud(_lots);
    SupabaseService.saveWitnessConsumptionsToCloud(_consumptions);
    if (mounted) setState(() {});
  }

  // --- Filtering & Sorting ---
  List<Map<String, dynamic>> get _filteredLots {
    return _lots.where((lot) {
      final lotNo = (lot['lotNo'] ?? '').toString().toLowerCase();
      final caliber = (lot['caliber'] ?? '').toString().toLowerCase();
      final powderLot = (lot['powderLot'] ?? '').toString().toLowerCase();
      final primerLot = (lot['primerLot'] ?? '').toString().toLowerCase();
      final location = (lot['storageLocation'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();

      final matchesQuery = query.isEmpty ||
          lotNo.contains(query) ||
          caliber.contains(query) ||
          powderLot.contains(query) ||
          primerLot.contains(query) ||
          location.contains(query);

      final matchesCaliber = _selectedCaliberFilter == 'All' ||
          lot['caliber']?.toString() == _selectedCaliberFilter;

      final status = (lot['status'] ?? 'ACTIVE').toString().toUpperCase();
      bool matchesStatus = true;
      if (_selectedStatusFilter == 'Active') {
        matchesStatus = status == 'ACTIVE';
      } else if (_selectedStatusFilter == 'Low Stock') {
        matchesStatus = status == 'LOW STOCK';
      } else if (_selectedStatusFilter == 'Depleted') {
        matchesStatus = status == 'DEPLETED';
      }

      return matchesQuery && matchesCaliber && matchesStatus;
    }).toList()
      ..sort((a, b) {
        if (_sortBy == 'Date Desc') {
          return (b['registeredAt'] ?? '').toString().compareTo((a['registeredAt'] ?? '').toString());
        } else if (_sortBy == 'Date Asc') {
          return (a['registeredAt'] ?? '').toString().compareTo((b['registeredAt'] ?? '').toString());
        } else if (_sortBy == 'Remaining Desc') {
          final ra = (a['remainingQty'] ?? 0) as num;
          final rb = (b['remainingQty'] ?? 0) as num;
          return rb.compareTo(ra);
        } else if (_sortBy == 'Remaining Asc') {
          final ra = (a['remainingQty'] ?? 0) as num;
          final rb = (b['remainingQty'] ?? 0) as num;
          return ra.compareTo(rb);
        } else if (_sortBy == 'Lot No') {
          return (a['lotNo'] ?? '').toString().compareTo((b['lotNo'] ?? '').toString());
        }
        return 0;
      });
  }

  // Statistics
  int get _totalLots => _lots.length;
  int get _totalInitialRounds => _lots.fold(0, (sum, lot) => sum + ((lot['initialQty'] ?? 0) as num).toInt());
  int get _totalConsumedRounds => _lots.fold(0, (sum, lot) => sum + ((lot['consumedQty'] ?? 0) as num).toInt());
  int get _totalRemainingRounds => _lots.fold(0, (sum, lot) => sum + ((lot['remainingQty'] ?? 0) as num).toInt());
  int get _activeCalibersCount {
    final set = <String>{};
    for (final l in _lots) {
      if ((l['caliber'] ?? '').toString().isNotEmpty) {
        set.add(l['caliber'].toString());
      }
    }
    return set.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFC4D6EC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
        ),
      );
    }

    final lowStockLots = _lots.where((l) => l['status'] == 'LOW STOCK').length;

    return Scaffold(
      backgroundColor: const Color(0xFFC4D6EC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header & Action Bar ──
            _buildHeader(),
            const SizedBox(height: 16.0),

            // ── Low Stock Alert Banner (if any) ──
            if (lowStockLots > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24.0),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        'Vault Notice: $lowStockLots witness lot(s) are at or below 20% remaining balance. Plan replenishment or archive depleted lots.',
                        style: const TextStyle(color: Color(0xFFB45309), fontSize: 13.0, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedStatusFilter = 'Low Stock';
                        });
                      },
                      child: const Text('View Low Balance', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // ── Metric Cards ──
            _buildMetricsSection(),
            const SizedBox(height: 20.0),

            // ── Search & Filter Controls ──
            _buildFilterBar(),
            const SizedBox(height: 16.0),

            // ── Lots Data Table ──
            _buildLotsTable(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header Widget
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 14, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFECFEFF),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: const Color(0xFFA5F3FC)),
            ),
            child: const Icon(Icons.archive_outlined, color: Color(0xFF0891B2), size: 28.0),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Witness Storage Vault & Inventory Management',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4.0),
                Text(
                  'Register witness lots with powder & primer specifications. Log consumed rounds with reasons and monitor real-time balance countdown.',
                  style: TextStyle(fontSize: 12.0, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 8.0,
            children: [
              // Log Consumption Button (All users)
              ElevatedButton.icon(
                onPressed: () => _openLogConsumptionDialog(),
                icon: const Icon(Icons.remove_circle_outline, size: 16.0),
                label: const Text('Log Consumption', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),

              // Register Lot Button (Technicians / Supervisors / Admins)
              if (_isTechnicianOrAdmin)
                ElevatedButton.icon(
                  onPressed: () => _openRegisterLotDialog(),
                  icon: const Icon(Icons.add_box_outlined, size: 16.0),
                  label: const Text('Register Witness Lot', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),

              // Audit Trail & History
              OutlinedButton.icon(
                onPressed: () => _openConsumptionHistoryDialog(),
                icon: const Icon(Icons.history_rounded, size: 16.0, color: Color(0xFF475569)),
                label: const Text('Audit Ledger', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),

              // Export Vault Report
              OutlinedButton.icon(
                onPressed: _exportVaultReport,
                icon: const Icon(Icons.print_outlined, size: 16.0, color: Color(0xFF475569)),
                label: const Text('Export Vault Report', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Metrics Section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMetricsSection() {
    final nf = NumberFormat('#,###');
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 900;

        if (isCompact) {
          return Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: [
              _buildMetricCard('Total Lots', _totalLots.toString(), Icons.layers_outlined, const Color(0xFF0284C7)),
              _buildMetricCard('Vault Balance', '${nf.format(_totalRemainingRounds)} rds', Icons.shield_outlined, const Color(0xFF10B981)),
              _buildMetricCard('Consumed Rounds', '${nf.format(_totalConsumedRounds)} rds', Icons.local_fire_department_outlined, const Color(0xFFF59E0B)),
              _buildMetricCard('Initial Vault', '${nf.format(_totalInitialRounds)} rds', Icons.warehouse_outlined, const Color(0xFF64748B)),
              _buildMetricCard('Active Calibers', _activeCalibersCount.toString(), Icons.military_tech_outlined, const Color(0xFF8B5CF6)),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildMetricCard('Total Lots', _totalLots.toString(), Icons.layers_outlined, const Color(0xFF0284C7))),
            const SizedBox(width: 12.0),
            Expanded(child: _buildMetricCard('Vault Balance', '${nf.format(_totalRemainingRounds)} rds', Icons.shield_outlined, const Color(0xFF10B981))),
            const SizedBox(width: 12.0),
            Expanded(child: _buildMetricCard('Consumed Rounds', '${nf.format(_totalConsumedRounds)} rds', Icons.local_fire_department_outlined, const Color(0xFFF59E0B))),
            const SizedBox(width: 12.0),
            Expanded(child: _buildMetricCard('Initial Vault', '${nf.format(_totalInitialRounds)} rds', Icons.warehouse_outlined, const Color(0xFF64748B))),
            const SizedBox(width: 12.0),
            Expanded(child: _buildMetricCard('Active Calibers', _activeCalibersCount.toString(), Icons.military_tech_outlined, const Color(0xFF8B5CF6))),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10, offset: Offset(0, 2)),
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
            child: Icon(icon, color: color, size: 22.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3.0),
                Text(
                  value,
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter Bar Widget
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final calibers = <String>['All', ..._standardCalibers];
    for (final l in _lots) {
      final cal = (l['caliber'] ?? '').toString();
      if (cal.isNotEmpty && !calibers.contains(cal)) {
        calibers.add(cal);
      }
    }

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
      ),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 10.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search input
          SizedBox(
            width: 280.0,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search Lot No, Powder, Primer, Location...',
                hintStyle: const TextStyle(fontSize: 12.0, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18.0, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Caliber dropdown filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCaliberFilter,
                icon: const Icon(Icons.filter_list, size: 16.0, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                items: calibers.map((c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(c == 'All' ? 'All Calibers' : c),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCaliberFilter = val);
                },
              ),
            ),
          ),

          // Status filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatusFilter,
                icon: const Icon(Icons.shield_outlined, size: 16.0, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'Active', child: Text('Active Only')),
                  DropdownMenuItem(value: 'Low Stock', child: Text('Low Balance (< 20%)')),
                  DropdownMenuItem(value: 'Depleted', child: Text('Depleted (0 rounds)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatusFilter = val);
                },
              ),
            ),
          ),

          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.sort, size: 16.0, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'Date Desc', child: Text('Sort: Newest First')),
                  DropdownMenuItem(value: 'Date Asc', child: Text('Sort: Oldest First')),
                  DropdownMenuItem(value: 'Remaining Desc', child: Text('Sort: Highest Balance')),
                  DropdownMenuItem(value: 'Remaining Asc', child: Text('Sort: Lowest Balance')),
                  DropdownMenuItem(value: 'Lot No', child: Text('Sort: Lot Number')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ),
          ),

          // Quick Refresh
          IconButton(
            onPressed: _loadData,
            tooltip: 'Sync & Refresh',
            icon: const Icon(Icons.refresh, color: Color(0xFF0284C7)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lots Data Table
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLotsTable() {
    final filtered = _filteredLots;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFFB8CEE5)),
        ),
        child: Column(
          children: [
            const Icon(Icons.archive_outlined, size: 54.0, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12.0),
            const Text(
              'No Witness Storage Lots Found',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6.0),
            Text(
              _lots.isEmpty
                  ? 'Click "Register Witness Lot" to register your first caliber and lot in the vault.'
                  : 'Try changing your search query or filters.',
              style: const TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
            ),
            if (_lots.isEmpty && _isTechnicianOrAdmin) ...[
              const SizedBox(height: 16.0),
              ElevatedButton.icon(
                onPressed: () => _openRegisterLotDialog(),
                icon: const Icon(Icons.add, size: 16.0),
                label: const Text('Register First Lot'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              ),
            ],
          ],
        ),
      );
    }

    final nf = NumberFormat('#,###');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E3A8A), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
            columnSpacing: 24.0,
            horizontalMargin: 16.0,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 12.0),
            dataTextStyle: const TextStyle(color: Color(0xFF334155), fontSize: 13.0),
            columns: const [
              DataColumn(label: Text('Caliber')),
              DataColumn(label: Text('Lot Number')),
              DataColumn(label: Text('Vault Countdown & Balance')),
              DataColumn(label: Text('Consumed / Initial')),
              DataColumn(label: Text('Powder Details')),
              DataColumn(label: Text('Primer Details')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: filtered.map((lot) {
              final initial = ((lot['initialQty'] ?? 0) as num).toInt();
              final consumed = ((lot['consumedQty'] ?? 0) as num).toInt();
              final remaining = ((lot['remainingQty'] ?? 0) as num).toInt();
              final double ratio = initial > 0 ? (remaining / initial).clamp(0.0, 1.0) : 0.0;

              final status = (lot['status'] ?? 'ACTIVE').toString().toUpperCase();
              final Color statusColor = status == 'DEPLETED'
                  ? const Color(0xFFEF4444)
                  : (status == 'LOW STOCK' ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

              return DataRow(
                cells: [
                  // Caliber badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF4FC),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFFB8CEE5)),
                      ),
                      child: Text(
                        lot['caliber']?.toString() ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0369A1), fontSize: 12.0),
                      ),
                    ),
                  ),

                  // Lot Number
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lot['lotNo']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 4.0),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14.0, color: Color(0xFF94A3B8)),
                          tooltip: 'Copy Lot No',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: lot['lotNo']?.toString() ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Copied Lot No: ${lot['lotNo']}')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Countdown & Balance with Progress Bar
                  DataCell(
                    Container(
                      width: 170.0,
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${nf.format(remaining)} rds',
                                style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13.0),
                              ),
                              Text(
                                '${(ratio * 100).toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 11.0, color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6.0,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Consumed / Initial
                  DataCell(
                    Text('${nf.format(consumed)} / ${nf.format(initial)}'),
                  ),

                  // Powder Details
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lot: ${lot['powderLot']?.toString().isNotEmpty == true ? lot['powderLot'] : 'N/A'}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
                        ),
                        Text(
                          '${lot['powderType'] ?? ''} ${lot['chargeWeight']?.toString().isNotEmpty == true ? '(${lot['chargeWeight']})' : ''}'.trim(),
                          style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  // Primer Details
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lot: ${lot['primerLot']?.toString().isNotEmpty == true ? lot['primerLot'] : 'N/A'}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
                        ),
                        Text(
                          '${lot['primerType'] ?? ''} ${lot['primerSupplier']?.toString().isNotEmpty == true ? '(${lot['primerSupplier']})' : ''}'.trim(),
                          style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  // Location
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_outlined, size: 14.0, color: Color(0xFF64748B)),
                        const SizedBox(width: 4.0),
                        Text(lot['storageLocation']?.toString().isNotEmpty == true ? lot['storageLocation'] : 'Vault'),
                      ],
                    ),
                  ),

                  // Status Badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11.0),
                      ),
                    ),
                  ),

                  // Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Fast Consume Button
                        IconButton(
                          icon: const Icon(Icons.local_fire_department_rounded, color: Color(0xFF0284C7), size: 20.0),
                          tooltip: 'Log Consumption',
                          onPressed: remaining > 0 ? () => _openLogConsumptionDialog(preselectedLot: lot) : null,
                        ),
                        // Lot Audit History
                        IconButton(
                          icon: const Icon(Icons.history, color: Color(0xFF475569), size: 20.0),
                          tooltip: 'Lot Consumption Ledger',
                          onPressed: () => _openConsumptionHistoryDialog(forLot: lot),
                        ),
                        // Edit Lot (Technicians / Admin)
                        if (_isTechnicianOrAdmin)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0D9488), size: 18.0),
                            tooltip: 'Edit Lot Details',
                            onPressed: () => _openRegisterLotDialog(editingLot: lot),
                          ),
                        // Delete Lot (Admin only)
                        if (_isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18.0),
                            tooltip: 'Delete Witness Lot',
                            onPressed: () => _confirmDeleteLot(lot),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dialog: Register / Edit Witness Lot (Technician / Admin)
  // ─────────────────────────────────────────────────────────────────────────
  void _openRegisterLotDialog({Map<String, dynamic>? editingLot}) {
    final bool isEdit = editingLot != null;
    final formKey = GlobalKey<FormState>();

    String selectedCaliber = editingLot?['caliber']?.toString() ?? _standardCalibers.first;
    bool isCustomCaliber = !_standardCalibers.contains(selectedCaliber);
    final customCaliberCtrl = TextEditingController(text: isCustomCaliber ? selectedCaliber : '');
    final lotNoCtrl = TextEditingController(text: editingLot?['lotNo']?.toString() ?? '');
    final initialQtyCtrl = TextEditingController(text: editingLot?['initialQty']?.toString() ?? '');
    final powderLotCtrl = TextEditingController(text: editingLot?['powderLot']?.toString() ?? '');
    final powderSupplierCtrl = TextEditingController(text: editingLot?['powderSupplier']?.toString() ?? '');
    final powderTypeCtrl = TextEditingController(text: editingLot?['powderType']?.toString() ?? '');
    final chargeWeightCtrl = TextEditingController(text: editingLot?['chargeWeight']?.toString() ?? '');
    final primerLotCtrl = TextEditingController(text: editingLot?['primerLot']?.toString() ?? '');
    final primerSupplierCtrl = TextEditingController(text: editingLot?['primerSupplier']?.toString() ?? '');
    final primerTypeCtrl = TextEditingController(text: editingLot?['primerType']?.toString() ?? '');
    final storageLocationCtrl = TextEditingController(text: editingLot?['storageLocation']?.toString() ?? 'Vault 1');
    final notesCtrl = TextEditingController(text: editingLot?['notes']?.toString() ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D9488),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.archive_outlined, color: Colors.white, size: 24.0),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Witness Storage Lot' : 'Register New Witness Storage Lot',
                        style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 650.0,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8.0),
                        // ── Basic Information ──
                        const Text(
                          '1. General & Caliber Specifications',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.0),
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            // Caliber selector
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: isCustomCaliber ? 'Custom' : selectedCaliber,
                                decoration: InputDecoration(
                                  labelText: 'Caliber *',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                                items: [
                                  ..._standardCalibers.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                  const DropdownMenuItem(value: 'Custom', child: Text('Custom Caliber...')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      if (val == 'Custom') {
                                        isCustomCaliber = true;
                                      } else {
                                        isCustomCaliber = false;
                                        selectedCaliber = val;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            if (isCustomCaliber) ...[
                              const SizedBox(width: 10.0),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: customCaliberCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Custom Caliber *',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            // Lot Number
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: lotNoCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Lot Number *',
                                  hintText: 'e.g. LOT-2026-001',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Lot Number is required';
                                  final norm = v.trim().toUpperCase();
                                  final duplicate = _lots.any((l) =>
                                      l['lotNo']?.toString().toUpperCase() == norm &&
                                      (!isEdit || l['id'] != editingLot['id']));
                                  if (duplicate) return 'Lot Number already exists!';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            // Initial Quantity
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: initialQtyCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'Initial Quantity (rounds) *',
                                  hintText: 'e.g. 1000',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final n = int.tryParse(v.trim());
                                  if (n == null || n <= 0) return 'Must be > 0';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20.0),

                        // ── Powder Details ──
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '2. Powder / Propellant Details',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.0),
                              ),
                              const SizedBox(height: 10.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: powderLotCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Powder Lot No',
                                        hintText: 'e.g. WC844-L02',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10.0),
                                  Expanded(
                                    child: TextFormField(
                                      controller: powderTypeCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Powder Type / Code',
                                        hintText: 'e.g. Ball Powder WC844',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: powderSupplierCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Powder Supplier / Maker',
                                        hintText: 'e.g. General Dynamics',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10.0),
                                  Expanded(
                                    child: TextFormField(
                                      controller: chargeWeightCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Charge Weight',
                                        hintText: 'e.g. 26.2 gr or 1.70 g',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // ── Primer Details ──
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '3. Primer Details',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.0),
                              ),
                              const SizedBox(height: 10.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: primerLotCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Primer Lot No',
                                        hintText: 'e.g. PR-2026-91',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10.0),
                                  Expanded(
                                    child: TextFormField(
                                      controller: primerTypeCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Primer Type',
                                        hintText: 'e.g. Boxer No. 41',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10.0),
                              TextFormField(
                                controller: primerSupplierCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Primer Supplier / Maker',
                                  hintText: 'e.g. CCI / Federal / Murom',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // ── Storage Location & Remarks ──
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: storageLocationCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Storage Location',
                                  hintText: 'e.g. Vault 1 - Bay B / Shelf 2',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes / Remarks',
                            hintText: 'e.g. Reserved for annual surveillance testing',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final effectiveCaliber = isCustomCaliber
                        ? customCaliberCtrl.text.trim()
                        : selectedCaliber;
                    final lotNo = lotNoCtrl.text.trim();
                    final initialQty = int.parse(initialQtyCtrl.text.trim());

                    if (isEdit) {
                      editingLot['caliber'] = effectiveCaliber;
                      editingLot['lotNo'] = lotNo;
                      editingLot['initialQty'] = initialQty;
                      editingLot['powderLot'] = powderLotCtrl.text.trim();
                      editingLot['powderSupplier'] = powderSupplierCtrl.text.trim();
                      editingLot['powderType'] = powderTypeCtrl.text.trim();
                      editingLot['chargeWeight'] = chargeWeightCtrl.text.trim();
                      editingLot['primerLot'] = primerLotCtrl.text.trim();
                      editingLot['primerSupplier'] = primerSupplierCtrl.text.trim();
                      editingLot['primerType'] = primerTypeCtrl.text.trim();
                      editingLot['storageLocation'] = storageLocationCtrl.text.trim();
                      editingLot['notes'] = notesCtrl.text.trim();
                    } else {
                      final newLot = <String, dynamic>{
                        'id': 'WL_${DateTime.now().millisecondsSinceEpoch}',
                        'lotNo': lotNo,
                        'caliber': effectiveCaliber,
                        'initialQty': initialQty,
                        'consumedQty': 0,
                        'remainingQty': initialQty,
                        'powderLot': powderLotCtrl.text.trim(),
                        'powderSupplier': powderSupplierCtrl.text.trim(),
                        'powderType': powderTypeCtrl.text.trim(),
                        'chargeWeight': chargeWeightCtrl.text.trim(),
                        'primerLot': primerLotCtrl.text.trim(),
                        'primerSupplier': primerSupplierCtrl.text.trim(),
                        'primerType': primerTypeCtrl.text.trim(),
                        'storageLocation': storageLocationCtrl.text.trim(),
                        'registeredBy': widget.loggedInUser.isNotEmpty ? widget.loggedInUser : 'Technician',
                        'registeredAt': DateTime.now().toIso8601String(),
                        'notes': notesCtrl.text.trim(),
                        'status': 'ACTIVE',
                      };
                      _lots.insert(0, newLot);
                    }

                    await _saveData();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Witness lot updated successfully!' : 'Witness lot registered in vault!'),
                        backgroundColor: const Color(0xFF0D9488),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check, size: 16.0),
                  label: Text(isEdit ? 'Save Changes' : 'Register Lot', style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Dialog: Log Consumption (All users, automated countdown)
  // ─────────────────────────────────────────────────────────────────────────
  void _openLogConsumptionDialog({Map<String, dynamic>? preselectedLot}) {
    if (_lots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No witness lots available in the vault to consume.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    Map<String, dynamic>? selectedLot = preselectedLot ?? _lots.firstWhere(
      (l) => ((l['remainingQty'] ?? 0) as num) > 0,
      orElse: () => _lots.first,
    );

    final qtyCtrl = TextEditingController();
    String selectedPurpose = _standardPurposes.first;
    bool isCustomPurpose = false;
    final customPurposeCtrl = TextEditingController();
    final orderRefCtrl = TextEditingController();
    final operatorCtrl = TextEditingController(text: widget.loggedInUser.isNotEmpty ? widget.loggedInUser : 'Operator');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final available = ((selectedLot?['remainingQty'] ?? 0) as num).toInt();

            final enteredQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
            final remainingAfter = available - enteredQty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                decoration: const BoxDecoration(
                  color: Color(0xFF0284C7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 24.0),
                    const SizedBox(width: 12.0),
                    const Expanded(
                      child: Text(
                        'Log Witness Storage Consumption',
                        style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 580.0,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8.0),
                        // Lot Selector Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedLot?['id']?.toString(),
                          decoration: InputDecoration(
                            labelText: 'Select Witness Lot *',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          items: _lots.map((l) {
                            final rem = (l['remainingQty'] ?? 0) as num;
                            return DropdownMenuItem<String>(
                              value: l['id']?.toString(),
                              child: Text('${l['caliber']} - Lot: ${l['lotNo']} (Available: $rem rds)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedLot = _lots.firstWhere((l) => l['id']?.toString() == val);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12.0),

                        // Real-time Countdown Banner
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF4FC),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFFB8CEE5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.speed, color: Color(0xFF0284C7), size: 22.0),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vault Countdown Preview:',
                                      style: TextStyle(fontSize: 11.0, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Row(
                                      children: [
                                        Text('Current Balance: $available rds', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                                        const SizedBox(width: 8.0),
                                        const Icon(Icons.arrow_forward, size: 14.0, color: Color(0xFF64748B)),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          'Remaining: ${remainingAfter >= 0 ? remainingAfter : 0} rds',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.0,
                                            color: remainingAfter < 0 ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14.0),

                        // Quantity Consumed
                        TextFormField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Rounds Consumed *',
                            hintText: 'e.g. 50',
                            suffixText: 'rounds',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final n = int.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Must be greater than 0';
                            if (n > available) return 'Cannot consume more than available balance ($available rounds)!';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12.0),

                        // Purpose / Reason
                        DropdownButtonFormField<String>(
                          value: selectedPurpose,
                          decoration: InputDecoration(
                            labelText: 'Purpose / Reason of Consumption *',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          items: _standardPurposes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedPurpose = val;
                                isCustomPurpose = (val == 'Other / Custom');
                              });
                            }
                          },
                        ),
                        if (isCustomPurpose) ...[
                          const SizedBox(height: 10.0),
                          TextFormField(
                            controller: customPurposeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Specify Custom Purpose *',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ],
                        const SizedBox(height: 12.0),

                        // Order Reference / Work Order
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: orderRefCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Test Order / Ref No',
                                  hintText: 'e.g. REF-1002 / WO-8841',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: TextFormField(
                                controller: operatorCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Logged By *',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),

                        // Notes
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes / Test Observations',
                            hintText: 'e.g. Rounds fired during high-velocity waterproof retest',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedLot == null) return;

                    final qty = int.parse(qtyCtrl.text.trim());
                    final finalPurpose = isCustomPurpose ? customPurposeCtrl.text.trim() : selectedPurpose;
                    final lotId = selectedLot!['id']?.toString() ?? '';
                    final lotNo = selectedLot!['lotNo']?.toString() ?? '';
                    final caliber = selectedLot!['caliber']?.toString() ?? '';

                    final currentRem = ((selectedLot!['remainingQty'] ?? 0) as num).toInt();
                    final remainingAfterTx = currentRem - qty;

                    final consumptionRecord = <String, dynamic>{
                      'id': 'WC_${DateTime.now().millisecondsSinceEpoch}',
                      'lotId': lotId,
                      'lotNo': lotNo,
                      'caliber': caliber,
                      'quantity': qty,
                      'purpose': finalPurpose,
                      'orderRef': orderRefCtrl.text.trim(),
                      'consumedBy': operatorCtrl.text.trim(),
                      'consumedAt': DateTime.now().toIso8601String(),
                      'remainingAfter': remainingAfterTx,
                      'notes': notesCtrl.text.trim(),
                    };

                    _consumptions.insert(0, consumptionRecord);
                    await _saveData();

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully logged $qty rounds consumed from Lot $lotNo!'),
                        backgroundColor: const Color(0xFF0284C7),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check, size: 16.0),
                  label: const Text('Confirm Consumption', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Dialog: Consumption History & Audit Trail Modal
  // ─────────────────────────────────────────────────────────────────────────
  void _openConsumptionHistoryDialog({Map<String, dynamic>? forLot}) {
    final list = forLot != null
        ? _consumptions.where((c) => c['lotId'] == forLot['id'] || c['lotNo'] == forLot['lotNo']).toList()
        : _consumptions;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: Colors.white, size: 24.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    forLot != null
                        ? 'Consumption Audit Ledger: ${forLot['caliber']} - Lot ${forLot['lotNo']}'
                        : 'Complete Witness Storage Consumption Audit Ledger',
                    style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 800.0,
            height: 480.0,
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.inventory_2_outlined, size: 48.0, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8.0),
                        Text(
                          'No consumption transactions recorded yet.',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                      columnSpacing: 18.0,
                      columns: const [
                        DataColumn(label: Text('Date & Time')),
                        DataColumn(label: Text('Caliber')),
                        DataColumn(label: Text('Lot No')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Purpose / Reason')),
                        DataColumn(label: Text('Ref / Order')),
                        DataColumn(label: Text('Logged By')),
                        DataColumn(label: Text('Balance After')),
                      ],
                      rows: list.map((c) {
                        final dt = DateTime.tryParse(c['consumedAt']?.toString() ?? '');
                        final dateStr = dt != null ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : (c['consumedAt'] ?? 'N/A');

                        return DataRow(
                          cells: [
                            DataCell(Text(dateStr, style: const TextStyle(fontSize: 12.0))),
                            DataCell(Text(c['caliber']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(c['lotNo']?.toString() ?? '')),
                            DataCell(Text(
                              '-${c['quantity']} rds',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                            )),
                            DataCell(Text(c['purpose']?.toString() ?? '')),
                            DataCell(Text(c['orderRef']?.toString() ?? '-')),
                            DataCell(Text(c['consumedBy']?.toString() ?? '')),
                            DataCell(Text(
                              '${c['remainingAfter'] ?? '-'} rds',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          actions: [
            if (list.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _exportConsumptionsCsv(list),
                icon: const Icon(Icons.download, size: 16.0),
                label: const Text('Export Ledger CSV'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete Lot Confirmation (Admin)
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmDeleteLot(Map<String, dynamic> lot) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Witness Storage Lot?'),
          content: Text(
            'Are you sure you want to delete Lot "${lot['lotNo']}" (${lot['caliber']}) from the Witness Storage vault? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _lots.removeWhere((l) => l['id'] == lot['id']);
                });
                await _saveData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lot "${lot['lotNo']}" removed from vault.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Export Vault Report & Consumptions CSV
  // ─────────────────────────────────────────────────────────────────────────
  void _exportConsumptionsCsv(List<Map<String, dynamic>> list) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Caliber,Lot_No,Quantity_Consumed,Purpose,Order_Ref,Consumed_By,Remaining_After,Notes');
    for (final c in list) {
      buffer.writeln(
        '"${c['id']}","${c['consumedAt']}","${c['caliber']}","${c['lotNo']}","${c['quantity']}","${c['purpose']}","${c['orderRef']}","${c['consumedBy']}","${c['remainingAfter']}","${c['notes']}"',
      );
    }
    ReportHelper.instance.downloadCsv(
      content: buffer.toString(),
      filename: 'Witness_Storage_Consumption_Ledger_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
    );
  }

  void _exportVaultReport() {
    final nf = NumberFormat('#,###');
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.write('''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Witness Storage Vault Inventory Report</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; color: #1e293b; background: #fff; }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #0284c7; padding-bottom: 12px; margin-bottom: 20px; }
  .title { font-size: 22px; font-weight: bold; color: #0f172a; }
  .subtitle { font-size: 13px; color: #64748b; margin-top: 4px; }
  .meta { text-align: right; font-size: 12px; color: #475569; }
  .metrics-grid { display: flex; gap: 15px; margin-bottom: 20px; }
  .metric-card { flex: 1; padding: 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; }
  .metric-title { font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: bold; }
  .metric-value { font-size: 20px; font-weight: bold; color: #0284c7; margin-top: 4px; }
  table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 12px; }
  th, td { border: 1px solid #cbd5e1; padding: 8px 10px; text-align: left; }
  th { background-color: #f1f5f9; color: #0f172a; font-weight: bold; }
  tr:nth-child(even) { background-color: #f8fafc; }
  .badge { display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 11px; font-weight: bold; }
  .badge-active { background-color: #dcfce7; color: #15803d; }
  .badge-low { background-color: #fef3c7; color: #b45309; }
  .badge-depleted { background-color: #fee2e2; color: #b91c1c; }
  .footer { margin-top: 40px; display: flex; justify-content: space-between; font-size: 12px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
  .signature-box { width: 220px; text-align: center; border-top: 1px dashed #94a3b8; padding-top: 6px; }
</style>
</head>
<body>
  <div class="header">
    <div>
      <div class="title">OMPC BALLISTICS LABORATORY</div>
      <div class="subtitle">Witness Storage Vault & Inventory Status Report</div>
    </div>
    <div class="meta">
      <div><strong>Report Date:</strong> $nowStr</div>
      <div><strong>Generated By:</strong> ${widget.loggedInUser.isNotEmpty ? widget.loggedInUser : 'Operator'}</div>
      <div><strong>Status:</strong> OFFICIAL RECORD</div>
    </div>
  </div>

  <div class="metrics-grid">
    <div class="metric-card">
      <div class="metric-title">Total Witness Lots</div>
      <div class="metric-value">$_totalLots</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">Remaining Vault Rounds</div>
      <div class="metric-value">${nf.format(_totalRemainingRounds)} rds</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">Total Consumed Rounds</div>
      <div class="metric-value">${nf.format(_totalConsumedRounds)} rds</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">Initial Registered Vault</div>
      <div class="metric-value">${nf.format(_totalInitialRounds)} rds</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">Active Calibers</div>
      <div class="metric-value">$_activeCalibersCount</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Caliber</th>
        <th>Lot Number</th>
        <th>Initial Qty</th>
        <th>Consumed Qty</th>
        <th>Remaining Balance</th>
        <th>Powder Details</th>
        <th>Primer Details</th>
        <th>Location</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
''');

    for (final lot in _lots) {
      final initial = ((lot['initialQty'] ?? 0) as num).toInt();
      final consumed = ((lot['consumedQty'] ?? 0) as num).toInt();
      final remaining = ((lot['remainingQty'] ?? 0) as num).toInt();
      final status = (lot['status'] ?? 'ACTIVE').toString().toUpperCase();

      String badgeClass = 'badge-active';
      if (status == 'LOW STOCK') badgeClass = 'badge-low';
      if (status == 'DEPLETED') badgeClass = 'badge-depleted';

      final powderDetails = 'Lot: ${lot['powderLot'] ?? 'N/A'}, ${lot['powderType'] ?? ''} ${lot['chargeWeight'] ?? ''}'.trim();
      final primerDetails = 'Lot: ${lot['primerLot'] ?? 'N/A'}, ${lot['primerType'] ?? ''} ${lot['primerSupplier'] ?? ''}'.trim();

      buffer.write('''
      <tr>
        <td><strong>${lot['caliber']}</strong></td>
        <td>${lot['lotNo']}</td>
        <td>${nf.format(initial)}</td>
        <td>${nf.format(consumed)}</td>
        <td><strong>${nf.format(remaining)} rds</strong></td>
        <td>$powderDetails</td>
        <td>$primerDetails</td>
        <td>${lot['storageLocation'] ?? 'Vault'}</td>
        <td><span class="badge $badgeClass">$status</span></td>
      </tr>
''');
    }

    buffer.write('''
    </tbody>
  </table>

  <div class="footer">
    <div class="signature-box">
      <div>Ballistics Technician</div>
      <div style="margin-top: 30px; font-weight: bold;">Signature & Date</div>
    </div>
    <div class="signature-box">
      <div>Shift Supervisor</div>
      <div style="margin-top: 30px; font-weight: bold;">Signature & Date</div>
    </div>
    <div class="signature-box">
      <div>Quality Assurance Manager</div>
      <div style="margin-top: 30px; font-weight: bold;">Signature & Date</div>
    </div>
  </div>
</body>
</html>
''');

    ReportHelper.instance.printHtml(
      htmlContent: buffer.toString(),
      filename: 'Witness_Storage_Vault_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );
  }
}
