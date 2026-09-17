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

  /// Insert a single BallisticRecord to Supabase
  static Future<BallisticRecord?> insertRecord(BallisticRecord record) async {
    if (!_initialized) return null;
    try {
      final map = record.toSupabaseMap();
      // Remove null or empty id so database generates standard UUID
      if (map['id'] == null || map['id'] == '') {
        map.remove('id');
      }

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
    String? lotNo,
    String? testName,
    String? caliber,
    int limit = 3000,
  }) async {
    if (!_initialized) return [];
    try {
      var query = client.from(tableName).select();

      if (lotNo != null && lotNo.isNotEmpty && lotNo != 'All') {
        query = query.eq('lot_no', lotNo);
      }
      if (testName != null && testName.isNotEmpty && testName != 'All') {
        query = query.eq('test_name', testName);
      }
      if (caliber != null && caliber.isNotEmpty && caliber != 'All') {
        query = query.eq('caliber', caliber);
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
      return [];
    }
  }

  /// Update an existing record in Supabase
  static Future<bool> updateRecord(String id, BallisticRecord record) async {
    if (!_initialized || id.isEmpty) return false;
    try {
      final map = record.toSupabaseMap();
      map.remove('id'); // Don't overwrite primary key

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
  static Future<bool> deleteRecord(String id) async {
    if (!_initialized || id.isEmpty) return false;
    try {
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
