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
      debugPrint('Error initializing Supabase: $e');
    }
  }

  /// Check whether Supabase is reachable and table exists
  static Future<bool> isConnected() async {
    if (!_initialized) return false;
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
    final bool isLot = module == 'Lot Acceptance Test';
    final String prefix = isLot ? 'lot_acceptance' : 'daily';

    switch (testName) {
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
        return '${prefix}_primer_sensitivity_test';
      default:
        return tableName;
    }
  }

  /// Insert a single BallisticRecord to Supabase (saves to dedicated test table AND master table)
  static Future<BallisticRecord?> insertRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    if (!_initialized) return null;
    try {
      final effectiveModule = record.module.isNotEmpty ? record.module : module;
      final map = record.toSupabaseMap();
      map['module'] = effectiveModule;
      // Remove null or empty id so database generates standard UUID
      if (map['id'] == null || map['id'] == '') {
        map.remove('id');
      }

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
    if (!_initialized) return [];
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
    if (!_initialized || id.isEmpty) return false;
    try {
      final map = record.toSupabaseMap();
      map['module'] = module;
      map.remove('id'); // Don't overwrite primary key

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

  /// Delete a record from Supabase by its id
  static Future<bool> deleteRecord(String id, {String? module, String? testName}) async {
    if (!_initialized || id.isEmpty) return false;
    try {
      if (module != null && testName != null) {
        final dedicatedTable = getTableName(module: module, testName: testName);
        if (dedicatedTable != tableName) {
          try {
            await client.from(dedicatedTable).delete().eq('id', id);
          } catch (_) {}
        }
      }

      await client
          .from(tableName)
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting record from Supabase: $e');
      return false;
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
}
