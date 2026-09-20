import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class ConsumablesTab extends StatefulWidget {
  final String loggedInUser;
  final String userRole; // 'admin' or 'operator'

  const ConsumablesTab({
    Key? key,
    required this.loggedInUser,
    required this.userRole,
  }) : super(key: key);

  @override
  State<ConsumablesTab> createState() => _ConsumablesTabState();
}

class _ConsumablesTabState extends State<ConsumablesTab> {
  final StorageService _storageService = StorageService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _stockFilter = 'All'; // 'All', 'Low Stock', 'In Stock'

  static const List<String> _categories = [
    'All',
    'Primers',
    'Propellants & Powders',
    'Projectiles & Bullets',
    'Cartridge Cases',
    'EPVAT Transducers & Consumables',
    'Targets & Range Supplies',
    'Packaging & Crates',
    'Other Supplies',
  ];

  static const List<String> _units = [
    'pcs',
    'rounds',
    'boxes',
    'kg',
    'grams',
    'liters',
    'sets',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load local cache first
      final local = await _storageService.loadConsumables();
      if (local.isNotEmpty && mounted) {
        setState(() {
          _items = local;
          _isLoading = false;
        });
      }

      // 2. Fetch from Supabase Cloud
      final cloud = await SupabaseService.fetchConsumablesFromCloud();
      if (cloud != null && mounted) {
        setState(() {
          _items = cloud;
          _isLoading = false;
        });
        await _storageService.saveConsumables(cloud);
      } else if (local.isEmpty && mounted) {
        // Initialize default consumables if completely empty
        _items = _getDefaultInitialItems();
        await _saveData();
      }
    } catch (e) {
      debugPrint('Error loading consumables: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getDefaultInitialItems() {
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    return [
      {
        'id': 'cons_1',
        'name': 'Boxer Primers 5.56mm Small Rifle',
        'serial': 'PR-556-2026-A',
        'category': 'Primers',
        'quantity': 25000,
        'minSafeThreshold': 5000,
        'unit': 'pcs',
        'supplier': 'OMPC Ballistics Plant 1',
        'location': 'Ammunition Vault A-02',
        'imageBase64': '',
        'history': [
          {
            'type': 'RECEIVED',
            'quantity': 25000,
            'date': now,
            'user': 'System',
            'purpose': 'Initial Stock Allocation',
            'remaining': 25000,
          }
        ]
      },
      {
        'id': 'cons_2',
        'name': 'Smokeless Propellant WC844 (5.56mm)',
        'serial': 'POW-WC844-LOT88',
        'category': 'Propellants & Powders',
        'quantity': 450,
        'minSafeThreshold': 80,
        'unit': 'kg',
        'supplier': 'Standard Nitrochem Corp',
        'location': 'Bunker 4 - Hazardous Material',
        'imageBase64': '',
        'history': [
          {
            'type': 'RECEIVED',
            'quantity': 450,
            'date': now,
            'user': 'System',
            'purpose': 'Initial Stock Allocation',
            'remaining': 450,
          }
        ]
      },
      {
        'id': 'cons_3',
        'name': 'FMJ Projectiles 55gr M193',
        'serial': 'BUL-M193-55G-01',
        'category': 'Projectiles & Bullets',
        'quantity': 40000,
        'minSafeThreshold': 6000,
        'unit': 'pcs',
        'supplier': 'Precision Metallurgy Div',
        'location': 'Bay 12 Shelf C',
        'imageBase64': '',
        'history': [
          {
            'type': 'RECEIVED',
            'quantity': 40000,
            'date': now,
            'user': 'System',
            'purpose': 'Initial Stock Allocation',
            'remaining': 40000,
          }
        ]
      },
      {
        'id': 'cons_4',
        'name': 'EPVAT Copper Crusher Gauges (P1)',
        'serial': 'EPV-CRUSH-P1-26',
        'category': 'EPVAT Transducers & Consumables',
        'quantity': 350,
        'minSafeThreshold': 100,
        'unit': 'pcs',
        'supplier': 'Kistler Instruments',
        'location': 'Metrology Lab Cabinet 2',
        'imageBase64': '',
        'history': [
          {
            'type': 'RECEIVED',
            'quantity': 350,
            'date': now,
            'user': 'System',
            'purpose': 'Calibration Stock Allocation',
            'remaining': 350,
          }
        ]
      },
      {
        'id': 'cons_5',
        'name': 'Standard 25m EPVAT Paper Targets',
        'serial': 'TGT-25M-OMPC',
        'category': 'Targets & Range Supplies',
        'quantity': 1200,
        'minSafeThreshold': 200,
        'unit': 'pcs',
        'supplier': 'OMPC Logistics Depot',
        'location': 'Shooting Tunnel Storage',
        'imageBase64': '',
        'history': [
          {
            'type': 'RECEIVED',
            'quantity': 1200,
            'date': now,
            'user': 'System',
            'purpose': 'Range Readiness Stock',
            'remaining': 1200,
          }
        ]
      },
    ];
  }

  Future<void> _saveData() async {
    await _storageService.saveConsumables(_items);
    SupabaseService.saveConsumablesToCloud(_items);
  }

  // Filtered items list
  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final serial = (item['serial'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? '').toString();
      final query = _searchQuery.toLowerCase();

      final matchesQuery = query.isEmpty || name.contains(query) || serial.contains(query);
      final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;

      final qty = (item['quantity'] ?? 0) as num;
      final min = (item['minSafeThreshold'] ?? 0) as num;

      bool matchesStock = true;
      if (_stockFilter == 'Low Stock') {
        matchesStock = qty <= min;
      } else if (_stockFilter == 'In Stock') {
        matchesStock = qty > min;
      }

      return matchesQuery && matchesCategory && matchesStock;
    }).toList();
  }

  int get _lowStockCount {
    return _items.where((item) {
      final qty = (item['quantity'] ?? 0) as num;
      final min = (item['minSafeThreshold'] ?? 0) as num;
      return qty <= min;
    }).length;
  }

  num get _totalUnitsCount {
    return _items.fold<num>(0, (sum, item) => sum + ((item['quantity'] ?? 0) as num));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E223D),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header & Top Actions ──────────────────────────────────────────
            _buildHeader(),
            const SizedBox(height: 20.0),

            // ─── Metric Cards ─────────────────────────────────────────────────
            _buildMetricCards(),
            const SizedBox(height: 24.0),

            // ─── Filter & Search Bar ───────────────────────────────────────────
            _buildFilterBar(),
            const SizedBox(height: 20.0),

            // ─── Consumables Grid/List ─────────────────────────────────────────
            _buildItemsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF06B6D4), size: 28.0),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consumable Items & Inventory Management',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Track ammunition components, propellants, primers, and testing hardware. Auto-deduct usage & receive shipments.',
                  style: TextStyle(fontSize: 12.0, color: const Color(0xFFBAE6FD).withOpacity(0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          // Action Buttons
          Wrap(
            spacing: 10.0,
            runSpacing: 8.0,
            children: [
              ElevatedButton.icon(
                onPressed: _openConsumeDialog,
                icon: const Icon(Icons.remove_circle_outline, size: 16.0),
                label: const Text('Log Usage', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              if (_isAdmin) ...[
                ElevatedButton.icon(
                  onPressed: _openReceiveShipmentDialog,
                  icon: const Icon(Icons.add_shopping_cart, size: 16.0),
                  label: const Text('Receive Shipment', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openRegisterItemDialog,
                  icon: const Icon(Icons.add, size: 16.0),
                  label: const Text('Register Item', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF06B6D4)),
                tooltip: 'Sync with Cloud',
                onPressed: () async {
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Consumables inventory synchronized with Supabase cloud.'),
                        backgroundColor: Color(0xFF0284C7),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'TOTAL REGISTERED ITEMS',
            value: '${_items.length}',
            subtitle: '${_categories.length - 1} Distinct Categories',
            icon: Icons.category_outlined,
            color: const Color(0xFF06B6D4),
          ),
        ),
        const SizedBox(width: 14.0),
        Expanded(
          child: _buildStatCard(
            title: 'TOTAL CUMULATIVE UNITS',
            value: NumberFormat('#,###').format(_totalUnitsCount),
            subtitle: 'Stocked across all vaults',
            icon: Icons.all_inbox_outlined,
            color: const Color(0xFF38BDF8),
          ),
        ),
        const SizedBox(width: 14.0),
        Expanded(
          child: _buildStatCard(
            title: 'LOW STOCK ALERTS',
            value: '$_lowStockCount',
            subtitle: _lowStockCount > 0 ? 'Action needed: reorder soon' : 'All safe thresholds met',
            icon: Icons.warning_amber_rounded,
            color: _lowStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E49),
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
            child: Icon(icon, color: color, size: 24.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4.0),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 22.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            flex: 3,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13.0),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by item name or serial...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12.5),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF06B6D4), size: 18.0),
                filled: true,
                fillColor: const Color(0xFF0E223D),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 14.0),

          // Category Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0E223D),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1C3351),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  isExpanded: true,
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14.0),

          // Stock Status Filter
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0E223D),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _stockFilter,
                  dropdownColor: const Color(0xFF1C3351),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  isExpanded: true,
                  onChanged: (v) => setState(() => _stockFilter = v ?? 'All'),
                  items: ['All', 'In Stock', 'Low Stock'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1C3351),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFF1E3A8A)),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, color: Color(0xFF8E96A3), size: 48.0),
            const SizedBox(height: 12.0),
            const Text(
              'No Consumable Items Found',
              style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Try changing your search query or click "Register Item" to add new inventory.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            mainAxisExtent: 275.0,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildItemCard(filtered[index]);
          },
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final qty = (item['quantity'] ?? 0) as num;
    final minSafe = (item['minSafeThreshold'] ?? 0) as num;
    final unit = item['unit'] ?? 'pcs';
    final isLowStock = qty <= minSafe;
    final isCritical = qty == 0;
    final imageBase64 = (item['imageBase64'] ?? '') as String;

    Color badgeColor = const Color(0xFF10B981);
    String badgeText = 'IN STOCK';
    if (isCritical) {
      badgeColor = const Color(0xFFEF4444);
      badgeText = 'OUT OF STOCK';
    } else if (isLowStock) {
      badgeColor = const Color(0xFFF59E0B);
      badgeText = 'LOW STOCK';
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isLowStock ? badgeColor.withOpacity(0.5) : const Color(0xFF06B6D4).withOpacity(0.2),
          width: isLowStock ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category Chip & Stock Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  (item['category'] ?? 'General').toString().toUpperCase(),
                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Item Visual Thumbnail & Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E223D),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF1E3A8A)),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageBase64.isNotEmpty
                    ? Image.memory(
                        base64Decode(imageBase64),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: Color(0xFF06B6D4)),
                      )
                    : Icon(_getCategoryIcon(item['category']), color: const Color(0xFF06B6D4), size: 28.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unnamed Consumable',
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'S/N: ${item['serial'] ?? 'N/A'}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontFamily: 'JetBrainsMono'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Stock Quantity Bar & Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0E223D),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Stock', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 10.0)),
                    const SizedBox(height: 2.0),
                    Text(
                      '${NumberFormat('#,###').format(qty)} $unit',
                      style: TextStyle(
                        color: isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Safe Min Threshold', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 10.0)),
                    const SizedBox(height: 2.0),
                    Text(
                      '${NumberFormat('#,###').format(minSafe)} $unit',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),

          // Card Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openItemConsumeModal(item),
                  icon: const Icon(Icons.remove, size: 14.0),
                  label: const Text('Consume', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openItemRestockModal(item),
                    icon: const Icon(Icons.add, size: 14.0),
                    label: const Text('Restock', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6.0),
              IconButton(
                icon: const Icon(Icons.history, color: Color(0xFF94A3B8), size: 18.0),
                tooltip: 'Transaction History',
                onPressed: () => _showHistoryDialog(item),
              ),
              if (_isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 18.0),
                  color: const Color(0xFF2C415E),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openEditItemDialog(item);
                    } else if (val == 'delete') {
                      _confirmDeleteItem(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 16.0),
                          SizedBox(width: 8.0),
                          Text('Edit Item', style: TextStyle(color: Colors.white, fontSize: 12.0)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16.0),
                          SizedBox(width: 8.0),
                          Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.0)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(dynamic category) {
    final cat = (category ?? '').toString();
    if (cat.contains('Primer')) return Icons.flash_on_outlined;
    if (cat.contains('Propellant') || cat.contains('Powder')) return Icons.local_fire_department_outlined;
    if (cat.contains('Projectile') || cat.contains('Bullet')) return Icons.filter_center_focus;
    if (cat.contains('Case')) return Icons.crop_portrait_outlined;
    if (cat.contains('EPVAT')) return Icons.compress_outlined;
    if (cat.contains('Target')) return Icons.track_changes;
    if (cat.contains('Packaging')) return Icons.inventory_2;
    return Icons.widgets_outlined;
  }

  // ─── Modal Dialogs ─────────────────────────────────────────────────────────

  // 1. Consume Dialog (Decrements stock)
  void _openItemConsumeModal(Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final userCtrl = TextEditingController(text: widget.loggedInUser);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: Row(
          children: [
            const Icon(Icons.remove_circle_outline, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8.0),
            Text('Log Consumption: ${item['name']}', style: const TextStyle(color: Colors.white, fontSize: 15.0)),
          ],
        ),
        content: SizedBox(
          width: 420.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E223D),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Available Stock:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0)),
                    Text('${item['quantity']} ${item['unit']}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13.0)),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: InputDecoration(
                  labelText: 'Quantity Consumed (${item['unit']})',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: purposeCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: InputDecoration(
                  labelText: 'Testing Purpose / Lot Number / Order Ref',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: InputDecoration(
                  labelText: 'Operator In Charge',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () async {
              final val = num.tryParse(qtyCtrl.text.trim());
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid positive quantity.'), backgroundColor: Colors.red),
                );
                return;
              }
              final currentQty = (item['quantity'] ?? 0) as num;
              if (val > currentQty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot consume more than available stock!'), backgroundColor: Colors.red),
                );
                return;
              }

              final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
              final newQty = currentQty - val;

              final historyList = List<dynamic>.from(item['history'] ?? []);
              historyList.insert(0, {
                'type': 'CONSUMED',
                'quantity': val,
                'date': now,
                'user': userCtrl.text.trim().isNotEmpty ? userCtrl.text.trim() : widget.loggedInUser,
                'purpose': purposeCtrl.text.trim().isNotEmpty ? purposeCtrl.text.trim() : 'Routine Ballistic Testing',
                'remaining': newQty,
              });

              setState(() {
                item['quantity'] = newQty;
                item['history'] = historyList;
              });

              await _saveData();
              Navigator.pop(ctx);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logged consumption of $val ${item['unit']} for "${item['name']}". New Balance: $newQty'),
                    backgroundColor: const Color(0xFF0284C7),
                  ),
                );
              }
            },
            child: const Text('Confirm Consumption', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 2. Restock Dialog (Increments stock)
  void _openItemRestockModal(Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController();
    final invoiceCtrl = TextEditingController();
    final supplierCtrl = TextEditingController(text: item['supplier'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart, color: Color(0xFF10B981)),
            const SizedBox(width: 8.0),
            Text('Receive Shipment: ${item['name']}', style: const TextStyle(color: Colors.white, fontSize: 15.0)),
          ],
        ),
        content: SizedBox(
          width: 420.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E223D),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Available Stock:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0)),
                    Text('${item['quantity']} ${item['unit']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13.0)),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: InputDecoration(
                  labelText: 'Received Quantity (${item['unit']})',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: invoiceCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: InputDecoration(
                  labelText: 'Invoice / PO / Shipment Tracking No.',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: supplierCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: InputDecoration(
                  labelText: 'Supplier / Origin Source',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final val = num.tryParse(qtyCtrl.text.trim());
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid positive quantity.'), backgroundColor: Colors.red),
                );
                return;
              }

              final currentQty = (item['quantity'] ?? 0) as num;
              final newQty = currentQty + val;
              final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

              final historyList = List<dynamic>.from(item['history'] ?? []);
              historyList.insert(0, {
                'type': 'RECEIVED',
                'quantity': val,
                'date': now,
                'user': widget.loggedInUser,
                'purpose': invoiceCtrl.text.trim().isNotEmpty ? 'Shipment Inv #${invoiceCtrl.text.trim()}' : 'Stock Replenishment',
                'remaining': newQty,
              });

              setState(() {
                item['quantity'] = newQty;
                item['history'] = historyList;
                if (supplierCtrl.text.trim().isNotEmpty) {
                  item['supplier'] = supplierCtrl.text.trim();
                }
              });

              await _saveData();
              Navigator.pop(ctx);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully added $val ${item['unit']} to "${item['name']}". New Stock: $newQty'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Confirm Restock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 3. Register New Consumable Item
  void _openRegisterItemDialog() {
    final nameCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1000');
    final minSafeCtrl = TextEditingController(text: '200');
    final supplierCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String category = _categories.firstWhere((c) => c != 'All', orElse: () => 'Primers');
    String unit = 'pcs';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1C3351),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          title: const Row(
            children: [
              Icon(Icons.add_box_outlined, color: Color(0xFF06B6D4)),
              SizedBox(width: 8.0),
              Text('Register New Consumable Item', style: TextStyle(color: Colors.white, fontSize: 16.0)),
            ],
          ),
          content: SizedBox(
            width: 480.0,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: InputDecoration(
                      labelText: 'Item Name *',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: serialCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0),
                          decoration: InputDecoration(
                            labelText: 'Serial / SKU / Lot No.',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF0E223D),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E223D),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF1E3A8A)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: category,
                              dropdownColor: const Color(0xFF1C3351),
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              isExpanded: true,
                              items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setDlgState(() => category = v!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 13.0),
                          decoration: InputDecoration(
                            labelText: 'Initial Total Quantity *',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF0E223D),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E223D),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF1E3A8A)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: unit,
                              dropdownColor: const Color(0xFF1C3351),
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              isExpanded: true,
                              items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) => setDlgState(() => unit = v!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    controller: minSafeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: InputDecoration(
                      labelText: 'Safe Min Alert Threshold',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    controller: supplierCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: InputDecoration(
                      labelText: 'Supplier / Manufacturer',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: InputDecoration(
                      labelText: 'Storage Location (Vault / Bay / Shelf)',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final qty = num.tryParse(qtyCtrl.text.trim()) ?? 0;
                final minSafe = num.tryParse(minSafeCtrl.text.trim()) ?? 0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item name cannot be empty.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
                final newItem = {
                  'id': 'cons_${DateTime.now().millisecondsSinceEpoch}',
                  'name': name,
                  'serial': serialCtrl.text.trim().isNotEmpty ? serialCtrl.text.trim() : 'GEN-${DateTime.now().millisecondsSinceEpoch % 10000}',
                  'category': category,
                  'quantity': qty,
                  'minSafeThreshold': minSafe,
                  'unit': unit,
                  'supplier': supplierCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'imageBase64': '',
                  'history': [
                    {
                      'type': 'RECEIVED',
                      'quantity': qty,
                      'date': now,
                      'user': widget.loggedInUser,
                      'purpose': 'Initial Item Registration',
                      'remaining': qty,
                    }
                  ]
                };

                setState(() {
                  _items.insert(0, newItem);
                });

                await _saveData();
                Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Registered item "$name" successfully with $qty $unit.'),
                      backgroundColor: const Color(0xFF6366F1),
                    ),
                  );
                }
              },
              child: const Text('Save & Register', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Generic Consume Trigger Button
  void _openConsumeDialog() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in inventory to consume.'), backgroundColor: Colors.orange),
      );
      return;
    }
    _openItemConsumeModal(_items.first);
  }

  // Generic Receive Shipment Trigger Button
  void _openReceiveShipmentDialog() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items registered. Please register an item first.'), backgroundColor: Colors.orange),
      );
      return;
    }
    _openItemRestockModal(_items.first);
  }

  // Edit Item Dialog
  void _openEditItemDialog(Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['name'] ?? '');
    final serialCtrl = TextEditingController(text: item['serial'] ?? '');
    final minSafeCtrl = TextEditingController(text: '${item['minSafeThreshold'] ?? 0}');
    final supplierCtrl = TextEditingController(text: item['supplier'] ?? '');
    final locationCtrl = TextEditingController(text: item['location'] ?? '');
    String category = item['category'] ?? 'Primers';
    String unit = item['unit'] ?? 'pcs';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1C3351),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          title: const Text('Edit Consumable Item', style: TextStyle(color: Colors.white, fontSize: 16.0)),
          content: SizedBox(
            width: 450.0,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(labelText: 'Item Name', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: serialCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(labelText: 'Serial / SKU', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: minSafeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(labelText: 'Safe Min Alert Threshold', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: supplierCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(labelText: 'Supplier', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(labelText: 'Location', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
              onPressed: () async {
                setState(() {
                  item['name'] = nameCtrl.text.trim();
                  item['serial'] = serialCtrl.text.trim();
                  item['minSafeThreshold'] = num.tryParse(minSafeCtrl.text.trim()) ?? item['minSafeThreshold'];
                  item['supplier'] = supplierCtrl.text.trim();
                  item['location'] = locationCtrl.text.trim();
                });
                await _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Confirm Delete
  void _confirmDeleteItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Text('Delete Consumable Item', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${item['name']}"? This cannot be undone.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              setState(() {
                _items.remove(item);
              });
              await _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Transaction History Modal
  void _showHistoryDialog(Map<String, dynamic> item) {
    final history = List<dynamic>.from(item['history'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF06B6D4)),
            const SizedBox(width: 8.0),
            Text('Transaction Log: ${item['name']}', style: const TextStyle(color: Colors.white, fontSize: 15.0)),
          ],
        ),
        content: SizedBox(
          width: 550.0,
          height: 380.0,
          child: history.isEmpty
              ? const Center(child: Text('No transaction logs available.', style: TextStyle(color: Color(0xFF94A3B8))))
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E3A8A), height: 16.0),
                  itemBuilder: (ctx, i) {
                    final tx = Map<String, dynamic>.from(history[i] as Map);
                    final isReceived = tx['type'] == 'RECEIVED';
                    final color = isReceived ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isReceived ? Icons.add : Icons.remove,
                            color: color,
                            size: 14.0,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${isReceived ? 'Received +' : 'Consumed -'}${tx['quantity']} ${item['unit']}',
                                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13.0),
                                  ),
                                  Text(
                                    tx['date'] ?? '',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                '${tx['purpose'] ?? 'General'} • By: ${tx['user'] ?? 'Operator'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                              if (tx['remaining'] != null) ...[
                                const SizedBox(height: 2.0),
                                Text(
                                  'Balance After: ${tx['remaining']} ${item['unit']}',
                                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 10.5, fontFamily: 'JetBrainsMono'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF06B6D4))),
          ),
        ],
      ),
    );
  }
}
