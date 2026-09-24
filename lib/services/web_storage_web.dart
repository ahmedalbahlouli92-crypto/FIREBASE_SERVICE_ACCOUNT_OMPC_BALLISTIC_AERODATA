import 'dart:convert';
import 'dart:html' as html;
import '../models/ballistic_record.dart';

String? _getItem(String key) {
  try {
    return html.window.localStorage[key];
  } catch (e) {
    print("Error reading localStorage key '$key': $e");
    return null;
  }
}

void _setItem(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (e) {
    print("Error writing localStorage key '$key': $e");
  }
}

bool hasWebRecordsKey(String module) {
  final key = 'records_$module';
  final clearedKey = 'cleared_$module';
  return _getItem(key) != null || _getItem(clearedKey) == 'true';
}

List<BallisticRecord> getWebRecords(String module) {
  final key = 'records_$module';
  final data = _getItem(key);
  if (data == null) return [];
  try {
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((r) => BallisticRecord.fromCsvRow(r as String)).toList();
  } catch (e) {
    print("Error reading web records: $e");
    return [];
  }
}

void saveWebRecord(BallisticRecord record, String module) {
  final records = getWebRecords(module);
  records.add(record);
  overwriteWebRecords(records, module);
}

void overwriteWebRecords(List<BallisticRecord> records, String module) {
  final key = 'records_$module';
  final csvRows = records.map((r) => r.toCsvRow()).toList();
  _setItem(key, jsonEncode(csvRows));
}

void deleteWebRecord(BallisticRecord record, String module) {
  final records = getWebRecords(module);
  final targetId = (record.id ?? '').trim();
  final targetTs = record.timestamp.trim();
  final targetLot = record.lotNo.trim();
  final targetHop = record.hopperNo.trim();
  final targetTest = record.testName.trim();
  final targetCal = record.caliber.trim();

  records.removeWhere((r) {
    final idMatch = targetId.isNotEmpty && r.id != null && r.id!.trim() == targetId;
    final rTs = r.timestamp.trim();
    final rLot = r.lotNo.trim();
    final rHop = r.hopperNo.trim();
    final rTest = r.testName.trim();
    final rCal = r.caliber.trim();
    final attrMatch = rTest == targetTest &&
        rCal == targetCal &&
        (rTs == targetTs || rTs.replaceAll('T', ' ').split('.').first == targetTs.replaceAll('T', ' ').split('.').first) &&
        (rLot == targetLot || (targetHop.isNotEmpty && rHop == targetHop));
    return idMatch || attrMatch;
  });

  overwriteWebRecords(records, module);
}

void clearWebRecords(String module) {
  final key = 'records_$module';
  _setItem(key, jsonEncode([]));
  _setItem('cleared_$module', 'true');
}

Set<String> getWebDeletedRecords() {
  final data = _getItem('deleted_record_keys');
  if (data == null || data.isEmpty) return {};
  try {
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => e.toString()).toSet();
  } catch (_) {
    return {};
  }
}

void saveWebDeletedRecords(Set<String> keys) {
  _setItem('deleted_record_keys', jsonEncode(keys.toList()));
}

Set<String> getWebPendingSyncIds() {
  final data = _getItem('pending_sync_ids');
  if (data == null || data.isEmpty) return {};
  try {
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => e.toString()).toSet();
  } catch (_) {
    return {};
  }
}

void saveWebPendingSyncIds(Set<String> ids) {
  _setItem('pending_sync_ids', jsonEncode(ids.toList()));
}

List<Map<String, String>> getWebOperators() {
  final data = _getItem('operators');
  if (data == null) return [];
  try {
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => {
      'email': ((item['email'] ?? item['username'] ?? '') as String),
      'password': ((item['password'] ?? '') as String),
      'role': ((item['role'] ?? 'operator') as String),
      'name': ((item['name'] ?? item['email'] ?? '') as String),
    }).toList();
  } catch (e) {
    print("Error loading web operators: $e");
    return [];
  }
}

void saveWebOperator(String email, String password, {String role = 'operator', String name = ''}) {
  final operators = getWebOperators();
  operators.removeWhere((op) => op['email']?.toLowerCase() == email.toLowerCase());
  operators.add({
    'email': email,
    'password': password,
    'role': role,
    'name': name.isNotEmpty ? name : email,
  });
  _setItem('operators', jsonEncode(operators));
}

void deleteWebOperator(String username) {
  final operators = getWebOperators();
  operators.removeWhere((op) => (op['email'] ?? op['username'] ?? '').toLowerCase() == username.toLowerCase());
  _setItem('operators', jsonEncode(operators));
}

Map<String, dynamic> getWebRules() {
  final data = _getItem('admin_rules');
  if (data == null) return {};
  try {
    return jsonDecode(data) as Map<String, dynamic>;
  } catch (e) {
    print("Error loading web rules: $e");
    return {};
  }
}

void saveWebRules(Map<String, dynamic> rules) {
  _setItem('admin_rules', jsonEncode(rules));
}

void saveWebFormDraft(Map<String, dynamic> draft) {
  _setItem('ompc_form_draft', jsonEncode(draft));
}

Map<String, dynamic>? getWebFormDraft() {
  final data = _getItem('ompc_form_draft');
  if (data == null || data.isEmpty) return null;
  try {
    return jsonDecode(data) as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}

void clearWebFormDraft() {
  _setItem('ompc_form_draft', '');
}

List<Map<String, dynamic>> getWebConsumables() {
  final data = _getItem('ompc_consumables_inventory');
  if (data == null || data.isEmpty) return [];
  try {
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    print("Error decoding web consumables: $e");
    return [];
  }
}

void saveWebConsumables(List<Map<String, dynamic>> items) {
  _setItem('ompc_consumables_inventory', jsonEncode(items));
}

String? getWebActiveModule() {
  final mod = _getItem('ompc_active_module');
  if (mod == null || mod.trim().isEmpty) return null;
  return mod.trim();
}

void saveWebActiveModule(String module) {
  if (module.isNotEmpty) {
    _setItem('ompc_active_module', module);
  }
}

