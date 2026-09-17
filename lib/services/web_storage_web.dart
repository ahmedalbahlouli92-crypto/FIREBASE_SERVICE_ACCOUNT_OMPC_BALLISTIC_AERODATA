import 'dart:convert';
import 'dart:js' as js;
import '../models/ballistic_record.dart';

String? _getItem(String key) {
  return js.context.callMethod('eval', ["localStorage.getItem('$key')"]) as String?;
}

void _setItem(String key, String value) {
  js.context.callMethod('eval', ["localStorage.setItem('$key', ${jsonEncode(value)})"]);
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

void clearWebRecords(String module) {
  final key = 'records_$module';
  _setItem(key, jsonEncode([]));
  _setItem('cleared_$module', 'true');
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
