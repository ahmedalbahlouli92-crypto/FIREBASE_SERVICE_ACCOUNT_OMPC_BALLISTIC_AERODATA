import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ballistic_record.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://dygzkvhvuxoukbgtjxfa.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5Z3prdmh2dXhvdWtiZ3RqeGZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1NTAwNjksImV4cCI6MjEwNTEyNjA2OX0.mvd6E8nQ30l-43wXVMEp_ARg2lHgiP3YxzgH9WCJKcU';

  static const String tableName = 'ballistic_records';

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase has not been initialized yet.');
    }
    return Supabase.instance.client;
  }

  /// Ensure Supabase client is initialized, retrying if earlier startup timed out
  static Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    try {
      await initialize();
      return _initialized;
    } catch (e) {
      debugPrint('ensureInitialized failed: $e');
      return false;
    }
  }

  /// Initialize Supabase Flutter Client
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      _initialized = true;
      debugPrint('Supabase connection initialized successfully');
    } catch (e) {
      try {
        if (Supabase.instance.client != null) {
          _initialized = true;
          debugPrint('Supabase client was already active');
          return;
        }
      } catch (_) {}
      debugPrint('Error initializing Supabase: $e');
    }
  }

  /// Check whether Supabase is reachable and table exists
  static Future<bool> isConnected() async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return false;
    }
    try {
      final res = await client
          .from(tableName)
          .select('id')
          .limit(1);
      return res != null;
    } catch (e) {
      debugPrint('Supabase connection check failed: $e');
      return false;
    }
  }

  /// Map Module + Test Name to its dedicated Supabase table name
  static String getTableName({String module = 'Lot Acceptance Test', String testName = ''}) {
    final bool isComponent = module == 'Component Test';
    final bool isLot = module == 'Lot Acceptance Test';
    final String prefix = isComponent ? 'component' : (isLot ? 'lot_acceptance' : 'daily');

    switch (testName) {
      case 'Propellant Test':
        return 'component_propellant_test';
      case 'Waterproof Test':
        return '${prefix}_waterproof_test';
      case 'Extraction Force Test':
        return '${prefix}_extraction_force_test';
      case 'Accuracy Test':
        return '${prefix}_accuracy_test';
      case 'EPVAT test':
        return '${prefix}_epvat_test';
      case 'Function Test':
        return '${prefix}_function_test';
      case 'Residual Stress Test':
        return '${prefix}_residual_stress_test';
      case 'Terminal Effect Test':
        return '${prefix}_terminal_effect_test';
      case 'Firing Rate Cycle Test':
        return '${prefix}_firing_rate_cycle_test';
      case 'Primer Sensitivity Test':
        return isComponent ? 'component_primer_sensitivity_test' : '${prefix}_primer_sensitivity_test';
      default:
        return tableName;
    }
  }

  /// Insert a single BallisticRecord to Supabase (saves to dedicated test table AND master table)
  static Future<BallisticRecord?> insertRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return null;
    }
    try {
      final effectiveModule = record.module.isNotEmpty ? record.module : module;
      final map = record.toSupabaseMap();
      map['module'] = effectiveModule;
      // Remove null or empty id so database generates standard UUID
      if (map['id'] == null || map['id'] == '') {
        map.remove('id');
      }
      map.remove('acc_largest_distance');

      final dedicatedTable = getTableName(module: effectiveModule, testName: record.testName);

      // 1. Attempt insert into dedicated test table
      if (dedicatedTable != tableName) {
        try {
          await client.from(dedicatedTable).insert(map);
        } catch (e) {
          debugPrint('Note: dedicated table $dedicatedTable insert skipped (may not be created yet): $e');
        }
      }

      // 2. Insert into consolidated master table
      final response = await client
          .from(tableName)
          .insert(map)
          .select()
          .single();

      return BallisticRecord.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('Error inserting record into Supabase: $e');
      return null;
    }
  }

  /// Fetch all ballistic records from Supabase
  static Future<List<BallisticRecord>> fetchRecords({
    String? module,
    String? testName,
    String? lotNo,
    String? caliber,
    int limit = 3000,
    bool useDedicatedTable = true,
  }) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return [];
    }
    try {
      final targetTable = (useDedicatedTable && module != null && testName != null && testName != 'All')
          ? getTableName(module: module, testName: testName)
          : tableName;

      var query = client.from(targetTable).select();

      if (lotNo != null && lotNo.isNotEmpty && lotNo != 'All') {
        query = query.eq('lot_no', lotNo);
      }
      if (testName != null && testName.isNotEmpty && testName != 'All' && targetTable == tableName) {
        query = query.eq('test_name', testName);
      }
      if (caliber != null && caliber.isNotEmpty && caliber != 'All') {
        query = query.eq('caliber', caliber);
      }
      if (module != null && module.isNotEmpty && targetTable == tableName) {
        if (module == 'Daily Test' || module == 'Daily Test Report') {
          query = query.eq('module', 'Daily Test');
        } else {
          query = query.or('module.eq.Lot Acceptance Test,module.is.null');
        }
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => BallisticRecord.fromSupabaseMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching records from Supabase: $e');
      // If querying dedicated table failed, fallback to master table once
      if (useDedicatedTable && module != null && testName != null && testName != 'All') {
        return fetchRecords(
          module: module,
          testName: testName,
          lotNo: lotNo,
          caliber: caliber,
          limit: limit,
          useDedicatedTable: false,
        );
      }
      return [];
    }
  }

  /// Update an existing record in Supabase
  static Future<bool> updateRecord(String id, BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return false;
    }
    if (id.isEmpty) return false;
    try {
      final map = record.toSupabaseMap();
      map['module'] = module;
      map.remove('id'); // Don't overwrite primary key
      map.remove('acc_largest_distance');

      final dedicatedTable = getTableName(module: module, testName: record.testName);
      if (dedicatedTable != tableName) {
        try {
          await client.from(dedicatedTable).update(map).eq('id', id);
        } catch (_) {}
      }

      await client
          .from(tableName)
          .update(map)
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating record in Supabase: $e');
      return false;
    }
  }

  /// Delete a record from Supabase by its id or attributes
  static Future<bool> deleteRecord(String id, {String? module, String? testName, String? timestamp, String? lotNo}) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return false;
    }
    try {
      if (module != null && testName != null) {
        final dedicatedTable = getTableName(module: module, testName: testName);
        if (dedicatedTable != tableName) {
          try {
            if (id.isNotEmpty) {
              await client.from(dedicatedTable).delete().eq('id', id);
            }
            if (timestamp != null && lotNo != null && timestamp.isNotEmpty && lotNo.isNotEmpty) {
              await client.from(dedicatedTable).delete().match({'timestamp': timestamp, 'lot_no': lotNo});
            }
          } catch (_) {}
        }
      }

      if (id.isNotEmpty) {
        await client
            .from(tableName)
            .delete()
            .eq('id', id);
      }
      if (timestamp != null && lotNo != null && timestamp.isNotEmpty && lotNo.isNotEmpty) {
        await client
            .from(tableName)
            .delete()
            .match({'timestamp': timestamp, 'lot_no': lotNo});
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting record from Supabase: $e');
      return false;
    }
  }

  static const List<String> dedicatedTestSuffixes = [
    'waterproof_test',
    'extraction_force_test',
    'accuracy_test',
    'epvat_test',
    'function_test',
    'residual_stress_test',
    'terminal_effect_test',
    'firing_rate_cycle_test',
    'primer_sensitivity_test',
    'propellant_test',
  ];

  /// Clear records from Supabase for a specific module or all
  static Future<void> clearAllRecords({String? module}) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return;
    }
    try {
      final isDaily = module == 'Daily Test' || module == 'Daily Test Report';
      final isLot = module == 'Lot Acceptance Test';
      final isComponent = module == 'Component Test';

      // 1. Delete from dedicated tables
      final prefixes = <String>[];
      if (module == null || module == 'all') {
        prefixes.addAll(['daily', 'lot_acceptance', 'component']);
      } else if (isDaily) {
        prefixes.add('daily');
      } else if (isLot) {
        prefixes.add('lot_acceptance');
      } else if (isComponent) {
        prefixes.add('component');
      }

      for (var prefix in prefixes) {
        for (var suffix in dedicatedTestSuffixes) {
          final tName = '${prefix}_$suffix';
          try {
            await client.from(tName).delete().neq('created_at', '1970-01-01T00:00:00Z');
          } catch (_) {}
        }
      }

      // 2. Delete from master ballistic_records table
      try {
        if (module == null || module == 'all') {
          await client.from(tableName).delete().neq('created_at', '1970-01-01T00:00:00Z');
        } else if (isDaily) {
          await client.from(tableName).delete().eq('module', 'Daily Test');
        } else if (isLot) {
          try {
            await client.from(tableName).delete().eq('module', 'Lot Acceptance Test');
          } catch (_) {
            await client.from(tableName).delete().neq('created_at', '1970-01-01T00:00:00Z');
          }
        }
      } catch (e) {
        debugPrint('Notice deleting from master table: $e');
      }
    } catch (e) {
      debugPrint('Error clearing Supabase records: $e');
    }
  }

  /// Realtime stream of records for live collaborative updates
  static Stream<List<BallisticRecord>> streamRecords({int limit = 500}) {
    if (!_initialized) {
      return const Stream.empty();
    }
    return client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((maps) => maps.map((m) => BallisticRecord.fromSupabaseMap(m)).toList());
  }

  /// Fetch operators registry from Supabase cloud configuration
  static Future<List<Map<String, String>>?> fetchOperatorsFromCloud() async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return null;
    }
    try {
      final res = await client
          .from(tableName)
          .select('id, notes')
          .eq('module', 'SYSTEM_CONFIG')
          .eq('test_name', 'OPERATORS_REGISTRY')
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty && res[0]['notes'] != null) {
        final notesStr = res[0]['notes'] as String;
        if (notesStr.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(notesStr);
          return decoded.map((item) => {
            'email': ((item['email'] ?? item['username'] ?? '') as String),
            'password': ((item['password'] ?? '') as String),
            'role': ((item['role'] ?? 'operator') as String),
            'name': ((item['name'] ?? item['email'] ?? '') as String),
          }).toList();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching operators from Supabase: $e');
      return null;
    }
  }

  /// Save operators registry to Supabase cloud configuration
  static Future<bool> saveOperatorsToCloud(List<Map<String, String>> operators) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return false;
    }
    try {
      final jsonString = jsonEncode(operators);
      final existing = await client
          .from(tableName)
          .select('id')
          .eq('module', 'SYSTEM_CONFIG')
          .eq('test_name', 'OPERATORS_REGISTRY')
          .limit(1);

      if (existing.isNotEmpty) {
        final existingId = existing[0]['id'];
        await client.from(tableName).update({
          'notes': jsonString,
          'timestamp': DateTime.now().toIso8601String(),
        }).eq('id', existingId);
      } else {
        await client.from(tableName).insert({
          'module': 'SYSTEM_CONFIG',
          'test_name': 'OPERATORS_REGISTRY',
          'operators': 'System',
          'notes': jsonString,
          'status': 'ACTIVE',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving operators to Supabase: $e');
      return false;
    }
  }

  /// Fetch admin rules from Supabase cloud configuration
  static Future<Map<String, dynamic>?> fetchRulesFromCloud() async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return null;
    }
    // 1. Try dedicated admin_control table
    try {
      final ctrlRes = await client
          .from('admin_control')
          .select('config_value')
          .eq('config_key', 'ADMIN_RULES')
          .limit(1);
      if (ctrlRes.isNotEmpty && ctrlRes[0]['config_value'] != null) {
        final val = ctrlRes[0]['config_value'];
        if (val is Map) return Map<String, dynamic>.from(val);
        if (val is String && val.isNotEmpty) {
          return jsonDecode(val) as Map<String, dynamic>;
        }
      }
    } catch (_) {}

    // 2. Fallback to master ballistic_records (SYSTEM_CONFIG)
    try {
      final res = await client
          .from(tableName)
          .select('id, notes')
          .eq('module', 'SYSTEM_CONFIG')
          .eq('test_name', 'ADMIN_RULES')
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty && res[0]['notes'] != null) {
        final notesStr = res[0]['notes'] as String;
        if (notesStr.isNotEmpty) {
          return jsonDecode(notesStr) as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching rules from Supabase: $e');
      return null;
    }
  }

  /// Save admin rules to Supabase cloud configuration
  static Future<bool> saveRulesToCloud(Map<String, dynamic> rules) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return false;
    }
    try {
      // 1. Save to dedicated admin_control table if available
      try {
        await client.from('admin_control').upsert({
          'config_key': 'ADMIN_RULES',
          'config_value': rules,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('admin_control upsert note: $e');
      }

      // 2. Always sync with master ballistic_records (SYSTEM_CONFIG)
      final jsonString = jsonEncode(rules);
      final existing = await client
          .from(tableName)
          .select('id')
          .eq('module', 'SYSTEM_CONFIG')
          .eq('test_name', 'ADMIN_RULES')
          .limit(1);

      if (existing.isNotEmpty) {
        final existingId = existing[0]['id'];
        await client.from(tableName).update({
          'notes': jsonString,
          'timestamp': DateTime.now().toIso8601String(),
        }).eq('id', existingId);
      } else {
        await client.from(tableName).insert({
          'module': 'SYSTEM_CONFIG',
          'test_name': 'ADMIN_RULES',
          'operators': 'System',
          'notes': jsonString,
          'status': 'ACTIVE',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving rules to Supabase: $e');
      return false;
    }
  }

  /// Fetch consumables inventory from Supabase cloud configuration
  static Future<List<Map<String, dynamic>>?> fetchConsumablesFromCloud() async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return null;
    }
    // 1. Try dedicated consumables_inventory table
    try {
      final invRes = await client.from('consumables_inventory').select();
      if (invRes.isNotEmpty) {
        return (invRes as List<dynamic>).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          if (m.containsKey('min_safe_threshold')) {
            m['minSafeThreshold'] = m['min_safe_threshold'];
          }
          return m;
        }).toList();
      }
    } catch (_) {}

    // 2. Fallback to master ballistic_records (SYSTEM_CONFIG)
    try {
      final res = await client
          .from(tableName)
          .select('id, notes')
          .eq('module', 'SYSTEM_CONFIG')
          .eq('test_name', 'CONSUMABLES_INVENTORY')
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty && res[0]['notes'] != null) {
        final notesStr = res[0]['notes'] as String;
        if (notesStr.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(notesStr);
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching consumables from Supabase: $e');
      return null;
    }
  }

  /// Save consumables inventory to Supabase cloud configuration
  static Future<bool> saveConsumablesToCloud(List<Map<String, dynamic>> items) async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return false;
    }
    try {
      // 1. Save to dedicated consumables_inventory table if available
      try {
        final rows = items.map((it) => {
          'id': it['id']?.toString() ?? '',
          'name': it['name']?.toString() ?? '',
          'serial': it['serial']?.toString() ?? '',
          'category': it['category']?.toString() ?? '',
          'quantity': it['quantity'] ?? 0,
          'unit': it['unit']?.toString() ?? 'pcs',
          'min_safe_threshold': it['minSafeThreshold'] ?? 0,
          'supplier': it['supplier']?.toString() ?? '',
          'location': it['location']?.toString() ?? '',
          'updated_at': DateTime.now().toIso8601String(),
        }).toList();
        await client.from('consumables_inventory').upsert(rows);
      } catch (e) {
        debugPrint('consumables_inventory upsert note: $e');
      }

      // 2. Always sync with master ballistic_records (SYSTEM_CONFIG)
      final jsonString = jsonEncode(items);
      final existing = await client
          .from(tableName)
          .select('id')
          .eq('module', 'SYSTEM_CONFIG')
          .eq('test_name', 'CONSUMABLES_INVENTORY')
          .limit(1);

      if (existing.isNotEmpty) {
        final existingId = existing[0]['id'];
        await client.from(tableName).update({
          'notes': jsonString,
          'timestamp': DateTime.now().toIso8601String(),
        }).eq('id', existingId);
      } else {
        await client.from(tableName).insert({
          'module': 'SYSTEM_CONFIG',
          'test_name': 'CONSUMABLES_INVENTORY',
          'operators': 'System',
          'notes': jsonString,
          'status': 'ACTIVE',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving consumables to Supabase: $e');
      return false;
    }
  }
}

