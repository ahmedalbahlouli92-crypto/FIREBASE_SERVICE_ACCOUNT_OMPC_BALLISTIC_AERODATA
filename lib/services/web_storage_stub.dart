import '../models/ballistic_record.dart';

List<BallisticRecord> getWebRecords(String module) => [];
bool hasWebRecordsKey(String module) => false;
void saveWebRecord(BallisticRecord record, String module) {}
void overwriteWebRecords(List<BallisticRecord> records, String module) {}
void deleteWebRecord(BallisticRecord record, String module) {}
void clearWebRecords(String module) {}
Set<String> getWebDeletedRecords() => {};
void saveWebDeletedRecords(Set<String> keys) {}
Set<String> getWebPendingSyncIds() => {};
void saveWebPendingSyncIds(Set<String> ids) {}
List<Map<String, String>> getWebOperators() => [];
void saveWebOperator(String email, String password, {String role = 'operator', String name = ''}) {}
void deleteWebOperator(String username) {}
Map<String, dynamic> getWebRules() => {};
void saveWebRules(Map<String, dynamic> rules) {}
void saveWebFormDraft(Map<String, dynamic> draft) {}
Map<String, dynamic>? getWebFormDraft() => null;
void clearWebFormDraft() {}
List<Map<String, dynamic>> getWebConsumables() => [];
void saveWebConsumables(List<Map<String, dynamic>> items) {}
String? getWebActiveModule() => null;
void saveWebActiveModule(String module) {}
List<Map<String, dynamic>> getWebWitnessLots() => [];
void saveWebWitnessLots(List<Map<String, dynamic>> lots) {}
List<Map<String, dynamic>> getWebWitnessConsumptions() => [];
void saveWebWitnessConsumptions(List<Map<String, dynamic>> consumptions) {}
int getWebRefCounter() => 0;
void saveWebRefCounter(int val) {}
List<Map<String, dynamic>> getWebEquipmentIssues() => [];
void saveWebEquipmentIssues(List<Map<String, dynamic>> issues) {}


