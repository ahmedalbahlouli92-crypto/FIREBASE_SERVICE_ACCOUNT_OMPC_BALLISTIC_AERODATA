import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import 'web_storage_stub.dart'
    if (dart.library.js) 'web_storage_web.dart';
import 'supabase_service.dart';
import 'epvat_formula_helper.dart';

class StorageService {
  /// Resequences non-deleted records cleanly starting from REF:01 in chronological order
  static List<BallisticRecord> resequenceReferenceNumbers(List<BallisticRecord> records) {
    if (records.isEmpty) return records;
    final sorted = List<BallisticRecord>.from(records)..sort((a, b) {
      return a.timestamp.compareTo(b.timestamp);
    });
    final List<BallisticRecord> resequenced = [];
    for (int i = 0; i < sorted.length; i++) {
      final refStr = 'REF:${(i + 1).toString().padLeft(2, '0')}';
      resequenced.add(sorted[i].copyWith(referenceNo: refStr));
    }
    return resequenced;
  }

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

  static const String fullCsvHeaders = 'Timestamp,Operators,Shift,Caliber Specification,Projectile/Lot Number,Quantity Tested,Defects Found,Remarks,Quality Status,Test Name,Pressure (Bar),Viscosity,Time of Test,Sampling Location,Mouth Slow,Mouth Fast,Primer Slow,Primer Fast,Hopper No,Box No,Requirement,Barrel S.N,Barrel Type,Distance,Mean X,Max X,Min X,Range X,SD X,Mean Y,Max Y,Min Y,Range Y,SD Y,Mean Vel,Min Vel,Max Vel,Range Vel,SD Vel,Mean Radius,Extraction Force Type,Extraction Force Rounds,Cartridge Temp,EPVAT Pressure Type,EPVAT Pressure Unit,EPVAT Pressure Rounds,EPVAT Mean Pressure,EPVAT Max Pressure,EPVAT Min Pressure,EPVAT Range Pressure,EPVAT SD Pressure,EPVAT P2 Mean Pressure,EPVAT P2 Max Pressure,EPVAT P2 Min Pressure,EPVAT P2 Range Pressure,EPVAT P2 SD Pressure,EPVAT P2 Pressure Rounds,EPVAT Velocity Rounds,Neck Slow,Neck Fast,Shoulder Slow,Shoulder Fast,Body Slow,Body Fast,Head Slow,Head Fast,Room Temp,Sensor 1,Sensor 2,Cyclic Weapon,Cyclic Ammo,Cyclic Val,Cyclic Min,Cyclic Max,Term Hole,Term Steel,Term Alum,Term Vel,Func L1,Func L2,Func L3,Func L4,Att Name,Att Base64,Func Defect Details,Action Time Mean,Action Time Min,Action Time Max,Action Time Range,Action Time SD,Action Time Rounds,Primer Drop Heights,Primer Fire Results,Primer Hbar,Primer SD,Primer All Fire H,Primer No Fire H,Primer Lot,Primer Supplier,Primer Insertion Depth,Propellant Supplier,Propellant Code,Propellant Lot,Propellant Charge,Is Retest,Retest Timestamp,Retest Operator,Retest Notes,Retest Status,Original Status,Record ID\n';

  // Ensure daily CSV file exists with standard quality control headers
  Future<dynamic> ensureDailyFileExists({String module = 'Lot Acceptance Test'}) async {
    if (kIsWeb) return null;
    final dirPath = await getDirectoryPath();
    final fileName = getDailyFileName(module: module);
    final file = File('$dirPath/$fileName');
    
    if (!await file.exists()) {
      await file.writeAsString(fullCsvHeaders, mode: FileMode.write, flush: true);
    }
    return file;
  }

