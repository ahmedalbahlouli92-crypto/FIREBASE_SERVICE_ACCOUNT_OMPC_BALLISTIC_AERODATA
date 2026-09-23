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
    final prefix = module == 'Lot Acceptance Test'
        ? 'ballistic_report'
        : (module == 'Component Test' ? 'component_test_report' : 'daily_test_report');
    return '${prefix}_$year-$month-$day.csv';
  }

  // Ensure daily CSV file exists with standard quality control headers
  Future<dynamic> ensureDailyFileExists({String module = 'Lot Acceptance Test'}) async {
    if (kIsWeb) return null;
    final dirPath = await getDirectoryPath();
    final fileName = getDailyFileName(module: module);
    final file = File('$dirPath/$fileName');
    
    if (!await file.exists()) {
      const headers = 'Timestamp,Operators,Shift,Caliber Specification,Projectile/Lot Number,Quantity Tested,Defects Found,Remarks,Quality Status,Test Name,Pressure (Bar),Viscosity,Time of Test,Sampling Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast,Hopper No,Box No,Requirement,Barrel S.N,Barrel Type,Distance,Mean X,Max X,Min X,Range X,SD X,Mean Y,Max Y,Min Y,Range Y,SD Y,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,Mean Radius,Extraction Force Type,Extraction Force Rounds,Cartridge Temp,EPVAT Pressure Type,EPVAT Pressure Unit,EPVAT Pressure Rounds,EPVAT Mean Pressure,EPVAT Max Pressure,EPVAT Min Pressure,EPVAT Range Pressure,EPVAT SD Pressure,EPVAT P2 Mean Pressure,EPVAT P2 Max Pressure,EPVAT P2 Min Pressure,EPVAT P2 Range Pressure,EPVAT P2 SD Pressure,EPVAT P2 Pressure Rounds,EPVAT Velocity Rounds,Neck Slow,Neck Fast,Shoulder Slow,Shoulder Fast,Body Slow,Body Fast,Head Slow,Head Fast,Room Temp,Sensor 1,Sensor 2,Cyclic Weapon,Cyclic Ammo,Cyclic Val,Cyclic Min,Cyclic Max,Term Hole,Term Steel,Term Alum,Term Vel,Func L1,Func L2,Func L3,Func L4,Att Name,Att Base64,Func Defect Details,Action Time Mean,Action Time Min,Action Time Max,Action Time Range,Action Time SD,Action Time Rounds,Primer Drop Heights,Primer Fire Results,Primer Hbar,Primer SD,Primer All Fire H,Primer No Fire H,Primer Lot,Primer Supplier,Primer Insertion Depth,Propellant Supplier,Propellant Code,Propellant Lot,Propellant Charge\n';
      await file.writeAsString(headers, mode: FileMode.write, flush: true);
    }
    return file;
  }

  // Append new ballistic test log entry to Supabase and local cache
  Future<void> saveRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    final cleanModule = (module == 'Daily Test' || module == 'Daily Test Report')
        ? 'Daily Test'
        : (module == 'Component Test' ? 'Component Test' : 'Lot Acceptance Test');
    final String assignedId = (record.id != null && record.id!.isNotEmpty) ? record.id! : BallisticRecord.generateUuid();
    BallisticRecord recordToSave = record.copyWith(id: assignedId, module: cleanModule);

    // 1. Immediate local persistence (guarantees record is saved even if offline)
    if (kIsWeb) {
      saveWebRecord(recordToSave, cleanModule);
    } else {
      try {
        final file = await ensureDailyFileExists(module: cleanModule) as File;
        await file.writeAsString(recordToSave.toCsvRow(), mode: FileMode.append, flush: true);
      } catch (e) {
        print("Error saving local file: $e");
      }
    }

    // 2. Save to Supabase Cloud Database
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        final inserted = await SupabaseService.insertRecord(recordToSave, module: cleanModule);
        if (inserted != null && inserted.id != null && inserted.id!.isNotEmpty) {
          recordToSave = inserted;
          if (kIsWeb) {
            // Update the locally cached record with its assigned Supabase UUID
            final webRecords = getWebRecords(cleanModule);
            if (webRecords.isNotEmpty) {
              final lastIdx = webRecords.length - 1;
              if (webRecords[lastIdx].timestamp == recordToSave.timestamp &&
                  webRecords[lastIdx].lotNo == recordToSave.lotNo) {
                webRecords[lastIdx] = recordToSave;
                overwriteWebRecords(webRecords, cleanModule);
              }
            }
          }
        }
      } catch (e) {
        print("Supabase save error (saved to local cache): $e");
      }
    }
  }

  // Read all local CSV records from disk for desktop
  Future<List<BallisticRecord>> _loadAllLocalCsvRecords(String cleanModule) async {
    if (kIsWeb) return [];
    try {
      final dirPath = await getDirectoryPath();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];

      final isComponent = cleanModule == 'Component Test';
      final isDaily = cleanModule == 'Daily Test';
      final prefix = cleanModule == 'Lot Acceptance Test'
          ? 'ballistic_report'
          : (isComponent ? 'component_test_report' : 'daily_test_report');
      final List<BallisticRecord> records = [];

      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.csv')) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.startsWith(prefix) || fileName.startsWith('ballistic_report') || fileName.startsWith('daily_test_report') || fileName.startsWith('component_test_report')) {
            try {
              final lines = await entity.readAsLines();
              for (int i = 1; i < lines.length; i++) {
                final line = lines[i].trim();
                if (line.isNotEmpty) {
                  try {
                    final r = BallisticRecord.fromCsvRow(line);
                    if (isDaily) {
                      if (r.module == 'Daily Test') records.add(r);
                    } else if (isComponent) {
                      if (r.module == 'Component Test') records.add(r);
                    } else {
                      if (r.module.isEmpty || r.module == 'Lot Acceptance Test') records.add(r);
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }
      }
      return records;
    } catch (e) {
      print("Error loading all local CSV records: $e");
      return [];
    }
  }

  // Load and parse all ballistic logs (from Supabase if connected, else local cache)
  Future<List<BallisticRecord>> loadRecords({String module = 'Lot Acceptance Test'}) async {
    final cleanModule = (module == 'Daily Test' || module == 'Daily Test Report')
        ? 'Daily Test'
        : (module == 'Component Test' ? 'Component Test' : 'Lot Acceptance Test');
    final bool isDaily = cleanModule == 'Daily Test';
    final bool isComponent = cleanModule == 'Component Test';

    // Ensure Supabase is initialized
    await SupabaseService.ensureInitialized();

    // 1. Attempt to fetch from Supabase Cloud Database
    if (SupabaseService.isInitialized) {
      try {
        final cloudRecords = await SupabaseService.fetchRecords(module: cleanModule);
        final filtered = cloudRecords.where((r) {
          if (isDaily) {
            return r.module == 'Daily Test';
          } else if (isComponent) {
            return r.module == 'Component Test';
          } else {
            return r.module.isEmpty || r.module == 'Lot Acceptance Test';
          }
        }).toList();

        // Merge with any locally cached records (web or desktop CSV)
        final List<BallisticRecord> localRecords = kIsWeb
            ? getWebRecords(cleanModule)
            : await _loadAllLocalCsvRecords(cleanModule);

        final combined = <BallisticRecord>[...filtered];
        final unsynced = <BallisticRecord>[];

        for (final local in localRecords) {
          final exists = combined.any((c) =>
            (c.id != null && c.id!.isNotEmpty && local.id != null && local.id!.isNotEmpty && c.id == local.id) ||
            (c.lotNo.trim() == local.lotNo.trim() &&
             c.testName.trim() == local.testName.trim() &&
             c.caliber.trim() == local.caliber.trim() &&
             c.produced == local.produced &&
             (c.timestamp == local.timestamp ||
              c.timestamp.replaceAll('T', ' ').split('.').first.trim() == local.timestamp.replaceAll('T', ' ').split('.').first.trim()))
          );
          if (!exists) {
            combined.add(local);
            unsynced.add(local);
          }
        }

        // Background sync: Upload unsynced local records up to Supabase
        if (unsynced.isNotEmpty) {
          Future.microtask(() async {
            for (final rec in unsynced) {
              try {
                await SupabaseService.insertRecord(rec, module: cleanModule);
              } catch (e) {
                print("Background sync upload failed: $e");
              }
            }
          });
        }

        if (kIsWeb) {
          overwriteWebRecords(combined, cleanModule);
        }

        if (combined.isNotEmpty) {
          return BallisticRecord.consolidateRecords(combined);
        }
      } catch (e) {
        print("Supabase load error: $e");
      }
    }

    // 2. Fallback to local storage (web localStorage or desktop CSV)
    if (kIsWeb) {
      if (!hasWebRecordsKey(cleanModule)) {
        return [];
      }
      final webList = getWebRecords(cleanModule);
      final filteredWeb = webList.where((r) {
        if (isDaily) {
          return r.module == 'Daily Test';
        } else if (isComponent) {
          return r.module == 'Component Test';
        } else {
          return r.module.isEmpty || r.module == 'Lot Acceptance Test';
        }
      }).toList();
      return BallisticRecord.consolidateRecords(filteredWeb);
    }
    try {
      final file = await ensureDailyFileExists(module: cleanModule) as File;
      final lines = await file.readAsLines();
      if (lines.length <= 1) return [];

      final List<BallisticRecord> records = [];
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            final r = BallisticRecord.fromCsvRow(line);
            if (isDaily) {
              if (r.module == 'Daily Test') records.add(r);
            } else if (isComponent) {
              if (r.module == 'Component Test') records.add(r);
            } else {
              if (r.module.isEmpty || r.module == 'Lot Acceptance Test') records.add(r);
            }
          } catch (e) {
            print("Error parsing CSV row: $e");
          }
        }
      }
      return BallisticRecord.consolidateRecords(records);
    } catch (e) {
      print("Error loading local records: $e");
      return [];
    }
  }

  // Delete record from Supabase by id or attributes
  Future<void> deleteRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.deleteRecord(
          record.id ?? '',
          module: module,
          testName: record.testName,
          timestamp: record.timestamp,
          lotNo: record.lotNumber,
        );
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
    const headers = 'Timestamp,Operators,Shift,Caliber Specification,Projectile/Lot Number,Quantity Tested,Defects Found,Remarks,Quality Status,Test Name,Pressure (Bar),Viscosity,Time of Test,Sampling Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast,Hopper No,Box No,Requirement,Barrel S.N,Barrel Type,Distance,Mean X,Max X,Min X,Range X,SD X,Mean Y,Max Y,Min Y,Range Y,SD Y,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,Mean Radius,Extraction Force Type,Extraction Force Rounds,Cartridge Temp,EPVAT Pressure Type,EPVAT Pressure Unit,EPVAT Pressure Rounds,EPVAT Mean Pressure,EPVAT Max Pressure,EPVAT Min Pressure,EPVAT Range Pressure,EPVAT SD Pressure,EPVAT P2 Mean Pressure,EPVAT P2 Max Pressure,EPVAT P2 Min Pressure,EPVAT P2 Range Pressure,EPVAT P2 SD Pressure,EPVAT P2 Pressure Rounds,EPVAT Velocity Rounds,Neck Slow,Neck Fast,Shoulder Slow,Shoulder Fast,Body Slow,Body Fast,Head Slow,Head Fast,Room Temp,Sensor 1,Sensor 2,Cyclic Weapon,Cyclic Ammo,Cyclic Val,Cyclic Min,Cyclic Max,Term Hole,Term Steel,Term Alum,Term Vel,Func L1,Func L2,Func L3,Func L4,Att Name,Att Base64,Func Defect Details,Action Time Mean,Action Time Min,Action Time Max,Action Time Range,Action Time SD,Action Time Rounds,Primer Drop Heights,Primer Fire Results,Primer Hbar,Primer SD,Primer All Fire H,Primer No Fire H,Primer Lot,Primer Supplier,Primer Insertion Depth,Propellant Supplier,Propellant Code,Propellant Lot\n';
    final buffer = StringBuffer(headers);
    for (var r in records) {
      buffer.write(r.toCsvRow());
    }
    await file.writeAsString(buffer.toString(), mode: FileMode.write, flush: true);
  }

  // Update existing record on Supabase cloud database
  Future<void> updateRecord(BallisticRecord oldRecord, BallisticRecord newRecord, {String module = 'Lot Acceptance Test'}) async {
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized && oldRecord.id != null && oldRecord.id!.isNotEmpty) {
      try {
        await SupabaseService.updateRecord(oldRecord.id!, newRecord, module: module);
      } catch (e) {
        print("Supabase update record error: $e");
      }
    }
  }

  // Clear all records for a specific module (e.g. Daily Test) locally and on Supabase
  Future<void> clearRecords({String module = 'Daily Test'}) async {
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.clearAllRecords(module: module);
      } catch (e) {
        print("Supabase clear records error: $e");
      }
    }
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

  // Load registered operators from storage (cloud-synced + local fallback with smart merging)
  Future<List<Map<String, String>>> loadOperators() async {
    final defaultOperators = [
      {'email': 'admin', 'password': 'admin123', 'role': 'admin', 'name': 'System Administrator'},
      {'email': 'manager', 'password': 'manager123', 'role': 'manager', 'name': 'Quality Manager'},
      {'email': 'supervisor', 'password': 'supervisor123', 'role': 'supervisor', 'name': 'Shift Supervisor'},
      {'email': 'technician', 'password': 'technician123', 'role': 'technician', 'name': 'Ballistics Technician'},
      {'email': 'operator', 'password': 'operator123', 'role': 'operator', 'name': 'Ahmed Said'},
      {'email': 'admin@ompc.com', 'password': 'admin', 'role': 'admin', 'name': 'System Admin'},
      {'email': 'operator@ompc.com', 'password': 'operator123', 'role': 'operator', 'name': 'Lead Operator'},
    ];

    final Map<String, Map<String, String>> merged = {};

    // 1. Seed with default baseline personnel
    for (var op in defaultOperators) {
      final key = (op['email'] ?? '').trim().toLowerCase();
      if (key.isNotEmpty) merged[key] = Map<String, String>.from(op);
    }

    // 2. Overlay local storage users so local accounts are NEVER wiped out
    if (kIsWeb) {
      final localWeb = getWebOperators();
      for (var op in localWeb) {
        final key = (op['email'] ?? '').trim().toLowerCase();
        if (key.isNotEmpty) merged[key] = Map<String, String>.from(op);
      }
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/operators.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            final List<dynamic> decoded = jsonDecode(content);
            for (var item in decoded) {
              final em = ((item['email'] ?? item['username'] ?? '') as String).trim();
              if (em.isNotEmpty) {
                merged[em.toLowerCase()] = {
                  'email': em,
                  'password': (item['password'] ?? '') as String,
                  'role': (item['role'] ?? 'operator') as String,
                  'name': (item['name'] ?? item['email'] ?? '') as String,
                };
              }
            }
          }
        }
      } catch (e) {
        print("Error reading local operators: $e");
      }
    }

    // 3. Overlay Supabase Cloud users (syncs across PCs and mobile devices)
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        final cloudOps = await SupabaseService.fetchOperatorsFromCloud();
        if (cloudOps != null && cloudOps.isNotEmpty) {
          for (var op in cloudOps) {
            final key = (op['email'] ?? '').trim().toLowerCase();
            if (key.isNotEmpty) merged[key] = Map<String, String>.from(op);
          }
        }
      } catch (e) {
        print("Supabase load operators error: $e");
      }
    }

    final combinedList = merged.values.toList();

    // 4. Save merged list locally to ensure offline operation
    if (kIsWeb) {
      for (var op in combinedList) {
        saveWebOperator(op['email'] ?? '', op['password'] ?? '', role: op['role'] ?? 'operator', name: op['name'] ?? '');
      }
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/operators.json');
        await file.writeAsString(jsonEncode(combinedList), mode: FileMode.write, flush: true);
      } catch (_) {}
    }

    // 5. Background sync: ensure cloud is fully updated with any new/merged accounts
    if (SupabaseService.isInitialized) {
      SupabaseService.saveOperatorsToCloud(combinedList);
    }

    return combinedList;
  }

  // Save new user credentials with role (syncs to both local and Supabase cloud)
  Future<void> saveOperator(String email, String password, {String role = 'operator', String name = ''}) async {
    final operators = await loadOperators();
    operators.removeWhere((op) => (op['email'] ?? '').toLowerCase() == email.toLowerCase());
    operators.add({
      'email': email,
      'password': password,
      'role': role,
      'name': name.isNotEmpty ? name : email,
    });

    // 1. Immediate local save
    if (kIsWeb) {
      saveWebOperator(email, password, role: role, name: name);
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/operators.json');
        await file.writeAsString(jsonEncode(operators), mode: FileMode.write, flush: true);
      } catch (e) {
        print("Error saving local operator file: $e");
      }
    }

    // 2. Cloud synchronization (ensures user exists across all other PCs & web)
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.saveOperatorsToCloud(operators);
      } catch (e) {
        print("Error syncing operator to Supabase: $e");
      }
    }
  }

  // Delete user credentials (updates local and cloud)
  Future<void> deleteOperator(String identifier) async {
    final operators = await loadOperators();
    operators.removeWhere((op) => (op['email'] ?? '').toLowerCase() == identifier.toLowerCase());

    if (kIsWeb) {
      deleteWebOperator(identifier);
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/operators.json');
        await file.writeAsString(jsonEncode(operators), mode: FileMode.write, flush: true);
      } catch (_) {}
    }

    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.deleteOperatorFromCloud(identifier);
        await SupabaseService.saveOperatorsToCloud(operators);
      } catch (_) {}
    }
  }

  // Edit user credentials (updates local and cloud)
  Future<void> editOperator(
    String oldIdentifier, {
    required String newEmail,
    required String newPassword,
    required String newRole,
    required String newName,
  }) async {
    final operators = await loadOperators();
    operators.removeWhere((op) => (op['email'] ?? '').toLowerCase() == oldIdentifier.toLowerCase());
    final updatedOp = {
      'email': newEmail,
      'password': newPassword,
      'role': newRole,
      'name': newName.isNotEmpty ? newName : newEmail,
    };
    operators.add(updatedOp);

    if (kIsWeb) {
      deleteWebOperator(oldIdentifier);
      saveWebOperator(newEmail, newPassword, role: newRole, name: newName);
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/operators.json');
        await file.writeAsString(jsonEncode(operators), mode: FileMode.write, flush: true);
      } catch (_) {}
    }

    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.updateOperatorInCloud(oldIdentifier, updatedOp);
      } catch (_) {}
    }
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

  // Load Admin Rules (cloud-synced + local fallback)
  Future<Map<String, dynamic>> loadRules() async {
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        final cloudRules = await SupabaseService.fetchRulesFromCloud();
        if (cloudRules != null && cloudRules.isNotEmpty) {
          if (kIsWeb) {
            saveWebRules(cloudRules);
          } else {
            try {
              final dirPath = await getDirectoryPath();
              final file = File('$dirPath/admin_rules.json');
              await file.writeAsString(jsonEncode(cloudRules), mode: FileMode.write, flush: true);
            } catch (_) {}
          }
          return cloudRules;
        }
      } catch (e) {
        print("Supabase load rules error: $e");
      }
    }

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

  // Save Admin Rules (syncs to local and cloud)
  Future<void> saveRules(Map<String, dynamic> rules) async {
    if (kIsWeb) {
      saveWebRules(rules);
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/admin_rules.json');
        await file.writeAsString(jsonEncode(rules), mode: FileMode.write, flush: true);
      } catch (_) {}
    }

    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.saveRulesToCloud(rules);
      } catch (e) {
        print("Error saving rules to Supabase: $e");
      }
    }
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

  // Load consumable inventory
  Future<List<Map<String, dynamic>>> loadConsumables() async {
    if (kIsWeb) {
      return getWebConsumables();
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/consumables_inventory.json');
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(content);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print("Error loading consumables: $e");
      return [];
    }
  }

  // Save consumable inventory
  Future<void> saveConsumables(List<Map<String, dynamic>> items) async {
    if (kIsWeb) {
      saveWebConsumables(items);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/consumables_inventory.json');
      await file.writeAsString(jsonEncode(items), mode: FileMode.write, flush: true);
    } catch (e) {
      print("Error saving consumables: $e");
    }
  }

  // Load consumable categories
  Future<List<String>> loadConsumableCategories() async {
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/consumables_categories.json');
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(content);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print("Error loading consumable categories: $e");
      return [];
    }
  }

  // Save consumable categories
  Future<void> saveConsumableCategories(List<String> categories) async {
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/consumables_categories.json');
      await file.writeAsString(jsonEncode(categories), mode: FileMode.write, flush: true);
    } catch (e) {
      print("Error saving consumable categories: $e");
    }
  }
}

