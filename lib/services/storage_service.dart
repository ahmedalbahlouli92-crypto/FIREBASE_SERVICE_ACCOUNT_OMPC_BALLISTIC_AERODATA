import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/ballistic_record.dart';
import 'web_storage_stub.dart'
    if (dart.library.js) 'web_storage_web.dart';
import 'supabase_service.dart';

class StorageService {
  static const _channel = MethodChannel('com.ompc.ballistic/storage');

  // Resolve platform-appropriate documents directory path
  Future<String> getDirectoryPath() async {
    if (kIsWeb) {
      return 'In-Memory Web Session';
    }
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'] ?? 'C:\\';
      final dir = Directory('$home\\Documents\\OMPC_Ballistic_AeroData');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/';
      final dir = Directory('$home/Documents/OMPC_Ballistic_AeroData');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        final String? path = await _channel.invokeMethod<String>('getDocumentsDirectory');
        if (path != null) {
          final dir = Directory(path);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return path;
        }
      } catch (e) {
        print("Error retrieving native mobile documents path: $e");
      }
    }
    
    // Fallback: active workspace current folder
    return Directory.current.path;
  }

  // Get daily filename based on date
  String getDailyFileName({String module = 'Lot Acceptance Test'}) {
    final d = DateTime.now();
    final year = d.year;
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final prefix = module == 'Lot Acceptance Test' ? 'ballistic_report' : 'daily_test_report';
    return '${prefix}_$year-$month-$day.csv';
  }

  // Ensure daily CSV file exists with standard quality control headers
  Future<dynamic> ensureDailyFileExists({String module = 'Lot Acceptance Test'}) async {
    if (kIsWeb) return null;
    final dirPath = await getDirectoryPath();
    final fileName = getDailyFileName(module: module);
    final file = File('$dirPath/$fileName');
    
    if (!await file.exists()) {
      const headers = 'Timestamp,Operators,Shift,Caliber Specification,Projectile/Lot Number,Quantity Tested,Defects Found,Remarks,Quality Status,Test Name,Pressure (Bar),Viscosity,Time of Test,Sampling Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast,Hopper No,Box No,Requirement,Barrel S.N,Barrel Type,Distance,Mean X,Max X,Min X,Range X,SD X,Mean Y,Max Y,Min Y,Range Y,SD Y,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,Mean Radius,Extraction Force Type,Extraction Force Rounds,Cartridge Temp,EPVAT Pressure Type,EPVAT Pressure Unit,EPVAT Pressure Rounds,EPVAT Mean Pressure,EPVAT Max Pressure,EPVAT Min Pressure,EPVAT Range Pressure,EPVAT SD Pressure,EPVAT P2 Mean Pressure,EPVAT P2 Max Pressure,EPVAT P2 Min Pressure,EPVAT P2 Range Pressure,EPVAT P2 SD Pressure,EPVAT P2 Pressure Rounds,EPVAT Velocity Rounds,Neck Slow,Neck Fast,Shoulder Slow,Shoulder Fast,Body Slow,Body Fast,Head Slow,Head Fast,Room Temp,Sensor 1,Sensor 2,Cyclic Weapon,Cyclic Ammo,Cyclic Val,Cyclic Min,Cyclic Max,Term Hole,Term Steel,Term Alum,Term Vel,Func L1,Func L2,Func L3,Func L4,Att Name,Att Base64,Func Defect Details,Action Time Mean,Action Time Min,Action Time Max,Action Time Range,Action Time SD,Action Time Rounds,Primer Drop Heights,Primer Fire Results,Primer Hbar,Primer SD,Primer All Fire H,Primer No Fire H\n';
      await file.writeAsString(headers, mode: FileMode.write, flush: true);
    }
    return file;
  }

  // Append new ballistic test log entry to Supabase and local cache
  Future<void> saveRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    BallisticRecord recordToSave = record;

    // 1. Save to Supabase Cloud Database
    if (SupabaseService.isInitialized) {
      try {
        final inserted = await SupabaseService.insertRecord(record);
        if (inserted != null) {
          recordToSave = inserted;
        }
      } catch (e) {
        print("Supabase save error (falling back to local): $e");
      }
    }

    // 2. Local persistence (web storage or local CSV)
    if (kIsWeb) {
      saveWebRecord(recordToSave, module);
      return;
    }
    final file = await ensureDailyFileExists(module: module) as File;
    await file.writeAsString(recordToSave.toCsvRow(), mode: FileMode.append, flush: true);
  }

  // Load and parse all ballistic logs (from Supabase if connected, else local cache)
  Future<List<BallisticRecord>> loadRecords({String module = 'Lot Acceptance Test'}) async {
    // 1. Attempt to fetch from Supabase Cloud Database
    if (SupabaseService.isInitialized) {
      try {
        final cloudRecords = await SupabaseService.fetchRecords();
        if (cloudRecords.isNotEmpty) {
          if (kIsWeb) {
            overwriteWebRecords(cloudRecords, module);
          }
          return cloudRecords;
        }
      } catch (e) {
        print("Supabase load error: $e");
      }
    }

    // 2. Fallback to local storage (web localStorage or desktop CSV)
    if (kIsWeb) {
      if (!hasWebRecordsKey(module)) {
        return [];
      }
      return getWebRecords(module);
    }
    try {
      final file = await ensureDailyFileExists(module: module) as File;
      final lines = await file.readAsLines();
      final List<BallisticRecord> records = [];
      
      // Skip header line
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        records.add(BallisticRecord.fromCsvRow(line));
      }
      return records;
    } catch (e) {
      print("Error loading records: $e");
      return [];
    }
  }

  // Delete record from Supabase if an id exists
  Future<void> deleteRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    if (record.id != null && record.id!.isNotEmpty && SupabaseService.isInitialized) {
      try {
        await SupabaseService.deleteRecord(record.id!);
      } catch (e) {
        print("Supabase delete error: $e");
      }
    }
  }

  // Overwrite daily CSV log with list of records (e.g. after deletion)
  Future<void> overwriteRecords(List<BallisticRecord> records, {String module = 'Lot Acceptance Test'}) async {
    if (kIsWeb) {
      overwriteWebRecords(records, module);
      return;
    }
    final file = await ensureDailyFileExists(module: module) as File;
    const headers = 'Timestamp,Operators,Shift,Caliber Specification,Projectile/Lot Number,Quantity Tested,Defects Found,Remarks,Quality Status,Test Name,Pressure (Bar),Viscosity,Time of Test,Sampling Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast,Hopper No,Box No,Requirement,Barrel S.N,Barrel Type,Distance,Mean X,Max X,Min X,Range X,SD X,Mean Y,Max Y,Min Y,Range Y,SD Y,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,Mean Radius,Extraction Force Type,Extraction Force Rounds,Cartridge Temp,EPVAT Pressure Type,EPVAT Pressure Unit,EPVAT Pressure Rounds,EPVAT Mean Pressure,EPVAT Max Pressure,EPVAT Min Pressure,EPVAT Range Pressure,EPVAT SD Pressure,EPVAT P2 Mean Pressure,EPVAT P2 Max Pressure,EPVAT P2 Min Pressure,EPVAT P2 Range Pressure,EPVAT P2 SD Pressure,EPVAT P2 Pressure Rounds,EPVAT Velocity Rounds,Neck Slow,Neck Fast,Shoulder Slow,Shoulder Fast,Body Slow,Body Fast,Head Slow,Head Fast,Room Temp,Sensor 1,Sensor 2,Cyclic Weapon,Cyclic Ammo,Cyclic Val,Cyclic Min,Cyclic Max,Term Hole,Term Steel,Term Alum,Term Vel,Func L1,Func L2,Func L3,Func L4,Att Name,Att Base64,Func Defect Details,Action Time Mean,Action Time Min,Action Time Max,Action Time Range,Action Time SD,Action Time Rounds,Primer Drop Heights,Primer Fire Results,Primer Hbar,Primer SD,Primer All Fire H,Primer No Fire H\n';
    final buffer = StringBuffer(headers);
    for (var r in records) {
      buffer.write(r.toCsvRow());
    }
    await file.writeAsString(buffer.toString(), mode: FileMode.write, flush: true);
  }

  // Clear all records for a specific module (e.g. Daily Test)
  Future<void> clearRecords({String module = 'Daily Test'}) async {
    if (kIsWeb) {
      clearWebRecords(module);
      return;
    }
    await overwriteRecords([], module: module);
  }

  // Open directory natively in Windows Explorer / Apple Finder
  Future<void> openLogsDirectory() async {
    if (kIsWeb) return;
    final dirPath = await getDirectoryPath();
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [dirPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dirPath]);
    }
  }

  // Load registered operators from storage
  Future<List<Map<String, String>>> loadOperators() async {
    if (kIsWeb) {
      final list = getWebOperators();
      if (list.isEmpty) {
        final defaultOperators = [
          {'email': 'manager', 'password': 'manager123', 'role': 'manager', 'name': 'Quality Manager'},
          {'email': 'supervisor', 'password': 'supervisor123', 'role': 'supervisor', 'name': 'Shift Supervisor'},
          {'email': 'technician', 'password': 'technician123', 'role': 'technician', 'name': 'Ballistics Technician'},
          {'email': 'operator', 'password': 'operator123', 'role': 'operator', 'name': 'Ahmed Said'},
        ];
        for (var op in defaultOperators) {
          saveWebOperator(op['email']!, op['password']!, role: op['role']!, name: op['name']!);
        }
        return defaultOperators;
      }
      return list;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/operators.json');
      if (!await file.exists()) {
        final defaultOperators = [
          {'email': 'manager', 'password': 'manager123', 'role': 'manager', 'name': 'Quality Manager'},
          {'email': 'supervisor', 'password': 'supervisor123', 'role': 'supervisor', 'name': 'Shift Supervisor'},
          {'email': 'technician', 'password': 'technician123', 'role': 'technician', 'name': 'Ballistics Technician'},
          {'email': 'operator', 'password': 'operator123', 'role': 'operator', 'name': 'Ahmed Said'},
        ];
        await file.writeAsString(jsonEncode(defaultOperators), mode: FileMode.write, flush: true);
        return defaultOperators;
      }
      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      return decoded.map((item) => {
        'email': (item['email'] ?? item['username'] ?? '') as String,
        'password': (item['password'] ?? '') as String,
        'role': (item['role'] ?? 'operator') as String,
        'name': (item['name'] ?? item['email'] ?? '') as String,
      }).toList();
    } catch (e) {
      print("Error loading operators: $e");
      return [
        {'email': 'manager', 'password': 'manager123', 'role': 'manager', 'name': 'Quality Manager'},
        {'email': 'supervisor', 'password': 'supervisor123', 'role': 'supervisor', 'name': 'Shift Supervisor'},
        {'email': 'technician', 'password': 'technician123', 'role': 'technician', 'name': 'Ballistics Technician'},
        {'email': 'operator', 'password': 'operator123', 'role': 'operator', 'name': 'Ahmed Said'},
      ];
    }
  }

  // Save new user credentials with role
  Future<void> saveOperator(String email, String password, {String role = 'operator', String name = ''}) async {
    if (kIsWeb) {
      saveWebOperator(email, password, role: role, name: name);
      return;
    }
    final operators = await loadOperators();
    operators.removeWhere((op) => (op['email'] ?? '').toLowerCase() == email.toLowerCase());
    operators.add({
      'email': email,
      'password': password,
      'role': role,
      'name': name.isNotEmpty ? name : email,
    });
    final dirPath = await getDirectoryPath();
    final file = File('$dirPath/operators.json');
    await file.writeAsString(jsonEncode(operators), mode: FileMode.write, flush: true);
  }

  // Delete user credentials
  Future<void> deleteOperator(String identifier) async {
    if (kIsWeb) {
      deleteWebOperator(identifier);
      return;
    }
    final operators = await loadOperators();
    operators.removeWhere((op) => (op['email'] ?? '').toLowerCase() == identifier.toLowerCase());
    final dirPath = await getDirectoryPath();
    final file = File('$dirPath/operators.json');
    await file.writeAsString(jsonEncode(operators), mode: FileMode.write, flush: true);
  }

  // Calculate cumulative rounds fired across all tests for a specific asset serial
  int calculateAssetRounds(List<BallisticRecord> records, String assetSerial) {
    if (assetSerial.isEmpty) return 0;
    final cleanSerial = assetSerial.trim().toLowerCase();
    int total = 0;
    for (var r in records) {
      final bSn = r.barrelSN.trim().toLowerCase();
      final gSn = r.gp6Serial.trim().toLowerCase();
      final wSn = r.cyclicRateWeaponType.trim().toLowerCase();
      
      if (bSn == cleanSerial || gSn == cleanSerial || wSn.contains(cleanSerial)) {
        total += r.produced;
      }
    }
    return total;
  }

  // Build a summary map of rounds used for all known asset serials
  Map<String, int> getAssetRoundCounts(List<BallisticRecord> records, List<String> allSerials) {
    final Map<String, int> counts = {};
    for (var serial in allSerials) {
      counts[serial] = calculateAssetRounds(records, serial);
    }
    return counts;
  }

  // Load Admin Rules
  Future<Map<String, dynamic>> loadRules() async {
    if (kIsWeb) {
      return getWebRules();
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/admin_rules.json');
      if (!await file.exists()) {
        return {};
      }
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print("Error loading admin rules: $e");
      return {};
    }
  }

  // Save Admin Rules
  Future<void> saveRules(Map<String, dynamic> rules) async {
    if (kIsWeb) {
      saveWebRules(rules);
      return;
    }
    final dirPath = await getDirectoryPath();
    final file = File('$dirPath/admin_rules.json');
    await file.writeAsString(jsonEncode(rules), mode: FileMode.write, flush: true);
  }

  // Save form draft locally (auto-save engine)
  Future<void> saveFormDraft(Map<String, dynamic> draft) async {
    if (kIsWeb) {
      saveWebFormDraft(draft);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/form_draft.json');
      await file.writeAsString(jsonEncode(draft), mode: FileMode.write, flush: true);
    } catch (e) {
      print("Error saving form draft: $e");
    }
  }

  // Load form draft locally
  Future<Map<String, dynamic>?> loadFormDraft() async {
    if (kIsWeb) {
      return getWebFormDraft();
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/form_draft.json');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print("Error loading form draft: $e");
      return null;
    }
  }

  // Clear form draft
  Future<void> clearFormDraft() async {
    if (kIsWeb) {
      clearWebFormDraft();
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/form_draft.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print("Error clearing form draft: $e");
    }
  }
}
