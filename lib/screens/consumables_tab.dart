import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/attachment_helper.dart';
import '../models/default_consumables.dart';

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
  String _selectedCategory = 'None'; // User chooses category -> items appear. If 'None', no items appear, only statistics.
  String _stockFilter = 'All'; // 'All', 'Low Stock', 'In Stock'

  // Exact 8 categories requested by user
  static const List<String> _defaultCategories = [
    'Shooting system',
    'closed Vessel and Calibration Unit',
    'Manual loading tools',
    'Primer Equipment',
    'Weapon cleaning item',
    'Residual Stress items',
    'Styer rifle spare Part',
    'M16 & M4 Spare Part',
  ];

  List<String> _categories = List<String>.from(_defaultCategories);

  static const List<String> _units = [
    'pcs',
    'liters',
    'rounds',
    'boxes',
    'kg',
    'grams',
    'sets',
    'cans',
    'bottles',
    'packs',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  bool _isLegacyData(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return true;
    return list.any((it) {
      final cat = it['category']?.toString() ?? '';
      return cat == 'Shooting System' ||
          cat == 'Closed Vessel and Calibration Unit' ||
          cat == 'Steyr Rifle Spare Parts' ||
          cat == 'Weapon Cleaning Items' ||
          cat == 'Residual Stress Items' ||
          cat == 'M16 & M4 Spare Parts' ||
          cat == 'Primers' ||
          cat == 'Propellants & Powders' ||
          cat == 'Projectiles & Bullets' ||
          cat == 'Cartridge Cases' ||
          cat == 'EPVAT Transducers & Consumables' ||
          cat == 'Targets & Range Supplies' ||
          cat == 'Packaging & Crates' ||
          cat == 'Other Supplies';
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load saved categories first
      final savedCats = await _storageService.loadConsumableCategories();
      final mergedCats = <String>[..._defaultCategories];
      for (final c in savedCats) {
        if (!mergedCats.contains(c)) mergedCats.add(c);
      }
      _categories = mergedCats;

      // 1. Load local cache
      final local = await _storageService.loadConsumables();
      if (_isLegacyData(local)) {
        final fresh = _getDefaultInitialItems();
        if (mounted) {
          setState(() {
            _items = fresh;
            _isLoading = false;
          });
        }
        await _saveData();
        return;
      }

      if (local.isNotEmpty && mounted) {
        setState(() {
          _items = local;
          _isLoading = false;
        });
      }

      // 2. Fetch from Supabase Cloud
      final cloud = await SupabaseService.fetchConsumablesFromCloud();
      if (cloud != null && mounted) {
        if (_isLegacyData(cloud)) {
          final fresh = _getDefaultInitialItems();
          setState(() {
            _items = fresh;
            _isLoading = false;
          });
          await _saveData();
        } else {
          setState(() {
            _items = cloud;
            _isLoading = false;
          });
          await _storageService.saveConsumables(cloud);
        }
      } else if (local.isEmpty && mounted) {
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
    return getDefaultConsumablesCatalog();
  }

  Future<void> _saveData() async {
    await _storageService.saveConsumables(_items);
    SupabaseService.saveConsumablesToCloud(_items);
  }

  // Filtered items list: when _selectedCategory == 'None', NO items appear
  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategory == 'None') {
      return [];
    }

    return _items.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final serial = (item['serial'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? '').toString();
      final query = _searchQuery.toLowerCase();

      final matchesQuery = query.isEmpty || name.contains(query) || serial.contains(query);
      final matchesCategory = category == _selectedCategory;

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

  // Calculate items used in day / month / year / all-time
  num _getUsage(String period) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final thisMonthStr = DateFormat('yyyy-MM').format(now);
    final thisYearStr = DateFormat('yyyy').format(now);

    num total = 0;
    for (final item in _items) {
      final history = item['history'] as List<dynamic>? ?? [];
      for (final h in history) {
        if (h is Map) {
          final type = (h['type'] ?? '').toString();
          if (type == 'CONSUMED' || type == 'DISPENSED') {
            final dateStr = (h['date'] ?? '').toString();
            final qty = (h['quantity'] ?? 0) as num;
            if (period == 'day' && dateStr.startsWith(todayStr)) {
              total += qty;
            } else if (period == 'month' && dateStr.startsWith(thisMonthStr)) {
              total += qty;
            } else if (period == 'year' && dateStr.startsWith(thisYearStr)) {
              total += qty;
            } else if (period == 'all') {
              total += qty;
            }
          }
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    final lowStock = _lowStockCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0E223D),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header & Top Actions ──────────────────────────────────────────
            _buildHeader(),
            const SizedBox(height: 16.0),

            // ─── Low Stock Alert Banner (if any) ───────────────────────────────
            if (lowStock > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24.0),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        'Attention: $lowStock item(s) are currently at or below their safe minimum stock threshold! Immediate replenishment is recommended.',
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13.0, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _stockFilter = 'Low Stock';
                          if (_selectedCategory == 'None' && _categories.isNotEmpty) {
                            _selectedCategory = _categories.first;
                          }
                        });
                      },
                      child: const Text('View Low Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // ─── Statistics Section (Always visible) ─────────────────────────
            _buildStatisticsSection(),
            const SizedBox(height: 20.0),

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
                  'Consumables & Inventory Management',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Select a category to view and log items. Monitor real-time daily, monthly, and yearly consumption statistics.',
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
                ElevatedButton.icon(
                  onPressed: _openAddCategoryDialog,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16.0),
                  label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
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

  // ─── Statistics Section (Usage per day, month, year, in total) ───────────
  Widget _buildStatisticsSection() {
    final usedToday = _getUsage('day');
    final usedMonth = _getUsage('month');
    final usedYear = _getUsage('year');
    final usedTotal = _getUsage('all');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF38BDF8), size: 18.0),
            const SizedBox(width: 8.0),
            const Text(
              'CONSUMPTION & INVENTORY STATISTICS',
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.0, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const Spacer(),
            Text(
              '${_categories.length} Categories • ${_items.length} Registered Items',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 6 : (constraints.maxWidth > 600 ? 3 : 2),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 12.0,
              childAspectRatio: isWide ? 1.7 : 1.9,
              children: [
                _buildStatCard(
                  title: 'USED TODAY',
                  value: NumberFormat('#,###').format(usedToday),
                  subtitle: DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  icon: Icons.today,
                  color: const Color(0xFF06B6D4),
                ),
                _buildStatCard(
                  title: 'THIS MONTH',
                  value: NumberFormat('#,###').format(usedMonth),
                  subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
                  icon: Icons.calendar_month,
                  color: const Color(0xFF3B82F6),
                ),
                _buildStatCard(
                  title: 'THIS YEAR',
                  value: NumberFormat('#,###').format(usedYear),
                  subtitle: 'Year ${DateTime.now().year}',
                  icon: Icons.date_range,
                  color: const Color(0xFF8B5CF6),
                ),
                _buildStatCard(
                  title: 'TOTAL USAGE',
                  value: NumberFormat('#,###').format(usedTotal),
                  subtitle: 'Lifetime consumption',
                  icon: Icons.history_edu,
                  color: const Color(0xFFEC4899),
                ),
                _buildStatCard(
                  title: 'TOTAL ITEMS',
                  value: '${_items.length}',
                  subtitle: 'Across ${_categories.length} categories',
                  icon: Icons.category_outlined,
                  color: const Color(0xFF10B981),
                ),
                _buildStatCard(
                  title: 'LOW STOCK',
                  value: '$_lowStockCount',
                  subtitle: _lowStockCount > 0 ? 'Action required' : 'All stocks safe',
                  icon: Icons.warning_amber_rounded,
                  color: _lowStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ],
            );
          },
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E49),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(icon, color: color, size: 20.0),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 18.0, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1.0),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                hintText: 'Search by part name or serial...',
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

          // Category Dropdown (Defaults to 'None')
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0E223D),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _selectedCategory == 'None' ? const Color(0xFFF59E0B) : const Color(0xFF06B6D4),
                  width: _selectedCategory == 'None' ? 1.5 : 1.0,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1C3351),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  isExpanded: true,
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'None'),
                  items: [
                    const DropdownMenuItem(
                      value: 'None',
                      child: Text(
                        '-- Choose Category (Items Hidden) --',
                        style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  ],
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
    // Crucial requirement: When category is not chosen ('None'), DO NOT show any items, only show statistics
    if (_selectedCategory == 'None') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1C3351),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.touch_app_outlined, color: Color(0xFF06B6D4), size: 40.0),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Select a Category to View Inventory Items',
              style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            SizedBox(
              width: 580.0,
              child: Text(
                'Please select one of the ${_categories.length} categories from the dropdown above to display its corresponding items and parts. General usage and threshold statistics for all items are displayed in the dashboard above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13.0, height: 1.4),
              ),
            ),
            const SizedBox(height: 20.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: _categories.map((cat) {
                final count = _items.where((it) => it['category'] == cat).length;
                return ActionChip(
                  backgroundColor: const Color(0xFF0E223D),
                  side: BorderSide(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                  avatar: const Icon(Icons.folder_open, size: 14.0, color: Color(0xFF06B6D4)),
                  label: Text('$cat ($count)', style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                  onPressed: () {
                    setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

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
            Text(
              'No items found under "$_selectedCategory"',
              style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Try changing your search query or click "Register Item" to add new inventory under this category.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CATEGORY: ${_selectedCategory.toUpperCase()} (${filtered.length} ITEMS)',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.0, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedCategory = 'None'),
              icon: const Icon(Icons.visibility_off_outlined, size: 14.0, color: Color(0xFF94A3B8)),
              label: const Text('Hide Items', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                mainAxisExtent: 280.0,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return _buildItemCard(filtered[index]);
              },
            );
          },
        ),
      ],
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
      badgeText = 'LOW STOCK ALERT';
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3351),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isLowStock ? badgeColor.withOpacity(0.6) : const Color(0xFF06B6D4).withOpacity(0.2),
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
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    (item['category'] ?? 'General').toString().toUpperCase(),
                    style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 9.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
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

          // Item Visual Thumbnail & Name (Separate Part Name and Serial Number)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54.0,
                height: 54.0,
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
                    : Icon(_getCategoryIcon(item['category']), color: const Color(0xFF06B6D4), size: 26.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unnamed Consumable',
                      style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E223D),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        'S/N: ${item['serial'] ?? 'N/A'}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontFamily: 'JetBrainsMono'),
                      ),
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
                        fontSize: 14.5,
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
                          Text('Edit Item & Specs', style: TextStyle(color: Colors.white, fontSize: 12.0)),
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
    if (cat.contains('Shooting')) return Icons.track_changes;
    if (cat.contains('Vessel') || cat.contains('Calibration')) return Icons.speed_outlined;
    if (cat.contains('Manual loading')) return Icons.build_outlined;
    if (cat.contains('Weapon cleaning')) return Icons.cleaning_services_outlined;
    if (cat.contains('Residual')) return Icons.science_outlined;
    if (cat.contains('Styer')) return Icons.military_tech_outlined;
    if (cat.contains('M16') || cat.contains('M4')) return Icons.gavel_outlined;
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
            Expanded(
              child: Text(
                'Log Consumption: ${item['name']}',
                style: const TextStyle(color: Colors.white, fontSize: 15.0),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                decoration: const InputDecoration(
                  labelText: 'Testing Purpose / Lot Number / Order Ref',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: const InputDecoration(
                  labelText: 'Operator In Charge',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
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
    final batchCtrl = TextEditingController();
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
            Expanded(
              child: Text(
                'Receive Shipment: ${item['name']}',
                style: const TextStyle(color: Colors.white, fontSize: 15.0),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                  labelText: 'Quantity Received (${item['unit']})',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: batchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: const InputDecoration(
                  labelText: 'Shipment / Invoice / Batch No.',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: supplierCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: const InputDecoration(
                  labelText: 'Supplier / Manufacturer',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Color(0xFF0E223D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
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
                'purpose': 'Shipment Batch: ${batchCtrl.text.trim().isNotEmpty ? batchCtrl.text.trim() : 'Standard Delivery'}',
                'remaining': newQty,
              });

              setState(() {
                item['quantity'] = newQty;
                if (supplierCtrl.text.trim().isNotEmpty) {
                  item['supplier'] = supplierCtrl.text.trim();
                }
                item['history'] = historyList;
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
    final qtyCtrl = TextEditingController(text: '0');
    final minSafeCtrl = TextEditingController(text: '10');
    final supplierCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String category = _selectedCategory != 'None' ? _selectedCategory : _categories.first;
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
                      labelText: 'Part / Item Name *',
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
                            labelText: 'Serial Number / SKU (Separate field)',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            hintText: 'e.g. SN-4901 or N/A',
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
                              value: _categories.contains(category) ? category : _categories.first,
                              dropdownColor: const Color(0xFF1C3351),
                              style: const TextStyle(color: Colors.white, fontSize: 12.0),
                              isExpanded: true,
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) {
                                if (v != null) setDlgState(() => category = v);
                              },
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
                            labelText: 'Initial Quantity in Stock *',
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
                              value: _units.contains(unit) ? unit : _units.first,
                              dropdownColor: const Color(0xFF1C3351),
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              isExpanded: true,
                              items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) {
                                if (v != null) setDlgState(() => unit = v);
                              },
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
                      labelText: 'Safe Minimum Stock Alert Threshold',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      helperText: 'Alert triggers when stock falls to or below this value',
                      helperStyle: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0),
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
                  'serial': serialCtrl.text.trim().isNotEmpty ? serialCtrl.text.trim() : 'N/A',
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
                  _selectedCategory = category;
                });

                await _saveData();
                Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Registered item "$name" successfully under $category.'),
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

  // 4. Edit Item Dialog (Admin can change part name, edit serial, change unit, adjust min safe threshold)
  void _openEditItemDialog(Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['name'] ?? '');
    final serialCtrl = TextEditingController(text: item['serial'] ?? '');
    final quantityCtrl = TextEditingController(text: '${item['quantity'] ?? 0}');
    final minSafeCtrl = TextEditingController(text: '${item['minSafeThreshold'] ?? 0}');
    final supplierCtrl = TextEditingController(text: item['supplier'] ?? '');
    final locationCtrl = TextEditingController(text: item['location'] ?? '');
    String currentImageBase64 = (item['imageBase64'] ?? '') as String;
    String category = item['category'] ?? (_categories.isNotEmpty ? _categories.first : 'Shooting system');
    String unit = item['unit'] ?? 'pcs';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1C3351),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF06B6D4)),
              SizedBox(width: 8.0),
              Text('Edit Consumable Item & Settings', style: TextStyle(color: Colors.white, fontSize: 16.0)),
            ],
          ),
          content: SizedBox(
            width: 500.0,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(
                      labelText: 'Part / Item Name (Admin editable)',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: serialCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0),
                          decoration: const InputDecoration(
                            labelText: 'Serial Number / SKU (Separate field)',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: Color(0xFF0E223D),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
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
                              value: _categories.contains(category) ? category : _categories.first,
                              dropdownColor: const Color(0xFF1C3351),
                              style: const TextStyle(color: Colors.white, fontSize: 12.0),
                              isExpanded: true,
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) {
                                if (v != null) setDlgState(() => category = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 13.0),
                          decoration: InputDecoration(
                            labelText: 'Current Stock ($unit)',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF0E223D),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
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
                              value: _units.contains(unit) ? unit : _units.first,
                              dropdownColor: const Color(0xFF1C3351),
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              isExpanded: true,
                              items: _units.map((u) => DropdownMenuItem(value: u, child: Text('Unit: $u'))).toList(),
                              onChanged: (v) {
                                if (v != null) setDlgState(() => unit = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: minSafeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(
                      labelText: 'Safe Minimum Stock Alert Threshold',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      helperText: 'System generates low stock alert when quantity <= threshold',
                      helperStyle: TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0),
                      filled: true,
                      fillColor: Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: supplierCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Color(0xFF0E223D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                    ),
                  ),
                  const SizedBox(height: 14.0),
                  // Picture Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E223D),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Item Picture', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: currentImageBase64.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(7.0),
                                      child: Image.memory(
                                        base64Decode(currentImageBase64),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image_outlined, color: Colors.orange, size: 28),
                                      ),
                                    )
                                  : const Icon(Icons.image_not_supported_outlined, color: Color(0xFF64748B), size: 28),
                            ),
                            const SizedBox(width: 14.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
                                    label: Text(
                                      currentImageBase64.isNotEmpty ? 'Change Picture' : 'Upload Picture',
                                      style: const TextStyle(fontSize: 12.0, color: Colors.white),
                                    ),
                                    onPressed: () async {
                                      final res = await getAttachmentHelper().pickFileAsBase64(accept: 'image/*');
                                      if (res != null && res['data'] != null) {
                                        setDlgState(() {
                                          currentImageBase64 = res['data']!;
                                        });
                                      }
                                    },
                                  ),
                                  if (currentImageBase64.isNotEmpty) ...[
                                    const SizedBox(height: 6.0),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                      icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                      label: const Text('Remove Picture', style: TextStyle(fontSize: 11.5, color: Colors.redAccent)),
                                      onPressed: () {
                                        setDlgState(() {
                                          currentImageBase64 = '';
                                        });
                                      },
                                    ),
                                  ],
                                ],
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
              onPressed: () async {
                final oldQty = num.tryParse('${item['quantity'] ?? 0}') ?? 0;
                final newQty = num.tryParse(quantityCtrl.text.trim()) ?? oldQty;

                setState(() {
                  item['name'] = nameCtrl.text.trim();
                  item['serial'] = serialCtrl.text.trim();
                  item['category'] = category;
                  item['unit'] = unit;
                  item['quantity'] = newQty;
                  item['imageBase64'] = currentImageBase64;
                  item['minSafeThreshold'] = num.tryParse(minSafeCtrl.text.trim()) ?? item['minSafeThreshold'];
                  item['supplier'] = supplierCtrl.text.trim();
                  item['location'] = locationCtrl.text.trim();

                  if (newQty != oldQty) {
                    final historyList = List<Map<String, dynamic>>.from(item['history'] ?? []);
                    historyList.insert(0, {
                      'type': newQty > oldQty ? 'RECEIVED' : 'DISPENSED',
                      'quantity': (newQty - oldQty).abs(),
                      'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                      'user': widget.loggedInUser,
                      'purpose': 'Admin stock adjustment',
                      'remaining': newQty,
                    });
                    item['history'] = historyList;
                  }
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

  // 5. Add New Category Dialog (Admin can add new category)
  void _openAddCategoryDialog() {
    final catCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_outlined, color: Color(0xFF0D9488)),
            SizedBox(width: 8.0),
            Text('Add New Consumable Category', style: TextStyle(color: Colors.white, fontSize: 16.0)),
          ],
        ),
        content: SizedBox(
          width: 400.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the name of the new inventory category:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: catCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                decoration: InputDecoration(
                  labelText: 'Category Name',
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            onPressed: () async {
              final newCat = catCtrl.text.trim();
              if (newCat.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category name cannot be empty.'), backgroundColor: Colors.red),
                );
                return;
              }
              if (_categories.contains(newCat)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category already exists.'), backgroundColor: Colors.orange),
                );
                return;
              }

              setState(() {
                _categories.add(newCat);
                _selectedCategory = newCat;
              });

              await _storageService.saveConsumableCategories(_categories);
              Navigator.pop(ctx);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "$newCat" created successfully.'),
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                );
              }
            },
            child: const Text('Add Category', style: TextStyle(color: Colors.white)),
          ),
        ],
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