  // --- Offline Pending Sync & Tombstone Tracking ---
  Future<Set<String>> _getPendingSyncIds() async {
    if (kIsWeb) {
      return getWebPendingSyncIds();
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/pending_sync.json');
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _addPendingSyncId(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;
    final current = await _getPendingSyncIds();
    current.add(cleanId);
    if (kIsWeb) {
      saveWebPendingSyncIds(current);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/pending_sync.json');
      await file.writeAsString(jsonEncode(current.toList()), mode: FileMode.write, flush: true);
    } catch (_) {}
  }

  Future<void> _removePendingSyncId(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;
    final current = await _getPendingSyncIds();
    if (current.remove(cleanId)) {
      if (kIsWeb) {
        saveWebPendingSyncIds(current);
        return;
      }
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/pending_sync.json');
        await file.writeAsString(jsonEncode(current.toList()), mode: FileMode.write, flush: true);
      } catch (_) {}
    }
  }

  // Memory cache for cloud deleted keys to avoid redundant network hits during parallel module loading
  Set<String>? _cachedDeletedKeys;
  DateTime? _lastDeletedKeysFetch;

  Future<Set<String>> _getAllDeletedKeys({bool localOnly = false}) async {
    final Set<String> keys = {};
    if (kIsWeb) {
      keys.addAll(getWebDeletedRecords());
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/deleted_records.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is List) {
            keys.addAll(decoded.map((e) => e.toString()));
          }
        }
      } catch (_) {}
    }

    if (localOnly) {
      if (_cachedDeletedKeys != null) {
        keys.addAll(_cachedDeletedKeys!);
      }
      return keys;
    }

    if (SupabaseService.isInitialized) {
      // Re-use cached deleted keys if fetched within the last 15 seconds
      if (_cachedDeletedKeys != null &&
          _lastDeletedKeysFetch != null &&
          DateTime.now().difference(_lastDeletedKeysFetch!).inSeconds < 15) {
        return Set<String>.from(_cachedDeletedKeys!);
      }
      try {
        final cloudDeleted = await SupabaseService.fetchDeletedRecordsFromCloud();
        _cachedDeletedKeys = cloudDeleted.toSet();
        _lastDeletedKeysFetch = DateTime.now();
        // Authoritative reconciliation: the cloud deleted records list is the true ground truth.
        // We sync local storage with cloudDeleted to purge any false local tombstones.
        if (kIsWeb) {
          saveWebDeletedRecords(_cachedDeletedKeys!);
        } else {
          final dirPath = await getDirectoryPath();
          final file = File('$dirPath/deleted_records.json');
          await file.writeAsString(jsonEncode(_cachedDeletedKeys!.toList()), mode: FileMode.write, flush: true);
        }
        return Set<String>.from(_cachedDeletedKeys!);
      } catch (_) {}
    }
    return keys;
  }

  Future<void> _addDeletedKeys(List<String> newKeys) async {
    final validKeys = newKeys.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    if (validKeys.isEmpty) return;

    final keys = await _getAllDeletedKeys();
    keys.addAll(validKeys);

    if (kIsWeb) {
      saveWebDeletedRecords(keys);
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/deleted_records.json');
        await file.writeAsString(jsonEncode(keys.toList()), mode: FileMode.write, flush: true);
      } catch (_) {}
    }
  }

  bool _isRecordDeleted(BallisticRecord r, Set<String> deletedKeys) {
    if (deletedKeys.isEmpty) return false;
    if (r.id != null && r.id!.isNotEmpty && deletedKeys.contains(r.id!.trim())) {
      return true;
    }
    final sig1 = '${r.timestamp.trim()}|${r.lotNo.trim()}|${r.testName.trim()}';
    if (deletedKeys.contains(sig1)) return true;
    if (r.hopperNo.trim().isNotEmpty) {
      final sig2 = '${r.timestamp.trim()}|${r.hopperNo.trim()}|${r.testName.trim()}';
      if (deletedKeys.contains(sig2)) return true;
    }
    return false;
  }

  Future<void> _purgeRecordFromAllLocalCsvFiles(BallisticRecord record, String cleanModule) async {
    if (kIsWeb) return;
    try {
      final dirPath = await getDirectoryPath();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      final targetId = (record.id ?? '').trim();
      final targetTs = record.timestamp.trim();
      final targetLot = record.lotNo.trim();
      final targetHop = record.hopperNo.trim();
      final targetTest = record.testName.trim();
      final targetCal = record.caliber.trim();

      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.csv')) {
          try {
            final lines = await entity.readAsLines();
            if (lines.length <= 1) continue;
            bool modified = false;
            final newLines = <String>[lines.first];
            for (int i = 1; i < lines.length; i++) {
              final line = lines[i].trim();
              if (line.isEmpty) continue;
              try {
                final r = BallisticRecord.fromCsvRow(line);
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
                if (idMatch || attrMatch) {
                  modified = true;
                  continue;
                }
              } catch (_) {}
              newLines.add(lines[i]);
            }
            if (modified) {
              await entity.writeAsString('${newLines.join('\n')}\n', mode: FileMode.write, flush: true);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print("Error purging record from local CSV files: $e");
    }
  }

  // Append new ballistic test log entry to Supabase and local cache
  Future<BallisticRecord> saveRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    final cleanModule = (module == 'Daily Test' || module == 'Daily Test Report')
        ? 'Daily Test'
        : (module == 'Component Test' ? 'Component Test' : 'Lot Acceptance Test');
    final String assignedId = (record.id != null && record.id!.isNotEmpty) ? record.id! : BallisticRecord.generateUuid();
    String refNo = record.referenceNo;
    if (refNo.isEmpty) {
      final refNum = await getNextReferenceNumber();
      refNo = 'REF:${refNum.toString().padLeft(2, '0')}';
    }
    BallisticRecord recordToSave = record.copyWith(id: assignedId, module: cleanModule, referenceNo: refNo);

    // Track as pending sync until confirmed by cloud
    await _addPendingSyncId(assignedId);

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
        if (inserted != null) {
          // Cloud confirmed insert: remove from pending sync
          await _removePendingSyncId(assignedId);
          if (inserted.id != null && inserted.id!.isNotEmpty) {
            recordToSave = inserted;
            if (kIsWeb) {
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
        }
      } catch (e) {
        print("Supabase save error (saved to local cache, will sync later): $e");
      }
    }
    return recordToSave;
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
                    BallisticRecord r = BallisticRecord.fromCsvRow(line);
                    if (fileName.startsWith('daily_test_report') || isDaily) {
                      if (r.module.isEmpty || r.module == 'Lot Acceptance Test') {
                        r = r.copyWith(module: 'Daily Test');
                      }
                      if (r.module == 'Daily Test' || r.module == 'Daily Test Report') {
                        if (r.hopperNo.isEmpty && r.lotNo.isNotEmpty) {
                          r = r.copyWith(hopperNo: r.lotNo);
                        }
                        records.add(r);
                      }
                    } else if (fileName.startsWith('component_test_report') || isComponent) {
                      if (r.module.isEmpty || r.module == 'Lot Acceptance Test') {
                        r = r.copyWith(module: 'Component Test');
                      }
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
  Future<List<BallisticRecord>> loadRecords({String module = 'Lot Acceptance Test', bool localOnly = false}) async {
    final cleanModule = (module == 'Daily Test' || module == 'Daily Test Report')
        ? 'Daily Test'
        : (module == 'Component Test' ? 'Component Test' : 'Lot Acceptance Test');
    final bool isDaily = cleanModule == 'Daily Test';
    final bool isComponent = cleanModule == 'Component Test';

    // Fast-path: local only for instant app startup
    final deletedKeys = await _getAllDeletedKeys(localOnly: localOnly);

    if (localOnly) {
      final List<BallisticRecord> rawLocal = kIsWeb
          ? getWebRecords(cleanModule)
          : await _loadAllLocalCsvRecords(cleanModule);
      final filtered = rawLocal.where((r) {
        if (_isRecordDeleted(r, deletedKeys)) return false;
        if (isDaily) {
          return r.module == 'Daily Test' || r.module == 'Daily Test Report';
        } else if (isComponent) {
          return r.module == 'Component Test';
        } else {
          return r.module.isEmpty || r.module == 'Lot Acceptance Test';
        }
      }).map((r) {
        if (isDaily && r.hopperNo.isEmpty && r.lotNo.isNotEmpty) {
          return r.copyWith(hopperNo: r.lotNo, module: 'Daily Test');
        }
        return r;
      }).toList();
      return resequenceReferenceNumbers(BallisticRecord.consolidateRecords(filtered));
    }

    // Ensure Supabase is initialized
    await SupabaseService.ensureInitialized();

    // 1. Attempt to fetch from Supabase Cloud Database
    if (SupabaseService.isInitialized) {
      try {
        final cloudRecords = await SupabaseService.fetchRecords(module: cleanModule);
        final filteredCloud = cloudRecords.where((r) {
          if (_isRecordDeleted(r, deletedKeys)) return false;
          if (isDaily) {
            return r.module == 'Daily Test' || r.module == 'Daily Test Report';
          } else if (isComponent) {
            return r.module == 'Component Test';
          } else {
            return r.module.isEmpty || r.module == 'Lot Acceptance Test';
          }
        }).map((r) {
          if (isDaily && r.hopperNo.isEmpty && r.lotNo.isNotEmpty) {
            return r.copyWith(hopperNo: r.lotNo, module: 'Daily Test');
          }
          return r;
        }).toList();

        // Merge with locally cached records (web or desktop CSV)
        final List<BallisticRecord> rawLocal = kIsWeb
            ? getWebRecords(cleanModule)
            : await _loadAllLocalCsvRecords(cleanModule);

        final pendingSyncIds = await _getPendingSyncIds();
        final combined = <BallisticRecord>[...filteredCloud];
        final unsynced = <BallisticRecord>[];
        final recordsToPurgeLocally = <BallisticRecord>[];

        for (final local in rawLocal) {
          if (_isRecordDeleted(local, deletedKeys)) {
            recordsToPurgeLocally.add(local);
            continue;
          }

          final idx = combined.indexWhere((c) {
            if (c.id != null && c.id!.isNotEmpty && local.id != null && local.id!.isNotEmpty && c.id == local.id) {
              return true;
            }
            final matchTest = c.testName.trim() == local.testName.trim();
            final matchCal = c.caliber.trim() == local.caliber.trim();
            final matchLot = c.lotNo.trim().isNotEmpty && local.lotNo.trim().isNotEmpty && c.lotNo.trim() == local.lotNo.trim();
            final matchHop = c.hopperNo.trim().isNotEmpty && local.hopperNo.trim().isNotEmpty && c.hopperNo.trim() == local.hopperNo.trim();
            final matchTs = (c.timestamp == local.timestamp ||
              c.timestamp.replaceAll('T', ' ').split('.').first.trim() == local.timestamp.replaceAll('T', ' ').split('.').first.trim());
            return matchTest && matchCal && matchTs && (matchLot || matchHop || (c.lotNo.trim() == local.lotNo.trim()));
          });

          if (idx == -1) {
            // Local record is NOT in cloud records.
            // Only preserve and queue if it's a genuine offline-created record or in pendingSyncIds
            final bool isPending = local.id == null || local.id!.isEmpty || pendingSyncIds.contains(local.id);
            if (isPending) {
              combined.add(local);
              unsynced.add(local);
            }
          } else {
            // Local record matches a cloud record.
            // Cloud is authoritative unless this client has an explicit offline edit waiting to sync
            final c = combined[idx];
            final bool isPendingOffline = (local.id != null && pendingSyncIds.contains(local.id)) ||
                (c.id != null && pendingSyncIds.contains(c.id));
            if (isPendingOffline) {
              combined[idx] = local;
              unsynced.add(local);
            } else {
              // Cloud record is authoritative!
              combined[idx] = c;
            }
          }
        }

        // Auto-correct any EPVAT records whose status was previously 'Rejected' under obsolete rules but now pass all admin formulas
        final finalizedCombined = await _autoCorrectEpvatStatus(combined, syncModule: cleanModule);

        // Background sync: Upload genuine unsynced offline records up to Supabase
        if (unsynced.isNotEmpty) {
          Future.microtask(() async {
            for (final rec in unsynced) {
              try {
                if (rec.id != null && rec.id!.isNotEmpty) {
                  final ok = await SupabaseService.updateRecord(rec.id!, rec, module: cleanModule);
                  if (!ok) {
                    await SupabaseService.insertRecord(rec, module: cleanModule);
                  }
                  await _removePendingSyncId(rec.id!);
                } else {
                  final inserted = await SupabaseService.insertRecord(rec, module: cleanModule);
                  if (inserted != null && inserted.id != null) {
                    await _removePendingSyncId(inserted.id!);
                  }
                }
              } catch (e) {
                print("Background sync upload failed: $e");
              }
            }
          });
        }

        // Clean local cache so deleted records never persist in localStorage or CSV
        if (kIsWeb) {
          overwriteWebRecords(finalizedCombined, cleanModule);
        } else if (recordsToPurgeLocally.isNotEmpty) {
          for (final purged in recordsToPurgeLocally) {
            await _purgeRecordFromAllLocalCsvFiles(purged, cleanModule);
          }
        }

        if (finalizedCombined.isNotEmpty) {
          return resequenceReferenceNumbers(BallisticRecord.consolidateRecords(finalizedCombined));
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
        if (_isRecordDeleted(r, deletedKeys)) return false;
        if (isDaily) {
          return r.module == 'Daily Test' || r.module == 'Daily Test Report';
        } else if (isComponent) {
          return r.module == 'Component Test';
        } else {
          return r.module.isEmpty || r.module == 'Lot Acceptance Test';
        }
      }).map((r) {
        if (isDaily && r.hopperNo.isEmpty && r.lotNo.isNotEmpty) {
          return r.copyWith(hopperNo: r.lotNo, module: 'Daily Test');
        }
        return r;
      }).toList();
      final correctedWeb = await _autoCorrectEpvatStatus(filteredWeb);
      return resequenceReferenceNumbers(BallisticRecord.consolidateRecords(correctedWeb));
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
            BallisticRecord r = BallisticRecord.fromCsvRow(line);
            if (_isRecordDeleted(r, deletedKeys)) continue;
            if (isDaily) {
              if (r.module.isEmpty || r.module == 'Lot Acceptance Test') {
                r = r.copyWith(module: 'Daily Test');
              }
              if (r.module == 'Daily Test' || r.module == 'Daily Test Report') {
                if (r.hopperNo.isEmpty && r.lotNo.isNotEmpty) {
                  r = r.copyWith(hopperNo: r.lotNo);
                }
                records.add(r);
              }
            } else if (isComponent) {
              if (r.module.isEmpty || r.module == 'Lot Acceptance Test') {
                r = r.copyWith(module: 'Component Test');
              }
              if (r.module == 'Component Test') records.add(r);
            } else {
              if (r.module.isEmpty || r.module == 'Lot Acceptance Test') records.add(r);
            }
          } catch (e) {
            print("Error parsing CSV row: $e");
          }
        }
      }
      final correctedLocal = await _autoCorrectEpvatStatus(records);
      return resequenceReferenceNumbers(BallisticRecord.consolidateRecords(correctedLocal));
    } catch (e) {
      print("Error loading local records: $e");
      return [];
    }
  }

  Future<List<BallisticRecord>> _autoCorrectEpvatStatus(List<BallisticRecord> records, {String? syncModule}) async {
    try {
      final rules = await loadRules(localOnly: true);
      final epvRules = rules['epvat'] ?? {};
      final customFormulas = Map<String, dynamic>.from(epvRules['custom_formulas'] ?? {});
      if (customFormulas.isEmpty) return records;

      final updatedList = <BallisticRecord>[];
      for (final r in records) {
        if ((r.testName.toLowerCase().contains('epvat') || r.testName.toLowerCase().contains('propellant')) &&
            r.status.toLowerCase().contains('reject')) {
          final calculated = EpvatFormulaHelper.calculateEpvatRecordStatus(r, customFormulas);
          if (calculated == 'Approved') {
            final updatedRec = r.copyWith(status: 'Approved');
            updatedList.add(updatedRec);
            if (syncModule != null && updatedRec.id != null && updatedRec.id!.isNotEmpty) {
              SupabaseService.updateRecord(updatedRec.id!, updatedRec, module: syncModule);
            }
            continue;
          }
        }
        updatedList.add(r);
      }
      return updatedList;
    } catch (_) {
      return records;
    }
  }

  // Delete record from Supabase and local cache with tombstone protection
  Future<void> deleteRecord(BallisticRecord record, {String module = 'Lot Acceptance Test'}) async {
    final cleanModule = (module == 'Daily Test' || module == 'Daily Test Report')
        ? 'Daily Test'
        : (module == 'Component Test' ? 'Component Test' : 'Lot Acceptance Test');

    final recId = (record.id ?? '').trim();
    final sig1 = '${record.timestamp.trim()}|${record.lotNo.trim()}|${record.testName.trim()}';
    final sig2 = record.hopperNo.trim().isNotEmpty
        ? '${record.timestamp.trim()}|${record.hopperNo.trim()}|${record.testName.trim()}'
        : '';

    // 1. Record tombstone locally and in cloud so no client ever resurrects this record
    await _addDeletedKeys([if (recId.isNotEmpty) recId, sig1, if (sig2.isNotEmpty) sig2]);

    // 2. Remove from pending sync if it was queued
    if (recId.isNotEmpty) {
      await _removePendingSyncId(recId);
    }

    // 3. Purge immediately from local storage
    if (kIsWeb) {
      deleteWebRecord(record, cleanModule);
    } else {
      await _purgeRecordFromAllLocalCsvFiles(record, cleanModule);
    }

    // 4. Delete from Supabase and record cloud tombstone
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.deleteRecord(
          recId,
          module: cleanModule,
          testName: record.testName,
          timestamp: record.timestamp,
          lotNo: record.lotNumber,
          hopperNo: record.hopperNo,
        );
        await SupabaseService.recordCloudDeletion(
          id: recId,
          signature: sig1,
          signature2: sig2.isNotEmpty ? sig2 : null,
        );
      } catch (e) {
        print("Supabase delete error: $e");
      }
    }
  }

  // Overwrite daily CSV log with list of records (e.g. after deletion or edit)
  Future<void> overwriteRecords(List<BallisticRecord> records, {String module = 'Lot Acceptance Test'}) async {
    final cleanModule = (module == 'Daily Test' || module == 'Daily Test Report')
        ? 'Daily Test'
        : (module == 'Component Test' ? 'Component Test' : 'Lot Acceptance Test');

    if (kIsWeb) {
      overwriteWebRecords(records, cleanModule);
      return;
    }
    final file = await ensureDailyFileExists(module: cleanModule) as File;
    final buffer = StringBuffer(fullCsvHeaders);
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
    final cleanModule = (module == 'Daily Test' || module == 'Daily Test Report')
        ? 'Daily Test'
        : (module == 'Component Test' ? 'Component Test' : 'Lot Acceptance Test');

    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.clearAllRecords(module: cleanModule);
      } catch (e) {
        print("Supabase clear records error: $e");
      }
    }
    if (kIsWeb) {
      clearWebRecords(cleanModule);
      return;
    }

    // On desktop/mobile: purge ALL CSV files matching this module prefix
    try {
      final dirPath = await getDirectoryPath();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final prefix = cleanModule == 'Lot Acceptance Test'
            ? 'ballistic_report'
            : (cleanModule == 'Component Test' ? 'component_test_report' : 'daily_test_report');
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.csv')) {
            final fileName = entity.uri.pathSegments.last;
            if (fileName.startsWith(prefix)) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      print("Error clearing local CSV files: $e");
    }

    await ensureDailyFileExists(module: cleanModule);
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
  Future<List<Map<String, String>>> loadOperators({bool localOnly = false}) async {
    final defaultOperators = [
      {'email': 'admin', 'password': 'admin123', 'role': 'admin', 'name': 'System Administrator'},
      {'email': 'manager', 'password': 'manager123', 'role': 'manager', 'name': 'Quality Manager'},
      {'email': 'supervisor', 'password': 'supervisor123', 'role': 'supervisor', 'name': 'Shift Supervisor'},
      {'email': 'technician', 'password': 'technician123', 'role': 'technician', 'name': 'Ballistics Technician'},
      {'email': 'operator', 'password': 'operator123', 'role': 'operator', 'name': 'Ahmed Said'},
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
                  'signature_base64': (item['signature_base64'] ?? '') as String,
                };
              }
            }
          }
        }
      } catch (e) {
        print("Error reading local operators: $e");
      }
    }

    if (localOnly) {
      return merged.values.toList();
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
        saveWebOperator(
          op['email'] ?? '',
          op['password'] ?? '',
          role: op['role'] ?? 'operator',
          name: op['name'] ?? '',
          signatureBase64: op['signature_base64'] ?? '',
        );
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
  Future<void> saveOperator(String email, String password, {String role = 'operator', String name = '', String signatureBase64 = ''}) async {
    final operators = await loadOperators();
    operators.removeWhere((op) => (op['email'] ?? '').toLowerCase() == email.toLowerCase());
    operators.add({
      'email': email,
      'password': password,
      'role': role,
      'name': name.isNotEmpty ? name : email,
      'signature_base64': signatureBase64,
    });

    // 1. Immediate local save
    if (kIsWeb) {
      saveWebOperator(email, password, role: role, name: name, signatureBase64: signatureBase64);
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
    String newSignatureBase64 = '',
  }) async {
    final operators = await loadOperators();
    final existingOp = operators.firstWhere(
      (op) => (op['email'] ?? '').toLowerCase() == oldIdentifier.toLowerCase(),
      orElse: () => {},
    );
    final effectiveSig = newSignatureBase64.isNotEmpty ? newSignatureBase64 : (existingOp['signature_base64'] ?? '');

    operators.removeWhere((op) => (op['email'] ?? '').toLowerCase() == oldIdentifier.toLowerCase());
    final updatedOp = {
      'email': newEmail,
      'password': newPassword,
      'role': newRole,
      'name': newName.isNotEmpty ? newName : newEmail,
      'signature_base64': effectiveSig,
    };
    operators.add(updatedOp);

    if (kIsWeb) {
      deleteWebOperator(oldIdentifier);
      saveWebOperator(newEmail, newPassword, role: newRole, name: newName, signatureBase64: effectiveSig);
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
      final s1 = r.epvatSensor1.trim().toLowerCase();
      final s2 = r.epvatSensor2.trim().toLowerCase();
      final wSn = r.cyclicRateWeaponType.trim().toLowerCase();
      
      if (bSn == cleanSerial || gSn == cleanSerial || s1 == cleanSerial || s2 == cleanSerial || wSn.contains(cleanSerial)) {
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

  // Load Admin Rules (cloud-synced + local fallback with smart merge)
  Future<Map<String, dynamic>> loadRules({bool localOnly = false}) async {
    // 1. Load local rules first as baseline
    Map<String, dynamic> localRules = {};
    if (kIsWeb) {
      localRules = getWebRules();
    } else {
      try {
        final dirPath = await getDirectoryPath();
        final file = File('$dirPath/admin_rules.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          localRules = jsonDecode(content) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    if (localOnly) {
      return localRules;
    }

    // 2. Fetch cloud rules if connected
    await SupabaseService.ensureInitialized();
    if (SupabaseService.isInitialized) {
      try {
        final cloudRules = await SupabaseService.fetchRulesFromCloud();
        if (cloudRules != null && cloudRules.isNotEmpty) {
          final mergedRules = Map<String, dynamic>.from(cloudRules);

          // Smart merge: preserve local custom_formulas (including empty lists when rules are deleted)
          final localEpv = localRules['epvat'];
          final cloudEpv = mergedRules['epvat'];
          if (localEpv is Map && localEpv['custom_formulas'] is Map && (localEpv['custom_formulas'] as Map).isNotEmpty) {
            final Map<String, dynamic> mergedFormulas = {};
            // Start with local
            (localEpv['custom_formulas'] as Map).forEach((k, v) {
              if (v is List) mergedFormulas[k.toString()] = v;
            });
            // Overlay cloud if any
            if (cloudEpv is Map && cloudEpv['custom_formulas'] is Map) {
              (cloudEpv['custom_formulas'] as Map).forEach((k, v) {
                if (v is List) mergedFormulas[k.toString()] = v;
              });
            }
            if (cloudEpv is Map) {
              final newCloudEpv = Map<String, dynamic>.from(cloudEpv);
              newCloudEpv['custom_formulas'] = mergedFormulas;
              mergedRules['epvat'] = newCloudEpv;
            }
          }

          // Smart merge: preserve unified GP6 transducers
          final localGp6 = localRules['gp6_transducers'];
          if (localGp6 is List && localGp6.isNotEmpty && (mergedRules['gp6_transducers'] == null || (mergedRules['gp6_transducers'] as List).isEmpty)) {
            mergedRules['gp6_transducers'] = localGp6;
          }

          if (kIsWeb) {
            saveWebRules(mergedRules);
          } else {
            try {
              final dirPath = await getDirectoryPath();
              final file = File('$dirPath/admin_rules.json');
              await file.writeAsString(jsonEncode(mergedRules), mode: FileMode.write, flush: true);
            } catch (_) {}
          }
          return mergedRules;
        }
      } catch (e) {
        print("Supabase load rules error: $e");
      }
    }

    if (localRules.isNotEmpty) {
      return localRules;
    }

    if (kIsWeb) {
      return getWebRules();
    }
    return {};
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
  Future<void> saveFormDraft(Map<String, dynamic> draft, {String? scope}) async {
    if (kIsWeb) {
      saveWebFormDraft(draft, scope: scope);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final cleanScope = (scope != null && scope.isNotEmpty) ? '_${scope.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}' : '';
      final file = File('$dirPath/form_draft$cleanScope.json');
      await file.writeAsString(jsonEncode(draft), mode: FileMode.write, flush: true);
    } catch (e) {
      print("Error saving form draft: $e");
    }
  }

  // Load form draft locally
  Future<Map<String, dynamic>?> loadFormDraft({String? scope}) async {
    if (kIsWeb) {
      return getWebFormDraft(scope: scope);
    }
    try {
      final dirPath = await getDirectoryPath();
      final cleanScope = (scope != null && scope.isNotEmpty) ? '_${scope.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}' : '';
      final file = File('$dirPath/form_draft$cleanScope.json');
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
  Future<void> clearFormDraft({String? scope}) async {
    if (kIsWeb) {
      clearWebFormDraft(scope: scope);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final cleanScope = (scope != null && scope.isNotEmpty) ? '_${scope.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}' : '';
      final file = File('$dirPath/form_draft$cleanScope.json');
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

  // Persist and restore active test module across sessions
  String? loadActiveModule() {
    if (kIsWeb) return getWebActiveModule();
    return null;
  }

  void saveActiveModule(String module) {
    if (kIsWeb) saveWebActiveModule(module);
  }

  // Sequential Reference Number Counter for Tests - Based on Date of the Report Across All Modules & Tests
  Future<int> getNextReferenceNumber([DateTime? date]) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    // Scan existing records across all modules on this date to guarantee no collisions
    int maxExisting = 0;
    try {
      final allRecords = <BallisticRecord>[];
      final lots = await loadRecords(module: 'Lot Acceptance Test');
      final daily = await loadRecords(module: 'Daily Test');
      final comp = await loadRecords(module: 'Component Test');
      allRecords.addAll(lots);
      allRecords.addAll(daily);
      allRecords.addAll(comp);

      for (final r in allRecords) {
        final ts = r.timestamp.trim();
        final testTime = r.testTime.trim();
        bool isSameDate = ts.startsWith(dateStr) || testTime.startsWith(dateStr);
        if (!isSameDate) {
          final d = DateTime.tryParse(ts);
          if (d != null && DateFormat('yyyy-MM-dd').format(d) == dateStr) {
            isSameDate = true;
          }
        }
        if (isSameDate && r.referenceNo.isNotEmpty) {
          final match = RegExp(r'\d+').firstMatch(r.referenceNo);
          if (match != null) {
            final num = int.tryParse(match.group(0)!) ?? 0;
            if (num > maxExisting) maxExisting = num;
          }
        }
      }
    } catch (_) {}

    if (kIsWeb) {
      int current = getWebRefCounterForDate(dateStr);
      if (maxExisting > current) current = maxExisting;
      current++;
      saveWebRefCounterForDate(dateStr, current);
      return current;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/test_reference_counter_$dateStr.json');
      int current = 0;
      if (await file.exists()) {
        final content = await file.readAsString();
        current = int.tryParse(content.trim()) ?? 0;
      }
      if (maxExisting > current) current = maxExisting;
      current++;
      await file.writeAsString(current.toString(), mode: FileMode.write, flush: true);
      return current;
    } catch (e) {
      return maxExisting + 1;
    }
  }

  // Witness Storage: Load registered lots
  Future<List<Map<String, dynamic>>> loadWitnessStorageLots() async {
    if (kIsWeb) {
      return getWebWitnessLots();
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/witness_storage_lots.json');
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(content);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print("Error loading witness storage lots: $e");
      return [];
    }
  }

  // Witness Storage: Save registered lots
  Future<void> saveWitnessStorageLots(List<Map<String, dynamic>> lots) async {
    if (kIsWeb) {
      saveWebWitnessLots(lots);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/witness_storage_lots.json');
      await file.writeAsString(jsonEncode(lots), mode: FileMode.write, flush: true);
    } catch (e) {
      print("Error saving witness storage lots: $e");
    }
  }

  // Witness Storage: Load consumption records
  Future<List<Map<String, dynamic>>> loadWitnessStorageConsumptions() async {
    if (kIsWeb) {
      return getWebWitnessConsumptions();
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/witness_storage_consumptions.json');
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(content);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print("Error loading witness storage consumptions: $e");
      return [];
    }
  }

  // Witness Storage: Save consumption records
  Future<void> saveWitnessStorageConsumptions(List<Map<String, dynamic>> consumptions) async {
    if (kIsWeb) {
      saveWebWitnessConsumptions(consumptions);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/witness_storage_consumptions.json');
      await file.writeAsString(jsonEncode(consumptions), mode: FileMode.write, flush: true);
    } catch (e) {
      print("Error saving witness storage consumptions: $e");
    }
  }

  // Equipment Fleet Issue Reports
  Future<List<Map<String, dynamic>>> loadEquipmentIssues() async {
    if (kIsWeb) {
      return getWebEquipmentIssues();
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/equipment_issues.json');
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(content);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print("Error loading equipment issues: $e");
      return [];
    }
  }

  Future<void> saveEquipmentIssues(List<Map<String, dynamic>> issues) async {
    if (kIsWeb) {
      saveWebEquipmentIssues(issues);
      return;
    }
    try {
      final dirPath = await getDirectoryPath();
      final file = File('$dirPath/equipment_issues.json');
      await file.writeAsString(jsonEncode(issues), mode: FileMode.write, flush: true);
    } catch (e) {
      print("Error saving equipment issues: $e");
    }
  }

  Future<void> addEquipmentIssue(Map<String, dynamic> issue) async {
    final issues = await loadEquipmentIssues();
    issues.insert(0, issue);
    await saveEquipmentIssues(issues);
  }
}

