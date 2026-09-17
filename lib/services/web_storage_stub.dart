import '../models/ballistic_record.dart';

List<BallisticRecord> getWebRecords(String module) => [];
bool hasWebRecordsKey(String module) => false;
void saveWebRecord(BallisticRecord record, String module) {}
void overwriteWebRecords(List<BallisticRecord> records, String module) {}
void clearWebRecords(String module) {}
List<Map<String, String>> getWebOperators() => [];
void saveWebOperator(String email, String password, {String role = 'operator', String name = ''}) {}
void deleteWebOperator(String username) {}
Map<String, dynamic> getWebRules() => {};
void saveWebRules(Map<String, dynamic> rules) {}
void saveWebFormDraft(Map<String, dynamic> draft) {}
Map<String, dynamic>? getWebFormDraft() => null;
void clearWebFormDraft() {}
