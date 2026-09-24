import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import '../services/attachment_helper.dart';
import '../services/epvat_formula_helper.dart';
import '../services/storage_service.dart';

/// Formatter restricting Action Time inputs to at most 2 digits before decimal (supports 00.000, 1.5, 12.345)
class ActionTimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    // Allow at most 2 digits before decimal point, and up to 3 digits after decimal point
    final regExp = RegExp(r'^\d{0,2}(\.\d{0,3})?$');
    if (regExp.hasMatch(text)) {
      return newValue;
    }
    return oldValue;
  }
}

class EntryTab extends StatefulWidget {
  final String currentModule;
  final Future<void> Function(BallisticRecord) onSubmit;
  final String loggedInUser;
  final String initialCaliber;
  final String initialTestName;
  final ValueChanged<String> onCaliberChanged;
  final ValueChanged<String> onTestNameChanged;
  final Map<String, dynamic> adminRules;
  final List<BallisticRecord> records;
  final List<BallisticRecord> componentPrimerRecords;
  final List<BallisticRecord> componentPropellantRecords;
  final String userRole;

  const EntryTab({
    Key? key,
    required this.currentModule,
    required this.onSubmit,
    this.loggedInUser = '',
    this.records = const [],
    this.componentPrimerRecords = const [],
    this.componentPropellantRecords = const [],
    this.userRole = 'Operator',
    required this.initialCaliber,
    required this.initialTestName,
    required this.onCaliberChanged,
    required this.onTestNameChanged,
    required this.adminRules,
  }) : super(key: key);

  static const List<String> calibers = [
    '5.56x45 SS109',
    '5.56x45 M193',
    '5.56x45 .223 69 grains',
    '5.56x45 .223 55 grains',
    '5.56x45 .223 77 grains',
    '5.56x45 M200 Blank',
    '7.62x51 M80',
    '7.62x51 .308',
    '7.62x51 M82',
    '9x19mm Para',
    '9x19mm Luger',
    '9x19mm Match',
    '9x19mm 124 grains CMJ',
  ];

  static const List<String> testNames = [
    'Waterproof Test',
    'Extraction Force Test',
    'Accuracy Test',
    'EPVAT test',
    'Function Test',
    'Residual Stress Test',
    'Terminal Effect Test',
    'Firing Rate Cycle Test',
    'Primer Sensitivity Test',
    'Propellant Test',
  ];

  @override
  _EntryTabState createState() => _EntryTabState();
}

class _EntryTabState extends State<EntryTab> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final _gp6SerialController = TextEditingController();

  // Auto-jump GlobalKeys and FocusNodes for required field validation
  final GlobalKey _operatorFieldKey = GlobalKey();
  final GlobalKey _shiftFieldKey = GlobalKey();
  final GlobalKey _testTimeFieldKey = GlobalKey();
  final GlobalKey _caliberFieldKey = GlobalKey();
  final GlobalKey _lotFieldKey = GlobalKey();
  final GlobalKey _producedFieldKey = GlobalKey();
  final GlobalKey _barrelFieldKey = GlobalKey();
  final GlobalKey _gp6FieldKey = GlobalKey();
  final GlobalKey _weaponFieldKey = GlobalKey();
  final GlobalKey _distanceFieldKey = GlobalKey();
  final GlobalKey _roomTempFieldKey = GlobalKey();

  final FocusNode _operatorFocusNode = FocusNode();
  final FocusNode _testTimeFocusNode = FocusNode();
  final FocusNode _lotFocusNode = FocusNode();
  final FocusNode _producedFocusNode = FocusNode();
  final FocusNode _distanceFocusNode = FocusNode();
  final FocusNode _barrelFocusNode = FocusNode();
  final FocusNode _gp6FocusNode = FocusNode();
  final FocusNode _weaponFocusNode = FocusNode();
  final FocusNode _roomTempFocusNode = FocusNode();
  
  final _operatorsController = TextEditingController();
  final _lotController = TextEditingController();
  final _lotThreeDigitsController = TextEditingController();
  late final TextEditingController _lotYearController = TextEditingController(text: (DateTime.now().year % 100).toString().padLeft(2, '0'));
  final _hopperThreeDigitsController = TextEditingController();
  late final TextEditingController _hopperYearController = TextEditingController(text: (DateTime.now().year % 100).toString().padLeft(2, '0'));
  final _producedController = TextEditingController();
  final _defectsController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _requirementController = TextEditingController();
  final _pressureController = TextEditingController();
  final _viscosityController = TextEditingController();
  final _testTimeController = TextEditingController();

  final _primerInsertionDepthController = TextEditingController();
  final _primerLotController = TextEditingController();
  final _propellantLotController = TextEditingController();
  final _propellantChargeController = TextEditingController();
  final _propellantCodeController = TextEditingController(text: 'D-073.4');
  String _primerSupplier = 'CBC';
  String _propellantSupplier = 'Explosia';
  String? _selectedComponentPrimerLot;
  String? _selectedComponentPropellantLot;
  final List<String> _propellantCodes = const [
    'D-073.4',
    'D-073.5',
    'D-073.6',
    'PB-540',
    'S060',
    'S062',
    'S070',
    'Other',
  ];

  List<String> get _currentSupplierPropellantCodes {
    final supplierCodesMap = widget.adminRules['propellant_supplier_codes'];
    if (supplierCodesMap is Map && supplierCodesMap.containsKey(_propellantSupplier)) {
      final list = List<String>.from(supplierCodesMap[_propellantSupplier] ?? []);
      if (list.isNotEmpty) {
        if (!list.contains('Other')) return [...list, 'Other'];
        return list;
      }
    }
    if (_propellantSupplier == 'Explosia') {
      return ['D-073.4', 'D-073.5', 'D-073.6', 'S060', 'S062', 'S070', 'Other'];
    } else if (_propellantSupplier == 'PB Clermont') {
      return ['PB-540', 'PCL 507', 'PCL 511', 'Other'];
    } else if (_propellantSupplier == 'Gold Force') {
      return ['SP9', 'GF-201', 'GF-302', 'Other'];
    } else if (_propellantSupplier == 'Milan') {
      return ['Bofors RP3', 'RP-15', 'RP-20', 'Other'];
    }
    return _propellantCodes;
  }
  final List<String> _localAddedPrimerSuppliers = [];
  final List<String> _localAddedPropellantSuppliers = [];
  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  bool get _isCaliber9mm => _caliber.toLowerCase().contains('9mm') || _caliber.toLowerCase().contains('9x19');
  bool get _isCaliberSingleTempOnly {
    final c = _caliber.toLowerCase();
    return c.contains('.223') || c.contains('.308') || c.contains('luger') || c.contains('match') || c.contains('m82');
  }

  List<String> get _yearList {
    final List<String> years = [];
    for (int y = 2016; y <= 2035; y++) {
      years.add(y.toString());
    }
    return years;
  }

  List<String> get _shortYearList => _yearList.map((y) => (int.parse(y) % 100).toString().padLeft(2, '0')).toList();
  final _locationController = TextEditingController();
  final _mouthSlowController = TextEditingController(text: '0');
  final _mouthFastController = TextEditingController(text: '0');
  final _primerSlowController = TextEditingController(text: '0');
  final _primerFastController = TextEditingController(text: '0');

  // Accuracy Test controllers
  final _barrelSNController = TextEditingController();
  final _distanceController = TextEditingController();
  final _meanXController = TextEditingController();
  final _maxXController = TextEditingController();
  final _minXController = TextEditingController();
  final _rangeXController = TextEditingController();
  final _sdXController = TextEditingController();
  final _meanYController = TextEditingController();
  final _maxYController = TextEditingController();
  final _minYController = TextEditingController();
  final _rangeYController = TextEditingController();
  final _sdYController = TextEditingController();
  final _meanRadiusController = TextEditingController();
  final _accLargestDistanceController = TextEditingController();
  final _meanVelController = TextEditingController();
  final _minVelController = TextEditingController();
  final _maxVelController = TextEditingController();
  final _rangeVelController = TextEditingController();
  final _sdVelController = TextEditingController();

  // Sample Location state
  final List<String> _defaultSampleLocations = [
    'PC530',
    'After priming machine',
    'PD26',
    'after packing machine',
    'after visual inspection',
    'after link machine',
  ];
  final List<String> _customSampleLocations = [];
  List<String> get _allSampleLocations => [
    ..._defaultSampleLocations,
    ..._customSampleLocations,
  ];

  // Weapon cascading selection state and serial extractor
  String _extractWeaponSerial(String weaponStr) {
    if (weaponStr.isEmpty) return '';
    final snMatch = RegExp(r'SN[:\s]+([^\s\),]+)', caseSensitive: false).firstMatch(weaponStr);
    if (snMatch != null) {
      return snMatch.group(1)!.trim();
    }
    final wList = widget.adminRules['weapons'];
    if (wList is List) {
      for (final w in wList) {
        if (w is Map) {
          final t = (w['type'] ?? '').toString();
          final s = (w['serial'] ?? '').toString();
          if (s.isNotEmpty && (weaponStr.contains(s) || weaponStr.contains(t))) {
            return s;
          }
        }
      }
    }
    return weaponStr;
  }


  String _selectedRegisteredWeapon = '';
  final _customWeaponTypeController = TextEditingController();
  final _customWeaponSNController = TextEditingController();

  // Function Test 3-tier weapon selection: Category -> Model -> Serial
  String _functionSelectedCategory = 'Rifle';
  String _functionSelectedModel = '';
  String _functionSelectedSerial = '';
  final _functionCustomModelController = TextEditingController();
  final _functionCustomSerialController = TextEditingController();

  String _shift = 'Day';
  late String _caliber;
  late String _testName;
  String _status = 'Approved';
  bool _isSubmitting = false;

  // Extraction Force Test state
  String _extractionForceType = 'Overall'; // 'Overall' or 'Individual'
  final List<TextEditingController> _extractionRoundsControllers = [];

  // EPVAT Test state
  final _cartridgeTempController = TextEditingController();
  final _epvatMeanPressureController = TextEditingController();
  final _epvatMaxPressureController = TextEditingController();
  final _epvatMinPressureController = TextEditingController();
  final _epvatRangePressureController = TextEditingController();
  final _epvatSDPressureController = TextEditingController();
  String _epvatPressureType = 'Overall';
  String _epvatPressureUnit = 'bar';
  final List<TextEditingController> _epvatRoundsControllers = [];

  // New state variables for overall & individual EPVAT update
  final _epvatP2MeanPressureController = TextEditingController();
  final _epvatP2MaxPressureController = TextEditingController();
  final _epvatP2MinPressureController = TextEditingController();
  final _epvatP2RangePressureController = TextEditingController();
  final _epvatP2SDPressureController = TextEditingController();
  final List<TextEditingController> _epvatP2RoundsControllers = [];
  final List<TextEditingController> _epvatVelRoundsControllers = [];

  int _activeEpvatTempTabIndex = 0; // 0: +21, 1: +52, 2: -54
  final Map<String, Map<String, TextEditingController>> _overallEpvatControllers = {};

  // EPVAT overall sub-mode state variables
  final Map<String, String> _epvatOverallSubMode = {'+21': 'Stats Only', '+52': 'Stats Only', '-54': 'Stats Only'};
  final Map<String, int> _epvatOverallRoundCount = {'+21': 30, '+52': 30, '-54': 30};
  final Map<String, List<TextEditingController>> _overallEpvatVelRoundsControllers = {};
  final Map<String, List<TextEditingController>> _overallEpvatActionTimeRoundsControllers = {};
  final Map<String, List<TextEditingController>> _overallEpvatP1RoundsControllers = {};
  final Map<String, List<TextEditingController>> _overallEpvatP2RoundsControllers = {};

  // Action Time state controllers for EPVAT (Individual)
  final _actionTimeMeanController = TextEditingController();
  final _actionTimeMaxController = TextEditingController();
  final _actionTimeMinController = TextEditingController();
  final _actionTimeRangeController = TextEditingController();
  final _actionTimeSDController = TextEditingController();
  final List<TextEditingController> _actionTimeRoundsControllers = [];

  // Primer Sensitivity Test state
  final _primerDropWeightController = TextEditingController(text: '55');
  final List<TextEditingController> _primerDropHeightControllers = [];
  final List<String> _primerFireResults = []; // 'Fire' or 'Misfire'
  final _primerHbarController = TextEditingController();
  final _primerSDController = TextEditingController();
  final _primerHbarPlus5SController = TextEditingController();
  final _primerHbarMinus2SController = TextEditingController();
  final _primerMisfiresCountController = TextEditingController(text: '0');

  // Local storage auto-save state
  final StorageService _storageService = StorageService();
  Timer? _autoSaveDebounce;
  Timer? _liveClockTimer;
  String _autoSaveStatus = '';
  DateTime? _lastAutoSaveTime;

  // Residual Stress split controllers
  final _neckSlowController = TextEditingController(text: '0');
  final _neckFastController = TextEditingController(text: '0');
  final _shoulderSlowController = TextEditingController(text: '0');
  final _shoulderFastController = TextEditingController(text: '0');
  final _bodySlowController = TextEditingController(text: '0');
  final _bodyFastController = TextEditingController(text: '0');
  final _headSlowController = TextEditingController(text: '0');
  final _headFastController = TextEditingController(text: '0');
  final _roomTempController = TextEditingController();

  // EPVAT sensor controllers
  final _epvatSensor1Controller = TextEditingController();
  final _epvatSensor2Controller = TextEditingController();
  bool _manualGP1Entry = false;

  // Cyclic Rate Test state
  String _cyclicRateWeaponType = '';
  String _cyclicRateAmmoType = 'Rifle';
  final _cyclicRateController = TextEditingController();

  // Terminal Effect Test state
  final List<String> _terminalHoleDiameterRounds = [];
  final List<String> _terminalSteelPenetrationRounds = [];
  final List<String> _terminalAluminumPenetrationRounds = [];
  final List<TextEditingController> _terminalVelocityRoundsControllers = [];
  final _terminalBarrelSNController = TextEditingController();
  final _terminalDistanceController = TextEditingController();

  // Function Test state (Weapon, Temperature, 4-Level Defect Classification)
  String _functionWeapon = '';
  List<String> _selectedFunctionWeapons = [];
  String _functionTempMode = 'Single'; // 'Single' or 'All'
  String _functionSingleTemp = '+21'; // '+21', '+52', '-54', or '-32'
  int _activeFunctionTempTabIndex = 0; // 0: +21, 1: +52, 2: -54 or -32

  bool get _isFunctionBlankAmmo {
    final c = _caliber.toLowerCase();
    return c.contains('blank') || c.contains('m200') || c.contains('m82');
  }

  String get _functionColdTempKey => _isFunctionBlankAmmo ? '-32' : '-54';
  String get _functionColdTempLabel => _isFunctionBlankAmmo ? '-32 °C' : '-54 °C';
  List<String> get _functionTempList => ['+21', '+52', _functionColdTempKey];

  // Single temp defect controllers
  final _functionLevel1Controller = TextEditingController(text: '0');
  final _functionLevel2Controller = TextEditingController(text: '0');
  final _functionLevel3Controller = TextEditingController(text: '0');
  final _functionLevel4Controller = TextEditingController(text: '0');

  // Controllers for 'All' temperatures mode (+21, +52, -54, -32)
  final Map<String, TextEditingController> _funcAllProducedControllers = {
    '+21': TextEditingController(),
    '+52': TextEditingController(),
    '-54': TextEditingController(),
    '-32': TextEditingController(),
  };
  final Map<String, TextEditingController> _funcAllL1Controllers = {
    '+21': TextEditingController(text: '0'),
    '+52': TextEditingController(text: '0'),
    '-54': TextEditingController(text: '0'),
    '-32': TextEditingController(text: '0'),
  };
  final Map<String, TextEditingController> _funcAllL2Controllers = {
    '+21': TextEditingController(text: '0'),
    '+52': TextEditingController(text: '0'),
    '-54': TextEditingController(text: '0'),
    '-32': TextEditingController(text: '0'),
  };
  final Map<String, TextEditingController> _funcAllL3Controllers = {
    '+21': TextEditingController(text: '0'),
    '+52': TextEditingController(text: '0'),
    '-54': TextEditingController(text: '0'),
    '-32': TextEditingController(text: '0'),
  };
  final Map<String, TextEditingController> _funcAllL4Controllers = {
    '+21': TextEditingController(text: '0'),
    '+52': TextEditingController(text: '0'),
    '-54': TextEditingController(text: '0'),
    '-32': TextEditingController(text: '0'),
  };

  // Attachment state
  String _attachmentName = '';
  String _attachmentBase64 = '';

  // Defect item counts selected by operator
  final Map<String, int> _funcDefectItemCounts = {};

  Map<String, dynamic> get _currentFunctionCaliberRules {
    final func = widget.adminRules['function_test'] ?? {};
    final calibersMap = Map<String, dynamic>.from(func['calibers'] ?? {});
    final calRules = Map<String, dynamic>.from(calibersMap[_caliber] ?? calibersMap['default'] ?? func);
    return {
      'level1': calRules['level1'] ?? func['level1'] ?? {},
      'level2': calRules['level2'] ?? func['level2'] ?? {},
      'level3': calRules['level3'] ?? func['level3'] ?? {},
      'level4': calRules['level4'] ?? func['level4'] ?? {},
    };
  }

  List<String> _getDefectItemsForLevel(int level) {
    final rules = _currentFunctionCaliberRules;
    final lvlMap = rules['level$level'] ?? {};
    final desc = (lvlMap['description'] ?? '').toString();
    if (desc.trim().isEmpty) return [];
    return desc.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  int _getDefectCount(String item, String tempKey) {
    final key = tempKey.isNotEmpty ? '$tempKey:$item' : item;
    return _funcDefectItemCounts[key] ?? 0;
  }

  void _incrementDefect(String item, String tempKey, int level, TextEditingController controller) {
    final key = tempKey.isNotEmpty ? '$tempKey:$item' : item;
    final current = _funcDefectItemCounts[key] ?? 0;
    setState(() {
      _funcDefectItemCounts[key] = current + 1;
      _recalculateLevelFromChips(level, controller, tempKey);
    });
  }

  void _decrementDefect(String item, String tempKey, int level, TextEditingController controller) {
    final key = tempKey.isNotEmpty ? '$tempKey:$item' : item;
    final current = _funcDefectItemCounts[key] ?? 0;
    if (current > 0) {
      setState(() {
        if (current == 1) {
          _funcDefectItemCounts.remove(key);
        } else {
          _funcDefectItemCounts[key] = current - 1;
        }
        _recalculateLevelFromChips(level, controller, tempKey);
      });
    }
  }

  void _recalculateLevelFromChips(int level, TextEditingController controller, String tempKey) {
    final items = _getDefectItemsForLevel(level);
    int sum = 0;
    for (var it in items) {
      final key = tempKey.isNotEmpty ? '$tempKey:$it' : it;
      sum += (_funcDefectItemCounts[key] ?? 0);
    }
    controller.text = '$sum';
    _updateFunctionTestTotalDefects();
  }

  String get _functionDefectDetails {
    final entries = _funcDefectItemCounts.entries.where((e) => e.value > 0).map((e) => '${e.key} (${e.value})').toList();
    return entries.join(', ');
  }

  String _calculateFunctionTestStatus({required int l1, required int l2, required int l3, required int l4}) {
    final rules = _currentFunctionCaliberRules;
    final int l1Limit = rules['level1']?['max_allowed'] ?? 0;
    final int l2Limit = rules['level2']?['max_allowed'] ?? 0;
    final int l3Limit = rules['level3']?['max_allowed'] ?? 2;
    final int l4Limit = rules['level4']?['max_allowed'] ?? 5;
    if (l1 > l1Limit || l2 > l2Limit) return 'Rejected';
    if (l3 > l3Limit || l4 > l4Limit) return 'Retest';
    return 'Approved';
  }

  // Barrel Serial Numbers list from admin rules (all matched)
  List<String> get _barrelSerialNumbers {
    final Set<String> result = {};
    for (final key in ['barrel_serial_numbers', 'accuracy_barrels', 'epvat_barrels']) {
      final list = widget.adminRules[key];
      if (list is List) {
        for (final e in list) {
          final s = e.toString().trim();
          if (s.isNotEmpty) result.add(s);
        }
      }
    }
    if (result.isNotEmpty) return result.toList();
    return ['B1001', 'B1002', 'B1003'];
  }

  // GP Transducers lists from admin rules (all matched, purged of Kistler)
  List<String> get _gp1Transducers {
    final Set<String> result = {};
    final list1 = widget.adminRules['gp1_transducers'];
    if (list1 is List) {
      for (final e in list1) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !s.toLowerCase().contains('kistler')) result.add(s);
      }
    }
    final gp = widget.adminRules['gp_transducers']?['gp1'];
    if (gp is List) {
      for (final e in gp) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !s.toLowerCase().contains('kistler')) result.add(s);
      }
    }
    if (result.isNotEmpty) return result.toList();
    return ['GP1-001 (PCB 119B)', 'GP1-002 (PCB 119B)', 'GP1-003 (PCB 119B)'];
  }

  List<String> get _gp2Transducers {
    final Set<String> result = {};
    final gp = widget.adminRules['gp_transducers']?['gp2'];
    if (gp is List) {
      for (final e in gp) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !s.toLowerCase().contains('kistler')) result.add(s);
      }
    }
    final list6 = widget.adminRules['gp6_serials'];
    if (list6 is List) {
      for (final e in list6) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !s.toLowerCase().contains('kistler')) result.add(s);
      }
    }
    if (result.isNotEmpty) return result.toList();
    return ['GP2-001 (PCB 119B)', 'GP2-002 (PCB 119B)', 'GP2-003 (PCB 119B)'];
  }

  // Equipment lists & Round counting
  List<String> get _accuracyBarrels {
    final Set<String> result = {};
    final accList = widget.adminRules['accuracy_barrels'];
    if (accList is List) {
      for (final e in accList) {
        final s = e.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    final genList = widget.adminRules['barrel_serial_numbers'];
    if (genList is List) {
      for (final e in genList) {
        final s = e.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    if (result.isNotEmpty) return result.toList();
    return ['ACC-B-101', 'ACC-B-102', 'ACC-B-103'];
  }

  List<String> get _epvatBarrels {
    final Set<String> result = {};
    final epvList = widget.adminRules['epvat_barrels'];
    if (epvList is List) {
      for (final e in epvList) {
        final s = e.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    final genList = widget.adminRules['barrel_serial_numbers'];
    if (genList is List) {
      for (final e in genList) {
        final s = e.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    if (result.isNotEmpty) return result.toList();
    return ['EPVAT-B-201', 'EPVAT-B-202', 'EPVAT-B-203'];
  }

  List<String> get _gp6Serials {
    final Set<String> result = {};
    final list = widget.adminRules['gp6_serials'];
    if (list is List) {
      for (final e in list) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !s.toLowerCase().contains('kistler')) result.add(s);
      }
    }
    final gp2 = widget.adminRules['gp_transducers']?['gp2'];
    if (gp2 is List) {
      for (final e in gp2) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !s.toLowerCase().contains('kistler')) result.add(s);
      }
    }
    if (result.isNotEmpty) return result.toList();
    return ['GP2-PCB-9901', 'GP2-PCB-9902', 'GP2-PCB-9903'];
  }

  List<String> get _primerSuppliers {
    final list = widget.adminRules['primer_suppliers'];
    final base = <String>[];
    if (list is List && list.isNotEmpty) {
      base.addAll(list.map((e) => e.toString()));
    } else {
      base.addAll(['CBC', 'UNIS "GINIX"', 'S&B', 'MD']);
    }
    for (final s in _localAddedPrimerSuppliers) {
      if (!base.contains(s)) base.add(s);
    }
    return base;
  }

  List<String> get _propellantSuppliers {
    final list = widget.adminRules['propellant_suppliers'];
    final base = <String>[];
    if (list is List && list.isNotEmpty) {
      base.addAll(list.map((e) => e.toString()));
    } else {
      base.addAll(['Explosia', 'Gold Force', 'PB Clermont', 'Milan']);
    }
    for (final s in _localAddedPropellantSuppliers) {
      if (!base.contains(s)) base.add(s);
    }
    return base;
  }

  void _showAddPrimerSupplierDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Text('Add Primer Supplier', style: TextStyle(color: Colors.white, fontSize: 16.0)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Supplier Name',
            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Color(0xFF0E223D),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899)),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isEmpty) return;
              setState(() {
                if (!_localAddedPrimerSuppliers.contains(val)) {
                  _localAddedPrimerSuppliers.add(val);
                }
                final currentList = List<String>.from(_primerSuppliers);
                if (!currentList.contains(val)) currentList.add(val);
                widget.adminRules['primer_suppliers'] = currentList;
                _primerSupplier = val;
              });
              StorageService().saveRules(widget.adminRules);
              Navigator.pop(ctx);
            },
            child: const Text('Add Supplier', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddPropellantSupplierDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Text('Add Propellant Supplier', style: TextStyle(color: Colors.white, fontSize: 16.0)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Supplier Name',
            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Color(0xFF0E223D),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isEmpty) return;
              setState(() {
                if (!_localAddedPropellantSuppliers.contains(val)) {
                  _localAddedPropellantSuppliers.add(val);
                }
                final currentList = List<String>.from(_propellantSuppliers);
                if (!currentList.contains(val)) currentList.add(val);
                widget.adminRules['propellant_suppliers'] = currentList;
                _propellantSupplier = val;
              });
              StorageService().saveRules(widget.adminRules);
              Navigator.pop(ctx);
            },
            child: const Text('Add Supplier', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<String> get _allowedWeaponCategoriesForCaliber {
    final c = _caliber.toLowerCase();
    if (c.contains('9mm') || c.contains('9x19')) {
      return ['Pistol'];
    }
    if (c.contains('5.56') || c.contains('.223') || c.contains('7.62') || c.contains('.308') || c.contains('12.7')) {
      return ['Rifle', 'Machine Gun'];
    }
    return ['Rifle', 'Machine Gun', 'Pistol'];
  }

  List<Map<String, String>> get _fleetWeaponsDetailed {
    final List<Map<String, String>> items = [];
    final Set<String> seen = {};

    void addWeaponItem({
      required String category,
      required String model,
      required String serial,
      required String raw,
    }) {
      String cleanModel = model
          .replaceAll(RegExp(r'\s*\((Rifle|Machine Gun|Pistol|Carbine|Submachine Gun|Other)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(SN:[^\)]+\)', caseSensitive: false), '')
          .trim();
      if (cleanModel.toLowerCase().startsWith('styer')) {
        cleanModel = cleanModel.replaceFirst(RegExp('styer', caseSensitive: false), 'Steyr');
      }
      if (cleanModel.isEmpty) return;

      String cleanSerial = serial.trim();
      if (cleanSerial.isEmpty) {
        final snMatch = RegExp(r'SN[:\s]+([^\s\),]+)', caseSensitive: false).firstMatch(raw);
        if (snMatch != null) cleanSerial = snMatch.group(1)!.trim();
      }

      String cleanCat = category.trim();
      final checkCat = cleanCat.toLowerCase();
      final checkText = '$cleanModel $cleanCat $raw'.toLowerCase();

      if (checkCat == 'pistol' || checkText.contains('pistol') || checkText.contains('92fs') || checkText.contains('glock') || checkText.contains('browning hp') || checkText.contains('m9') || checkText.contains('beretta')) {
        cleanCat = 'Pistol';
      } else if (checkCat == 'machine gun' || checkCat == 'linked' || checkText.contains('machine gun') || checkText.contains('saw') || checkText.contains('m249') || checkText.contains('m60') || checkText.contains('m240')) {
        cleanCat = 'Machine Gun';
      } else {
        cleanCat = 'Rifle';
      }

      final key = '$cleanCat|$cleanModel|$cleanSerial'.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        items.add({
          'category': cleanCat,
          'model': cleanModel,
          'serial': cleanSerial,
          'raw': cleanSerial.isNotEmpty ? '$cleanModel (SN: $cleanSerial)' : cleanModel,
        });
      }
    }

    // 1. widget.adminRules['weapons']
    final list = widget.adminRules['weapons'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          final t = (e['type'] ?? '').toString().trim();
          final m = (e['model'] ?? '').toString().trim();
          final s = (e['serial'] ?? '').toString().trim();
          final c = (e['category'] ?? '').toString().trim();
          final mfg = (e['manufacturer'] ?? '').toString().trim();
          String modelName = m.isNotEmpty ? m : t;
          if (mfg.isNotEmpty && mfg != 'Other' && !modelName.toLowerCase().startsWith(mfg.toLowerCase())) {
            modelName = '$mfg $modelName';
          }
          addWeaponItem(category: c, model: modelName, serial: s, raw: t.isNotEmpty ? t : modelName);
        } else if (e != null && e.toString().trim().isNotEmpty) {
          addWeaponItem(category: '', model: e.toString().trim(), serial: '', raw: e.toString().trim());
        }
      }
    }

    // 2. widget.adminRules['function_test']?['weapons']
    final fWeapons = widget.adminRules['function_test']?['weapons'];
    if (fWeapons is List) {
      for (final e in fWeapons) {
        if (e != null && e.toString().trim().isNotEmpty) {
          addWeaponItem(category: '', model: e.toString().trim(), serial: '', raw: e.toString().trim());
        }
      }
    }

    // 3. widget.adminRules['cyclic_rate']?['weapons']
    final cyclicWeapons = widget.adminRules['cyclic_rate']?['weapons'];
    if (cyclicWeapons is List) {
      for (final e in cyclicWeapons) {
        if (e is Map) {
          final n = (e['name'] ?? '').toString().trim();
          final t = (e['type'] ?? '').toString().trim();
          if (n.isNotEmpty) {
            addWeaponItem(category: t, model: n, serial: '', raw: n);
          }
        } else if (e != null && e.toString().trim().isNotEmpty) {
          addWeaponItem(category: '', model: e.toString().trim(), serial: '', raw: e.toString().trim());
        }
      }
    }

    // Default fleet weapons if none registered
    if (items.isEmpty) {
      addWeaponItem(category: 'Rifle', model: 'Steyr AUG A3', serial: 'ST-556-01', raw: 'Steyr AUG A3 (SN: ST-556-01)');
      addWeaponItem(category: 'Rifle', model: 'M4A1 Carbine', serial: 'W-9012', raw: 'M4A1 Carbine (SN: W-9012)');
      addWeaponItem(category: 'Rifle', model: 'M16A4 Rifle', serial: 'W-9015', raw: 'M16A4 Rifle (SN: W-9015)');
      addWeaponItem(category: 'Rifle', model: 'G3A3 Rifle', serial: 'W-7721', raw: 'G3A3 Rifle (SN: W-7721)');
      addWeaponItem(category: 'Machine Gun', model: 'M249 SAW', serial: 'W-4401', raw: 'M249 SAW (SN: W-4401)');
      addWeaponItem(category: 'Pistol', model: 'Beretta M9 Pistol', serial: 'W-1102', raw: 'Beretta M9 Pistol (SN: W-1102)');
      addWeaponItem(category: 'Pistol', model: 'Beretta 92FS', serial: 'B-9201', raw: 'Beretta 92FS (SN: B-9201)');
      addWeaponItem(category: 'Pistol', model: 'Glock 17', serial: 'G-1701', raw: 'Glock 17 (SN: G-1701)');
    }

    return items;
  }

  List<String> get _weaponsList {
    return _fleetWeaponsDetailed.map((w) => w['raw']!).toSet().toList();
  }

  List<String> _getModelsForCategory(String category) {
    final models = _fleetWeaponsDetailed
        .where((w) => w['category'] == category)
        .map((w) => w['model']!)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    if (models.isEmpty) {
      if (category == 'Pistol') return ['Beretta 92FS', 'Glock 17', 'Browning HP'];
      if (category == 'Machine Gun') return ['M249 SAW', 'M60', 'M240'];
      return ['Steyr AUG A3', 'M16A4 Rifle', 'M4A1 Carbine', 'G3A3 Rifle'];
    }
    return models;
  }

  List<String> _getSerialsForModel(String category, String model) {
    if (model.isEmpty || model == '[+ Custom Model]') return [];
    return _fleetWeaponsDetailed
        .where((w) => w['category'] == category && w['model'] == model && w['serial']!.isNotEmpty)
        .map((w) => w['serial']!)
        .toSet()
        .toList();
  }

  void _syncFunctionWeaponState({bool resetSelections = false}) {
    final allowedCats = _allowedWeaponCategoriesForCaliber;
    if (!allowedCats.contains(_functionSelectedCategory)) {
      _functionSelectedCategory = allowedCats.first;
      resetSelections = true;
    }

    final models = _getModelsForCategory(_functionSelectedCategory);
    if (resetSelections || _functionSelectedModel.isEmpty || (!models.contains(_functionSelectedModel) && _functionSelectedModel != '[+ Custom Model]')) {
      _functionSelectedModel = models.isNotEmpty ? models.first : '[+ Custom Model]';
    }

    final serials = _getSerialsForModel(_functionSelectedCategory, _functionSelectedModel);
    if (resetSelections || _functionSelectedSerial.isEmpty || (!serials.contains(_functionSelectedSerial) && _functionSelectedSerial != '[+ Enter Custom Serial]')) {
      _functionSelectedSerial = serials.isNotEmpty ? serials.first : '';
    }

    final activeModel = _functionSelectedModel == '[+ Custom Model]'
        ? _functionCustomModelController.text.trim()
        : _functionSelectedModel;
    final activeSerial = _functionSelectedSerial == '[+ Enter Custom Serial]'
        ? _functionCustomSerialController.text.trim()
        : _functionSelectedSerial;

    final composed = activeSerial.isNotEmpty
        ? '$activeModel (SN: $activeSerial)'
        : activeModel;

    if (composed.isNotEmpty) {
      _functionWeapon = composed;
      if (_selectedFunctionWeapons.isEmpty || (_selectedFunctionWeapons.length == 1 && resetSelections)) {
        _selectedFunctionWeapons = [composed];
      }
    }
  }

  int _getAssetRounds(String serial) {
    if (serial.trim().isEmpty) return 0;
    return _storageService.calculateAssetRounds(widget.records, serial);
  }

  void _autoGenerateTime({bool force = false}) {
    if (force || _testTimeController.text.trim().isEmpty) {
      _testTimeController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    DateTime initial = now;
    try {
      if (_testTimeController.text.trim().isNotEmpty) {
        initial = DateFormat('yyyy-MM-dd HH:mm:ss').parse(_testTimeController.text.trim());
      }
    } catch (_) {}

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF31B9F6),
              onPrimary: Color(0xFF04599C),
              surface: Color(0xFFE0F2FE),
              onSurface: Color(0xFF0C2A4D),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF31B9F6),
              onPrimary: Color(0xFF04599C),
              surface: Color(0xFFE0F2FE),
              onSurface: Color(0xFF0C2A4D),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
      now.second,
    );
    setState(() {
      _testTimeController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    });
    _scheduleAutoSave();
  }

  void _showAddLocationDialog() {
    final addCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE0F2FE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF7DD3FC)),
        ),
        title: Row(
          children: const [
            Icon(Icons.add_location_alt_outlined, color: Color(0xFF31B9F6)),
            SizedBox(width: 8),
            Text('Add Sampling Location', style: TextStyle(color: Color(0xFF0C2A4D), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: addCtrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 14),
          decoration: InputDecoration(
            labelText: 'New Location Name',
            labelStyle: const TextStyle(color: Color(0xFF6495BF)),
            hintText: 'e.g., Station Alpha',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFD6EEFD),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF31B9F6),
              foregroundColor: const Color(0xFF04599C),
            ),
            onPressed: () {
              final val = addCtrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (!_customSampleLocations.contains(val)) {
                    _customSampleLocations.add(val);
                  }
                  _locationController.text = val;
                });
                // Persist to admin rules
                final existing = List<dynamic>.from(widget.adminRules['sample_locations'] ?? []);
                if (!existing.contains(val)) {
                  existing.add(val);
                  widget.adminRules['sample_locations'] = existing;
                  _storageService.saveRules(widget.adminRules);
                }
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add Location'),
          ),
        ],
      ),
    );
  }

  bool _validateAndAutoJump() {
    void jumpTo(GlobalKey key, FocusNode? focusNode, String fieldName) {
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          alignment: 0.15,
          curve: Curves.easeInOut,
        );
      }
      focusNode?.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Required field missing: $fieldName. All fields must be filled before the report can be submitted.')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    void notifyMissing(String fieldName, [GlobalKey? key, FocusNode? focusNode]) {
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          alignment: 0.15,
          curve: Curves.easeInOut,
        );
      }
      focusNode?.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Required field missing: $fieldName. All fields must be filled before the report can be submitted.')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // 1. Operator
    if (_operatorsController.text.trim().isEmpty) {
      jumpTo(_operatorFieldKey, _operatorFocusNode, 'Operators / Quality Inspector');
      return false;
    }

    // 2. Test Time (auto-generated)
    if (_testTimeController.text.trim().isEmpty) {
      _autoGenerateTime(force: true);
    }

    // 3. Lot / Hopper No
    if (widget.currentModule == 'Lot Acceptance Test') {
      if (_lotThreeDigitsController.text.trim().isEmpty) {
        jumpTo(_lotFieldKey, _lotFocusNode, 'Lot Number (3 Digits)');
        return false;
      }
      if (_lotThreeDigitsController.text.trim().length < 3) {
        notifyMissing('Please add three digits');
        jumpTo(_lotFieldKey, _lotFocusNode, 'Lot Number (3 Digits)');
        return false;
      }
    } else {
      if (_hopperThreeDigitsController.text.trim().isEmpty && _lotController.text.trim().isEmpty) {
        jumpTo(_lotFieldKey, _lotFocusNode, 'Hopper Number (3 Digits)');
        return false;
      }
      if (_hopperThreeDigitsController.text.trim().isNotEmpty && _hopperThreeDigitsController.text.trim().length < 3) {
        notifyMissing('Please add three digits');
        jumpTo(_lotFieldKey, _lotFocusNode, 'Hopper Number (3 Digits)');
        return false;
      }
    }

    // 4. Quantity Tested / Produced
    if (_producedController.text.trim().isEmpty || (int.tryParse(_producedController.text.trim()) ?? 0) <= 0) {
      jumpTo(_producedFieldKey, _producedFocusNode, 'Quantity Tested (Rounds)');
      return false;
    }

    // 5. Test specific field validation
    if (_testName == 'Waterproof Test') {
      if (_pressureController.text.trim().isEmpty) {
        notifyMissing('Waterproof Pressure (Bar)');
        return false;
      }
      if (_viscosityController.text.trim().isEmpty) {
        notifyMissing('Viscosity');
        return false;
      }
      if (_locationController.text.trim().isEmpty) {
        notifyMissing('Sampling Location');
        return false;
      }
    } else if (_testName == 'Accuracy Test') {
      if (_barrelSNController.text.trim().isEmpty) {
        jumpTo(_barrelFieldKey, _barrelFocusNode, 'Accuracy Barrel Test Serial');
        return false;
      }
      if (_distanceController.text.trim().isEmpty) {
        jumpTo(_distanceFieldKey, _distanceFocusNode, 'Distance of Velocity');
        return false;
      }
      if (_caliber == '5.56x45 M193') {
        if (_sdXController.text.trim().isEmpty) {
          notifyMissing('SD of X');
          return false;
        }
        if (_sdYController.text.trim().isEmpty) {
          notifyMissing('SD of Y');
          return false;
        }
        if (_meanRadiusController.text.trim().isEmpty) {
          notifyMissing('Mean Radius');
          return false;
        }
      } else {
        if (_meanXController.text.trim().isEmpty) {
          notifyMissing('Mean of X');
          return false;
        }
        if (_maxXController.text.trim().isEmpty) {
          notifyMissing('Max of X');
          return false;
        }
        if (_minXController.text.trim().isEmpty) {
          notifyMissing('Min of X');
          return false;
        }
        if (_meanYController.text.trim().isEmpty) {
          notifyMissing('Mean of Y');
          return false;
        }
        if (_maxYController.text.trim().isEmpty) {
          notifyMissing('Max of Y');
          return false;
        }
        if (_minYController.text.trim().isEmpty) {
          notifyMissing('Min of Y');
          return false;
        }
      }
      if (_meanVelController.text.trim().isEmpty) {
        notifyMissing('Mean Velocity');
        return false;
      }
    } else if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
      if (_testName == 'Propellant Test') {
        if (_propellantSupplier.isEmpty) {
          notifyMissing('Propellant Supplier');
          return false;
        }
        if (_propellantCodeController.text.trim().isEmpty) {
          notifyMissing('Powder Code');
          return false;
        }
        if (_propellantChargeController.text.trim().isEmpty) {
          notifyMissing('Powder Charge in Gram');
          return false;
        }
        if (double.tryParse(_propellantChargeController.text.trim()) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Powder Charge must be a valid number in grams.'), backgroundColor: Colors.red),
          );
          return false;
        }
        if (_propellantLotController.text.trim().isEmpty) {
          notifyMissing('Propellant Lot Number');
          return false;
        }
        if (int.tryParse(_propellantLotController.text.trim()) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Propellant Lot Number must be a number only.'), backgroundColor: Colors.red),
          );
          return false;
        }
      }
      if (_barrelSNController.text.trim().isEmpty) {
        jumpTo(_barrelFieldKey, _barrelFocusNode, 'EPVAT Barrel Test Serial');
        return false;
      }
      if (!_isCaliber9mm && _gp6SerialController.text.trim().isEmpty) {
        jumpTo(_gp6FieldKey, _gp6FocusNode, 'GP2 (Port)');
        return false;
      }
      if (_distanceController.text.trim().isEmpty) {
        jumpTo(_distanceFieldKey, _distanceFocusNode, 'Distance of Velocity');
        return false;
      }
      if (_epvatSensor1Controller.text.trim().isEmpty) {
        notifyMissing('GP1 (chamber)');
        return false;
      }
      if (_epvatPressureType == 'Overall') {
        const temps = ['+21', '+52', '-54'];
        for (final t in temps) {
          if (_overallEpvatControllers[t]?['vel_mean']?.text.trim().isEmpty ?? true) {
            notifyMissing('Velocity Mean (' + t + '°C)');
            return false;
          }
          if (_overallEpvatControllers[t]?['action_time_mean']?.text.trim().isEmpty ?? true) {
            notifyMissing('Action Time Mean (' + t + '°C)');
            return false;
          }
          if (_overallEpvatControllers[t]?['p1_mean']?.text.trim().isEmpty ?? true) {
            notifyMissing((_isCaliber9mm ? 'Chamber Pressure Mean (' : 'GP1 Chamber Pressure Mean (') + t + '°C)');
            return false;
          }
          if (!_isCaliber9mm && (_overallEpvatControllers[t]?['p2_mean']?.text.trim().isEmpty ?? true)) {
            notifyMissing('GP2 Port Pressure Mean (' + t + '°C)');
            return false;
          }
        }
      } else {
        if (_cartridgeTempController.text.trim().isEmpty) {
          notifyMissing('Cartridge Temperature');
          return false;
        }
        if (_meanVelController.text.trim().isEmpty) {
          notifyMissing('Mean Velocity');
          return false;
        }
        if (_actionTimeMeanController.text.trim().isEmpty) {
          notifyMissing('Mean Action Time');
          return false;
        }
        if (_epvatMeanPressureController.text.trim().isEmpty) {
          notifyMissing(_isCaliber9mm ? 'Mean Chamber Pressure' : 'GP1 Mean Chamber Pressure');
          return false;
        }
        if (!_isCaliber9mm && _epvatP2MeanPressureController.text.trim().isEmpty) {
          notifyMissing('GP2 Mean Port Pressure');
          return false;
        }
      }
    } else if (_testName == 'Residual Stress Test') {
      if (_roomTempController.text.trim().isEmpty) {
        jumpTo(_roomTempFieldKey, _roomTempFocusNode, 'Room Temperature (°C)');
        return false;
      }
      if (_locationController.text.trim().isEmpty) {
        notifyMissing('Sampling Location');
        return false;
      }
    } else if (_testName == 'Function Test') {
      final effectiveWeapon = _selectedFunctionWeapons.isNotEmpty
          ? _selectedFunctionWeapons.join(', ')
          : (_functionWeapon.isNotEmpty
              ? _functionWeapon
              : (_selectedRegisteredWeapon.isNotEmpty && _selectedRegisteredWeapon != '[+ Custom / Other Weapon]'
                  ? _selectedRegisteredWeapon
                  : (_customWeaponTypeController.text.trim().isNotEmpty
                      ? (_customWeaponSNController.text.trim().isNotEmpty
                          ? '${_customWeaponTypeController.text.trim()} (SN: ${_customWeaponSNController.text.trim()})'
                          : _customWeaponTypeController.text.trim())
                      : (_weaponsList.isNotEmpty ? _weaponsList.first : ''))));
      if (effectiveWeapon.trim().isEmpty) {
        jumpTo(_weaponFieldKey, _weaponFocusNode, 'Weapon Type & Serial');
        return false;
      }
      _functionWeapon = effectiveWeapon;
    } else if (_testName == 'Firing Rate Cycle Test') {
      if (_cyclicRateWeaponType.trim().isEmpty) {
        jumpTo(_weaponFieldKey, _weaponFocusNode, 'Weapon Type & Serial');
        return false;
      }
      if (_cyclicRateController.text.trim().isEmpty) {
        notifyMissing('Cyclic Rate Value (RPM)');
        return false;
      }
    } else if (_testName == 'Terminal Effect Test') {
      if (_terminalBarrelSNController.text.trim().isEmpty) {
        notifyMissing('Terminal Barrel Serial');
        return false;
      }
      if (_terminalDistanceController.text.trim().isEmpty) {
        notifyMissing('Distance of Velocity');
        return false;
      }
      final visCount = _getTerminalVisibleRounds();
      bool hasVel = false;
      for (int i = 0; i < visCount; i++) {
        if (i < _terminalVelocityRoundsControllers.length && _terminalVelocityRoundsControllers[i].text.trim().isNotEmpty) {
          hasVel = true;
          break;
        }
      }
      if (!hasVel) {
        notifyMissing('Terminal Velocity (at least 1 round)');
        return false;
      }
    } else if (_testName == 'Primer Sensitivity Test') {
      if (widget.currentModule == 'Lot Acceptance Test') {
        if (_selectedComponentPrimerLot == null) {
          notifyMissing('Primer Lot (from Component Module)');
          return false;
        }
      } else {
        if (_primerSupplier.isEmpty) {
          notifyMissing('Primer Supplier');
          return false;
        }
        if (_primerLotController.text.trim().isEmpty) {
          notifyMissing('Primer Lot Number');
          return false;
        }
        if (_primerInsertionDepthController.text.trim().isEmpty) {
          notifyMissing('Average Insertion Depth');
          return false;
        }
        final depthVal = double.tryParse(_primerInsertionDepthController.text.trim());
        if (depthVal == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Average Insertion Depth must be a valid number.'), backgroundColor: Colors.red),
          );
          return false;
        }
        if (depthVal < 0.05 || depthVal > 0.20) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Average Insertion Depth is out of specification! Allowed limits: 0.05 mm to 0.20 mm. Current: ${depthVal.toStringAsFixed(3)} mm'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
      }
      if (_primerHbarController.text.trim().isEmpty) {
        notifyMissing('H-bar (Average Height)');
        return false;
      }
      if (_primerSDController.text.trim().isEmpty) {
        notifyMissing('Standard Deviation (S)');
        return false;
      }
      if (_primerHbarPlus5SController.text.trim().isEmpty) {
        notifyMissing('All Fire Height (H + 5s)');
        return false;
      }
      if (_primerHbarMinus2SController.text.trim().isEmpty) {
        notifyMissing('No Fire Height (H - 2s)');
        return false;
      }
    }

    return true;
  }

    Future<void> _confirmCancelTest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text(
              'Cancel & Erase Test?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this test? All entered data, measurements, and progressive draft will be permanently erased.',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Cancel & Erase All Data', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _cancelAndEraseForm();
    }
  }

  void _cancelAndEraseForm() {
    setState(() {
      _lotController.clear();
      _lotThreeDigitsController.clear();
      final currentYearSuffix = (DateTime.now().year % 100).toString().padLeft(2, '0');
      _lotYearController.text = currentYearSuffix;
      _producedController.text = _testName == 'EPVAT test' && _epvatPressureType == 'Overall' ? '90' : '20';
      _defectsController.text = '0';
      _notesController.clear();
      _requirementController.clear();
      _pressureController.clear();
      _viscosityController.clear();
      _locationController.clear();
      _mouthSlowController.text = '0';
      _mouthFastController.text = '0';
      _primerSlowController.text = '0';
      _primerFastController.text = '0';
      _neckSlowController.text = '0';
      _neckFastController.text = '0';
      _shoulderSlowController.text = '0';
      _shoulderFastController.text = '0';
      _bodySlowController.text = '0';
      _bodyFastController.text = '0';
      _headSlowController.text = '0';
      _headFastController.text = '0';
      _roomTempController.clear();
      _updateDefaultDistance();
      _meanXController.clear();
      _maxXController.clear();
      _minXController.clear();
      _rangeXController.clear();
      _sdXController.clear();
      _meanYController.clear();
      _maxYController.clear();
      _minYController.clear();
      _rangeYController.clear();
      _sdYController.clear();
      _meanRadiusController.clear();
      _meanVelController.clear();
      _minVelController.clear();
      _maxVelController.clear();
      _rangeVelController.clear();
      _sdVelController.clear();
      _cartridgeTempController.clear();
      _epvatMeanPressureController.clear();
      _epvatMaxPressureController.clear();
      _epvatMinPressureController.clear();
      _epvatRangePressureController.clear();
      _epvatSDPressureController.clear();
      _epvatP2MeanPressureController.clear();
      _epvatP2MaxPressureController.clear();
      _epvatP2MinPressureController.clear();
      _epvatP2RangePressureController.clear();
      _epvatP2SDPressureController.clear();
      _actionTimeMeanController.clear();
      _actionTimeMaxController.clear();
      _actionTimeMinController.clear();
      _actionTimeRangeController.clear();
      _actionTimeSDController.clear();
      _cyclicRateController.clear();
      _terminalBarrelSNController.clear();
      _terminalDistanceController.clear();
      _functionLevel1Controller.text = '0';
      _functionLevel2Controller.text = '0';
      _functionLevel3Controller.text = '0';
      _functionLevel4Controller.text = '0';
      for (var c in _funcAllProducedControllers.values) c.text = '20';
      for (var c in _funcAllL1Controllers.values) c.text = '0';
      for (var c in _funcAllL2Controllers.values) c.text = '0';
      for (var c in _funcAllL3Controllers.values) c.text = '0';
      for (var c in _funcAllL4Controllers.values) c.text = '0';
      for (var c in _extractionRoundsControllers) c.clear();
      for (var c in _epvatRoundsControllers) c.clear();
      for (var c in _epvatP2RoundsControllers) c.clear();
      for (var c in _epvatVelRoundsControllers) c.clear();
      for (var c in _actionTimeRoundsControllers) c.clear();
      for (var c in _terminalVelocityRoundsControllers) c.clear();
      for (var map in _overallEpvatControllers.values) {
        for (var c in map.values) c.clear();
      }
      for (var list in _overallEpvatVelRoundsControllers.values) {
        for (var c in list) c.clear();
      }
      for (var list in _overallEpvatActionTimeRoundsControllers.values) {
        for (var c in list) c.clear();
      }
      for (var list in _overallEpvatP1RoundsControllers.values) {
        for (var c in list) c.clear();
      }
      for (var list in _overallEpvatP2RoundsControllers.values) {
        for (var c in list) c.clear();
      }
      _funcDefectItemCounts.clear();
      _attachmentName = '';
      _attachmentBase64 = '';
      for (var ctrl in _primerDropHeightControllers) {
        ctrl.dispose();
      }
      _primerDropHeightControllers.clear();
      _primerDropHeightControllers.add(TextEditingController());
      _primerFireResults.clear();
      _primerFireResults.add('Fire');
      _primerHbarController.clear();
      _primerSDController.clear();
      _primerHbarPlus5SController.clear();
      _primerHbarMinus2SController.clear();
      _primerMisfiresCountController.text = '0';
      _autoGenerateTime(force: true);
    });
    _autoSaveDebounce?.cancel();
    _storageService.clearFormDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Test cancelled. All entered data has been erased.'),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // calibers and testNames are now on EntryTab widget class
  List<String> get calibers {
    if (widget.currentModule == 'Component Test') {
      return const ['5.56', '7.62', '9mm'];
    }
    return EntryTab.calibers;
  }
  List<String> get testNames => EntryTab.testNames;

  // Caliber-specific test matrix and sample sizing
  bool _isTestAllowedForCaliber(String test, String cal) {
    if (widget.currentModule == 'Component Test') {
      return test == 'Propellant Test' || test == 'Primer Sensitivity Test';
    }
    if (test == 'Propellant Test') return false;

    final c = cal.toLowerCase();
    if (test == 'Waterproof Test') {
      if (c.contains('.223') || c.contains('69 grain') || c.contains('55 grain') || c.contains('77 grain') ||
          c.contains('.308') || c.contains('match') || c.contains('luger')) {
        return false;
      }
    } else if (test == 'Accuracy Test') {
      if (c.contains('m200') || c.contains('m82')) return false;
    } else if (test == 'Residual Stress Test') {
      if (c.contains('.223') || c.contains('69 grain') || c.contains('55 grain') || c.contains('77 grain') ||
          c.contains('.308') || c.contains('match') || c.contains('luger')) {
        return false;
      }
    } else if (test == 'EPVAT test') {
      if (c.contains('m200') || c.contains('m82')) return false;
    } else if (test == 'Terminal Effect Test') {
      if (widget.currentModule == 'Daily Test') return false;
      if (!c.contains('ss109')) return false;
    } else if (test == 'Firing Rate Cycle Test') {
      if (!(c.contains('m82') || c.contains('m200'))) return false;
    }
    return true;
  }

  List<String> _allowedTestsForCaliber(String cal) {
    return EntryTab.testNames.where((t) => _isTestAllowedForCaliber(t, cal)).toList();
  }

  int _getDefaultSampleSize({
    required String test,
    required String caliber,
    required String module,
    required bool isThreeTemp,
  }) {
    final c = caliber.toLowerCase();
    final bool isLot = module == 'Lot Acceptance Test';
    final bool isDaily = module == 'Daily Test';

    if (test == 'EPVAT test' || test == 'Propellant Test') {
      if (isThreeTemp) {
        if (c.contains('m193')) return 60; // 20 per temp
        return 90; // M80, SS109, 9mm Para
      } else {
        if (c.contains('m193')) return 20;
        if (c.contains('.223') || c.contains('.308') || c.contains('match') || c.contains('luger')) return 10;
        return 30;
      }
    }

    if (test == 'Function Test') {
      if (isThreeTemp) {
        if (isDaily) {
          if (c.contains('m80') || c.contains('para')) return 200;
          if (c.contains('ss109')) return 180;
          if (c.contains('m193')) return 180;
          if (c.contains('m200')) return 180;
          return 180;
        } else {
          // Lot Acceptance or Component module
          if (c.contains('m80') || c.contains('para')) return 315;
          if (c.contains('ss109')) return 500;
          if (c.contains('m193')) return 1500;
          if (c.contains('m200')) return 240;
          return 315;
        }
      } else {
        // Single temperature
        if (c.contains('ss109')) return isLot ? 180 : 60;
        if (c.contains('m193')) return isLot ? 480 : 60;
        if (c.contains('m200')) return isLot ? 480 : 60;
        if (c.contains('m80')) return isLot ? 200 : 100;
        if (c.contains('para')) return isLot ? 200 : 100;
        if (c.contains('.223')) return isLot ? 180 : 60;
        if (c.contains('.308')) return isLot ? 180 : 60;
        if (c.contains('m82')) return isLot ? 120 : 60;
        if (c.contains('match')) return isLot ? 120 : 60;
        if (c.contains('luger')) return isLot ? 120 : 60;
        return isLot ? 180 : 60;
      }
    }

    if (test == 'Waterproof Test') return 20;
    if (test == 'Residual Stress Test') return isLot ? 50 : 20;
    if (test == 'Terminal Effect Test') return 30;
    if (test == 'Firing Rate Cycle Test') return 60;
    if (test == 'Primer Sensitivity Test') return 275;
    if (test == 'Accuracy Test') {
      if (c.contains('.223') || c.contains('.308') || c.contains('match') || c.contains('luger')) {
        return 10;
      }
      return 30;
    }
    if (test == 'Extraction Force Test') return 20;

    return 30;
  }

  bool get _testHasTemperatureEvaluation {
    return _testName == 'EPVAT test' || _testName == 'Propellant Test' || _testName == 'Function Test';
  }

  bool get _isThreeTemperatureMode {
    if (_isCaliberSingleTempOnly) return false;
    if (_testName == 'Function Test') return _functionTempMode == 'All';
    if (_testName == 'EPVAT test' || _testName == 'Propellant Test') return _epvatPressureType == 'Overall';
    return false;
  }

  String get _selectedTemperatureDisplay {
    if (_isCaliberSingleTempOnly) return '+21 °C';
    if (_testName == 'Function Test') {
      return '$_functionSingleTemp °C';
    }
    final raw = _cartridgeTempController.text.trim().replaceAll(' °C', '').replaceAll('°C', '');
    if (raw.isEmpty) return '+21 °C';
    final sign = raw.startsWith('+') || raw.startsWith('-') ? '' : '+';
    return '$sign$raw °C';
  }

  void _onTemperatureModeChanged(String mode) {
    final bool isThree = mode.startsWith('All') && !_isCaliberSingleTempOnly;
    setState(() {
      if (_testName == 'Function Test') {
        _functionTempMode = isThree ? 'All' : 'Single';
        _updateFunctionTestTotalDefects();
      } else if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
        _epvatPressureType = isThree ? 'Overall' : 'Individual';
        if (!isThree && _cartridgeTempController.text.trim().isEmpty) {
          _cartridgeTempController.text = '+21';
        }
      }
      final defCount = _getDefaultSampleSize(
        test: _testName,
        caliber: _caliber,
        module: widget.currentModule,
        isThreeTemp: isThree,
      );
      _producedController.text = '$defCount';

      if (isThree) {
        if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
          final perTemp = _caliber.toLowerCase().contains('m193') ? 20 : 30;
          _epvatOverallRoundCount['+21'] = perTemp;
          _epvatOverallRoundCount['+52'] = perTemp;
          _epvatOverallRoundCount['-54'] = perTemp;
        } else if (_testName == 'Function Test') {
          final perTemp = (defCount / 3).round();
          for (var t in _functionTempList) {
            _funcAllProducedControllers[t]?.text = '$perTemp';
          }
        }
      } else {
        if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
          _syncIndividualRoundsControllers(defCount);
        }
      }
    });
    _scheduleAutoSave();
  }

  void _onSelectedTemperatureChanged(String temp) {
    final clean = temp.replaceAll(' °C', '').replaceAll('°C', '').trim();
    setState(() {
      _cartridgeTempController.text = clean;
      _functionSingleTemp = clean;
      if (!_isThreeTemperatureMode) {
        final defCount = _getDefaultSampleSize(
          test: _testName,
          caliber: _caliber,
          module: widget.currentModule,
          isThreeTemp: false,
        );
        _producedController.text = '$defCount';
      }
    });
    _scheduleAutoSave();
  }

  void _onCaliberSelected(String newCaliber) {
    setState(() {
      _caliber = newCaliber;
      if (!_isTestAllowedForCaliber(_testName, _caliber)) {
        final allowed = _allowedTestsForCaliber(_caliber);
        _testName = allowed.isNotEmpty ? allowed.first : 'Function Test';
        widget.onTestNameChanged(_testName);
      }
      if (_isCaliberSingleTempOnly) {
        _epvatPressureType = 'Individual';
        _functionTempMode = 'Single';
        _cartridgeTempController.text = '+21';
        _functionSingleTemp = '+21';
      }
      if (_testName == 'Waterproof Test') {
        _pressureController.text = (_caliber.contains('M82') || _caliber.contains('M200')) ? '0.14' : '0.5';
      }
      final sampleSize = _getDefaultSampleSize(
        test: _testName,
        caliber: _caliber,
        module: widget.currentModule,
        isThreeTemp: _isThreeTemperatureMode,
      );
      _producedController.text = '$sampleSize';
      _updateDefaultDistance();
      _updateEpvatSampleSizeForCaliber(_caliber);
      if (_testName == 'Primer Sensitivity Test') {
        final prRules = _getPrimerRulesForCaliber();
        _primerDropWeightController.text = ((prRules['drop_weight'] ?? 55.0) as num).toStringAsFixed(1);
      }
      if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
        _recalculateEpvatStats();
      }
      _syncFunctionWeaponState(resetSelections: true);
    });
    widget.onCaliberChanged(newCaliber);
    _scheduleAutoSave();
  }

  void _onTestNameSelected(String newTest) {
    setState(() {
      _testName = newTest;
      if (_testName == 'Waterproof Test') {
        _pressureController.text = (_caliber.contains('M82') || _caliber.contains('M200')) ? '0.14' : '0.5';
      } else {
        _pressureController.clear();
      }
      if (_isCaliberSingleTempOnly) {
        _epvatPressureType = 'Individual';
        _functionTempMode = 'Single';
        _cartridgeTempController.text = '+21';
        _functionSingleTemp = '+21';
      }
      final sampleSize = _getDefaultSampleSize(
        test: _testName,
        caliber: _caliber,
        module: widget.currentModule,
        isThreeTemp: _isThreeTemperatureMode,
      );
      _producedController.text = '$sampleSize';
      _autoGenerateTime();
      _updateDefaultDistance();
      if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
        _updateEpvatSampleSizeForCaliber(_caliber);
      } else if (_testName == 'Primer Sensitivity Test') {
        final prRules = _getPrimerRulesForCaliber();
        _primerDropWeightController.text = ((prRules['drop_weight'] ?? 55.0) as num).toStringAsFixed(1);
      }
    });
    widget.onTestNameChanged(newTest);
    _scheduleAutoSave();
  }

  void _updateEpvatSampleSizeForCaliber(String cal) {
    final count = _getDefaultSampleSize(
      test: _testName,
      caliber: cal,
      module: widget.currentModule,
      isThreeTemp: _isThreeTemperatureMode,
    );
    final perTemp = cal.toLowerCase().contains('m193') ? 20 : 30;
    _epvatOverallRoundCount['+21'] = perTemp;
    _epvatOverallRoundCount['+52'] = perTemp;
    _epvatOverallRoundCount['-54'] = perTemp;
    _producedController.text = '$count';
    if (_epvatPressureType == 'Individual') {
      _syncIndividualRoundsControllers(count);
    }
  }

  // Local auto-save debouncer and persistence engine
  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    try {
      final draft = <String, dynamic>{
        'caliber': _caliber,
        'testName': _testName,
        'shift': _shift,
        'operators': _operatorsController.text,
        'lotThreeDigits': _lotThreeDigitsController.text,
        'lotYear': _lotYearController.text,
        'hopperThreeDigits': _hopperThreeDigitsController.text,
        'hopperYear': _hopperYearController.text,
        'lot': _lotController.text,
        'propellantSupplier': _propellantSupplier,
        'primerSupplier': _primerSupplier,
        'selectedComponentPrimerLot': _selectedComponentPrimerLot,
        'selectedFunctionWeapons': _selectedFunctionWeapons,
        'produced': _producedController.text,
        'defects': _defectsController.text,
        'notes': _notesController.text,
        'requirement': _requirementController.text,
        'pressure': _pressureController.text,
        'viscosity': _viscosityController.text,
        'testTime': _testTimeController.text,
        'location': _locationController.text,
        'mouthSlow': _mouthSlowController.text,
        'mouthFast': _mouthFastController.text,
        'primerSlow': _primerSlowController.text,
        'primerFast': _primerFastController.text,
        'barrelSN': _barrelSNController.text,
        'distance': _distanceController.text,
        'meanX': _meanXController.text,
        'maxX': _maxXController.text,
        'minX': _minXController.text,
        'rangeX': _rangeXController.text,
        'sdX': _sdXController.text,
        'meanY': _meanYController.text,
        'maxY': _maxYController.text,
        'minY': _minYController.text,
        'rangeY': _rangeYController.text,
        'sdY': _sdYController.text,
        'meanRadius': _meanRadiusController.text,
        'meanVel': _meanVelController.text,
        'minVel': _minVelController.text,
        'maxVel': _maxVelController.text,
        'rangeVel': _rangeVelController.text,
        'sdVel': _sdVelController.text,
        'extractionForceType': _extractionForceType,
        'extractionRounds': _extractionRoundsControllers.map((c) => c.text).toList(),
        'epvatPressureType': _epvatPressureType,
        'epvatPressureUnit': _epvatPressureUnit,
        'cartridgeTemp': _cartridgeTempController.text,
        'epvatP1Mean': _epvatMeanPressureController.text,
        'epvatP1Max': _epvatMaxPressureController.text,
        'epvatP1Min': _epvatMinPressureController.text,
        'epvatP1Range': _epvatRangePressureController.text,
        'epvatP1SD': _epvatSDPressureController.text,
        'epvatP1Rounds': _epvatRoundsControllers.map((c) => c.text).toList(),
        'epvatP2Mean': _epvatP2MeanPressureController.text,
        'epvatP2Max': _epvatP2MaxPressureController.text,
        'epvatP2Min': _epvatP2MinPressureController.text,
        'epvatP2Range': _epvatP2RangePressureController.text,
        'epvatP2SD': _epvatP2SDPressureController.text,
        'epvatP2Rounds': _epvatP2RoundsControllers.map((c) => c.text).toList(),
        'epvatVelRounds': _epvatVelRoundsControllers.map((c) => c.text).toList(),
        'actionTimeMean': _actionTimeMeanController.text,
        'actionTimeMax': _actionTimeMaxController.text,
        'actionTimeMin': _actionTimeMinController.text,
        'actionTimeRange': _actionTimeRangeController.text,
        'actionTimeSD': _actionTimeSDController.text,
        'actionTimeRounds': _actionTimeRoundsControllers.map((c) => c.text).toList(),
        'primerDropWeight': _primerDropWeightController.text,
        'primerDropHeights': _primerDropHeightControllers.map((c) => c.text).toList(),
        'primerResults': _primerFireResults,
        'roomTemp': _roomTempController.text,
        'neckSlow': _neckSlowController.text,
        'neckFast': _neckFastController.text,
        'shoulderSlow': _shoulderSlowController.text,
        'shoulderFast': _shoulderFastController.text,
        'bodySlow': _bodySlowController.text,
        'bodyFast': _bodyFastController.text,
        'headSlow': _headSlowController.text,
        'headFast': _headFastController.text,
        'epvatOverallRoundCount': _epvatOverallRoundCount,
        'epvatOverallSubMode': _epvatOverallSubMode,
        'savedAt': DateTime.now().toIso8601String(),
      };
      
      final overallData = <String, Map<String, String>>{};
      _overallEpvatControllers.forEach((t, m) {
        overallData[t] = m.map((k, v) => MapEntry(k, v.text));
      });
      draft['overallEpvat'] = overallData;

      final overallRoundsData = <String, Map<String, List<String>>>{};
      for (var t in ['+21', '+52', '-54']) {
        overallRoundsData[t] = {
          'vel': (_overallEpvatVelRoundsControllers[t] ?? []).map((c) => c.text).toList(),
          'action_time': (_overallEpvatActionTimeRoundsControllers[t] ?? []).map((c) => c.text).toList(),
          'p1': (_overallEpvatP1RoundsControllers[t] ?? []).map((c) => c.text).toList(),
          'p2': (_overallEpvatP2RoundsControllers[t] ?? []).map((c) => c.text).toList(),
        };
      }
      draft['overallEpvatRounds'] = overallRoundsData;

      await _storageService.saveFormDraft(draft);
      if (mounted) {
        setState(() {
          _lastAutoSaveTime = DateTime.now();
          _autoSaveStatus = 'Auto-saved locally (${DateFormat('h:mm:ss a').format(_lastAutoSaveTime!)})';
        });
      }
    } catch (e) {
      print("Draft autosave error: $e");
    }
  }

  Future<void> _loadSavedDraft() async {
    try {
      final draft = await _storageService.loadFormDraft();
      if (draft == null || draft.isEmpty || !mounted) return;
      
      setState(() {
        if (draft['caliber'] != null) _caliber = draft['caliber'];
        if (draft['testName'] != null) _testName = draft['testName'];
        if (draft['shift'] != null) _shift = draft['shift'];
        if (draft['operators'] != null && _operatorsController.text.isEmpty) {
          _operatorsController.text = draft['operators'];
        }
        if (draft['lotThreeDigits'] != null) _lotThreeDigitsController.text = draft['lotThreeDigits'];
        if (draft['lotYear'] != null) _lotYearController.text = draft['lotYear'];
        if (draft['hopperThreeDigits'] != null) _hopperThreeDigitsController.text = draft['hopperThreeDigits'];
        if (draft['hopperYear'] != null) _hopperYearController.text = draft['hopperYear'];
        if (draft['lot'] != null) _lotController.text = draft['lot'];
        if (draft['propellantSupplier'] != null) _propellantSupplier = draft['propellantSupplier'];
        if (draft['primerSupplier'] != null) _primerSupplier = draft['primerSupplier'];
        if (draft['selectedComponentPrimerLot'] != null) _selectedComponentPrimerLot = draft['selectedComponentPrimerLot'];
        if (draft['selectedFunctionWeapons'] is List) {
          _selectedFunctionWeapons = List<String>.from(draft['selectedFunctionWeapons']);
          _functionWeapon = _selectedFunctionWeapons.join(', ');
        }
        if (draft['produced'] != null) _producedController.text = draft['produced'];
        if (draft['defects'] != null) _defectsController.text = draft['defects'];
        if (draft['notes'] != null) _notesController.text = draft['notes'];
        if (draft['requirement'] != null) _requirementController.text = draft['requirement'];
        if (draft['pressure'] != null) _pressureController.text = draft['pressure'];
        if (draft['viscosity'] != null) _viscosityController.text = draft['viscosity'];
        if (draft['testTime'] != null && (_testName == 'Waterproof Test' || _testName == 'Residual Stress Test')) {
          _testTimeController.text = draft['testTime'];
        }
        if (draft['location'] != null) _locationController.text = draft['location'];
        if (draft['mouthSlow'] != null) _mouthSlowController.text = draft['mouthSlow'];
        if (draft['mouthFast'] != null) _mouthFastController.text = draft['mouthFast'];
        if (draft['primerSlow'] != null) _primerSlowController.text = draft['primerSlow'];
        if (draft['primerFast'] != null) _primerFastController.text = draft['primerFast'];
        if (draft['barrelSN'] != null) _barrelSNController.text = draft['barrelSN'];
        if (draft['distance'] != null) _distanceController.text = draft['distance'];
        if (draft['meanX'] != null) _meanXController.text = draft['meanX'];
        if (draft['maxX'] != null) _maxXController.text = draft['maxX'];
        if (draft['minX'] != null) _minXController.text = draft['minX'];
        if (draft['rangeX'] != null) _rangeXController.text = draft['rangeX'];
        if (draft['sdX'] != null) _sdXController.text = draft['sdX'];
        if (draft['meanY'] != null) _meanYController.text = draft['meanY'];
        if (draft['maxY'] != null) _maxYController.text = draft['maxY'];
        if (draft['minY'] != null) _minYController.text = draft['minY'];
        if (draft['rangeY'] != null) _rangeYController.text = draft['rangeY'];
        if (draft['sdY'] != null) _sdYController.text = draft['sdY'];
        if (draft['meanRadius'] != null) _meanRadiusController.text = draft['meanRadius'];
        if (draft['meanVel'] != null) _meanVelController.text = draft['meanVel'];
        if (draft['minVel'] != null) _minVelController.text = draft['minVel'];
        if (draft['maxVel'] != null) _maxVelController.text = draft['maxVel'];
        if (draft['rangeVel'] != null) _rangeVelController.text = draft['rangeVel'];
        if (draft['sdVel'] != null) _sdVelController.text = draft['sdVel'];
        if (draft['roomTemp'] != null) _roomTempController.text = draft['roomTemp'];
        if (draft['neckSlow'] != null) _neckSlowController.text = draft['neckSlow'];
        if (draft['neckFast'] != null) _neckFastController.text = draft['neckFast'];
        if (draft['shoulderSlow'] != null) _shoulderSlowController.text = draft['shoulderSlow'];
        if (draft['shoulderFast'] != null) _shoulderFastController.text = draft['shoulderFast'];
        if (draft['bodySlow'] != null) _bodySlowController.text = draft['bodySlow'];
        if (draft['bodyFast'] != null) _bodyFastController.text = draft['bodyFast'];
        if (draft['headSlow'] != null) _headSlowController.text = draft['headSlow'];
        if (draft['headFast'] != null) _headFastController.text = draft['headFast'];

        if (draft['extractionRounds'] is List && (draft['extractionRounds'] as List).isNotEmpty) {
          final list = draft['extractionRounds'] as List;
          _extractionRoundsControllers.clear();
          for (var item in list) {
            _extractionRoundsControllers.add(TextEditingController(text: item.toString()));
          }
          if (_extractionRoundsControllers.isEmpty) {
            _extractionRoundsControllers.add(TextEditingController());
          }
        }

        if (draft['primerDropHeights'] is List && (draft['primerDropHeights'] as List).isNotEmpty) {
          final list = draft['primerDropHeights'] as List;
          _primerDropHeightControllers.clear();
          for (var item in list) {
            _primerDropHeightControllers.add(TextEditingController(text: item.toString()));
          }
          if (_primerDropHeightControllers.isEmpty) {
            _primerDropHeightControllers.add(TextEditingController());
          }
        }
        if (draft['primerResults'] is List && (draft['primerResults'] as List).isNotEmpty) {
          _primerFireResults.clear();
          for (var item in draft['primerResults'] as List) {
            _primerFireResults.add(item.toString());
          }
        }

        if (draft['actionTimeRounds'] is List && (draft['actionTimeRounds'] as List).isNotEmpty) {
          final list = draft['actionTimeRounds'] as List;
          _actionTimeRoundsControllers.clear();
          for (var item in list) {
            _actionTimeRoundsControllers.add(TextEditingController(text: item.toString()));
          }
        }

        if (draft['overallEpvat'] is Map) {
          final ov = draft['overallEpvat'] as Map;
          ov.forEach((t, metricsMap) {
            if (_overallEpvatControllers.containsKey(t) && metricsMap is Map) {
              metricsMap.forEach((k, v) {
                if (_overallEpvatControllers[t]!.containsKey(k)) {
                  _overallEpvatControllers[t]![k]!.text = v.toString();
                }
              });
            }
          });
        }

        if (draft['epvatOverallRoundCount'] is Map) {
          final ovCounts = draft['epvatOverallRoundCount'] as Map;
          ovCounts.forEach((k, v) {
            if (_epvatOverallRoundCount.containsKey(k) && v is int) {
              _epvatOverallRoundCount[k.toString()] = v;
            }
          });
        }

        if (draft['epvatOverallSubMode'] is Map) {
          final ovModes = draft['epvatOverallSubMode'] as Map;
          ovModes.forEach((k, v) {
            if (_epvatOverallSubMode.containsKey(k) && v is String) {
              _epvatOverallSubMode[k.toString()] = v;
            }
          });
        }

        _autoSaveStatus = 'Restored draft from local storage';
      });
    } catch (e) {
      print("Error loading form draft: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _caliber = widget.initialCaliber;
    _testName = widget.initialTestName;
    if (widget.currentModule == 'Component Test') {
      if (!const ['5.56', '7.62', '9mm'].contains(_caliber)) {
        _caliber = '5.56';
      }
      if (_testName != 'Propellant Test' && _testName != 'Primer Sensitivity Test') {
        _testName = 'Primer Sensitivity Test';
      }
    }
    _operatorsController.text = widget.loggedInUser;
    
    if (_barrelSNController.text.isEmpty && _accuracyBarrels.isNotEmpty) {
      _barrelSNController.text = _accuracyBarrels.first;
    }
    if (_gp6SerialController.text.isEmpty && _gp6Serials.isNotEmpty) {
      _gp6SerialController.text = _gp6Serials.first;
    }
    if (_terminalBarrelSNController.text.isEmpty && _barrelSerialNumbers.isNotEmpty) {
      _terminalBarrelSNController.text = _barrelSerialNumbers.first;
    }
    if (_epvatSensor1Controller.text.isEmpty && _gp1Transducers.isNotEmpty) {
      _epvatSensor1Controller.text = _gp1Transducers.first;
    }
    if (_epvatSensor2Controller.text.isEmpty && _gp2Transducers.isNotEmpty) {
      _epvatSensor2Controller.text = _gp2Transducers.first;
    }
    if (_weaponsList.isNotEmpty) {
      if (_selectedRegisteredWeapon.isEmpty) {
        _selectedRegisteredWeapon = _weaponsList.first;
      }
      if (_functionWeapon.isEmpty) {
        _functionWeapon = _weaponsList.first;
      }
      if (_selectedFunctionWeapons.isEmpty) {
        _selectedFunctionWeapons = [_weaponsList.first];
      }
    }
    _syncFunctionWeaponState(resetSelections: true);
    
    // Initialize test date and time locked to opening time (allows manual edit or defaults to submission time)
    _autoGenerateTime(force: true);
    
    // Initialize one round controller for Extraction Force Test
    _extractionRoundsControllers.add(TextEditingController());
    if (_testName == 'Waterproof Test') {
      if (_caliber.contains('M82') || _caliber.contains('M200')) {
        _pressureController.text = '0.14';
      } else {
        _pressureController.text = '0.5';
      }
    }
    final currentYearSuffix = (DateTime.now().year % 100).toString().padLeft(2, '0');
    _lotYearController.text = currentYearSuffix;
    _hopperYearController.text = currentYearSuffix;
    _producedController.text = '20';

    // Range Auto-Calculation Listeners
    _maxXController.addListener(() => _calculateRange(_maxXController, _minXController, _rangeXController));
    _minXController.addListener(() => _calculateRange(_maxXController, _minXController, _rangeXController));
    _maxYController.addListener(() => _calculateRange(_maxYController, _minYController, _rangeYController));
    _minYController.addListener(() => _calculateRange(_maxYController, _minYController, _rangeYController));
    _maxVelController.addListener(() => _calculateRange(_maxVelController, _minVelController, _rangeVelController));
    _minVelController.addListener(() => _calculateRange(_maxVelController, _minVelController, _rangeVelController));

    _updateDefaultDistance();

    // Initialize round controllers for EPVAT Test & Action Time
    _epvatRoundsControllers.add(TextEditingController());
    _epvatP2RoundsControllers.add(TextEditingController());
    _epvatVelRoundsControllers.add(TextEditingController());
    _actionTimeRoundsControllers.add(TextEditingController());

    _epvatMaxPressureController.addListener(() => _calculateRange(_epvatMaxPressureController, _epvatMinPressureController, _epvatRangePressureController));
    _epvatMinPressureController.addListener(() => _calculateRange(_epvatMaxPressureController, _epvatMinPressureController, _epvatRangePressureController));

    _epvatP2MaxPressureController.addListener(() => _calculateRange(_epvatP2MaxPressureController, _epvatP2MinPressureController, _epvatP2RangePressureController));
    _epvatP2MinPressureController.addListener(() => _calculateRange(_epvatP2MaxPressureController, _epvatP2MinPressureController, _epvatP2RangePressureController));

    _actionTimeMaxController.addListener(() => _calculateRange(_actionTimeMaxController, _actionTimeMinController, _actionTimeRangeController));
    _actionTimeMinController.addListener(() => _calculateRange(_actionTimeMaxController, _actionTimeMinController, _actionTimeRangeController));

    // Initialize Primer Sensitivity Test round
    _primerDropHeightControllers.add(TextEditingController());
    _primerFireResults.add('Fire');
    _primerHbarController.addListener(_onManualPrimerHbarOrSDChanged);
    _primerSDController.addListener(_onManualPrimerHbarOrSDChanged);


    // Initialize overall EPVAT controllers map for three temperatures (+21, +52, -54)
    final temps = ['+21', '+52', '-54'];
    final metrics = ['vel', 'action_time', 'p1', 'p2'];
    final subMetrics = ['mean', 'max', 'min', 'range', 'sd'];
    for (var t in temps) {
      _overallEpvatControllers[t] = {};
      for (var m in metrics) {
        for (var s in subMetrics) {
          final key = '${m}_$s';
          _overallEpvatControllers[t]![key] = TextEditingController();
        }
      }
    }

    // Add listeners to overall mode max/min controllers to calculate ranges
    for (var t in temps) {
      for (var m in metrics) {
        final maxCtrl = _overallEpvatControllers[t]!['${m}_max']!;
        final minCtrl = _overallEpvatControllers[t]!['${m}_min']!;
        final rangeCtrl = _overallEpvatControllers[t]!['${m}_range']!;
        maxCtrl.addListener(() => _calculateRange(maxCtrl, minCtrl, rangeCtrl));
        minCtrl.addListener(() => _calculateRange(maxCtrl, minCtrl, rangeCtrl));
      }
    }

    // Initialize round controllers for EPVAT Overall Mode (up to 50 rounds)
    for (var t in temps) {
      _overallEpvatVelRoundsControllers[t] = List.generate(50, (_) => TextEditingController());
      _overallEpvatActionTimeRoundsControllers[t] = List.generate(50, (_) => TextEditingController());
      _overallEpvatP1RoundsControllers[t] = List.generate(50, (_) => TextEditingController());
      _overallEpvatP2RoundsControllers[t] = List.generate(50, (_) => TextEditingController());
      
      for (int i = 0; i < 50; i++) {
        _overallEpvatVelRoundsControllers[t]![i].addListener(() {
          _calculateOverallTempStats(t);
          _scheduleAutoSave();
        });
        _overallEpvatActionTimeRoundsControllers[t]![i].addListener(() {
          _calculateOverallTempStats(t);
          _scheduleAutoSave();
        });
        _overallEpvatP1RoundsControllers[t]![i].addListener(() {
          _calculateOverallTempStats(t);
          _scheduleAutoSave();
        });
        _overallEpvatP2RoundsControllers[t]![i].addListener(() {
          _calculateOverallTempStats(t);
          _scheduleAutoSave();
        });
      }
    }

    // Initialize Terminal Effect rounds list to initial Quantity Tested (20)
    _syncTerminalRoundsControllers(20);

    // Apply caliber-specific sample sizing for EPVAT (30 for M80/SS109/9mm, 20 for M193, 10 for others)
    _updateEpvatSampleSizeForCaliber(_caliber);

    // Load any auto-saved local draft
    _loadSavedDraft();

    // Add listener to Quantity Tested controller to resize individual rounds count dynamically
    _producedController.addListener(() {
      final val = int.tryParse(_producedController.text.trim()) ?? 0;
      if (val > 0 && val <= 100) {
        if ((_testName == 'EPVAT test' || _testName == 'Propellant Test') && _epvatPressureType == 'Individual') {
          _syncIndividualRoundsControllers(val);
        } else if (_testName == 'Terminal Effect Test') {
          _syncTerminalRoundsControllers(val);
        }
      }
      _scheduleAutoSave();
    });
  }

  void _calculateRange(TextEditingController maxCtrl, TextEditingController minCtrl, TextEditingController rangeCtrl) {
    final maxVal = double.tryParse(maxCtrl.text.trim());
    final minVal = double.tryParse(minCtrl.text.trim());
    if (maxVal != null && minVal != null) {
      final diff = maxVal - minVal;
      rangeCtrl.text = diff.toStringAsFixed(diff.truncateToDouble() == diff ? 0 : 2);
    } else {
      rangeCtrl.clear();
    }
  }

  void _onManualPrimerHbarOrSDChanged() {
    if (_testName != 'Primer Sensitivity Test') return;
    final hm = double.tryParse(_primerHbarController.text.trim());
    final sd = double.tryParse(_primerSDController.text.trim());
    if (hm != null && sd != null) {
      final allFire = hm + (5 * sd);
      final noFire = hm - (2 * sd);
      _primerHbarPlus5SController.text = allFire.toStringAsFixed(1);
      _primerHbarMinus2SController.text = noFire.toStringAsFixed(1);
      if (mounted) setState(() {});
    }
  }


  void _updateDefaultDistance() {
    if (_testName != 'Accuracy Test' && _testName != 'EPVAT test') return;
    if (_caliber.contains('M193')) {
      _distanceController.text = '21';
    } else if (_caliber.contains('SS109') || _caliber.contains('M80')) {
      _distanceController.text = '24';
    } else if (_caliber.contains('Para')) {
      _distanceController.text = '16';
    } else if (_caliber.contains('.308') || _caliber.contains('.223') || _caliber.contains('Luger') || _caliber.contains('Match') || _caliber.contains('CMJ')) {
      _distanceController.text = '5';
    } else {
      _distanceController.text = '';
    }
  }

  @override
  void didUpdateWidget(covariant EntryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loggedInUser != widget.loggedInUser) {
      _operatorsController.text = widget.loggedInUser;
    }
    if (oldWidget.adminRules != widget.adminRules) {
      _syncFunctionWeaponState();
      if (_weaponsList.isNotEmpty && (_selectedRegisteredWeapon.isEmpty || !_weaponsList.contains(_selectedRegisteredWeapon))) {
        _selectedRegisteredWeapon = _weaponsList.first;
        if (_selectedFunctionWeapons.isEmpty) {
          _selectedFunctionWeapons = [_weaponsList.first];
          _functionWeapon = _weaponsList.first;
        }
      }
      if (_accuracyBarrels.isNotEmpty && (_barrelSNController.text.isEmpty || !_accuracyBarrels.contains(_barrelSNController.text))) {
        if (_testName == 'Accuracy Test') _barrelSNController.text = _accuracyBarrels.first;
      }
      if (_epvatBarrels.isNotEmpty && (_barrelSNController.text.isEmpty || !_epvatBarrels.contains(_barrelSNController.text))) {
        if (_testName == 'EPVAT test') _barrelSNController.text = _epvatBarrels.first;
      }
      if (_gp1Transducers.isNotEmpty && (_epvatSensor1Controller.text.isEmpty || !_gp1Transducers.contains(_epvatSensor1Controller.text))) {
        _epvatSensor1Controller.text = _gp1Transducers.first;
      }
      if (_gp6Serials.isNotEmpty && (_gp6SerialController.text.isEmpty || !_gp6Serials.contains(_gp6SerialController.text))) {
        _gp6SerialController.text = _gp6Serials.first;
      }
      if (_gp2Transducers.isNotEmpty && (_epvatSensor2Controller.text.isEmpty || !_gp2Transducers.contains(_epvatSensor2Controller.text))) {
        _epvatSensor2Controller.text = _gp2Transducers.first;
      }
      if (_barrelSerialNumbers.isNotEmpty && (_terminalBarrelSNController.text.isEmpty || !_barrelSerialNumbers.contains(_terminalBarrelSNController.text))) {
        _terminalBarrelSNController.text = _barrelSerialNumbers.first;
      }
    }
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    _operatorsController.dispose();
    _lotController.dispose();
    _primerInsertionDepthController.dispose();
    _primerLotController.dispose();
    _propellantLotController.dispose();
    _propellantChargeController.dispose();
    _propellantCodeController.dispose();
    _lotThreeDigitsController.dispose();
    _lotYearController.dispose();
    _producedController.dispose();
    _defectsController.dispose();
    _notesController.dispose();
    _requirementController.dispose();
    _pressureController.dispose();
    _viscosityController.dispose();
    _testTimeController.dispose();
    _locationController.dispose();
    _mouthSlowController.dispose();
    _mouthFastController.dispose();
    _primerSlowController.dispose();
    _primerFastController.dispose();
    _barrelSNController.dispose();
    _distanceController.dispose();
    _meanXController.dispose();
    _maxXController.dispose();
    _minXController.dispose();
    _rangeXController.dispose();
    _sdXController.dispose();
    _meanYController.dispose();
    _maxYController.dispose();
    _minYController.dispose();
    _rangeYController.dispose();
    _sdYController.dispose();
    _meanRadiusController.dispose();
    _meanVelController.dispose();
    _minVelController.dispose();
    _maxVelController.dispose();
    _rangeVelController.dispose();
    _sdVelController.dispose();
    for (var ctrl in _extractionRoundsControllers) {
      ctrl.dispose();
    }
    _cartridgeTempController.dispose();
    _epvatMeanPressureController.dispose();
    _epvatMaxPressureController.dispose();
    _epvatMinPressureController.dispose();
    _epvatRangePressureController.dispose();
    _epvatSDPressureController.dispose();
    for (var ctrl in _epvatRoundsControllers) {
      ctrl.dispose();
    }
    
    // Dispose P2 and velocity controllers
    _epvatP2MeanPressureController.dispose();
    _epvatP2MaxPressureController.dispose();
    _epvatP2MinPressureController.dispose();
    _epvatP2RangePressureController.dispose();
    _epvatP2SDPressureController.dispose();
    for (var ctrl in _epvatP2RoundsControllers) {
      ctrl.dispose();
    }
    for (var ctrl in _epvatVelRoundsControllers) {
      ctrl.dispose();
    }
    
    // Dispose overall EPVAT controllers map
    _overallEpvatControllers.forEach((temp, metricsMap) {
      metricsMap.forEach((key, controller) {
        controller.dispose();
      });
    });

    _neckSlowController.dispose();
    _neckFastController.dispose();
    _shoulderSlowController.dispose();
    _shoulderFastController.dispose();
    _bodySlowController.dispose();
    _bodyFastController.dispose();
    _headSlowController.dispose();
    _headFastController.dispose();
    _roomTempController.dispose();
    _epvatSensor1Controller.dispose();
    _epvatSensor2Controller.dispose();
    _cyclicRateController.dispose();
    for (var ctrl in _terminalVelocityRoundsControllers) {
      ctrl.dispose();
    }
    _terminalBarrelSNController.dispose();
    _terminalDistanceController.dispose();
    _functionLevel1Controller.dispose();
    _functionLevel2Controller.dispose();
    _functionLevel3Controller.dispose();
    _functionLevel4Controller.dispose();
    _funcAllProducedControllers.values.forEach((c) => c.dispose());
    _funcAllL1Controllers.values.forEach((c) => c.dispose());
    _funcAllL2Controllers.values.forEach((c) => c.dispose());
    _funcAllL3Controllers.values.forEach((c) => c.dispose());
    _funcAllL4Controllers.values.forEach((c) => c.dispose());

    _overallEpvatVelRoundsControllers.forEach((_, list) {
      for (var ctrl in list) {
        ctrl.dispose();
      }
    });
    _overallEpvatP1RoundsControllers.forEach((_, list) {
      for (var ctrl in list) {
        ctrl.dispose();
      }
    });
    _overallEpvatP2RoundsControllers.forEach((_, list) {
      for (var ctrl in list) {
        ctrl.dispose();
      }
    });

    _actionTimeMeanController.dispose();
    _actionTimeMaxController.dispose();
    _actionTimeMinController.dispose();
    _actionTimeRangeController.dispose();
    _actionTimeSDController.dispose();
    for (var ctrl in _actionTimeRoundsControllers) {
      ctrl.dispose();
    }
    _primerDropWeightController.dispose();
    for (var ctrl in _primerDropHeightControllers) {
      ctrl.dispose();
    }
    _primerHbarController.removeListener(_onManualPrimerHbarOrSDChanged);
    _primerSDController.removeListener(_onManualPrimerHbarOrSDChanged);
    _primerHbarController.dispose();
    _primerSDController.dispose();
    _primerHbarPlus5SController.dispose();
    _primerHbarMinus2SController.dispose();
    _primerMisfiresCountController.dispose();
    _overallEpvatActionTimeRoundsControllers.forEach((_, list) {
      for (var ctrl in list) {
        ctrl.dispose();
      }
    });
    _scrollController.dispose();
    _gp6SerialController.dispose();
    _operatorFocusNode.dispose();
    _testTimeFocusNode.dispose();
    _lotFocusNode.dispose();
    _producedFocusNode.dispose();
    _distanceFocusNode.dispose();
    _barrelFocusNode.dispose();
    _gp6FocusNode.dispose();
    _weaponFocusNode.dispose();
    _functionCustomModelController.dispose();
    _functionCustomSerialController.dispose();
    _autoSaveDebounce?.cancel();

    super.dispose();
  }

  void _calculateOverallTempStats(String temp) {
    if (_epvatOverallSubMode[temp] != 'Individual Rounds') return;
    final int count = _epvatOverallRoundCount[temp] ?? 30;
    
    // Helper to calculate list stats
    void calcMetrics(List<TextEditingController> controllers, String prefix) {
      final List<double> vals = [];
      for (int i = 0; i < count; i++) {
        if (i < controllers.length) {
          final val = double.tryParse(controllers[i].text.trim());
          if (val != null) {
            vals.add(val);
          }
        }
      }
      
      final meanCtrl = _overallEpvatControllers[temp]!['${prefix}_mean']!;
      final minCtrl = _overallEpvatControllers[temp]!['${prefix}_min']!;
      final maxCtrl = _overallEpvatControllers[temp]!['${prefix}_max']!;
      final rangeCtrl = _overallEpvatControllers[temp]!['${prefix}_range']!;
      final sdCtrl = _overallEpvatControllers[temp]!['${prefix}_sd']!;
      
      if (vals.isEmpty) {
        meanCtrl.text = '';
        minCtrl.text = '';
        maxCtrl.text = '';
        rangeCtrl.text = '';
        sdCtrl.text = '';
        return;
      }
      
      final double mean = vals.reduce((a, b) => a + b) / vals.length;
      final double minVal = vals.reduce(math.min);
      final double maxVal = vals.reduce(math.max);
      final double rangeVal = maxVal - minVal;
      
      double sd = 0.0;
      if (vals.length > 1) {
        double sumSq = 0.0;
        for (var v in vals) {
          sumSq += math.pow(v - mean, 2);
        }
        sd = math.sqrt(sumSq / (vals.length - 1));
      }
      
      meanCtrl.text = mean.toStringAsFixed(2);
      minCtrl.text = minVal.toStringAsFixed(2);
      maxCtrl.text = maxVal.toStringAsFixed(2);
      rangeCtrl.text = rangeVal.toStringAsFixed(2);
      sdCtrl.text = sd.toStringAsFixed(2);
    }
    
    calcMetrics(_overallEpvatVelRoundsControllers[temp] ?? [], 'vel');
    calcMetrics(_overallEpvatActionTimeRoundsControllers[temp] ?? [], 'action_time');
    calcMetrics(_overallEpvatP1RoundsControllers[temp] ?? [], 'p1');
    calcMetrics(_overallEpvatP2RoundsControllers[temp] ?? [], 'p2');
  }

  void _submitForm() async {
    if (!_validateAndAutoJump()) return;
    if (!_formKey.currentState!.validate()) return;

    final producedStr = _producedController.text.trim();
    final defectsStr = _defectsController.text.trim();
    
    final int produced = int.tryParse(producedStr) ?? 0;
    final int defects = int.tryParse(defectsStr) ?? 0;

    if (defects > produced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validation Error: Defects cannot exceed quantity tested.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final now = DateTime.now();
    // Format timestamp exactly like Node version (e.g. "6/23/2026 4:30:15 PM")
    final String formattedDate = DateFormat('M/d/yyyy h:mm:ss a').format(now);

    final String finalLotNo;
    if (widget.currentModule == 'Lot Acceptance Test') {
      final String threeDigits = _lotThreeDigitsController.text.trim();
      final String year = _lotYearController.text.trim();
      finalLotNo = threeDigits.isEmpty ? 'OMPC/$year' : '${threeDigits.padLeft(3, '0')} OMPC/$year';
    } else {
      final String threeDigits = _hopperThreeDigitsController.text.trim();
      final String year = _hopperYearController.text.trim();
      if (threeDigits.isNotEmpty && year.isNotEmpty) {
        finalLotNo = '${threeDigits.padLeft(3, '0')}-$year';
      } else {
        finalLotNo = _lotController.text.trim();
      }
    }

    final String finalStatus = _getCalculatedStatus();

    try {
      if ((_testName == 'EPVAT test' || _testName == 'Propellant Test') && _epvatPressureType == 'Overall') {
        // Save records for temperatures that actually have data entered
        final temps = ['+21', '+52', '-54'];
        final validTemps = temps.where((t) {
          final p1 = _overallEpvatControllers[t]?['p1_mean']?.text.trim() ?? '';
          final p2 = _overallEpvatControllers[t]?['p2_mean']?.text.trim() ?? '';
          final v = _overallEpvatControllers[t]?['vel_mean']?.text.trim() ?? '';
          final hasRounds = (_overallEpvatP1RoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false) ||
                            (_overallEpvatVelRoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false);
          return p1.isNotEmpty || p2.isNotEmpty || v.isNotEmpty || hasRounds;
        }).toList();

        // If no temps have values entered, fallback to the currently active tab
        final tempsToSave = validTemps.isNotEmpty ? validTemps : [temps[_activeEpvatTempTabIndex]];

        // SUM THE SAMPLE SIZES ACROSS TEMPERATURES INTO ONE UNIFIED TEST
        int totalProduced = 0;
        final List<String> tempDetails = [];
        for (var t in tempsToSave) {
          final count = _epvatOverallRoundCount[t] ?? 30;
          totalProduced += count;
          final p1m = _overallEpvatControllers[t]!['p1_mean']!.text.trim();
          final p1max = _overallEpvatControllers[t]!['p1_max']!.text.trim();
          final vm = _overallEpvatControllers[t]!['vel_mean']!.text.trim();
          tempDetails.add('$t°C ($count rds: P1=$p1m, Max=$p1max, V=$vm)');
        }

        // Primary baseline temp (+21 or first)
        final baselineTemp = tempsToSave.contains('+21') ? '+21' : tempsToSave.first;
        final baseP1Mean = _overallEpvatControllers[baselineTemp]!['p1_mean']!.text.trim();
        final baseP1Max = _overallEpvatControllers[baselineTemp]!['p1_max']!.text.trim();
        final baseP1Min = _overallEpvatControllers[baselineTemp]!['p1_min']!.text.trim();
        final baseP1Range = _overallEpvatControllers[baselineTemp]!['p1_range']!.text.trim();
        final baseP1SD = _overallEpvatControllers[baselineTemp]!['p1_sd']!.text.trim();

        final baseP2Mean = _overallEpvatControllers[baselineTemp]!['p2_mean']!.text.trim();
        final baseP2Max = _overallEpvatControllers[baselineTemp]!['p2_max']!.text.trim();
        final baseP2Min = _overallEpvatControllers[baselineTemp]!['p2_min']!.text.trim();
        final baseP2Range = _overallEpvatControllers[baselineTemp]!['p2_range']!.text.trim();
        final baseP2SD = _overallEpvatControllers[baselineTemp]!['p2_sd']!.text.trim();

        final baseVelMean = _overallEpvatControllers[baselineTemp]!['vel_mean']!.text.trim();
        final baseVelMax = _overallEpvatControllers[baselineTemp]!['vel_max']!.text.trim();
        final baseVelMin = _overallEpvatControllers[baselineTemp]!['vel_min']!.text.trim();
        final baseVelRange = _overallEpvatControllers[baselineTemp]!['vel_range']!.text.trim();
        final baseVelSD = _overallEpvatControllers[baselineTemp]!['vel_sd']!.text.trim();

        final baseActMean = _overallEpvatControllers[baselineTemp]!['action_time_mean']?.text.trim() ?? '';
        final baseActMax = _overallEpvatControllers[baselineTemp]!['action_time_max']?.text.trim() ?? '';
        final baseActMin = _overallEpvatControllers[baselineTemp]!['action_time_min']?.text.trim() ?? '';
        final baseActRange = _overallEpvatControllers[baselineTemp]!['action_time_range']?.text.trim() ?? '';
        final baseActSD = _overallEpvatControllers[baselineTemp]!['action_time_sd']?.text.trim() ?? '';

        final customNotes = _notesController.text.trim();
        final combinedNotes = tempDetails.isNotEmpty
            ? (customNotes.isNotEmpty ? '$customNotes | ' : '') + 'Temps: ${tempDetails.join('; ')}'
            : customNotes;

        final record = BallisticRecord(
          module: widget.currentModule,
          timestamp: formattedDate,
          operators: _operatorsController.text.trim(),
          shift: _shift,
          caliber: _caliber,
          lotNo: finalLotNo,
          produced: totalProduced, // SUM OF ALL TEMPERATURE ROUNDS
          defects: 0,
          notes: combinedNotes,
          status: finalStatus,
          testName: _testName,
          pressureBar: '',
          viscosity: '',
          testTime: _testTimeController.text.trim().isNotEmpty ? _testTimeController.text.trim() : formattedDate,
          gp6Serial: _gp6SerialController.text.trim(),
          userRole: widget.userRole,
          samplingLocation: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : (_allSampleLocations.isNotEmpty ? _allSampleLocations.first : ''),
          mouthSlow: 0,
          mouthFast: 0,
          primerSlow: 0,
          primerFast: 0,
          hopperNo: (widget.currentModule == 'Daily Test' || widget.currentModule == 'Daily Test Report') ? finalLotNo : '',
          boxNo: '',
          requirement: _requirementController.text.trim(),
          barrelSN: _barrelSNController.text.trim(),
          barrelType: '',
          velocityDistance: _distanceController.text.trim(),
          velMean: baseVelMean,
          velMax: baseVelMax,
          velMin: baseVelMin,
          velRange: baseVelRange,
          velSD: baseVelSD,
          actionTimeMean: baseActMean,
          actionTimeMax: baseActMax,
          actionTimeMin: baseActMin,
          actionTimeRange: baseActRange,
          actionTimeSD: baseActSD,
          cartridgeTemp: tempsToSave.map((t) => '$t°C').join(', '),
          epvatPressureType: 'Overall',
          epvatPressureUnit: _epvatPressureUnit,
          epvatMeanPressure: baseP1Mean,
          epvatMaxPressure: baseP1Max,
          epvatMinPressure: baseP1Min,
          epvatRangePressure: baseP1Range,
          epvatSDPressure: baseP1SD,
          epvatP2MeanPressure: baseP2Mean,
          epvatP2MaxPressure: baseP2Max,
          epvatP2MinPressure: baseP2Min,
          epvatP2RangePressure: baseP2Range,
          epvatP2SDPressure: baseP2SD,
          epvatPressureRounds: tempsToSave.map((t) => (_overallEpvatP1RoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',')).where((s) => s.isNotEmpty).join(';'),
          epvatP2PressureRounds: tempsToSave.map((t) => (_overallEpvatP2RoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',')).where((s) => s.isNotEmpty).join(';'),
          epvatVelRounds: tempsToSave.map((t) => (_overallEpvatVelRoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',')).where((s) => s.isNotEmpty).join(';'),
          actionTimeRounds: tempsToSave.map((t) => (_overallEpvatActionTimeRoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',')).where((s) => s.isNotEmpty).join(';'),
          roomTemp: '',
          neckSlow: 0,
          neckFast: 0,
          shoulderSlow: 0,
          shoulderFast: 0,
          bodySlow: 0,
          bodyFast: 0,
          headSlow: 0,
          headFast: 0,
          attachmentName: _attachmentName,
          attachmentBase64: _attachmentBase64,
          primerLot: (_testName == 'EPVAT test' || _testName == 'Propellant Test')
              ? (_selectedComponentPrimerLot ?? _primerLotController.text.trim())
              : '',
          primerSupplier: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _primerSupplier : '',
          primerInsertionDepth: '',
          propellantSupplier: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _propellantSupplier : '',
          propellantCode: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _propellantCodeController.text.trim() : '',
          propellantLot: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? (_selectedComponentPropellantLot ?? _propellantLotController.text.trim()) : '',
          propellantCharge: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _propellantChargeController.text.trim() : '',
        );
        await widget.onSubmit(record);
      } else if (_testName == 'Function Test' && _functionTempMode == 'All') {
        final temps = _functionTempList;
        final validTemps = temps.where((t) {
          final prod = _funcAllProducedControllers[t]?.text.trim() ?? '';
          final l1 = _funcAllL1Controllers[t]?.text.trim() ?? '';
          final l2 = _funcAllL2Controllers[t]?.text.trim() ?? '';
          final l3 = _funcAllL3Controllers[t]?.text.trim() ?? '';
          final l4 = _funcAllL4Controllers[t]?.text.trim() ?? '';
          return prod.isNotEmpty || l1.isNotEmpty || l2.isNotEmpty || l3.isNotEmpty || l4.isNotEmpty;
        }).toList();

        final tempsToSave = validTemps.isNotEmpty ? validTemps : [temps[_activeFunctionTempTabIndex]];

        // SUM ALL TEMPERATURE SAMPLE SIZES AND DEFECTS INTO ONE TEST RECORD
        int totalProduced = 0;
        int sumL1 = 0;
        int sumL2 = 0;
        int sumL3 = 0;
        int sumL4 = 0;
        final List<String> tempSummaries = [];

        for (var t in tempsToSave) {
          final count = int.tryParse(_funcAllProducedControllers[t]?.text.trim() ?? '') ?? 20;
          final l1 = int.tryParse(_funcAllL1Controllers[t]?.text.trim() ?? '') ?? 0;
          final l2 = int.tryParse(_funcAllL2Controllers[t]?.text.trim() ?? '') ?? 0;
          final l3 = int.tryParse(_funcAllL3Controllers[t]?.text.trim() ?? '') ?? 0;
          final l4 = int.tryParse(_funcAllL4Controllers[t]?.text.trim() ?? '') ?? 0;
          totalProduced += count;
          sumL1 += l1;
          sumL2 += l2;
          sumL3 += l3;
          sumL4 += l4;
          tempSummaries.add('$t°C ($count rds, ${l1 + l2 + l3 + l4} def)');
        }

        final totalDefects = sumL1 + sumL2 + sumL3 + sumL4;
        final overallStatus = _calculateFunctionTestStatus(l1: sumL1, l2: sumL2, l3: sumL3, l4: sumL4);

        final customNotes = _notesController.text.trim();
        final combinedNotes = tempSummaries.isNotEmpty
            ? (customNotes.isNotEmpty ? '$customNotes | ' : '') + 'Temps: ${tempSummaries.join('; ')}'
            : customNotes;

        final record = BallisticRecord(
          module: widget.currentModule,
          timestamp: formattedDate,
          operators: _operatorsController.text.trim(),
          shift: _shift,
          caliber: _caliber,
          lotNo: finalLotNo,
          produced: totalProduced, // SUM OF ALL TEMPERATURE ROUNDS
          defects: totalDefects,
          notes: combinedNotes,
          status: overallStatus,
          testName: _testName,
          pressureBar: '',
          viscosity: '',
          testTime: _testTimeController.text.trim().isNotEmpty ? _testTimeController.text.trim() : formattedDate,
          gp6Serial: '',
          userRole: widget.userRole,
          samplingLocation: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : (_allSampleLocations.isNotEmpty ? _allSampleLocations.first : ''),
          mouthSlow: 0,
          mouthFast: 0,
          primerSlow: 0,
          primerFast: 0,
          hopperNo: (widget.currentModule == 'Daily Test' || widget.currentModule == 'Daily Test Report') ? finalLotNo : '',
          boxNo: '',
          requirement: _requirementController.text.trim(),
          cartridgeTemp: tempsToSave.map((t) => '$t °C').join(', '),
          cyclicRateWeaponType: _selectedFunctionWeapons.isNotEmpty ? _selectedFunctionWeapons.join(', ') : _functionWeapon,
          barrelSN: _selectedFunctionWeapons.isNotEmpty ? _selectedFunctionWeapons.join(', ') : _functionWeapon,
          functionLevel1: sumL1,
          functionLevel2: sumL2,
          functionLevel3: sumL3,
          functionLevel4: sumL4,
          attachmentName: _attachmentName,
          attachmentBase64: _attachmentBase64,
          functionDefectDetails: _functionDefectDetails,
          primerLot: '',
          primerSupplier: '',
          primerInsertionDepth: '',
          propellantSupplier: '',
          propellantCode: '',
          propellantLot: '',
        );
        await widget.onSubmit(record);
      } else {
        // Individual or other test name
        final record = BallisticRecord(
          module: widget.currentModule,
          timestamp: formattedDate,
          operators: _operatorsController.text.trim(),
          shift: _shift,
          caliber: _caliber,
          lotNo: finalLotNo,
          produced: produced,
          defects: _testName == 'Function Test'
              ? ((int.tryParse(_functionLevel1Controller.text.trim()) ?? 0) +
                  (int.tryParse(_functionLevel2Controller.text.trim()) ?? 0) +
                  (int.tryParse(_functionLevel3Controller.text.trim()) ?? 0) +
                  (int.tryParse(_functionLevel4Controller.text.trim()) ?? 0))
              : defects,
          notes: _notesController.text.trim(),
          status: finalStatus,
          testName: _testName,
          pressureBar: _testName == 'Waterproof Test' ? _pressureController.text.trim() : '',
          viscosity: _testName == 'Waterproof Test' ? _viscosityController.text.trim() : '',
          testTime: _testTimeController.text.trim().isNotEmpty ? _testTimeController.text.trim() : formattedDate,
          gp6Serial: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _gp6SerialController.text.trim() : '',
          userRole: widget.userRole,
          samplingLocation: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : (_allSampleLocations.isNotEmpty ? _allSampleLocations.first : ''),
          mouthSlow: _testName == 'Waterproof Test' ? (int.tryParse(_mouthSlowController.text.trim()) ?? 0) : 0,
          mouthFast: _testName == 'Waterproof Test' ? (int.tryParse(_mouthFastController.text.trim()) ?? 0) : 0,
          primerSlow: _testName == 'Waterproof Test' ? (int.tryParse(_primerSlowController.text.trim()) ?? 0) : 0,
          primerFast: _testName == 'Waterproof Test' ? (int.tryParse(_primerFastController.text.trim()) ?? 0) : 0,
          hopperNo: (widget.currentModule == 'Daily Test' || widget.currentModule == 'Daily Test Report') ? finalLotNo : '',
          boxNo: '',
          requirement: _requirementController.text.trim(),
          barrelSN: _testName == 'Function Test'
              ? (_selectedFunctionWeapons.isNotEmpty ? _selectedFunctionWeapons.join(', ') : _functionWeapon)
              : (_testName == 'Accuracy Test' || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _barrelSNController.text.trim() : (_testName == 'Terminal Effect Test' ? _terminalBarrelSNController.text.trim() : '')),
          barrelType: '',
          velocityDistance: _testName == 'Accuracy Test' || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _distanceController.text.trim() : (_testName == 'Terminal Effect Test' ? _terminalDistanceController.text.trim() : ''),
          accMeanX: (_testName == 'Accuracy Test' && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _meanXController.text.trim() : '',
          accMaxX: (_testName == 'Accuracy Test' && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _maxXController.text.trim() : '',
          accMinX: (_testName == 'Accuracy Test' && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _minXController.text.trim() : '',
          accRangeX: (_testName == 'Accuracy Test' && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _rangeXController.text.trim() : '',
          accSDX: _testName == 'Accuracy Test' || _testName == 'Extraction Force Test' ? _sdXController.text.trim() : '',
          accMeanY: _testName == 'Accuracy Test' && _caliber != '5.56x45 M193' ? _meanYController.text.trim() : '',
          accMaxY: _testName == 'Accuracy Test' && _caliber != '5.56x45 M193' ? _maxYController.text.trim() : '',
          accMinY: _testName == 'Accuracy Test' && _caliber != '5.56x45 M193' ? _minYController.text.trim() : '',
          accRangeY: _testName == 'Accuracy Test' && _caliber != '5.56x45 M193' ? _rangeYController.text.trim() : '',
          accSDY: _testName == 'Accuracy Test' ? _sdYController.text.trim() : '',
          velMean: _testName == 'Accuracy Test' || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _meanVelController.text.trim() : '',
          velMin: _testName == 'Accuracy Test' || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _minVelController.text.trim() : '',
          velMax: _testName == 'Accuracy Test' || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _maxVelController.text.trim() : '',
          velRange: _testName == 'Accuracy Test' || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _rangeVelController.text.trim() : '',
          velSD: _testName == 'Accuracy Test' || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _sdVelController.text.trim() : '',
          accMeanRadius: _testName == 'Accuracy Test' && _caliber == '5.56x45 M193' ? _meanRadiusController.text.trim() : '',
          extractionForceType: _testName == 'Extraction Force Test' ? _extractionForceType : '',
          extractionForceRounds: _testName == 'Extraction Force Test' ? _extractionRoundsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          cartridgeTemp: (_testName == 'EPVAT test' || _testName == 'Propellant Test')
              ? _cartridgeTempController.text.trim()
              : (_testName == 'Function Test' ? '$_functionSingleTemp °C' : ''),
          epvatPressureType: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatPressureType : '',
          epvatPressureUnit: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatPressureUnit : '',
          epvatPressureRounds: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatRoundsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          epvatMeanPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatMeanPressureController.text.trim() : '',
          epvatMaxPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatMaxPressureController.text.trim() : '',
          epvatMinPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatMinPressureController.text.trim() : '',
          epvatRangePressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatRangePressureController.text.trim() : '',
          epvatSDPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatSDPressureController.text.trim() : '',
          epvatP2MeanPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatP2MeanPressureController.text.trim() : '',
          epvatP2MaxPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatP2MaxPressureController.text.trim() : '',
          epvatP2MinPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatP2MinPressureController.text.trim() : '',
          epvatP2RangePressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatP2RangePressureController.text.trim() : '',
          epvatP2SDPressure: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatP2SDPressureController.text.trim() : '',
          epvatP2PressureRounds: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatP2RoundsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          epvatVelRounds: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatVelRoundsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          actionTimeMean: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _actionTimeMeanController.text.trim() : '',
          actionTimeMax: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _actionTimeMaxController.text.trim() : '',
          actionTimeMin: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _actionTimeMinController.text.trim() : '',
          actionTimeRange: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _actionTimeRangeController.text.trim() : '',
          actionTimeSD: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _actionTimeSDController.text.trim() : '',
          actionTimeRounds: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _actionTimeRoundsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          primerDropHeights: _testName == 'Primer Sensitivity Test' ? _primerDropHeightControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          primerFireResults: _testName == 'Primer Sensitivity Test' ? _primerFireResults.take(_primerDropHeightControllers.length).join(',') : '',
          primerHbar: _testName == 'Primer Sensitivity Test' ? _primerHbarController.text.trim() : '',
          primerSD: _testName == 'Primer Sensitivity Test' ? _primerSDController.text.trim() : '',
          primerAllFireH: _testName == 'Primer Sensitivity Test' ? _primerHbarPlus5SController.text.trim() : '',
          primerNoFireH: _testName == 'Primer Sensitivity Test' ? _primerHbarMinus2SController.text.trim() : '',
          epvatSensor1: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatSensor1Controller.text.trim() : '',
          epvatSensor2: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatSensor2Controller.text.trim() : '',
          cyclicRateWeaponType: _testName == 'Firing Rate Cycle Test'
              ? _cyclicRateWeaponType
              : (_testName == 'Function Test' ? _functionWeapon : ''),
          cyclicRateAmmoType: _testName == 'Firing Rate Cycle Test' ? _cyclicRateAmmoType : '',
          cyclicRateValue: _testName == 'Firing Rate Cycle Test' ? _cyclicRateController.text.trim() : '',
          cyclicRateMin: _testName == 'Firing Rate Cycle Test' ? (() {
            final weapons = List<Map<String, dynamic>>.from(
              (widget.adminRules['cyclic_rate']?['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)));
            final w = weapons.firstWhere((w) => w['name'] == _cyclicRateWeaponType, orElse: () => {});
            return (w['min'] ?? 0).toString();
          })() : '',
          cyclicRateMax: _testName == 'Firing Rate Cycle Test' ? (() {
            final weapons = List<Map<String, dynamic>>.from(
              (widget.adminRules['cyclic_rate']?['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)));
            final w = weapons.firstWhere((w) => w['name'] == _cyclicRateWeaponType, orElse: () => {});
            return (w['max'] ?? '').toString();
          })() : '',
          terminalHoleDiameter: _testName == 'Terminal Effect Test' ? _terminalHoleDiameterRounds.join(',') : '',
          terminalSteelPenetration: _testName == 'Terminal Effect Test' ? _terminalSteelPenetrationRounds.join(',') : '',
          terminalAluminumPenetration: _testName == 'Terminal Effect Test' ? _terminalAluminumPenetrationRounds.join(',') : '',
          terminalVelocity: _testName == 'Terminal Effect Test' ? _terminalVelocityRoundsControllers.map((c) => c.text.trim()).join(',') : '',
          roomTemp: _testName == 'Residual Stress Test' ? _roomTempController.text.trim() : '',
          neckSlow: _testName == 'Residual Stress Test' ? (int.tryParse(_neckSlowController.text.trim()) ?? 0) : 0,
          neckFast: _testName == 'Residual Stress Test' ? (int.tryParse(_neckFastController.text.trim()) ?? 0) : 0,
          shoulderSlow: _testName == 'Residual Stress Test' ? (int.tryParse(_shoulderSlowController.text.trim()) ?? 0) : 0,
          shoulderFast: _testName == 'Residual Stress Test' ? (int.tryParse(_shoulderFastController.text.trim()) ?? 0) : 0,
          bodySlow: _testName == 'Residual Stress Test' ? (int.tryParse(_bodySlowController.text.trim()) ?? 0) : 0,
          bodyFast: _testName == 'Residual Stress Test' ? (int.tryParse(_bodyFastController.text.trim()) ?? 0) : 0,
          headSlow: _testName == 'Residual Stress Test' ? (int.tryParse(_headSlowController.text.trim()) ?? 0) : 0,
          headFast: _testName == 'Residual Stress Test' ? (int.tryParse(_headFastController.text.trim()) ?? 0) : 0,
          functionLevel1: _testName == 'Function Test' ? (int.tryParse(_functionLevel1Controller.text.trim()) ?? 0) : 0,
          functionLevel2: _testName == 'Function Test' ? (int.tryParse(_functionLevel2Controller.text.trim()) ?? 0) : 0,
          functionLevel3: _testName == 'Function Test' ? (int.tryParse(_functionLevel3Controller.text.trim()) ?? 0) : 0,
          functionLevel4: _testName == 'Function Test' ? (int.tryParse(_functionLevel4Controller.text.trim()) ?? 0) : 0,
          attachmentName: _attachmentName,
          attachmentBase64: _attachmentBase64,
          functionDefectDetails: _testName == 'Function Test' ? _functionDefectDetails : '',
          primerLot: (_testName == 'Primer Sensitivity Test' || _testName == 'EPVAT test')
              ? (_selectedComponentPrimerLot ?? _primerLotController.text.trim())
              : '',
          primerSupplier: (_testName == 'Primer Sensitivity Test' || _testName == 'EPVAT test')
              ? _primerSupplier
              : '',
          primerInsertionDepth: _testName == 'Primer Sensitivity Test'
              ? _primerInsertionDepthController.text.trim()
              : '',
          propellantSupplier: (_testName == 'Propellant Test' || _testName == 'EPVAT test') ? _propellantSupplier : '',
          propellantCode: (_testName == 'Propellant Test' || _testName == 'EPVAT test') ? _propellantCodeController.text.trim() : '',
          propellantLot: (_testName == 'Propellant Test' || _testName == 'EPVAT test') ? (_selectedComponentPropellantLot ?? _propellantLotController.text.trim()) : '',
          propellantCharge: (_testName == 'Propellant Test' || _testName == 'EPVAT test') ? _propellantChargeController.text.trim() : '',
        );
        await widget.onSubmit(record);
      }

      // Clear form on success
      _attachmentName = '';
      _attachmentBase64 = '';
      _funcDefectItemCounts.clear();
      _operatorsController.text = widget.loggedInUser;
      _lotController.clear();
      _lotThreeDigitsController.clear();
      final currentYearSuffix = (DateTime.now().year % 100).toString().padLeft(2, '0');
      _lotYearController.text = currentYearSuffix;
      _producedController.text = _getDefaultSampleSize(
        test: _testName,
        caliber: _caliber,
        module: widget.currentModule,
        isThreeTemp: _isThreeTemperatureMode,
      ).toString();
      _primerInsertionDepthController.clear();
      _primerLotController.clear();
      _propellantLotController.clear();
      _propellantChargeController.clear();
      _propellantCodeController.text = 'D-073.4';
      _defectsController.text = '0';
      _functionLevel1Controller.text = '0';
      _functionLevel2Controller.text = '0';
      _functionLevel3Controller.text = '0';
      _functionLevel4Controller.text = '0';
      for (var c in _funcAllProducedControllers.values) {
        c.text = '20';
      }
      for (var c in _funcAllL1Controllers.values) {
        c.text = '0';
      }
      for (var c in _funcAllL2Controllers.values) {
        c.text = '0';
      }
      for (var c in _funcAllL3Controllers.values) {
        c.text = '0';
      }
      for (var c in _funcAllL4Controllers.values) {
        c.text = '0';
      }
      _notesController.clear();
      _requirementController.clear();
      _viscosityController.clear();
      _locationController.clear();
      _mouthSlowController.clear();
      _mouthFastController.clear();
      _primerSlowController.clear();
      _primerFastController.clear();
      _barrelSNController.text = _barrelSerialNumbers.isNotEmpty ? _barrelSerialNumbers.first : '';
      _updateDefaultDistance();
      _meanXController.clear();
      _maxXController.clear();
      _minXController.clear();
      _rangeXController.clear();
      _sdXController.clear();
      _meanYController.clear();
      _maxYController.clear();
      _minYController.clear();
      _rangeYController.clear();
      _sdYController.clear();
      _meanRadiusController.clear();
      _meanVelController.clear();
      _minVelController.clear();
      _maxVelController.clear();
      _rangeVelController.clear();
      _sdVelController.clear();
      for (var ctrl in _extractionRoundsControllers) {
        ctrl.dispose();
      }
      _extractionRoundsControllers.clear();
      _extractionRoundsControllers.add(TextEditingController());
      
      _cartridgeTempController.clear();
      _roomTempController.clear();
      _epvatSensor1Controller.clear();
      _epvatSensor2Controller.clear();
      _cyclicRateController.clear();
      _cyclicRateWeaponType = '';
      _cyclicRateAmmoType = 'Rifle';
      for (var c in _terminalVelocityRoundsControllers) {
        c.clear();
      }
      _terminalBarrelSNController.text = _barrelSerialNumbers.isNotEmpty ? _barrelSerialNumbers.first : '';
      _terminalDistanceController.clear();
      _terminalHoleDiameterRounds.clear();
      _terminalSteelPenetrationRounds.clear();
      _terminalAluminumPenetrationRounds.clear();
      _syncTerminalRoundsControllers(20);
      _neckSlowController.text = '0';
      _neckFastController.text = '0';
      _shoulderSlowController.text = '0';
      _shoulderFastController.text = '0';
      _bodySlowController.text = '0';
      _bodyFastController.text = '0';
      _headSlowController.text = '0';
      _headFastController.text = '0';
      _epvatMeanPressureController.clear();
      _epvatMaxPressureController.clear();
      _epvatMinPressureController.clear();
      _epvatRangePressureController.clear();
      _epvatSDPressureController.clear();
      for (var ctrl in _epvatRoundsControllers) {
        ctrl.dispose();
      }
      _epvatRoundsControllers.clear();
      _epvatRoundsControllers.add(TextEditingController());

      // Clear new EPVAT controllers
      _epvatP2MeanPressureController.clear();
      _epvatP2MaxPressureController.clear();
      _epvatP2MinPressureController.clear();
      _epvatP2RangePressureController.clear();
      _epvatP2SDPressureController.clear();
      for (var ctrl in _epvatP2RoundsControllers) {
        ctrl.dispose();
      }
      _epvatP2RoundsControllers.clear();
      _epvatP2RoundsControllers.add(TextEditingController());

      for (var ctrl in _epvatVelRoundsControllers) {
        ctrl.dispose();
      }
      _epvatVelRoundsControllers.clear();
      _epvatVelRoundsControllers.add(TextEditingController());

      _overallEpvatControllers.forEach((temp, metricsMap) {
        metricsMap.forEach((key, controller) {
          controller.clear();
        });
      });

      _actionTimeMeanController.clear();
      _actionTimeMaxController.clear();
      _actionTimeMinController.clear();
      _actionTimeRangeController.clear();
      _actionTimeSDController.clear();
      for (var ctrl in _actionTimeRoundsControllers) {
        ctrl.dispose();
      }
      _actionTimeRoundsControllers.clear();
      _actionTimeRoundsControllers.add(TextEditingController());

      for (var ctrl in _primerDropHeightControllers) {
        ctrl.dispose();
      }
      _primerDropHeightControllers.clear();
      _primerDropHeightControllers.add(TextEditingController());
      _primerFireResults.clear();
      _primerFireResults.add('Fire');
      _primerHbarController.clear();
      _primerSDController.clear();
      _primerHbarPlus5SController.clear();
      _primerHbarMinus2SController.clear();
      _primerMisfiresCountController.text = '0';

      _autoSaveDebounce?.cancel();
      await _storageService.clearFormDraft();

      _autoGenerateTime(force: true);
      if (_testName == 'Waterproof Test') {
        if (_caliber.contains('M82') || _caliber.contains('M200')) {
          _pressureController.text = '0.14';
        } else {
          _pressureController.text = '0.5';
        }
      } else {
        _pressureController.clear();
      }
      
      setState(() {
        _status = 'Approved';
        _autoSaveStatus = '';
        _lastAutoSaveTime = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quality entry recorded successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save record: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8.0, bottom: 64.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Cancel Test Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Record Quality Specification',
                        style: TextStyle(
                          fontSize: 26.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        'Log fresh ballistic trial, lot tolerances, and mechanical parameters',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                OutlinedButton.icon(
                  onPressed: _confirmCancelTest,
                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 18),
                  label: const Text(
                    'Cancel Test',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24.0),

            // Form container card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 14.0 : 24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF344D6E),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    blurRadius: 16.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auto-Save Status Banner
                  if (_autoSaveStatus.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14.0, color: Color(0xFF10B981)),
                          const SizedBox(width: 6.0),
                          Text(
                            _autoSaveStatus,
                            style: const TextStyle(fontSize: 12.0, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Consolidated Header Row: Operators, Shift, Test Time, Caliber, Lot/Hopper, Test Name
                  _buildFormRow([
                    _buildFlexibleField(
                      key: _operatorFieldKey,
                      flex: 3,
                      label: 'Operators / Inspectors',
                      isRequired: true,
                      child: _buildTextField(
                        controller: _operatorsController,
                        focusNode: _operatorFocusNode,
                        hint: 'e.g., Ahmed, Salim',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Inspectors required' : null,
                      ),
                    ),
                    _buildFlexibleField(
                      key: _shiftFieldKey,
                      flex: 2,
                      label: 'Shift',
                      isRequired: true,
                      child: _buildDropdownField(
                        value: _shift,
                        items: ['Day', 'Night'],
                        onChanged: (v) => setState(() => _shift = v!),
                      ),
                    ),
                    _buildFlexibleField(
                      key: _testTimeFieldKey,
                      flex: 3,
                      label: 'Date & Time',
                      isRequired: true,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _testTimeController,
                              focusNode: _testTimeFocusNode,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0284C7)),
                              tooltip: 'Pick date & time from calendar',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: _pickDateTime,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0284C7)),
                              tooltip: 'Refresh date & time to now',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => setState(() => _autoGenerateTime(force: true)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildFlexibleField(
                      key: _caliberFieldKey,
                      flex: 3,
                      label: 'Caliber Specification',
                      isRequired: true,
                      child: _buildDropdownField(
                        value: _caliber,
                        items: calibers,
                        onChanged: (v) {
                          if (v != null) _onCaliberSelected(v);
                        },
                      ),
                    ),
                    _buildFlexibleField(
                      key: _lotFieldKey,
                      flex: 3,
                      label: widget.currentModule == 'Lot Acceptance Test'
                          ? 'Lot Number'
                          : (widget.currentModule == 'Component Test'
                              ? (_testName == 'Primer Sensitivity Test' ? 'Primer Lot No.' : 'Propellant Lot No.')
                              : 'Hopper No.'),
                      isRequired: true,
                      child: _buildLotNoField(focusNode: _lotFocusNode),
                    ),
                    _buildFlexibleField(
                      flex: 3,
                      label: 'Test Name',
                      isRequired: true,
                      child: _buildDropdownField(
                        value: _testName,
                        items: _allowedTestsForCaliber(_caliber),
                        onChanged: (v) {
                          if (v != null) _onTestNameSelected(v);
                        },
                      ),
                    ),
                  ], lockSingleRow: true),
                  const SizedBox(height: 20.0),
                  _buildComponentAndPrimerFieldsCard(),
                  _buildAdminInstructionsCard(),

                  // Function Test Specifications Sub-Card (Dynamic)
                  if (_testName == 'Function Test') ...[
                    _buildFunctionTestSpecsCard(),
                    const SizedBox(height: 20.0),
                  ],

                  // Consolidated Row 2 (Viscosity, Sampling Location, Quality Status, Quantity Tested, Barrel Number, Transducers in 1 or max 2 rows)
                  _buildConsolidatedRow2(),
                  const SizedBox(height: 20.0),

                  // Function Test 4-Level Defects Section (Dynamic)
                  if (_testName == 'Function Test') ...[
                    _buildFunctionTestDefectsCard(),
                    const SizedBox(height: 20.0),
                  ],

                  // Waterproof Leakage Test Results Section (Dynamic)
                  if (_testName == 'Waterproof Test') ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.list_alt_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Test Result (Waterproof Leaks)',
                                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),

                          // TABLE HEADERS
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text('Location', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Slow Leak (Rounds)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Fast Leak (Rounds)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 16.0),

                          // ROW 1: MOUTH
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text('Mouth', style: TextStyle(color: Colors.white70, fontSize: 13.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _mouthSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _mouthFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // ROW 2: PRIMER
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text('Primer', style: TextStyle(color: Colors.white70, fontSize: 13.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _primerSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _primerFastController),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 24.0),

                          // CALCULATED TOTAL DISPLAY
                          Builder(
                            builder: (context) {
                              final ms = int.tryParse(_mouthSlowController.text) ?? 0;
                              final mf = int.tryParse(_mouthFastController.text) ?? 0;
                              final ps = int.tryParse(_primerSlowController.text) ?? 0;
                              final pf = int.tryParse(_primerFastController.text) ?? 0;
                              final total = ms + mf + ps + pf;
                              final bool isM82OrM200 = _caliber.contains('M82') || _caliber.contains('M200');
                              final bool isRed = total >= (isM82OrM200 ? 9 : 7);

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Leaks Count:',
                                    style: TextStyle(
                                      color: isRed ? const Color(0xFFEF4444) : const Color(0xFF8E96A3),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.0,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: isRed ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(color: isRed ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isRed) ...[
                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 14.0),
                                          const SizedBox(width: 6.0),
                                        ],
                                        Text(
                                          '$total Leaks',
                                          style: TextStyle(
                                            color: isRed ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            fontFamily: 'JetBrainsMono',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],

                  // Residual Stress Test UI (Dynamic)
                  if (_testName == 'Residual Stress Test') ...[
                    // 1. Stress Test setup card (Room Temp)
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.thermostat_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Residual Stress Test Setup',
                                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          _buildFormRow([
                            _buildFlexibleField(
                              key: _roomTempFieldKey,
                              flex: 1,
                              label: 'Room Temperature (°C)',
                              isRequired: true,
                              child: _buildTextField(
                                controller: _roomTempController,
                                focusNode: _roomTempFocusNode,
                                hint: 'e.g., 22.5',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                validator: (v) => _testName == 'Residual Stress Test' && (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Sampling Location',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildDropdownField(
                                      value: _locationController.text.isNotEmpty && _allSampleLocations.contains(_locationController.text)
                                          ? _locationController.text
                                          : _allSampleLocations.first,
                                      items: _allSampleLocations,
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _locationController.text = v);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF0284C7), size: 18),
                                      tooltip: 'Admin: Add new sample location',
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                      onPressed: _showAddLocationDialog,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // 2. Splits/cracks grid card
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.report_problem_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Test Result (Splits/Cracks per Zone)',
                                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),

                          // TABLE HEADERS
                          Row(
                            children: const [
                              Expanded(
                                flex: 2,
                                child: Text('Crack Zone', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Hairline Crack (Minor)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Split/Crack (Major)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 16.0),

                          // ROW 1: Neck (I zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Neck (I zone)', style: TextStyle(color: Colors.white70, fontSize: 13.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _neckSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _neckFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // ROW 2: Shoulder (S zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Shoulder (S zone)', style: TextStyle(color: Colors.white70, fontSize: 13.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _shoulderSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _shoulderFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // ROW 3: Body (J & K zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Body (J & K zone)', style: TextStyle(color: Colors.white70, fontSize: 13.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _bodySlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _bodyFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // ROW 4: Head (L & M zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Head (L & M zone)', style: TextStyle(color: Colors.white70, fontSize: 13.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _headSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _buildLeakTextField(controller: _headFastController),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 24.0),

                          // CALCULATED TOTAL DISPLAY
                          Builder(
                            builder: (context) {
                              final ns = int.tryParse(_neckSlowController.text) ?? 0;
                              final nf = int.tryParse(_neckFastController.text) ?? 0;
                              final ss = int.tryParse(_shoulderSlowController.text) ?? 0;
                              final sf = int.tryParse(_shoulderFastController.text) ?? 0;
                              final bs = int.tryParse(_bodySlowController.text) ?? 0;
                              final bf = int.tryParse(_bodyFastController.text) ?? 0;
                              final hs = int.tryParse(_headSlowController.text) ?? 0;
                              final hf = int.tryParse(_headFastController.text) ?? 0;
                              final total = ns + nf + ss + sf + bs + bf + hs + hf;
                              
                              final rs = widget.adminRules['residual_stress'] ?? {};
                              final int rejectLimit = rs['reject_limit'] ?? 3;
                              final bool isRed = total >= rejectLimit;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Splits/Cracks:',
                                    style: TextStyle(
                                      color: isRed ? const Color(0xFFEF4444) : const Color(0xFF8E96A3),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.0,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: isRed ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(color: isRed ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isRed) ...[
                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 14.0),
                                          const SizedBox(width: 6.0),
                                        ],
                                        Text(
                                          '$total Splits/Cracks',
                                          style: TextStyle(
                                            color: isRed ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            fontFamily: 'JetBrainsMono',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // 3. Cartridge classification reference diagram
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.photo_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Residual Stress Classification Reference Diagram',
                                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.asset(
                                _isCaliber9mm ? 'assets/cartridge_9mm.png' : 'assets/cartridge_bottleneck.png',
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          Center(
                            child: Text(
                              _isCaliber9mm ? '9mm Residual Stress Reference Diagram' : '5.56 / 7.62 Residual Stress Reference Diagram',
                              style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],

                  // Cyclic Rate Test UI
                  if (_testName == 'Firing Rate Cycle Test') ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.speed_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text('Firing Rate Cycle Test', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Builder(builder: (context) {
                            final allWeapons = List<Map<String, dynamic>>.from(
                              (widget.adminRules['cyclic_rate']?['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
                            );
                            
                            // Merge registered fleet weapons
                            final adminFleet = widget.adminRules['weapons'];
                            if (adminFleet is List) {
                              for (final item in adminFleet) {
                                String label = '';
                                String cat = 'Rifle';
                                if (item is Map) {
                                  final t = (item['type'] ?? '').toString();
                                  final s = (item['serial'] ?? '').toString();
                                  final c = (item['category'] ?? '').toString();
                                  label = s.isNotEmpty ? '$t (SN: $s)' : t;
                                  if (c.toLowerCase().contains('machine') || t.toLowerCase().contains('saw') || t.toLowerCase().contains('minimi')) cat = 'Machine Gun';
                                } else if (item != null) {
                                  label = item.toString();
                                }
                                if (label.isNotEmpty && !allWeapons.any((w) => w['name'] == label)) {
                                  allWeapons.add({
                                    'name': label,
                                    'type': cat,
                                    'min': 550,
                                    'max': 950,
                                  });
                                }
                              }
                            }
                            for (final wLabel in _weaponsList) {
                              if (!allWeapons.any((w) => w['name'] == wLabel)) {
                                final isMg = wLabel.toLowerCase().contains('machine') || wLabel.toLowerCase().contains('saw') || wLabel.toLowerCase().contains('minimi');
                                allWeapons.add({
                                  'name': wLabel,
                                  'type': isMg ? 'Machine Gun' : 'Rifle',
                                  'min': 550,
                                  'max': 950,
                                });
                              }
                            }
                            
                            // Filter weapons by category (Rifle vs Machine Gun)
                            final isMgSelected = _cyclicRateAmmoType == 'Machine Gun';
                            final filteredWeapons = allWeapons.where((w) {
                              final wType = (w['type'] ?? '').toString().toLowerCase();
                              final wName = (w['name'] ?? '').toString().toLowerCase();
                              if (isMgSelected) {
                                return wType == 'machine gun' || wType == 'linked' || wName.contains('saw') || wName.contains('minimi') || wName.contains('mg');
                              } else {
                                return wType != 'machine gun' && wType != 'linked' && !wName.contains('saw') && !wName.contains('minimi');
                              }
                            }).toList();
                            
                            final weapons = filteredWeapons.isNotEmpty ? filteredWeapons : allWeapons;

                            if (_cyclicRateWeaponType.isEmpty && weapons.isNotEmpty) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _cyclicRateWeaponType = weapons.first['name'] ?? '');
                              });
                            } else if (_cyclicRateWeaponType.isNotEmpty && weapons.isNotEmpty && !weapons.any((w) => w['name'] == _cyclicRateWeaponType)) {
                              // If current weapon doesn't match selected category, switch to first in filtered list
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _cyclicRateWeaponType = weapons.first['name'] ?? '');
                              });
                            }

                            final selectedWeapon = weapons.firstWhere(
                              (w) => w['name'] == _cyclicRateWeaponType,
                              orElse: () => weapons.isNotEmpty ? weapons.first : {},
                            );

                            final int rpmMin = (selectedWeapon['min'] ?? 0) as int;
                            final int? rpmMax = selectedWeapon['max'] as int?;
                            final double? enteredRpm = double.tryParse(_cyclicRateController.text.trim());
                            final bool isOutOfRange = enteredRpm != null && (enteredRpm < rpmMin || (rpmMax != null && enteredRpm > rpmMax));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Category: ', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5)),
                                    const SizedBox(width: 12.0),
                                    _buildCyclicAmmoRadio('Rifle'),
                                    const SizedBox(width: 16.0),
                                    _buildCyclicAmmoRadio('Machine Gun'),
                                  ],
                                ),
                                const SizedBox(height: 14.0),
                                const Text('Weapon Type', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6.0),
                                if (weapons.isEmpty)
                                  const Text('No weapons configured for this category in Control Panel.', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.0))
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C415E),
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(color: const Color(0xFF1E3A8A)),
                                    ),
                                    child: DropdownButton<String>(
                                      value: weapons.any((w) => w['name'] == _cyclicRateWeaponType) ? _cyclicRateWeaponType : (weapons.isNotEmpty ? weapons.first['name'] as String : ''),
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF344D6E),
                                      underline: const SizedBox(),
                                      style: const TextStyle(color: Colors.white, fontSize: 13.0),
                                      onChanged: (val) => setState(() => _cyclicRateWeaponType = val ?? ''),
                                      items: weapons.map((w) => DropdownMenuItem<String>(value: w['name'] as String, child: Text(w['name'] ?? ''))).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 14.0),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Cyclic Rate (RPM)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6.0),
                                          _buildTextField(
                                            controller: _cyclicRateController,
                                            hint: 'Enter measured RPM',
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            onChanged: (v) => setState(() {}),
                                            validator: (v) {
                                              if (v == null || v.trim().isEmpty) return 'Required';
                                              final val = double.tryParse(v.trim());
                                              if (val == null) return 'Must be a number';
                                              if (val < rpmMin || (rpmMax != null && val > rpmMax)) {
                                                return rpmMax == null ? 'Must be \u2265 $rpmMin RPM' : 'Must be $rpmMin \u2013 $rpmMax RPM';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16.0),
                                    Container(
                                      margin: const EdgeInsets.only(top: 22.0),
                                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                      decoration: BoxDecoration(
                                        color: isOutOfRange ? const Color(0xFFEF4444).withOpacity(0.1) : const Color(0xFF10B981).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: isOutOfRange ? const Color(0xFFEF4444).withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Limit ($_cyclicRateAmmoType)', style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4.0),
                                          Text(rpmMax == null ? '\u2265 $rpmMin RPM' : '$rpmMin \u2013 $rpmMax RPM', style: TextStyle(
                                            color: isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                            fontSize: 13.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono',
                                          )),
                                          if (isOutOfRange) ...const [
                                            SizedBox(height: 4.0),
                                            Row(mainAxisSize: MainAxisSize.min, children: [
                                              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 13.0),
                                              SizedBox(width: 4.0),
                                              Text('Out of range', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5)),
                                            ]),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],

                  // Terminal Effect Test UI
                  if (_testName == 'Terminal Effect Test') ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.gps_fixed_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text('Terminal Effect Test Setup', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          _buildFormRow([
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Barrel S.N',
                              child: _buildDropdownField(
                                value: _barrelSerialNumbers.contains(_terminalBarrelSNController.text)
                                    ? _terminalBarrelSNController.text
                                    : (_barrelSerialNumbers.isNotEmpty ? _barrelSerialNumbers.first : ''),
                                items: _barrelSerialNumbers,
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _terminalBarrelSNController.text = v);
                                  }
                                },
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Distance (m)',
                              child: _buildTextField(
                                controller: _terminalDistanceController,
                                hint: 'e.g., 100',
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.track_changes_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text('Terminal Effect Results (Round-by-Round)', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Table(
                              defaultColumnWidth: const FixedColumnWidth(130.0),
                              columnWidths: const {
                                0: FixedColumnWidth(60.0),   // Round #
                                1: FixedColumnWidth(180.0),  // Hole Diameter
                                2: FixedColumnWidth(140.0),  // Steel Penetration
                                3: FixedColumnWidth(140.0),  // Aluminum Penetration
                                4: FixedColumnWidth(130.0),  // Velocity (m/s)
                              },
                              children: [
                                // Table Header
                                TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(8.0), child: Text('Round', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    Padding(padding: const EdgeInsets.all(8.0), child: Text('Hole > Bullet?', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    Padding(padding: const EdgeInsets.all(8.0), child: Text('Steel Penetration', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    Padding(padding: const EdgeInsets.all(8.0), child: Text('Alum Penetration', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    Padding(padding: const EdgeInsets.all(8.0), child: Text('Velocity (m/s)', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                // Table Rows
                                ...List.generate(_getTerminalVisibleRounds(), (idx) {
                                  // Make sure list elements are initialized
                                  while (_terminalHoleDiameterRounds.length <= idx) {
                                    _terminalHoleDiameterRounds.add('Yes');
                                  }
                                  while (_terminalSteelPenetrationRounds.length <= idx) {
                                    _terminalSteelPenetrationRounds.add('Yes');
                                  }
                                  while (_terminalAluminumPenetrationRounds.length <= idx) {
                                    _terminalAluminumPenetrationRounds.add('Yes');
                                  }
                                  
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 12.5))),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2C415E),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: const Color(0xFF1E3A8A)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _terminalHoleDiameterRounds[idx],
                                              dropdownColor: const Color(0xFF344D6E),
                                              style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                              onChanged: (v) => setState(() => _terminalHoleDiameterRounds[idx] = v!),
                                              items: const [
                                                DropdownMenuItem(value: 'Yes', child: Text('Hole > Bullet')),
                                                DropdownMenuItem(value: 'No', child: Text('Hole \u2264 Bullet')),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2C415E),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: const Color(0xFF1E3A8A)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _terminalSteelPenetrationRounds[idx],
                                              dropdownColor: const Color(0xFF344D6E),
                                              style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                              onChanged: (v) => setState(() => _terminalSteelPenetrationRounds[idx] = v!),
                                              items: const [
                                                DropdownMenuItem(value: 'Yes', child: Text('Yes (Passed)')),
                                                DropdownMenuItem(value: 'No', child: Text('No (Failed)')),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2C415E),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: const Color(0xFF1E3A8A)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _terminalAluminumPenetrationRounds[idx],
                                              dropdownColor: const Color(0xFF344D6E),
                                              style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                              onChanged: (v) => setState(() => _terminalAluminumPenetrationRounds[idx] = v!),
                                              items: const [
                                                DropdownMenuItem(value: 'Yes', child: Text('Yes (Passed)')),
                                                DropdownMenuItem(value: 'No', child: Text('No (Failed)')),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                        child: _buildTextField(
                                          controller: _terminalVelocityRoundsControllers[idx],
                                          hint: 'm/s (opt)',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          validator: null,
                                          onChanged: (val) {
                                            setState(() {});
                                            _scheduleAutoSave();
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],

                  if (_testName == 'Accuracy Test') ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),

                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.gps_fixed_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Accuracy Test Specifications',
                                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          if (_caliber == '5.56x45 M193') ...[
                            const SizedBox(height: 16.0),
                            const Text(
                              'Coordinate Target Deviation / Mean Radius (mm)',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8.0),
                            _buildFormRow([
                              _buildFlexibleField(
                                flex: 1,
                                label: 'SD of X',
                                child: _buildTextField(
                                  controller: _sdXController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'SD of Y',
                                child: _buildTextField(
                                  controller: _sdYController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Mean Radius',
                                child: _buildTextField(
                                  controller: _meanRadiusController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                ),
                              ),
                            ]),
                          ] else ...[
                            const SizedBox(height: 16.0),
                            const Text(
                              'X-Coordinate Target Deviation (mm)',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8.0),
                            _buildFormRow([
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Mean of X',
                                child: _buildTextField(
                                  controller: _meanXController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Max of X',
                                child: _buildTextField(
                                  controller: _maxXController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Min of X',
                                child: _buildTextField(
                                  controller: _minXController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Range of X',
                                child: _buildTextField(
                                  controller: _rangeXController,
                                  hint: '0.0',
                                  readOnly: true,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'SD of X',
                                child: _buildTextField(
                                  controller: _sdXController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16.0),
                            const Text(
                              'Y-Coordinate Target Deviation (mm)',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8.0),
                            _buildFormRow([
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Mean of Y',
                                child: _buildTextField(
                                  controller: _meanYController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Max of Y',
                                child: _buildTextField(
                                  controller: _maxYController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Min of Y',
                                child: _buildTextField(
                                  controller: _minYController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'Range of Y',
                                child: _buildTextField(
                                  controller: _rangeYController,
                                  hint: '0.0',
                                  readOnly: true,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 1,
                                label: 'SD of Y',
                                child: _buildTextField(
                                  controller: _sdYController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                ),
                              ),
                            ]),
                          ],
                          const SizedBox(height: 16.0),
                          const Text(
                            'Velocity Parameters (m/s)',
                            style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          _buildFormRow([
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Mean Vel',
                              child: _buildTextField(
                                controller: _meanVelController,
                                hint: '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Max Vel',
                              child: _buildTextField(
                                controller: _maxVelController,
                                hint: '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Min Vel',
                              child: _buildTextField(
                                controller: _minVelController,
                                hint: '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Range Vel',
                              child: _buildTextField(
                                controller: _rangeVelController,
                                hint: '0.0',
                                readOnly: true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'SD Vel',
                              child: _buildTextField(
                                controller: _sdVelController,
                                hint: '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16.0),
                          const Text(
                            'Dispersion & Largest Distance (mm)',
                            style: TextStyle(color: Color(0xFF0284C7), fontSize: 12.0, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          _buildFormRow([
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Largest Distance (mm)',
                              child: _buildTextField(
                                controller: _accLargestDistanceController,
                                hint: '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],

                  if (_testName == 'Extraction Force Test') ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.layers_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Extraction Force Test Specifications',
                                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              const Text('Result Input Mode: ', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5)),
                              const SizedBox(width: 12.0),
                              _buildModeRadioButton('Overall', 'Overall Results'),
                              const SizedBox(width: 16.0),
                              _buildModeRadioButton('Individual', 'Individual Rounds'),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          if (_extractionForceType == 'Individual') ...[
                            const Text(
                              'Individual Round Inputs (Newtons)',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8.0),
                            Wrap(
                              spacing: 12.0,
                              runSpacing: 12.0,
                              children: List.generate(_extractionRoundsControllers.length, (index) {
                                return SizedBox(
                                  width: 90.0,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Round ${index + 1}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.0, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 4.0),
                                      _buildTextField(
                                        controller: _extractionRoundsControllers[index],
                                        hint: '0.0',
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (val) {
                                          if (index == _extractionRoundsControllers.length - 1 && val.trim().isNotEmpty) {
                                            setState(() {
                                              _extractionRoundsControllers.add(TextEditingController());
                                            });
                                          }
                                          _recalculateExtractionStats();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20.0),
                            const Text(
                              'Auto-Calculated Statistics',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                          ] else ...[
                            const Text(
                              'Overall Extraction Force (Newtons)',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                          ],
                          const SizedBox(height: 8.0),
                          _buildFormRow([
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Min Force',
                              child: _buildTextField(
                                controller: _minXController,
                                hint: '0.0',
                                readOnly: _extractionForceType == 'Individual',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Max Force',
                              child: _buildTextField(
                                controller: _maxXController,
                                hint: '0.0',
                                readOnly: _extractionForceType == 'Individual',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Mean Force',
                              child: _buildTextField(
                                controller: _meanXController,
                                hint: '0.0',
                                readOnly: _extractionForceType == 'Individual',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Force SD',
                              child: _buildTextField(
                                controller: _sdXController,
                                hint: '0.0',
                                readOnly: _extractionForceType == 'Individual',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Force Range',
                              child: _buildTextField(
                                controller: _rangeXController,
                                hint: '0.0',
                                readOnly: true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],

                  if (_testName == 'EPVAT test' || _testName == 'Propellant Test') ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.compress_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'EPVAT Pressure & Velocity Specifications',
                                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              const Text('Pressure Unit: ', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5)),
                              const SizedBox(width: 12.0),
                              _buildEpvatUnitRadioButton('bar', 'bar'),
                              const SizedBox(width: 16.0),
                              _buildEpvatUnitRadioButton('MPa', 'MPa'),
                              const SizedBox(width: 16.0),
                              _buildEpvatUnitRadioButton('kg/cm²', 'kg/cm²'),
                            ],
                          ),
                          const SizedBox(height: 20.0),
                          if (_epvatPressureType == 'Overall') ...[
                            // Overall mode layout: Tabbed container for temperatures +21, +52, -54
                            const Text(
                              'Overall Trial Parameters by Temperature',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12.0),
                            Row(
                              children: [0, 1, 2].map((idx) {
                                final tempKeys = ['+21', '+52', '-54'];
                                final labels = ['+21 °C', '+52 °C', '-54 °C'];
                                final tKey = tempKeys[idx];
                                final hasData = (_overallEpvatControllers[tKey]?['vel_mean']?.text.trim().isNotEmpty ?? false) ||
                                                (_overallEpvatControllers[tKey]?['p1_mean']?.text.trim().isNotEmpty ?? false) ||
                                                (_overallEpvatP1RoundsControllers[tKey]?.any((c) => c.text.trim().isNotEmpty) ?? false);
                                final isSelected = _activeEpvatTempTabIndex == idx;
                                return GestureDetector(
                                  onTap: () => setState(() => _activeEpvatTempTabIndex = idx),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12.0),
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          labels[idx],
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.0,
                                          ),
                                        ),
                                        if (hasData) ...[
                                          const SizedBox(width: 6.0),
                                          Icon(Icons.check_circle, size: 14.0, color: isSelected ? Colors.black : const Color(0xFF10B981)),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20.0),
                            Builder(
                              builder: (context) {
                                final tempKeys = ['+21', '+52', '-54'];
                                final t = tempKeys[_activeEpvatTempTabIndex];
                                final isIndividualMode = _epvatOverallSubMode[t] == 'Individual Rounds';
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Sub-mode selector
                                    Row(
                                      children: [
                                        const Text('Result Entry Method: ', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5)),
                                        const SizedBox(width: 12.0),
                                        ChoiceChip(
                                          label: const Text('Stats Only', style: TextStyle(fontSize: 12.0)),
                                          selected: _epvatOverallSubMode[t] == 'Stats Only',
                                          selectedColor: const Color(0xFF06B6D4),
                                          backgroundColor: Colors.white.withOpacity(0.05),
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                _epvatOverallSubMode[t] = 'Stats Only';
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 12.0),
                                        ChoiceChip(
                                          label: const Text('Individual Rounds', style: TextStyle(fontSize: 12.0)),
                                          selected: _epvatOverallSubMode[t] == 'Individual Rounds',
                                          selectedColor: const Color(0xFF06B6D4),
                                          backgroundColor: Colors.white.withOpacity(0.05),
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                _epvatOverallSubMode[t] = 'Individual Rounds';
                                              });
                                              _calculateOverallTempStats(t);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16.0),
                                    
                                    if (isIndividualMode) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Individual Round Inputs',
                                            style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                          ),
                                          Row(
                                            children: [
                                              const Text('Rounds: ', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0)),
                                              const SizedBox(width: 8.0),
                                              DropdownButton<int>(
                                                value: _epvatOverallRoundCount[t] ?? 30,
                                                dropdownColor: const Color(0xFF344D6E),
                                                style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                                underline: const SizedBox(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() {
                                                      _epvatOverallRoundCount[t] = val;
                                                    });
                                                    _calculateOverallTempStats(t);
                                                  }
                                                },
                                                items: ({5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 100, _epvatOverallRoundCount[t] ?? 30}.toList()..sort()).map((int count) {
                                                  return DropdownMenuItem<int>(
                                                    value: count,
                                                    child: Text('$count Rounds'),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      Row(
                                        children: [
                                          const Expanded(flex: 1, child: Text('Round', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          const Expanded(flex: 2, child: Text('Velocity (m/s)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          const Expanded(flex: 2, child: Text('Action Time (ms)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          Expanded(flex: 2, child: Text(_isCaliber9mm ? 'Chamber Pres.' : 'GP1 (Chamber) Pres.', style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          if (!_isCaliber9mm)
                                            const Expanded(flex: 2, child: Text('GP2 (Port) Pres.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      Container(
                                        height: 240.0,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8.0),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(8.0),
                                          itemCount: _getOverallEpvatVisibleRounds(t),
                                          itemBuilder: (context, rIdx) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      'Round ${rIdx + 1}',
                                                      style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                      child: _buildTextField(
                                                        controller: _overallEpvatVelRoundsControllers[t]![rIdx],
                                                        hint: 'm/s',
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                      child: _buildTextField(
                                                        controller: _overallEpvatActionTimeRoundsControllers[t]![rIdx],
                                                        hint: 'ms',
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        inputFormatters: [ActionTimeInputFormatter()],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                      child: _buildTextField(
                                                        controller: _overallEpvatP1RoundsControllers[t]![rIdx],
                                                        hint: 'P1',
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      ),
                                                    ),
                                                  ),
                                                  if (!_isCaliber9mm)
                                                    Expanded(
                                                      flex: 2,
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                        child: _buildTextField(
                                                          controller: _overallEpvatP2RoundsControllers[t]![rIdx],
                                                          hint: 'P2',
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 20.0),
                                    ],
                                    
                                    Text(
                                      'Summary Statistics Evaluation ($t °C)',
                                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13.0, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12.0),
                                    Text(
                                      _isCaliber9mm ? 'Chamber Pressure ($t °C) (${_epvatPressureUnit})' : 'GP1 (Chamber) Pressure ($t °C) (${_epvatPressureUnit})',
                                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _buildFormRow([
                                      _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Mean P' : 'Mean P1', child: _buildTextField(controller: _overallEpvatControllers[t]!['p1_mean']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                                      _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Max P' : 'Max P1', child: _buildTextField(controller: _overallEpvatControllers[t]!['p1_max']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                      _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Min P' : 'Min P1', child: _buildTextField(controller: _overallEpvatControllers[t]!['p1_min']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                      _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Range P' : 'Range P1', child: _buildTextField(controller: _overallEpvatControllers[t]!['p1_range']!, hint: '0.0', readOnly: true, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                      _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'SD P' : 'SD P1', child: _buildTextField(controller: _overallEpvatControllers[t]!['p1_sd']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                    ]),
                                    if (!_isCaliber9mm) ...[
                                      const SizedBox(height: 16.0),
                                      Text(
                                        'GP2 (Port) Pressure ($t °C) (${_epvatPressureUnit})',
                                        style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8.0),
                                      _buildFormRow([
                                        _buildFlexibleField(flex: 1, label: 'Mean P2', child: _buildTextField(controller: _overallEpvatControllers[t]!['p2_mean']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                                        _buildFlexibleField(flex: 1, label: 'Max P2', child: _buildTextField(controller: _overallEpvatControllers[t]!['p2_max']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                        _buildFlexibleField(flex: 1, label: 'Min P2', child: _buildTextField(controller: _overallEpvatControllers[t]!['p2_min']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                        _buildFlexibleField(flex: 1, label: 'Range P2', child: _buildTextField(controller: _overallEpvatControllers[t]!['p2_range']!, hint: '0.0', readOnly: true, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                        _buildFlexibleField(flex: 1, label: 'SD P2', child: _buildTextField(controller: _overallEpvatControllers[t]!['p2_sd']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                      ]),
                                    ],
                                    const SizedBox(height: 16.0),
                                    Text(
                                      'Velocity ($t °C) (m/s)',
                                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _buildFormRow([
                                      _buildFlexibleField(flex: 1, label: 'Mean Vel', child: _buildTextField(controller: _overallEpvatControllers[t]!['vel_mean']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                                      _buildFlexibleField(flex: 1, label: 'Max Vel', child: _buildTextField(controller: _overallEpvatControllers[t]!['vel_max']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                      _buildFlexibleField(flex: 1, label: 'Min Vel', child: _buildTextField(controller: _overallEpvatControllers[t]!['vel_min']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                      _buildFlexibleField(flex: 1, label: 'Range Vel', child: _buildTextField(controller: _overallEpvatControllers[t]!['vel_range']!, hint: '0.0', readOnly: true, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                      _buildFlexibleField(flex: 1, label: 'SD Vel', child: _buildTextField(controller: _overallEpvatControllers[t]!['vel_sd']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                    ]),
                                    const SizedBox(height: 16.0),
                                    Text(
                                      'Action Time ($t °C) (ms)',
                                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _buildFormRow([
                                      _buildFlexibleField(flex: 1, label: 'Mean Action Time', child: _buildTextField(controller: _overallEpvatControllers[t]!['action_time_mean']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()], onChanged: (_) => setState(() {}))),
                                      _buildFlexibleField(flex: 1, label: 'Max Action Time', child: _buildTextField(controller: _overallEpvatControllers[t]!['action_time_max']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                      _buildFlexibleField(flex: 1, label: 'Min Action Time', child: _buildTextField(controller: _overallEpvatControllers[t]!['action_time_min']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                      _buildFlexibleField(flex: 1, label: 'Range Action Time', child: _buildTextField(controller: _overallEpvatControllers[t]!['action_time_range']!, hint: '0.0', readOnly: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                      _buildFlexibleField(flex: 1, label: 'SD Action Time', child: _buildTextField(controller: _overallEpvatControllers[t]!['action_time_sd']!, hint: '0.0', readOnly: isIndividualMode, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                    ]),
                                    
                                    // --- Kinetic Energy Display (only for +21°C tab) ---
                                    if (t == '+21') ...[  
                                      const SizedBox(height: 12.0),
                                      Builder(builder: (ctx) {
                                        final epvRules = widget.adminRules['epvat'] ?? {};
                                        final massMap = epvRules['bullet_mass_grams'] ?? {};
                                        final double? massG = (massMap[_caliber] as num?)?.toDouble();
                                        final double? vMean = double.tryParse(_overallEpvatControllers['+21']!['vel_mean']!.text.trim());
                                        if (massG == null || vMean == null || vMean == 0.0) {
                                          return const SizedBox.shrink();
                                        }
                                        final double ke = 0.5 * (massG / 1000.0) * vMean * vMean;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8.0),
                                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.bolt, color: Color(0xFF6366F1), size: 16.0),
                                              const SizedBox(width: 8.0),
                                              Expanded(
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF8E96A3)),
                                                    children: [
                                                      const TextSpan(text: 'Kinetic Energy (+21°C): '),
                                                      TextSpan(
                                                        text: '${ke.toStringAsFixed(1)} J',
                                                        style: const TextStyle(
                                                          color: Color(0xFF6366F1),
                                                          fontWeight: FontWeight.bold,
                                                          fontFamily: 'JetBrainsMono',
                                                          fontSize: 13.0,
                                                        ),
                                                      ),
                                                      TextSpan(text: '  (m = ${massG.toStringAsFixed(2)} g, v = ${vMean.toStringAsFixed(1)} m/s)'),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ] else ...[
                            // Individual mode layout: Custom rounds list
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Individual Round Inputs (${_epvatPressureUnit})',
                                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8.0),
                                Row(
                                  children: [
                                    const Expanded(flex: 1, child: Text('Round', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    const Expanded(flex: 2, child: Text('Velocity (m/s)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    const Expanded(flex: 2, child: Text('Action Time (ms)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text(_isCaliber9mm ? 'Chamber Pres.' : 'GP1 (Chamber) Pres.', style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    if (!_isCaliber9mm)
                                      const Expanded(flex: 2, child: Text('GP2 (Port) Pres.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                ...List.generate(_getIndividualEpvatVisibleRounds(), (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Round ${index + 1}',
                                            style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: _buildTextField(
                                              controller: _epvatVelRoundsControllers[index],
                                              hint: '0.0',
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              onChanged: (val) => _recalculateEpvatStats(),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: _buildTextField(
                                              controller: _actionTimeRoundsControllers[index],
                                              hint: '0.0',
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              inputFormatters: [ActionTimeInputFormatter()],
                                              onChanged: (val) => _recalculateEpvatStats(),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: EdgeInsets.only(right: _isCaliber9mm ? 0.0 : 8.0),
                                            child: _buildTextField(
                                              controller: _epvatRoundsControllers[index],
                                              hint: '0.0',
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              onChanged: (val) => _recalculateEpvatStats(),
                                            ),
                                          ),
                                        ),
                                        if (!_isCaliber9mm)
                                          Expanded(
                                            flex: 2,
                                            child: _buildTextField(
                                              controller: _epvatP2RoundsControllers[index],
                                              hint: '0.0',
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              onChanged: (val) => _recalculateEpvatStats(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 20.0),
                                const Text(
                                  'Auto-Calculated Statistics',
                                  style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8.0),
                                const Text(
                                  'Velocity Statistics (m/s)',
                                  style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4.0),
                                _buildFormRow([
                                   _buildFlexibleField(flex: 1, label: 'Mean Vel', child: _buildTextField(controller: _meanVelController, hint: '0.0', readOnly: _epvatVelRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                   _buildFlexibleField(flex: 1, label: 'Max Vel', child: _buildTextField(controller: _maxVelController, hint: '0.0', readOnly: _epvatVelRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                   _buildFlexibleField(flex: 1, label: 'Min Vel', child: _buildTextField(controller: _minVelController, hint: '0.0', readOnly: _epvatVelRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                   _buildFlexibleField(flex: 1, label: 'Range Vel', child: _buildTextField(controller: _rangeVelController, hint: '0.0', readOnly: true, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                   _buildFlexibleField(flex: 1, label: 'SD Vel', child: _buildTextField(controller: _sdVelController, hint: '0.0', readOnly: _epvatVelRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                 ]),
                                const SizedBox(height: 12.0),
                                const Text(
                                  'Action Time Statistics (ms)',
                                  style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4.0),
                                _buildFormRow([
                                   _buildFlexibleField(flex: 1, label: 'Mean Action Time', child: _buildTextField(controller: _actionTimeMeanController, hint: '0.0', readOnly: _actionTimeRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                   _buildFlexibleField(flex: 1, label: 'Max Action Time', child: _buildTextField(controller: _actionTimeMaxController, hint: '0.0', readOnly: _actionTimeRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                   _buildFlexibleField(flex: 1, label: 'Min Action Time', child: _buildTextField(controller: _actionTimeMinController, hint: '0.0', readOnly: _actionTimeRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                   _buildFlexibleField(flex: 1, label: 'Range Action Time', child: _buildTextField(controller: _actionTimeRangeController, hint: '0.0', readOnly: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                   _buildFlexibleField(flex: 1, label: 'SD Action Time', child: _buildTextField(controller: _actionTimeSDController, hint: '0.0', readOnly: _actionTimeRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ActionTimeInputFormatter()])),
                                 ]),
                                const SizedBox(height: 12.0),
                                Text(
                                  _isCaliber9mm ? 'Chamber Pressure Statistics (${_epvatPressureUnit})' : 'GP1 (Chamber) Pressure Statistics (${_epvatPressureUnit})',
                                  style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4.0),
                                _buildFormRow([
                                  _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Mean P' : 'Mean P1', child: _buildTextField(controller: _epvatMeanPressureController, hint: '0.0', readOnly: _epvatRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                  _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Max P' : 'Max P1', child: _buildTextField(controller: _epvatMaxPressureController, hint: '0.0', readOnly: _epvatRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                  _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Min P' : 'Min P1', child: _buildTextField(controller: _epvatMinPressureController, hint: '0.0', readOnly: _epvatRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                  _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'Range P' : 'Range P1', child: _buildTextField(controller: _epvatRangePressureController, hint: '0.0', readOnly: _epvatRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                  _buildFlexibleField(flex: 1, label: _isCaliber9mm ? 'SD P' : 'SD P1', child: _buildTextField(controller: _epvatSDPressureController, hint: '0.0', readOnly: _epvatRoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                ]),
                                if (!_isCaliber9mm) ...[
                                  const SizedBox(height: 12.0),
                                  Text(
                                    'GP2 (Port) Pressure Statistics (${_epvatPressureUnit})',
                                    style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4.0),
                                  _buildFormRow([
                                    _buildFlexibleField(flex: 1, label: 'Mean P2', child: _buildTextField(controller: _epvatP2MeanPressureController, hint: '0.0', readOnly: _epvatP2RoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                    _buildFlexibleField(flex: 1, label: 'Max P2', child: _buildTextField(controller: _epvatP2MaxPressureController, hint: '0.0', readOnly: _epvatP2RoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                    _buildFlexibleField(flex: 1, label: 'Min P2', child: _buildTextField(controller: _epvatP2MinPressureController, hint: '0.0', readOnly: _epvatP2RoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                    _buildFlexibleField(flex: 1, label: 'Range P2', child: _buildTextField(controller: _epvatP2RangePressureController, hint: '0.0', readOnly: _epvatP2RoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                    _buildFlexibleField(flex: 1, label: 'SD P2', child: _buildTextField(controller: _epvatP2SDPressureController, hint: '0.0', readOnly: _epvatP2RoundsControllers.any((c) => c.text.trim().isNotEmpty), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                  ]),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    if (_testName == 'EPVAT test' || _testName == 'Propellant Test') ...[
                      _buildEpvatCustomCalculationsCard(),
                    ],
                  ],
                  if (_testName == 'Primer Sensitivity Test') ...[
                    _buildPrimerSensitivityCard(),
                  ],
                  const SizedBox(height: 20.0),

                  // Row 4: Notes
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Remarks',
                        style: TextStyle(
                          color: Color(0xFF8E96A3),
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Enter any remarks, observations, or quality anomalies...',
                          hintStyle: const TextStyle(color: Color(0xFF6495BF)),
                          filled: true,
                          fillColor: const Color(0xFFE0F2FE),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // Requirement (Optional)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requirement (Optional)',
                        style: TextStyle(
                          color: Color(0xFF8E96A3),
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _requirementController,
                        maxLines: 2,
                        style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Enter any manual requirement text...',
                          hintStyle: const TextStyle(color: Color(0xFF6495BF)),
                          filled: true,
                          fillColor: const Color(0xFFE0F2FE),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_testName == 'Extraction Force Test' && (_caliber.contains('M200') || _caliber.contains('M82'))) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20.0),
                          SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              'Extraction Force Test is not applicable for blank calibers (M200 / M82). Submission is disabled.',
                              style: TextStyle(color: Colors.white, fontSize: 13.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10.0),

                  // Attachment card
                  _buildAttachmentCard(),
                  const SizedBox(height: 24.0),

                  // Submit and Cancel action buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _confirmCancelTest,
                        icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 18.0),
                        label: const Text(
                          'Cancel & Erase',
                          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: SizedBox(
                          height: 48.0,
                          child: ElevatedButton(
                            onPressed: (_isSubmitting || (_testName == 'Extraction Force Test' && (_caliber.contains('M200') || _caliber.contains('M82')))) ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withOpacity(0.35),
                                    blurRadius: 15.0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20.0,
                                        height: 20.0,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Text(
                                            'Submit Ballistic Report',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          SizedBox(width: 8.0),
                                          Icon(Icons.check, color: Colors.white, size: 18.0),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormRow(List<Widget> children, {double spacing = 12.0, bool lockSingleRow = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = children.length;

        if (lockSingleRow) {
          final rowWidget = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < count; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(
                  flex: children[i] is FormRowField ? (children[i] as FormRowField).flex : 1,
                  child: children[i],
                ),
              ],
            ],
          );

          if (width < 960) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 980.0,
                child: rowWidget,
              ),
            );
          }
          return rowWidget;
        }

        // Desktop single row if wide enough for all fields (min 130px per field, or >= 750px)
        if (width >= (count * 130.0).clamp(550.0, 1920.0)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < count; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(
                  flex: children[i] is FormRowField ? (children[i] as FormRowField).flex : 1,
                  child: children[i],
                ),
              ],
            ],
          );
        } else if (width >= 620 && count > 2) {
          // Medium screen / tablet: chunk into rows of 2 or 3
          final int itemsPerRow = (width >= 850 && count >= 3) ? 3 : 2;
          final List<Widget> rowWidgets = [];
          for (int i = 0; i < count; i += itemsPerRow) {
            final chunk = children.sublist(i, math.min(i + itemsPerRow, count));
            rowWidgets.add(
              Padding(
                padding: EdgeInsets.only(bottom: (i + itemsPerRow < count) ? 16.0 : 0.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int j = 0; j < chunk.length; j++) ...[
                      if (j > 0) SizedBox(width: spacing),
                      Expanded(
                        flex: chunk[j] is FormRowField ? (chunk[j] as FormRowField).flex : 1,
                        child: chunk[j],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowWidgets,
          );
        } else {
          // Mobile (< 620px): Clean vertical stack with proper touch sizing
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < count; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i < count - 1 ? 14.0 : 0.0),
                  child: children[i],
                ),
            ],
          );
        }
      },
    );
  }

  Future<void> _showMultiWeaponSelectDialog() async {
    final allowedCats = _allowedWeaponCategoriesForCaliber;
    final weaponsInCaliber = _fleetWeaponsDetailed
        .where((w) => allowedCats.contains(w['category']))
        .map((w) => w['raw']!)
        .toSet()
        .toList();
    final allWeapons = weaponsInCaliber.isNotEmpty ? weaponsInCaliber : _weaponsList;
    final List<String> tempSelected = List<String>.from(_selectedFunctionWeapons);
    final customCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.military_tech_outlined, color: Color(0xFF38BDF8), size: 22.0),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Select Weapons for Function Test ($_caliber)',
                      style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Showing fleet weapons for $_caliber (${allowedCats.join(" / ")}):',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
                      ),
                      const SizedBox(height: 12.0),
                      if (allWeapons.isNotEmpty) ...[
                        const Text(
                          'Available Fleet Weapons:',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6.0),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: allWeapons.length,
                            separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E3A8A), height: 1),
                            itemBuilder: (c, idx) {
                              final w = allWeapons[idx];
                              final isChecked = tempSelected.contains(w);
                              final sn = _extractWeaponSerial(w);
                              final rds = _getAssetRounds(sn);
                              return CheckboxListTile(
                                dense: true,
                                activeColor: const Color(0xFF0284C7),
                                checkColor: Colors.white,
                                title: Text(
                                  w,
                                  style: TextStyle(
                                    color: isChecked ? Colors.white : const Color(0xFFCBD5E1),
                                    fontSize: 12.5,
                                    fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                    fontFamily: 'JetBrainsMono',
                                  ),
                                ),
                                subtitle: sn.isNotEmpty
                                    ? Text('$rds cumulative rounds fired', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontFamily: 'JetBrainsMono'))
                                    : null,
                                value: isChecked,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      if (!tempSelected.contains(w)) tempSelected.add(w);
                                    } else {
                                      tempSelected.remove(w);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 14.0),
                      const Text(
                        'Add Custom Weapon:',
                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'e.g., Steyr AUG (SN: ST-998)',
                                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF334155))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            ),
                            icon: const Icon(Icons.add, size: 16.0),
                            label: const Text('Add', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              final text = customCtrl.text.trim();
                              if (text.isNotEmpty && !tempSelected.contains(text)) {
                                setDialogState(() {
                                  tempSelected.add(text);
                                  customCtrl.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      if (tempSelected.isNotEmpty) ...[
                        const SizedBox(height: 14.0),
                        Text(
                          'Selected Weapons (${tempSelected.length}):',
                          style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6.0),
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          children: tempSelected.map((w) {
                            return Chip(
                              label: Text(w, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                              backgroundColor: const Color(0xFF0284C7).withOpacity(0.3),
                              deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                              onDeleted: () {
                                setDialogState(() => tempSelected.remove(w));
                              },
                              side: const BorderSide(color: Color(0xFF0284C7)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedFunctionWeapons = List<String>.from(tempSelected);
                      _functionWeapon = _selectedFunctionWeapons.join(', ');
                    });
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Confirm Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFunctionTestSpecsCard() {
    _syncFunctionWeaponState();

    final allowedCats = _allowedWeaponCategoriesForCaliber;
    final currentCat = allowedCats.contains(_functionSelectedCategory)
        ? _functionSelectedCategory
        : allowedCats.first;

    final modelsInCat = _getModelsForCategory(currentCat);
    final modelDropdownItems = <String>[
      ...modelsInCat,
      '[+ Custom Model]',
    ];
    final currentModel = modelDropdownItems.contains(_functionSelectedModel)
        ? _functionSelectedModel
        : (modelDropdownItems.isNotEmpty ? modelDropdownItems.first : '[+ Custom Model]');

    final registeredSerials = _getSerialsForModel(currentCat, currentModel);
    final hasRegisteredSerials = registeredSerials.isNotEmpty;
    final serialDropdownItems = <String>[
      ...registeredSerials,
      '[+ Enter Custom Serial]',
    ];

    String activeSerial = '';
    if (hasRegisteredSerials && _functionSelectedSerial != '[+ Enter Custom Serial]') {
      activeSerial = serialDropdownItems.contains(_functionSelectedSerial)
          ? _functionSelectedSerial
          : registeredSerials.first;
    } else {
      activeSerial = _functionCustomSerialController.text.trim();
    }

    final activeModelName = currentModel == '[+ Custom Model]'
        ? _functionCustomModelController.text.trim()
        : currentModel;

    final String previewLabel = activeSerial.isNotEmpty
        ? '$activeModelName (SN: $activeSerial)'
        : activeModelName;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.05),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_outlined, color: Color(0xFF0284C7), size: 18.0),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'Function Test Specifications & Weapon Selection ($_caliber)',
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showMultiWeaponSelectDialog,
                icon: const Icon(Icons.checklist_rtl_rounded, size: 16.0),
                label: const Text('Select Multiple Weapons', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Text(
            _isCaliber9mm
                ? 'Caliber is 9mm: Weapon Type locked to Pistols per standard protocol.'
                : 'Caliber is $_caliber: Weapon Type restricted to Rifles and Machine Guns.',
            style: TextStyle(
              color: const Color(0xFF0284C7).withOpacity(0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14.0),
          _buildFormRow([
            // 1. Weapon Category / Type
            _buildFlexibleField(
              key: _weaponFieldKey,
              flex: 2,
              label: 'Weapon Type',
              isRequired: true,
              child: _buildDropdownField(
                focusNode: _weaponFocusNode,
                value: currentCat,
                items: allowedCats,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _functionSelectedCategory = v;
                      final models = _getModelsForCategory(_functionSelectedCategory);
                      _functionSelectedModel = models.isNotEmpty ? models.first : '[+ Custom Model]';
                      final serials = _getSerialsForModel(_functionSelectedCategory, _functionSelectedModel);
                      _functionSelectedSerial = serials.isNotEmpty ? serials.first : '';
                      _syncFunctionWeaponState();
                    });
                  }
                },
              ),
            ),
            // 2. Weapon Model
            _buildFlexibleField(
              flex: 3,
              label: '$currentCat Model (Fleet)',
              isRequired: true,
              child: _buildDropdownField(
                value: currentModel,
                items: modelDropdownItems,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _functionSelectedModel = v;
                      final serials = _getSerialsForModel(_functionSelectedCategory, _functionSelectedModel);
                      _functionSelectedSerial = serials.isNotEmpty ? serials.first : '';
                      _syncFunctionWeaponState();
                    });
                  }
                },
              ),
            ),
            // 3. Serial Number
            _buildFlexibleField(
              flex: 2,
              label: 'Serial Number',
              isRequired: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasRegisteredSerials && _functionSelectedSerial != '[+ Enter Custom Serial]')
                    _buildDropdownField(
                      value: serialDropdownItems.contains(_functionSelectedSerial)
                          ? _functionSelectedSerial
                          : serialDropdownItems.first,
                      items: serialDropdownItems,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _functionSelectedSerial = v;
                            _syncFunctionWeaponState();
                          });
                        }
                      },
                    )
                  else
                    _buildTextField(
                      controller: _functionCustomSerialController,
                      hint: hasRegisteredSerials ? 'Enter custom SN' : 'e.g., SN-001',
                      onChanged: (val) {
                        setState(() {
                          _syncFunctionWeaponState();
                        });
                      },
                    ),
                  if (activeSerial.isNotEmpty) ...[
                    const SizedBox(height: 4.0),
                    Padding(
                      padding: const EdgeInsets.only(left: 2.0),
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 13, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4.0),
                          Text(
                            '${_getAssetRounds(activeSerial)} cumulative rounds tracked',
                            style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 4. Add to Tested Weapons
            _buildFlexibleField(
              flex: 2,
              label: 'Add to Test',
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final toAdd = previewLabel.trim();
                    if (toAdd.isNotEmpty) {
                      setState(() {
                        if (!_selectedFunctionWeapons.contains(toAdd)) {
                          _selectedFunctionWeapons.add(toAdd);
                        }
                        _functionWeapon = _selectedFunctionWeapons.join(', ');
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 16.0),
                  label: const Text('Add Weapon', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                ),
              ),
            ),
          ]),

          if (currentModel == '[+ Custom Model]') ...[
            const SizedBox(height: 10.0),
            _buildFormRow([
              _buildFlexibleField(
                flex: 3,
                label: 'Custom $currentCat Model Name',
                isRequired: true,
                child: _buildTextField(
                  controller: _functionCustomModelController,
                  hint: 'e.g., Steyr AUG A3 CQB',
                  onChanged: (val) {
                    setState(() => _syncFunctionWeaponState());
                  },
                ),
              ),
              _buildFlexibleField(
                flex: 2,
                label: 'Serial Number',
                isRequired: true,
                child: _buildTextField(
                  controller: _functionCustomSerialController,
                  hint: 'e.g., ST-8801',
                  onChanged: (val) {
                    setState(() => _syncFunctionWeaponState());
                  },
                ),
              ),
            ]),
          ],

          if (hasRegisteredSerials && _functionSelectedSerial == '[+ Enter Custom Serial]') ...[
            const SizedBox(height: 10.0),
            _buildFormRow([
              _buildFlexibleField(
                flex: 3,
                label: 'Enter Custom Serial for $currentModel',
                isRequired: true,
                child: _buildTextField(
                  controller: _functionCustomSerialController,
                  hint: 'e.g., SN-Custom-9901',
                  onChanged: (val) {
                    setState(() => _syncFunctionWeaponState());
                  },
                ),
              ),
            ]),
          ],

          // Selected weapons interactive chips
          if (_selectedFunctionWeapons.isNotEmpty) ...[
            const SizedBox(height: 14.0),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF0284C7), size: 16.0),
                const SizedBox(width: 6.0),
                Text(
                  'Selected Tested Weapons (${_selectedFunctionWeapons.length}):',
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _selectedFunctionWeapons.map((weapon) {
                final rds = _getAssetRounds(_extractWeaponSerial(weapon));
                return Chip(
                  avatar: const Icon(Icons.military_tech_rounded, size: 16.0, color: Color(0xFF0284C7)),
                  label: Text('$weapon ($rds rds)', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.0)),
                  backgroundColor: const Color(0xFFE0F2FE),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFF0284C7)),
                  onDeleted: () {
                    setState(() {
                      _selectedFunctionWeapons.remove(weapon);
                      _functionWeapon = _selectedFunctionWeapons.join(', ');
                    });
                  },
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                );
              }).toList(),
            ),
          ],

          if (_isFunctionBlankAmmo) ...[
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 14.0),
                  SizedBox(width: 8.0),
                  Text(
                    'Blank Ammunition detected: Cold temperature standard is -32 °C (standard live ammo is -54 °C).',
                    style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.5, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16.0),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.photo_outlined, color: Color(0xFF0284C7), size: 16.0),
                    SizedBox(width: 8.0),
                    Text(
                      'Cartridge Classification Reference Diagram',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6.0),
                    child: Image.asset(
                      _isCaliber9mm ? 'assets/cartridge_9mm.png' : 'assets/cartridge_bottleneck.png',
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
                Center(
                  child: Text(
                    _isCaliber9mm ? '9mm Cartridge Reference' : '5.56 / 7.62 Cartridge Reference',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.attachment_rounded, color: Color(0xFF06B6D4), size: 18.0),
                  SizedBox(width: 8.0),
                  Text(
                    'Test Attachment / Documentation (Optional)',
                    style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ],
              ),
              if (_attachmentName.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _attachmentName = '';
                      _attachmentBase64 = '';
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 14.0, color: Color(0xFFEF4444)),
                  label: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11.5)),
                ),
            ],
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Upload a photo, evidence image, or test document for this test entry. The attachment will be saved with the record and displayed in inspection logs & reports.',
            style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 12.0),
          if (_attachmentName.isEmpty) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final res = await getAttachmentHelper().pickFileAsBase64();
                if (res != null && res['name'] != null && res['data'] != null) {
                  setState(() {
                    _attachmentName = res['name']!;
                    _attachmentBase64 = res['data']!;
                  });
                }
              },
              icon: const Icon(Icons.upload_file, size: 16.0, color: Color(0xFF06B6D4)),
              label: const Text('Attach Photo or Document', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF06B6D4)),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  if (_attachmentBase64.startsWith('data:image/') || (!_attachmentName.toLowerCase().endsWith('.pdf') && !_attachmentName.toLowerCase().endsWith('.doc'))) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: Container(
                        width: 70.0,
                        height: 70.0,
                        color: Colors.black38,
                        child: Image.memory(
                          base64Decode(_attachmentBase64.contains(',') ? _attachmentBase64.split(',')[1] : _attachmentBase64),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Color(0xFF8E96A3)),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 70.0,
                      height: 70.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: const Icon(Icons.description_outlined, color: Color(0xFF06B6D4), size: 32.0),
                    ),
                  ],
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _attachmentName,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4.0),
                        const Text(
                          'Ready to submit with record',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFunctionTestDefectsCard() {
    final funcRules = _currentFunctionCaliberRules;
    final l1Cfg = funcRules['level1'] ?? {};
    final l2Cfg = funcRules['level2'] ?? {};
    final l3Cfg = funcRules['level3'] ?? {};
    final l4Cfg = funcRules['level4'] ?? {};

    final int l1Max = l1Cfg['max_allowed'] ?? 0;
    final String l1Desc = (l1Cfg['description'] ?? 'Blown primer, Split case, Perforated primer, Bullet lodged in bore').toString();

    final int l2Max = l2Cfg['max_allowed'] ?? 0;
    final String l2Desc = (l2Cfg['description'] ?? 'Failure to extract, Failure to eject, Misfeed, Hangfire').toString();

    final int l3Max = l3Cfg['max_allowed'] ?? 2;
    final String l3Desc = (l3Cfg['description'] ?? 'Mild case dent, Minor extractor mark, Light primer indentation').toString();

    final int l4Max = l4Cfg['max_allowed'] ?? 5;
    final String l4Desc = (l4Cfg['description'] ?? 'Superficial scratches, Minor cosmetic blemish, Slight discoloration').toString();

    if (_functionTempMode == 'All') {
      final activeTempKey = _functionTempList[_activeFunctionTempTabIndex];
      final activeProducedCtrl = _funcAllProducedControllers[activeTempKey]!;
      final activeL1Ctrl = _funcAllL1Controllers[activeTempKey]!;
      final activeL2Ctrl = _funcAllL2Controllers[activeTempKey]!;
      final activeL3Ctrl = _funcAllL3Controllers[activeTempKey]!;
      final activeL4Ctrl = _funcAllL4Controllers[activeTempKey]!;

      int totalAllDefects = 0;
      int totalAllProduced = 0;
      for (var t in _functionTempList) {
        final l1 = int.tryParse(_funcAllL1Controllers[t]?.text.trim() ?? '') ?? 0;
        final l2 = int.tryParse(_funcAllL2Controllers[t]?.text.trim() ?? '') ?? 0;
        final l3 = int.tryParse(_funcAllL3Controllers[t]?.text.trim() ?? '') ?? 0;
        final l4 = int.tryParse(_funcAllL4Controllers[t]?.text.trim() ?? '') ?? 0;
        final p = int.tryParse(_funcAllProducedControllers[t]?.text.trim() ?? '') ?? 0;
        totalAllDefects += (l1 + l2 + l3 + l4);
        totalAllProduced += p;
      }

      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18.0),
                    SizedBox(width: 8.0),
                    Text(
                      'Function Test Defects (All 3 Temperatures)',
                      style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    'Combined Qty: $totalAllProduced | Total Defects: $totalAllDefects',
                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Temperature selection tabs
            Row(
              children: _functionTempList.asMap().entries.map((entry) {
                final idx = entry.key;
                final tempKey = entry.value;
                final isSel = _activeFunctionTempTabIndex == idx;
                final label = tempKey == _functionColdTempKey ? _functionColdTempLabel : '$tempKey °C';
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF8E96A3),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12.0,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    onSelected: (val) {
                      if (val) setState(() => _activeFunctionTempTabIndex = idx);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14.0),

            // Quantity Tested for this tab
            _buildFormRow([
              _buildFlexibleField(
                flex: 1,
                label: 'Rounds Tested at $activeTempKey °C',
                child: _buildTextField(
                  controller: activeProducedCtrl,
                  hint: '20',
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    _updateFunctionTestTotalDefects();
                    setState(() {});
                  },
                ),
              ),
            ]),
            const SizedBox(height: 14.0),

            _buildFormRow([
              _buildDefectLevelTile(
                label: 'Level 1: Critical Defect (Max: $l1Max)',
                hint: '0',
                controller: activeL1Ctrl,
                color: const Color(0xFFEF4444),
                subtitle: l1Desc,
                level: 1,
                tempKey: activeTempKey,
              ),
              _buildDefectLevelTile(
                label: 'Level 2: Major Defect (Max: $l2Max)',
                hint: '0',
                controller: activeL2Ctrl,
                color: const Color(0xFFF59E0B),
                subtitle: l2Desc,
                level: 2,
                tempKey: activeTempKey,
              ),
            ]),
            const SizedBox(height: 12.0),
            _buildFormRow([
              _buildDefectLevelTile(
                label: 'Level 3: Minor Defect (Max: $l3Max)',
                hint: '0',
                controller: activeL3Ctrl,
                color: const Color(0xFF3B82F6),
                subtitle: l3Desc,
                level: 3,
                tempKey: activeTempKey,
              ),
              _buildDefectLevelTile(
                label: 'Level 4: Level 4 Defect (Max: $l4Max)',
                hint: '0',
                controller: activeL4Ctrl,
                color: const Color(0xFF10B981),
                subtitle: l4Desc,
                level: 4,
                tempKey: activeTempKey,
              ),
            ]),
            const Divider(color: Colors.white12, height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total No. of defect at $activeTempKey °C:',
                  style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 13.0, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(int.tryParse(activeL1Ctrl.text) ?? 0) + (int.tryParse(activeL2Ctrl.text) ?? 0) + (int.tryParse(activeL3Ctrl.text) ?? 0) + (int.tryParse(activeL4Ctrl.text) ?? 0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Single Temperature Mode
    final singleTempLabel = '$_functionSingleTemp °C';
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18.0),
              const SizedBox(width: 8.0),
              Text(
                'Function Test Defects ($singleTempLabel)',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'Caliber: $_caliber • Level 1 (Max: $l1Max) • Level 2 (Max: $l2Max) • Level 3 (Max: $l3Max) • Level 4 (Max: $l4Max)',
            style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5),
          ),
          const SizedBox(height: 16.0),
          _buildFormRow([
            _buildDefectLevelTile(
              label: 'Level 1: Critical Defect (Max: $l1Max)',
              hint: '0',
              controller: _functionLevel1Controller,
              color: const Color(0xFFEF4444),
              subtitle: l1Desc,
              level: 1,
            ),
            _buildDefectLevelTile(
              label: 'Level 2: Major Defect (Max: $l2Max)',
              hint: '0',
              controller: _functionLevel2Controller,
              color: const Color(0xFFF59E0B),
              subtitle: l2Desc,
              level: 2,
            ),
          ]),
          const SizedBox(height: 12.0),
          _buildFormRow([
            _buildDefectLevelTile(
              label: 'Level 3: Minor Defect (Max: $l3Max)',
              hint: '0',
              controller: _functionLevel3Controller,
              color: const Color(0xFF3B82F6),
              subtitle: l3Desc,
              level: 3,
            ),
            _buildDefectLevelTile(
              label: 'Level 4: Level 4 Defect (Max: $l4Max)',
              hint: '0',
              controller: _functionLevel4Controller,
              color: const Color(0xFF10B981),
              subtitle: l4Desc,
              level: 4,
            ),
          ]),
          const Divider(color: Colors.white12, height: 24.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total No. of defect:',
                style: TextStyle(color: Color(0xFF8E96A3), fontSize: 13.0, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(int.tryParse(_functionLevel1Controller.text) ?? 0) + (int.tryParse(_functionLevel2Controller.text) ?? 0) + (int.tryParse(_functionLevel3Controller.text) ?? 0) + (int.tryParse(_functionLevel4Controller.text) ?? 0)}',
                style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefectLevelTile({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color color,
    required String subtitle,
    required int level,
    String tempKey = '',
  }) {
    final defectItems = subtitle.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return _buildFlexibleField(
      flex: 1,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: color, fontSize: 14.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: color.withOpacity(0.06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
            ),
            onChanged: (_) {
              _updateFunctionTestTotalDefects();
              setState(() {});
            },
          ),
          if (defectItems.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            Text('Select defect found (Click to increment count):', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10.5)),
            const SizedBox(height: 6.0),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: defectItems.map((item) {
                final count = _getDefectCount(item, tempKey);
                final bool hasCount = count > 0;
                return Container(
                  decoration: BoxDecoration(
                    color: hasCount ? color.withOpacity(0.25) : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: hasCount ? color : Colors.white.withOpacity(0.1),
                      width: hasCount ? 1.5 : 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6.0),
                      onTap: () => _incrementDefect(item, tempKey, level, controller),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item,
                              style: TextStyle(
                                color: hasCount ? Colors.white : Colors.white.withOpacity(0.7),
                                fontSize: 11.0,
                                fontWeight: hasCount ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (hasCount) ...[
                              const SizedBox(width: 6.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(color: Colors.black, fontSize: 10.0, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              InkWell(
                                onTap: () => _decrementDefect(item, tempKey, level, controller),
                                child: const Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Icon(Icons.remove_circle, size: 14.0, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _updateFunctionTestTotalDefects() {
    if (_functionTempMode == 'All') {
      int total = 0;
      int totalProd = 0;
      for (var t in _functionTempList) {
        final l1 = int.tryParse(_funcAllL1Controllers[t]?.text.trim() ?? '') ?? 0;
        final l2 = int.tryParse(_funcAllL2Controllers[t]?.text.trim() ?? '') ?? 0;
        final l3 = int.tryParse(_funcAllL3Controllers[t]?.text.trim() ?? '') ?? 0;
        final l4 = int.tryParse(_funcAllL4Controllers[t]?.text.trim() ?? '') ?? 0;
        final p = int.tryParse(_funcAllProducedControllers[t]?.text.trim() ?? '') ?? 0;
        total += (l1 + l2 + l3 + l4);
        totalProd += p;
      }
      _defectsController.text = '$total';
      if (totalProd > 0) {
        _producedController.text = '$totalProd';
      }
    } else {
      final l1 = int.tryParse(_functionLevel1Controller.text.trim()) ?? 0;
      final l2 = int.tryParse(_functionLevel2Controller.text.trim()) ?? 0;
      final l3 = int.tryParse(_functionLevel3Controller.text.trim()) ?? 0;
      final l4 = int.tryParse(_functionLevel4Controller.text.trim()) ?? 0;
      _defectsController.text = '${l1 + l2 + l3 + l4}';
    }
  }

  Widget _buildLeakTextField({required TextEditingController controller}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.0, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold),
      onChanged: (_) => setState(() {}),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (int.tryParse(v) == null) return 'Must be integer';
        if (int.parse(v) < 0) return 'Cannot be negative';
        return null;
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        filled: true,
        fillColor: const Color(0xFFE0F2FE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFlexibleField({
    Key? key,
    required int flex,
    required String label,
    required Widget child,
    bool isRequired = false,
  }) {
    return FormRowField(
      key: key,
      flex: flex,
      label: label,
      isRequired: isRequired,
      child: child,
    );
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.length <= 1) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final varianceSum = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b);
    return math.sqrt(varianceSum / (values.length - 1));
  }

  void _recalculateExtractionStats() {
    final List<double> values = [];
    for (var ctrl in _extractionRoundsControllers) {
      final val = double.tryParse(ctrl.text.trim());
      if (val != null) {
        values.add(val);
      }
    }

    if (values.isNotEmpty) {
      final minVal = values.reduce((a, b) => a < b ? a : b);
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      final rangeVal = maxVal - minVal;
      final sdVal = _calculateStandardDeviation(values);
      final meanVal = values.reduce((a, b) => a + b) / values.length;

      _minXController.text = minVal.toStringAsFixed(2);
      _maxXController.text = maxVal.toStringAsFixed(2);
      _rangeXController.text = rangeVal.toStringAsFixed(2);
      _sdXController.text = sdVal.toStringAsFixed(2);
      _meanXController.text = meanVal.toStringAsFixed(2);
      if (_extractionForceType == 'Individual') {
        _producedController.text = '${values.length}';
      }
    } else {
      _minXController.clear();
      _maxXController.clear();
      _rangeXController.clear();
      _sdXController.clear();
      _meanXController.clear();
      if (_extractionForceType == 'Individual') {
        _producedController.text = '1';
      }
    }
  }

  Widget _buildModeRadioButton(String mode, String label) {
    final bool isSelected = _extractionForceType == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _extractionForceType = mode;
          _minXController.clear();
          _maxXController.clear();
          _rangeXController.clear();
          _sdXController.clear();
          _meanXController.clear();
          if (mode == 'Individual') {
            _extractionRoundsControllers.clear();
            _extractionRoundsControllers.add(TextEditingController());
          }
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: mode,
            groupValue: _extractionForceType,
            activeColor: const Color(0xFF06B6D4),
            onChanged: (val) {
              setState(() {
                _extractionForceType = val!;
                _minXController.clear();
                _maxXController.clear();
                _rangeXController.clear();
                _sdXController.clear();
                _meanXController.clear();
                if (val == 'Individual') {
                  _extractionRoundsControllers.clear();
                  _extractionRoundsControllers.add(TextEditingController());
                }
              });
            },
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8E96A3),
              fontSize: 13.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String hint = '',
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? (
        keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : (keyboardType == const TextInputType.numberWithOptions(decimal: true) || keyboardType.decimal == true)
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
                : null
      ),
      readOnly: readOnly,
      onChanged: onChanged,
      style: TextStyle(
        color: readOnly ? const Color(0xFF475569) : const Color(0xFF0C2A4D),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6495BF)),
        filled: true,
        fillColor: readOnly ? const Color(0xFFC8E3F5) : const Color(0xFFE0F2FE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
    FocusNode? focusNode,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
      focusNode: focusNode,
      isExpanded: true,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.5, fontWeight: FontWeight.w500),
      dropdownColor: const Color(0xFFE0F2FE),
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF31B9F6)),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFE0F2FE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(color: Color(0xFF0C2A4D))),
        );
      }).toList(),
    );
  }

  Widget _buildLotNoField({FocusNode? focusNode}) {
    if (widget.currentModule == 'Lot Acceptance Test') {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _lotThreeDigitsController,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: 3,
              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                hintText: '###',
                hintStyle: const TextStyle(color: Color(0xFF6495BF)),
                filled: true,
                fillColor: const Color(0xFFE0F2FE),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty || v.trim().length != 3) {
                  return 'Please add three digits';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12.0),
          const Text(
            ' OMPC/',
            style: TextStyle(
              color: Color(0xFF31B9F6),
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            flex: 2,
            child: _buildDropdownField(
              value: _shortYearList.contains(_lotYearController.text.trim())
                  ? _lotYearController.text.trim()
                  : _shortYearList.last,
              items: _shortYearList,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _lotYearController.text = val;
                  });
                }
              },
            ),
          ),
        ],
      );
    } else if (widget.currentModule == 'Component Test') {
      final isPrimer = _testName == 'Primer Sensitivity Test';
      final ctrl = isPrimer ? _primerLotController : _propellantLotController;
      return TextFormField(
        controller: ctrl,
        focusNode: focusNode,
        style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.5, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: isPrimer ? 'Enter Primer Lot (e.g. CBC-26-01)' : 'Enter Propellant Lot (e.g. 90124)',
          hintStyle: const TextStyle(color: Color(0xFF6495BF)),
          filled: true,
          fillColor: const Color(0xFFE0F2FE),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
          ),
        ),
        onChanged: (val) {
          _lotController.text = val.trim();
        },
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return isPrimer ? 'Please enter Primer Lot' : 'Please enter Propellant Lot';
          }
          return null;
        },
      );
    } else {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _hopperThreeDigitsController,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: 3,
              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                hintText: '###',
                hintStyle: const TextStyle(color: Color(0xFF6495BF)),
                filled: true,
                fillColor: const Color(0xFFE0F2FE),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 2.0),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (val) {
                final y = _hopperYearController.text.trim();
                _lotController.text = val.isNotEmpty ? '${val.padLeft(3, '0')}-$y' : '';
              },
              validator: (v) {
                if (v == null || v.trim().isEmpty || v.trim().length != 3) {
                  return 'Please add three digits';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8.0),
          const Text(
            '-',
            style: TextStyle(
              color: Color(0xFF31B9F6),
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            flex: 2,
            child: _buildDropdownField(
              value: _shortYearList.contains(_hopperYearController.text.trim())
                  ? _hopperYearController.text.trim()
                  : _shortYearList.last,
              items: _shortYearList,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _hopperYearController.text = val;
                    final d = _hopperThreeDigitsController.text.trim();
                    _lotController.text = d.isNotEmpty ? '${d.padLeft(3, '0')}-$val' : '';
                  });
                }
              },
            ),
          ),
        ],
      );
    }
  }

  void _onPressureUnitChanged(String newUnit) {
    if (_epvatPressureUnit == newUnit) return;
    final oldUnit = _epvatPressureUnit;

    void convertCtrl(TextEditingController ctrl) {
      final val = double.tryParse(ctrl.text.trim());
      if (val != null) {
        final converted = EpvatFormulaHelper.convertPressure(val, oldUnit, newUnit);
        ctrl.text = converted.toStringAsFixed(2);
      }
    }

    // 1. Individual rounds
    for (var ctrl in _epvatRoundsControllers) {
      convertCtrl(ctrl);
    }
    for (var ctrl in _epvatP2RoundsControllers) {
      convertCtrl(ctrl);
    }

    // 2. Individual statistics
    convertCtrl(_epvatMeanPressureController);
    convertCtrl(_epvatMaxPressureController);
    convertCtrl(_epvatMinPressureController);
    convertCtrl(_epvatRangePressureController);
    convertCtrl(_epvatSDPressureController);
    convertCtrl(_epvatP2MeanPressureController);
    convertCtrl(_epvatP2MaxPressureController);
    convertCtrl(_epvatP2MinPressureController);
    convertCtrl(_epvatP2RangePressureController);
    convertCtrl(_epvatP2SDPressureController);

    // 3. Overall mode temperatures
    final temps = ['+21', '+52', '-54', '-32'];
    for (var t in temps) {
      if (_overallEpvatControllers.containsKey(t)) {
        for (var sub in ['mean', 'max', 'min', 'range', 'sd']) {
          final p1c = _overallEpvatControllers[t]!['p1_$sub'];
          if (p1c != null) convertCtrl(p1c);
          final p2c = _overallEpvatControllers[t]!['p2_$sub'];
          if (p2c != null) convertCtrl(p2c);
        }
      }
      if (_overallEpvatP1RoundsControllers.containsKey(t)) {
        for (var c in _overallEpvatP1RoundsControllers[t]!) {
          convertCtrl(c);
        }
      }
      if (_overallEpvatP2RoundsControllers.containsKey(t)) {
        for (var c in _overallEpvatP2RoundsControllers[t]!) {
          convertCtrl(c);
        }
      }
    }

    setState(() {
      _epvatPressureUnit = newUnit;
    });
    if (_epvatPressureType == 'Individual') {
      _recalculateEpvatStats();
    } else {
      for (var t in temps) {
        _calculateOverallTempStats(t);
      }
    }
  }

  Widget _buildEpvatUnitRadioButton(String unit, String label) {
    final bool isSelected = _epvatPressureUnit == unit;
    return InkWell(
      onTap: () => _onPressureUnitChanged(unit),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: unit,
            groupValue: _epvatPressureUnit,
            activeColor: const Color(0xFF06B6D4),
            onChanged: (val) {
              if (val != null) _onPressureUnitChanged(val);
            },
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8E96A3),
              fontSize: 13.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyclicAmmoRadio(String type) {
    final bool isSelected = _cyclicRateAmmoType == type;
    return InkWell(
      onTap: () => setState(() { _cyclicRateAmmoType = type; }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: type,
            groupValue: _cyclicRateAmmoType,
            activeColor: const Color(0xFF06B6D4),
            onChanged: (val) => setState(() { _cyclicRateAmmoType = val!; }),
          ),
          Text(
            type,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8E96A3),
              fontSize: 13.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _recalculateEpvatStats() {
    // 1. P1 Chamber Pressure stats
    final List<double> p1Values = [];
    for (var ctrl in _epvatRoundsControllers) {
      final val = double.tryParse(ctrl.text.trim());
      if (val != null) p1Values.add(val);
    }
    _calculateStatsForValues(
      p1Values,
      _epvatMeanPressureController,
      _epvatMaxPressureController,
      _epvatMinPressureController,
      _epvatRangePressureController,
      _epvatSDPressureController,
    );

    // 2. P2 Port Pressure stats
    final List<double> p2Values = [];
    for (var ctrl in _epvatP2RoundsControllers) {
      final val = double.tryParse(ctrl.text.trim());
      if (val != null) p2Values.add(val);
    }
    _calculateStatsForValues(
      p2Values,
      _epvatP2MeanPressureController,
      _epvatP2MaxPressureController,
      _epvatP2MinPressureController,
      _epvatP2RangePressureController,
      _epvatP2SDPressureController,
    );

    // 3. Velocity stats
    final List<double> velValues = [];
    for (var ctrl in _epvatVelRoundsControllers) {
      final val = double.tryParse(ctrl.text.trim());
      if (val != null) velValues.add(val);
    }
    _calculateStatsForValues(
      velValues,
      _meanVelController,
      _maxVelController,
      _minVelController,
      _rangeVelController,
      _sdVelController,
    );

    // 4. Action Time stats
    final List<double> actionTimeValues = [];
    for (var ctrl in _actionTimeRoundsControllers) {
      final val = double.tryParse(ctrl.text.trim());
      if (val != null) actionTimeValues.add(val);
    }
    _calculateStatsForValues(
      actionTimeValues,
      _actionTimeMeanController,
      _actionTimeMaxController,
      _actionTimeMinController,
      _actionTimeRangeController,
      _actionTimeSDController,
    );

    if (_epvatPressureType == 'Individual') {
      final maxRounds = math.max(p1Values.length, math.max(p2Values.length, velValues.length));
      if (maxRounds > 0) {
        _producedController.text = '$maxRounds';
      }
    }
  }

  void _calculateStatsForValues(
    List<double> values,
    TextEditingController meanCtrl,
    TextEditingController maxCtrl,
    TextEditingController minCtrl,
    TextEditingController rangeCtrl,
    TextEditingController sdCtrl,
  ) {
    if (values.isNotEmpty) {
      final minVal = values.reduce((a, b) => a < b ? a : b);
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      final rangeVal = maxVal - minVal;
      final sdVal = _calculateStandardDeviation(values);
      final meanVal = values.reduce((a, b) => a + b) / values.length;

      minCtrl.text = minVal.toStringAsFixed(2);
      maxCtrl.text = maxVal.toStringAsFixed(2);
      rangeCtrl.text = rangeVal.toStringAsFixed(2);
      sdCtrl.text = sdVal.toStringAsFixed(2);
      meanCtrl.text = meanVal.toStringAsFixed(2);
    } else {
      minCtrl.clear();
      maxCtrl.clear();
      rangeCtrl.clear();
      sdCtrl.clear();
      meanCtrl.clear();
    }
  }

  void _syncIndividualRoundsControllers(int targetCount) {
    if (_epvatRoundsControllers.length == targetCount) return;
    setState(() {
      if (_epvatRoundsControllers.length < targetCount) {
        while (_epvatRoundsControllers.length < targetCount) {
          _epvatRoundsControllers.add(TextEditingController());
          _epvatP2RoundsControllers.add(TextEditingController());
          _epvatVelRoundsControllers.add(TextEditingController());
          _actionTimeRoundsControllers.add(TextEditingController());
        }
      } else {
        while (_epvatRoundsControllers.length > targetCount) {
          _epvatRoundsControllers.removeLast().dispose();
          _epvatP2RoundsControllers.removeLast().dispose();
          _epvatVelRoundsControllers.removeLast().dispose();
          _actionTimeRoundsControllers.removeLast().dispose();
        }
      }
    });
  }

  void _syncTerminalRoundsControllers(int targetCount) {
    if (_terminalVelocityRoundsControllers.length == targetCount) return;
    setState(() {
      if (_terminalVelocityRoundsControllers.length < targetCount) {
        while (_terminalVelocityRoundsControllers.length < targetCount) {
          _terminalHoleDiameterRounds.add('Yes');
          _terminalSteelPenetrationRounds.add('Yes');
          _terminalAluminumPenetrationRounds.add('Yes');
          _terminalVelocityRoundsControllers.add(TextEditingController());
        }
      } else {
        while (_terminalVelocityRoundsControllers.length > targetCount) {
          _terminalHoleDiameterRounds.removeLast();
          _terminalSteelPenetrationRounds.removeLast();
          _terminalAluminumPenetrationRounds.removeLast();
          _terminalVelocityRoundsControllers.removeLast().dispose();
        }
      }
    });
  }

  // Progressive round entry helpers across tests
  int _getOverallEpvatVisibleRounds(String temp) {
    final count = _epvatOverallRoundCount[temp] ?? 30;
    final velList = _overallEpvatVelRoundsControllers[temp] ?? [];
    final actList = _overallEpvatActionTimeRoundsControllers[temp] ?? [];
    final p1List = _overallEpvatP1RoundsControllers[temp] ?? [];
    final p2List = _overallEpvatP2RoundsControllers[temp] ?? [];
    
    int highestEntered = 0;
    for (int i = 0; i < count; i++) {
      final hasVel = i < velList.length && velList[i].text.trim().isNotEmpty;
      final hasAct = i < actList.length && actList[i].text.trim().isNotEmpty;
      final hasP1 = i < p1List.length && p1List[i].text.trim().isNotEmpty;
      final hasP2 = i < p2List.length && p2List[i].text.trim().isNotEmpty;
      if (hasVel || hasAct || hasP1 || hasP2) {
        highestEntered = i + 1;
      }
    }
    return math.min(highestEntered + 1, count);
  }

  int _getIndividualEpvatVisibleRounds() {
    final count = _epvatRoundsControllers.length;
    if (count <= 1) return count;
    int highestEntered = 0;
    for (int i = 0; i < count; i++) {
      final hasP1 = i < _epvatRoundsControllers.length && _epvatRoundsControllers[i].text.trim().isNotEmpty;
      final hasP2 = i < _epvatP2RoundsControllers.length && _epvatP2RoundsControllers[i].text.trim().isNotEmpty;
      final hasVel = i < _epvatVelRoundsControllers.length && _epvatVelRoundsControllers[i].text.trim().isNotEmpty;
      final hasAct = i < _actionTimeRoundsControllers.length && _actionTimeRoundsControllers[i].text.trim().isNotEmpty;
      if (hasP1 || hasP2 || hasVel || hasAct) {
        highestEntered = i + 1;
      }
    }
    return math.min(highestEntered + 1, count);
  }

  int _getTerminalVisibleRounds() {
    final count = _terminalVelocityRoundsControllers.length;
    if (count <= 1) return count;
    int highestEntered = 0;
    for (int i = 0; i < count; i++) {
      if (_terminalVelocityRoundsControllers[i].text.trim().isNotEmpty) {
        highestEntered = i + 1;
      }
    }
    return math.min(highestEntered + 1, count);
  }

  Map<String, double> _getEpvatVariablesMap() {
    final Map<String, double> variables = {};
    final tempKeys = ['+21', '+52', '-54', '-32'];
    final suffixMap = {'+21': '21', '+52': '52', '-54': '54', '-32': '32'};
    
    if (_epvatPressureType == 'Overall') {
      for (var t in tempKeys) {
        final sfx = suffixMap[t]!;
        final metricsMap = _overallEpvatControllers[t] ?? {};
        metricsMap.forEach((key, ctrl) {
          variables['${key}_${sfx}'] = double.tryParse(ctrl.text.trim()) ?? 0.0;
        });
      }
    } else {
      final activeTemp = _cartridgeTempController.text.trim();
      final String sfx = activeTemp.contains('52') ? '52' : (activeTemp.contains('32') ? '32' : (activeTemp.contains('54') ? '54' : '21'));
      
      variables['p1_mean_$sfx'] = double.tryParse(_epvatMeanPressureController.text.trim()) ?? 0.0;
      variables['p1_max_$sfx'] = double.tryParse(_epvatMaxPressureController.text.trim()) ?? 0.0;
      variables['p1_min_$sfx'] = double.tryParse(_epvatMinPressureController.text.trim()) ?? 0.0;
      variables['p1_range_$sfx'] = double.tryParse(_epvatRangePressureController.text.trim()) ?? 0.0;
      variables['p1_sd_$sfx'] = double.tryParse(_epvatSDPressureController.text.trim()) ?? 0.0;

      variables['p2_mean_$sfx'] = double.tryParse(_epvatP2MeanPressureController.text.trim()) ?? 0.0;
      variables['p2_max_$sfx'] = double.tryParse(_epvatP2MaxPressureController.text.trim()) ?? 0.0;
      variables['p2_min_$sfx'] = double.tryParse(_epvatP2MinPressureController.text.trim()) ?? 0.0;
      variables['p2_range_$sfx'] = double.tryParse(_epvatP2RangePressureController.text.trim()) ?? 0.0;
      variables['p2_sd_$sfx'] = double.tryParse(_epvatP2SDPressureController.text.trim()) ?? 0.0;

      variables['vel_mean_$sfx'] = double.tryParse(_meanVelController.text.trim()) ?? 0.0;
      variables['vel_max_$sfx'] = double.tryParse(_maxVelController.text.trim()) ?? 0.0;
      variables['vel_min_$sfx'] = double.tryParse(_minVelController.text.trim()) ?? 0.0;
      variables['vel_range_$sfx'] = double.tryParse(_rangeVelController.text.trim()) ?? 0.0;
      variables['vel_sd_$sfx'] = double.tryParse(_sdVelController.text.trim()) ?? 0.0;

      variables['action_time_mean_$sfx'] = double.tryParse(_actionTimeMeanController.text.trim()) ?? 0.0;
      variables['action_time_max_$sfx'] = double.tryParse(_actionTimeMaxController.text.trim()) ?? 0.0;
      variables['action_time_min_$sfx'] = double.tryParse(_actionTimeMinController.text.trim()) ?? 0.0;
      variables['action_time_range_$sfx'] = double.tryParse(_actionTimeRangeController.text.trim()) ?? 0.0;
      variables['action_time_sd_$sfx'] = double.tryParse(_actionTimeSDController.text.trim()) ?? 0.0;
    }
    return variables;
  }

  Map<String, dynamic> _getWaterproofRulesForCaliber() {
    final wp = widget.adminRules['waterproof'] ?? {};
    final calibersMap = wp['calibers'] as Map<String, dynamic>? ?? {};
    if (calibersMap.containsKey(_caliber)) {
      return Map<String, dynamic>.from(calibersMap[_caliber]);
    }
    final matchKey = calibersMap.keys.firstWhere(
      (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
      orElse: () => '',
    );
    if (matchKey.isNotEmpty) {
      return Map<String, dynamic>.from(calibersMap[matchKey]);
    }
    final bool isBlank = _caliber.contains('M82') || _caliber.contains('M200') || _caliber.toLowerCase().contains('blank');
    final int standardRetest = wp['retest_limit'] ?? 4;
    final int standardReject = wp['reject_limit'] ?? 7;
    final int blankRetest = wp['blank_retest_limit'] ?? 4;
    final int blankReject = wp['blank_reject_limit'] ?? 9;
    return {
      'retest_limit': isBlank ? blankRetest : standardRetest,
      'reject_limit': isBlank ? blankReject : standardReject,
      'instructions': wp['instructions'] ?? 'Follow waterproof leakage inspection protocol. Inspect primer and mouth sealings.',
    };
  }

  Map<String, dynamic> _getResidualStressRulesForCaliber() {
    final rs = widget.adminRules['residual_stress'] ?? {};
    final calibersMap = rs['calibers'] as Map<String, dynamic>? ?? {};
    if (calibersMap.containsKey(_caliber)) {
      return Map<String, dynamic>.from(calibersMap[_caliber]);
    }
    final matchKey = calibersMap.keys.firstWhere(
      (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
      orElse: () => '',
    );
    if (matchKey.isNotEmpty) {
      return Map<String, dynamic>.from(calibersMap[matchKey]);
    }
    return {
      'retest_limit': rs['retest_limit'] ?? 1,
      'reject_limit': rs['reject_limit'] ?? 3,
      'instructions': rs['instructions'] ?? 'Examine splits on Neck, Shoulder, Body, and Head. No pressure applied.',
    };
  }

  Map<String, dynamic> _getExtractionRulesForCaliber() {
    final ext = widget.adminRules['extraction'] ?? {};
    final calibersMap = ext['calibers'] as Map<String, dynamic>? ?? {};
    if (calibersMap.containsKey(_caliber)) {
      return Map<String, dynamic>.from(calibersMap[_caliber]);
    }
    final matchKey = calibersMap.keys.firstWhere(
      (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
      orElse: () => '',
    );
    if (matchKey.isNotEmpty) {
      return Map<String, dynamic>.from(calibersMap[matchKey]);
    }
    final extLimits = ext['limits'] ?? {};
    double limit = 200.0;
    if (extLimits.containsKey(_caliber)) {
      limit = (extLimits[_caliber] as num).toDouble();
    } else {
      final limMatch = extLimits.keys.firstWhere(
        (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
        orElse: () => '',
      );
      if (limMatch.isNotEmpty) {
        limit = (extLimits[limMatch] as num).toDouble();
      }
    }
    return {
      'min_force': limit,
      'instructions': ext['instructions'] ?? 'Perform pull-out test of bullet and record peak force.',
    };
  }

  Map<String, dynamic> _getAccuracyRulesForCaliber() {
    final acc = widget.adminRules['accuracy'] ?? {};
    final accLimits = acc['limits'] ?? {};
    Map<String, dynamic> limits = {};
    if (accLimits.containsKey(_caliber)) {
      limits = Map<String, dynamic>.from(accLimits[_caliber]);
    } else {
      final matchKey = accLimits.keys.firstWhere(
        (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
        orElse: () => '',
      );
      if (matchKey.isNotEmpty) {
        limits = Map<String, dynamic>.from(accLimits[matchKey]);
      } else {
        limits = Map<String, dynamic>.from(accLimits['default'] ?? {});
      }
    }
    return {
      'max_mean_radius': (limits['max_mean_radius'] ?? 50.0).toDouble(),
      'max_sd': (limits['max_sd'] ?? 200.0).toDouble(),
      'cond_sd': (limits['cond_sd'] ?? 170.0).toDouble(),
      'vel_min': (limits['vel_min'] ?? 700.0).toDouble(),
      'vel_max': (limits['vel_max'] ?? 900.0).toDouble(),
      'instructions': limits['instructions'] ?? acc['instructions'] ?? 'Assess group sizing at target distance and mean velocity bounds.',
    };
  }

  Map<String, dynamic> _getEpvatRulesForCaliber(String temp) {
    final epv = widget.adminRules['epvat'] ?? {};
    final limitsByCaliber = epv['limits_by_caliber'] as Map<String, dynamic>? ?? {};
    
    // Normalize temperature key (e.g. "+21", "+52", "-54" or "-32")
    final String cleanTemp = temp.contains('+52') || temp == '52' ? '+52' : ((temp.contains('-54') || temp.contains('-32') || temp.startsWith('-')) ? (temp.startsWith('-') ? temp : '-$temp') : '+21');
    
    Map<String, dynamic>? caliberTemps;
    if (limitsByCaliber.containsKey(_caliber)) {
      caliberTemps = Map<String, dynamic>.from(limitsByCaliber[_caliber]);
    } else {
      final matchKey = limitsByCaliber.keys.firstWhere(
        (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
        orElse: () => '',
      );
      if (matchKey.isNotEmpty) {
        caliberTemps = Map<String, dynamic>.from(limitsByCaliber[matchKey]);
      }
    }
    
    if (caliberTemps != null) {
      if (caliberTemps.containsKey(cleanTemp)) {
        return Map<String, dynamic>.from(caliberTemps[cleanTemp]);
      }
      if (caliberTemps.containsKey('+21')) {
        return Map<String, dynamic>.from(caliberTemps['+21']);
      }
    }
    
    // Fallback to top-level limits
    final epvLimits = epv['limits'] ?? {};
    final activeEpv = epvLimits[cleanTemp] ?? epvLimits['+21'] ?? {};
    return {
      'vel_min': (activeEpv['vel_min'] ?? 900.0).toDouble(),
      'vel_max': (activeEpv['vel_max'] ?? 930.0).toDouble(),
      'p1_max': (activeEpv['p1_max'] ?? 3800.0).toDouble(),
      'p2_min': (activeEpv['p2_min'] ?? 200.0).toDouble(),
    };
  }
  
  String _getEpvatInstructionsForCaliber() {
    final epv = widget.adminRules['epvat'] ?? {};
    final instructionsByCaliber = epv['instructions_by_caliber'] as Map<String, dynamic>? ?? {};
    if (instructionsByCaliber.containsKey(_caliber)) {
      return instructionsByCaliber[_caliber].toString();
    }
    final matchKey = instructionsByCaliber.keys.firstWhere(
      (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
      orElse: () => '',
    );
    if (matchKey.isNotEmpty) {
      return instructionsByCaliber[matchKey].toString();
    }
    return epv['instructions'] ?? 'Measure ammunition performance and structural safety under pressure targets.';
  }

  Map<String, dynamic> _getPrimerRulesForCaliber() {
    final ps = widget.adminRules['primer_sensitivity'] ?? {};
    final calibersMap = ps['calibers'] as Map<String, dynamic>? ?? {};
    if (calibersMap.containsKey(_caliber)) {
      return Map<String, dynamic>.from(calibersMap[_caliber]);
    }
    final matchKey = calibersMap.keys.firstWhere(
      (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
      orElse: () => '',
    );
    if (matchKey.isNotEmpty) {
      return Map<String, dynamic>.from(calibersMap[matchKey]);
    }
    final is762 = _caliber.contains('7.62') || _caliber.contains('M80') || _caliber.contains('.308');
    final is9mm = _caliber.contains('9x19') || _caliber.contains('Para') || _caliber.contains('Luger');
    return {
      'drop_weight': is762 ? 110.0 : 55.0,
      'hbar_min': is9mm ? 200.0 : (is762 ? 300.0 : 250.0),
      'hbar_max': is9mm ? 400.0 : (is762 ? 500.0 : 450.0),
      'all_fire_h': is9mm ? 450.0 : (is762 ? 550.0 : 500.0),
      'no_fire_h': is9mm ? 120.0 : (is762 ? 200.0 : 150.0),
      'max_sd': is762 ? 70.0 : (is9mm ? 50.0 : 60.0),
      'instructions': ps['instructions'] ?? 'Perform drop ball sensitivity test. Record drop height (mm) and Fire/Misfire outcome for each round.',
    };
  }

  void _recalculatePrimerStats() {
    final List<double> heights = [];
    int misfires = 0;
    for (int i = 0; i < _primerDropHeightControllers.length; i++) {
      final h = double.tryParse(_primerDropHeightControllers[i].text.trim());
      if (h != null) {
        heights.add(h);
        if (i < _primerFireResults.length && _primerFireResults[i] == 'Misfire') {
          misfires++;
        }
      }
    }
    _primerMisfiresCountController.text = '$misfires';

    if (heights.isEmpty) {
      _primerHbarController.clear();
      _primerSDController.clear();
      _primerHbarPlus5SController.clear();
      _primerHbarMinus2SController.clear();
      return;
    }

    final double hbar = heights.reduce((a, b) => a + b) / heights.length;
    double sd = 0.0;
    if (heights.length > 1) {
      double sumSq = 0.0;
      for (var h in heights) {
        sumSq += math.pow(h - hbar, 2);
      }
      sd = math.sqrt(sumSq / (heights.length - 1));
    }
    final double hbarPlus5S = hbar + (5 * sd);
    final double hbarMinus2S = hbar - (2 * sd);

    _primerHbarController.text = hbar.toStringAsFixed(1);
    _primerSDController.text = sd.toStringAsFixed(1);
    _primerHbarPlus5SController.text = hbarPlus5S.toStringAsFixed(1);
    _primerHbarMinus2SController.text = hbarMinus2S.toStringAsFixed(1);
    _producedController.text = '${heights.length}';
  }

  String _getCalculatedStatus() {
    if (_testName == 'Waterproof Test') {
      final wpRules = _getWaterproofRulesForCaliber();
      final int retestLimit = wpRules['retest_limit'] ?? 4;
      final int rejectLimit = wpRules['reject_limit'] ?? 7;
      
      final totalLeaks = (int.tryParse(_mouthSlowController.text.trim()) ?? 0) +
          (int.tryParse(_mouthFastController.text.trim()) ?? 0) +
          (int.tryParse(_primerSlowController.text.trim()) ?? 0) +
          (int.tryParse(_primerFastController.text.trim()) ?? 0);
          
      if (totalLeaks >= rejectLimit) return 'Rejected';
      if (totalLeaks >= retestLimit) return 'Retest';
      if (totalLeaks > 0) return 'Approved with condition';
      return 'Approved';
    }
    
    if (_testName == 'Residual Stress Test') {
      final rsRules = _getResidualStressRulesForCaliber();
      final int retestLimit = rsRules['retest_limit'] ?? 1;
      final int rejectLimit = rsRules['reject_limit'] ?? 3;
      
      final totalSplits = (int.tryParse(_neckSlowController.text.trim()) ?? 0) +
          (int.tryParse(_neckFastController.text.trim()) ?? 0) +
          (int.tryParse(_shoulderSlowController.text.trim()) ?? 0) +
          (int.tryParse(_shoulderFastController.text.trim()) ?? 0) +
          (int.tryParse(_bodySlowController.text.trim()) ?? 0) +
          (int.tryParse(_bodyFastController.text.trim()) ?? 0) +
          (int.tryParse(_headSlowController.text.trim()) ?? 0) +
          (int.tryParse(_headFastController.text.trim()) ?? 0);
          
      if (totalSplits >= rejectLimit) return 'Rejected';
      if (totalSplits >= retestLimit) return 'Retest';
      if (totalSplits > 0) return 'Approved with condition';
      return 'Approved';
    }
    
    if (_testName == 'Extraction Force Test') {
      final extRules = _getExtractionRulesForCaliber();
      final double limit = (extRules['min_force'] ?? 200.0).toDouble();
      
      final force = double.tryParse(_minXController.text.trim()) ??
          double.tryParse(_epvatMeanPressureController.text.trim()) ?? 999.0;
      if (force < limit) return 'Rejected';
      if (force < limit + 15.0) return 'Approved with condition';
      return 'Approved';
    }
    
    if (_testName == 'Accuracy Test') {
      final accRules = _getAccuracyRulesForCaliber();
      final double maxMeanRadius = (accRules['max_mean_radius'] ?? 50.0).toDouble();
      final double maxSD = (accRules['max_sd'] ?? 200.0).toDouble();
      final double condSD = (accRules['cond_sd'] ?? 170.0).toDouble();
      final double velMin = (accRules['vel_min'] ?? 700.0).toDouble();
      final double velMax = (accRules['vel_max'] ?? 900.0).toDouble();
      
      final meanVel = double.tryParse(_meanVelController.text.trim());
      if (meanVel != null && (meanVel < velMin || meanVel > velMax)) {
        return 'Rejected';
      }
      
      final meanRadius = double.tryParse(_meanRadiusController.text.trim()) ?? 0.0;
      final sdX = double.tryParse(_sdXController.text.trim()) ?? 0.0;
      final sdY = double.tryParse(_sdYController.text.trim()) ?? 0.0;
      
      if (meanRadius > maxMeanRadius || sdX > maxSD || sdY > maxSD) {
        return 'Rejected';
      } else if (sdX >= condSD || sdY >= condSD) {
        return 'Retest';
      } else if ((meanRadius > maxMeanRadius * 0.88) || (sdX > condSD * 0.88) || (sdY > condSD * 0.88)) {
        return 'Approved with condition';
      }
      return 'Approved';
    }
    
    if (_testName == 'Firing Rate Cycle Test') {
      final allWeapons = List<Map<String, dynamic>>.from(
        (widget.adminRules['cyclic_rate']?['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
      );
      final selectedWeapon = allWeapons.firstWhere(
        (w) => w['name'] == _cyclicRateWeaponType,
        orElse: () => {},
      );
      final int rpmMin = (selectedWeapon['min'] ?? 0) as int;
      final int? rpmMax = selectedWeapon['max'] as int?;
      final double? val = double.tryParse(_cyclicRateController.text.trim());
      if (val == null || val < rpmMin || (rpmMax != null && val > rpmMax)) {
        return 'Rejected';
      }
      if (rpmMax != null && (val <= rpmMin + 20 || val >= rpmMax - 20)) {
        return 'Approved with condition';
      }
      return 'Approved';
    }
    
    if (_testName == 'Terminal Effect Test') {
      for (int i = 0; i < _terminalVelocityRoundsControllers.length; i++) {
        final hole = _terminalHoleDiameterRounds.length > i ? _terminalHoleDiameterRounds[i] : 'Yes';
        final steel = _terminalSteelPenetrationRounds.length > i ? _terminalSteelPenetrationRounds[i] : 'Yes';
        final alum = _terminalAluminumPenetrationRounds.length > i ? _terminalAluminumPenetrationRounds[i] : 'Yes';
        
        if (hole == 'No' || steel == 'No' || alum == 'No') {
          return 'Rejected';
        }
      }
      return 'Approved';
    }
    
    if (_testName == 'Function Test') {
      final l1 = int.tryParse(_functionLevel1Controller.text.trim()) ?? 0;
      final l2 = int.tryParse(_functionLevel2Controller.text.trim()) ?? 0;
      final l3 = int.tryParse(_functionLevel3Controller.text.trim()) ?? 0;
      final l4 = int.tryParse(_functionLevel4Controller.text.trim()) ?? 0;
      return _calculateFunctionTestStatus(l1: l1, l2: l2, l3: l3, l4: l4);
    }

    if (_testName == 'Primer Sensitivity Test') {
      final prRules = _getPrimerRulesForCaliber();
      final double hbarMin = (prRules['hbar_min'] ?? 250.0).toDouble();
      final double hbarMax = (prRules['hbar_max'] ?? 450.0).toDouble();
      final double allFireLimit = (prRules['all_fire_h'] ?? 500.0).toDouble();
      final double noFireLimit = (prRules['no_fire_h'] ?? 150.0).toDouble();
      final double maxSD = (prRules['max_sd'] ?? 60.0).toDouble();

      final double? hbar = double.tryParse(_primerHbarController.text.trim());
      final double? sd = double.tryParse(_primerSDController.text.trim());
      final double? allFireH = double.tryParse(_primerHbarPlus5SController.text.trim());
      final double? noFireH = double.tryParse(_primerHbarMinus2SController.text.trim());
      final int misfires = int.tryParse(_primerMisfiresCountController.text.trim()) ?? 0;

      if (hbar == null || sd == null || allFireH == null || noFireH == null) {
        return 'Approved';
      }

      if (hbar < hbarMin || hbar > hbarMax || allFireH > allFireLimit || noFireH < noFireLimit) {
        return 'Rejected';
      }
      if (sd > maxSD) {
        return 'Retest';
      }
      if (misfires > 0 || sd > maxSD * 0.85) {
        return 'Approved with condition';
      }
      return 'Approved';
    }

    if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
      final epv = widget.adminRules['epvat'] ?? {};
      
      bool isRejected = false;
      
      void checkTemp(String t, Map<String, dynamic> variables) {
        final activeEpv = _getEpvatRulesForCaliber(t);
        final double velMin = (activeEpv['vel_min'] ?? 0.0).toDouble();
        final double velMax = (activeEpv['vel_max'] ?? 9999.0).toDouble();
        final double p1Max = (activeEpv['p1_max'] ?? 9999.0).toDouble();
        final double p2Min = (activeEpv['p2_min'] ?? 0.0).toDouble();
        final double maxActionTime = (activeEpv['max_action_time'] ?? epv['max_action_time'] ?? 4.0).toDouble();
        
        final double vMean = variables['vel_mean_${t.replaceAll('+', '').replaceAll('-', '')}'] ?? 0.0;
        final double p1MaxVal = variables['p1_max_${t.replaceAll('+', '').replaceAll('-', '')}'] ?? 0.0;
        final double p2MinVal = variables['p2_min_${t.replaceAll('+', '').replaceAll('-', '')}'] ?? 0.0;
        final double aMean = variables['action_time_mean_${t.replaceAll('+', '').replaceAll('-', '')}'] ?? 0.0;
        
        if (vMean > 0 && (vMean < velMin || vMean > velMax)) {
          isRejected = true;
        }
        if (p1MaxVal > 0 && p1MaxVal > p1Max) {
          isRejected = true;
        }
        if (p2MinVal > 0 && p2MinVal < p2Min) {
          isRejected = true;
        }
        if (aMean > 0 && aMean > maxActionTime) {
          isRejected = true;
        }
      }
      
      final variables = _getEpvatVariablesMap();
      if (_epvatPressureType == 'Overall') {
        final bool isBlank = _caliber.contains('M82') || _caliber.contains('M200') || _caliber.toLowerCase().contains('blank');
        final coldT = isBlank ? '-32' : '-54';
        final temps = ['+21', '+52', coldT];
        final validTemps = temps.where((t) {
          final p1 = _overallEpvatControllers[t]?['p1_mean']?.text.trim() ?? '';
          final p2 = _overallEpvatControllers[t]?['p2_mean']?.text.trim() ?? '';
          final v = _overallEpvatControllers[t]?['vel_mean']?.text.trim() ?? '';
          return p1.isNotEmpty || p2.isNotEmpty || v.isNotEmpty;
        }).toList();
        final tempsToCheck = validTemps.isNotEmpty ? validTemps : [temps[_activeEpvatTempTabIndex]];
        for (var t in tempsToCheck) {
          checkTemp(t, variables);
        }
      } else {
        final activeTemp = _cartridgeTempController.text.trim();
        final tKey = activeTemp.contains('52') ? '+52' : (activeTemp.contains('32') ? '-32' : (activeTemp.contains('54') ? '-54' : '+21'));
        checkTemp(tKey, variables);
      }
      
      if (isRejected) return 'Rejected';
      
      final formulasMap = Map<String, dynamic>.from(epv['custom_formulas'] ?? {});
      var list = List<dynamic>.from(formulasMap[_caliber] ?? []);
      if (list.isEmpty) {
        list = List<dynamic>.from(formulasMap['default'] ?? []);
      }
      if (list.isEmpty) {
        list = EpvatFormulaHelper.getDefaultFormulas(isThreeTemp: _epvatPressureType == 'Overall');
      }
      
      final defaultTemp = _epvatPressureType == 'Overall'
          ? '21'
          : (_cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim().isEmpty
              ? '21'
              : _cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim());

      for (var f in list) {
        final item = Map<String, dynamic>.from(f as Map);
        final res = EpvatFormulaHelper.evaluateFormulaItem(
          item,
          variables,
          defaultTemp: defaultTemp,
          activePressureUnit: _epvatPressureUnit,
        );
        if (!res.isPassed) {
          return 'Rejected';
        }
      }
    }

    return 'Approved';
  }

  Widget _buildEpvatCustomCalculationsCard() {
    final epv = widget.adminRules['epvat'] ?? {};
    final formulasMap = Map<String, dynamic>.from(epv['custom_formulas'] ?? {});
    var list = List<dynamic>.from(formulasMap[_caliber] ?? []);
    if (list.isEmpty) {
      list = List<dynamic>.from(formulasMap['default'] ?? []);
    }
    if (list.isEmpty) {
      list = EpvatFormulaHelper.getDefaultFormulas(isThreeTemp: _epvatPressureType == 'Overall');
    }
    
    if (list.isEmpty) return const SizedBox.shrink();
    
    final defaultTemp = _epvatPressureType == 'Overall'
        ? '21'
        : (_cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim().isEmpty
            ? '21'
            : _cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim());

    final variables = _getEpvatVariablesMap();
    final results = list.map((f) => EpvatFormulaHelper.evaluateFormulaItem(
      Map<String, dynamic>.from(f as Map),
      variables,
      defaultTemp: defaultTemp,
      activePressureUnit: _epvatPressureUnit,
    )).toList();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.calculate_outlined, color: Color(0xFF06B6D4), size: 18.0),
                  SizedBox(width: 8.0),
                  Text(
                    'EPVAT Calculated Results & Formulas (Admin Defined)',
                    style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                ),
                child: const Text(
                  'Auto Calculated',
                  style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          ...results.map((res) {
            final passed = res.isPassed;
            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: passed ? const Color(0xFF10B981).withOpacity(0.05) : const Color(0xFFEF4444).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: passed ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(res.name, style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                res.formula,
                                style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontFamily: 'JetBrainsMono'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.0, fontFamily: 'JetBrainsMono'),
                            children: [
                              const TextSpan(text: 'Calculation: ', style: TextStyle(color: Color(0xFF8E96A3))),
                              TextSpan(
                                text: res.substitutedText,
                                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: res.op == '±' || res.op == '+/-'
                                    ? ' ${res.unit} (Limit: ±${res.limitValue.toStringAsFixed(1)} ${res.unit})'
                                    : ' ${res.unit} ${res.op} ${res.limitValue.toStringAsFixed(1)} ${res.unit}',
                                style: TextStyle(color: passed ? const Color(0xFF8E96A3) : const Color(0xFFF87171), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: passed ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: passed ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4)),
                    ),
                    child: Text(
                      passed ? 'PASSED' : 'FAILED',
                      style: TextStyle(
                        color: passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPrimerSensitivityCard() {
    final prRules = _getPrimerRulesForCaliber();
    final double defaultDropWeight = ((prRules['drop_weight'] ?? 55.0) as num).toDouble();
    final bool isLotPrimerLocked = widget.currentModule == 'Lot Acceptance Test';

    if (_primerDropWeightController.text.isEmpty) {
      _primerDropWeightController.text = defaultDropWeight.toStringAsFixed(1);
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.track_changes_outlined, color: Color(0xFF06B6D4), size: 18.0),
                  SizedBox(width: 8.0),
                  Text(
                    'Primer Sensitivity Test (Drop Ball Method)',
                    style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                ),
                child: Text(
                  'Spec: ${defaultDropWeight.toStringAsFixed(1)}g Ball',
                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          if (isLotPrimerLocked) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14.0),
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFF38BDF8), size: 20.0),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      'Lot Acceptance Module: Primer Sensitivity metrics are synchronized automatically from Component Primer Lot (${_selectedComponentPrimerLot ?? _primerLotController.text}) and locked against manual changes.',
                      style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 12.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _buildFormRow([
            _buildFlexibleField(
              flex: 1,
              label: 'Drop Ball Weight (grams)',
              child: _buildTextField(
                controller: _primerDropWeightController,
                readOnly: isLotPrimerLocked,
                hint: 'e.g. 55.0 or 111.86',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) {
                  _scheduleAutoSave();
                  setState(() {});
                },
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'Total Test Rounds Recorded',
              child: _buildTextField(
                controller: _producedController,
                readOnly: isLotPrimerLocked,
                hint: '50',
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  _scheduleAutoSave();
                  setState(() {});
                },
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'Misfires Count',
              child: _buildTextField(
                controller: _primerMisfiresCountController,
                readOnly: isLotPrimerLocked,
                hint: '0',
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  _scheduleAutoSave();
                  setState(() {});
                },
              ),
            ),
          ]),
          const SizedBox(height: 16.0),
          const Text(
            'Primer Sensitivity Metrics & Auto-Calculated Limits',
            style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          _buildFormRow([
            _buildFlexibleField(
              flex: 1,
              label: 'Mean Height H̄ / HM (mm)',
              child: _buildTextField(
                controller: _primerHbarController,
                hint: 'e.g. 350.0',
                readOnly: isLotPrimerLocked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  final h = double.tryParse(_primerHbarController.text.trim());
                  final s = double.tryParse(_primerSDController.text.trim());
                  if (h != null && s != null) {
                    _primerHbarPlus5SController.text = (h + 5 * s).toStringAsFixed(2);
                    _primerHbarMinus2SController.text = (h - 2 * s).toStringAsFixed(2);
                  }
                  setState(() {});
                  _scheduleAutoSave();
                },
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'Std Deviation S / SD (mm)',
              child: _buildTextField(
                controller: _primerSDController,
                hint: 'e.g. 30.0',
                readOnly: isLotPrimerLocked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  final h = double.tryParse(_primerHbarController.text.trim());
                  final s = double.tryParse(_primerSDController.text.trim());
                  if (h != null && s != null) {
                    _primerHbarPlus5SController.text = (h + 5 * s).toStringAsFixed(2);
                    _primerHbarMinus2SController.text = (h - 2 * s).toStringAsFixed(2);
                  }
                  setState(() {});
                  _scheduleAutoSave();
                },
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'All Fire H̄ + 5S (mm)',
              child: _buildTextField(controller: _primerHbarPlus5SController, hint: 'Auto', readOnly: true),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'No Fire H̄ - 2S (mm)',
              child: _buildTextField(controller: _primerHbarMinus2SController, hint: 'Auto', readOnly: true),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildQualityStatusField({int flex = 3}) {
    return Builder(
      builder: (context) {
        String? autoStatus;
        
        if (_testName == 'Waterproof Test') {
          final wpRules = _getWaterproofRulesForCaliber();
          final int retestLimit = wpRules['retest_limit'] ?? 4;
          final int rejectLimit = wpRules['reject_limit'] ?? 7;

          final ms = int.tryParse(_mouthSlowController.text) ?? 0;
          final mf = int.tryParse(_mouthFastController.text) ?? 0;
          final ps = int.tryParse(_primerSlowController.text) ?? 0;
          final pf = int.tryParse(_primerFastController.text) ?? 0;
          final totalLeaks = ms + mf + ps + pf;

          if (totalLeaks >= rejectLimit) {
            autoStatus = 'Rejected';
          } else if (totalLeaks >= retestLimit) {
            autoStatus = 'Retest';
          } else {
            autoStatus = 'Approved';
          }
        } else if (_testName == 'Residual Stress Test') {
          final rsRules = _getResidualStressRulesForCaliber();
          final int retestLimit = rsRules['retest_limit'] ?? 1;
          final int rejectLimit = rsRules['reject_limit'] ?? 3;

          final ns = int.tryParse(_neckSlowController.text) ?? 0;
          final nf = int.tryParse(_neckFastController.text) ?? 0;
          final ss = int.tryParse(_shoulderSlowController.text) ?? 0;
          final sf = int.tryParse(_shoulderFastController.text) ?? 0;
          final bs = int.tryParse(_bodySlowController.text) ?? 0;
          final bf = int.tryParse(_bodyFastController.text) ?? 0;
          final hs = int.tryParse(_headSlowController.text) ?? 0;
          final hf = int.tryParse(_headFastController.text) ?? 0;
          final totalSplits = ns + nf + ss + sf + bs + bf + hs + hf;

          if (totalSplits >= rejectLimit) {
            autoStatus = 'Rejected';
          } else if (totalSplits >= retestLimit) {
            autoStatus = 'Retest';
          } else {
            autoStatus = 'Approved';
          }
        } else if (_testName == 'Accuracy Test') {
          final accRules = _getAccuracyRulesForCaliber();
          final double maxMeanRadius = (accRules['max_mean_radius'] ?? 50.0).toDouble();
          final double maxSD = (accRules['max_sd'] ?? 200.0).toDouble();
          final double condSD = (accRules['cond_sd'] ?? 170.0).toDouble();
          final double velMin = (accRules['vel_min'] ?? 700.0).toDouble();
          final double velMax = (accRules['vel_max'] ?? 900.0).toDouble();

          final double? meanVel = double.tryParse(_meanVelController.text.trim());
          bool isVelReject = false;
          if (meanVel != null) {
            isVelReject = meanVel < velMin || meanVel > velMax;
          }

          if (isVelReject) {
            autoStatus = 'Rejected';
          } else {
            final double meanRadius = double.tryParse(_meanRadiusController.text.trim()) ?? 0.0;
            final double sdx = double.tryParse(_sdXController.text.trim()) ?? 0.0;
            final double sdy = double.tryParse(_sdYController.text.trim()) ?? 0.0;

            if (meanRadius > maxMeanRadius || sdx > maxSD || sdy > maxSD) {
              autoStatus = 'Rejected';
            } else if (sdx >= condSD || sdy >= condSD) {
              autoStatus = 'Approved with condition';
            } else {
              autoStatus = 'Approved';
            }
          }
        } else if (_testName == 'Extraction Force Test') {
          final double? minForce = double.tryParse(_minXController.text.trim());
          if (minForce != null) {
            final extRules = _getExtractionRulesForCaliber();
            final double limit = (extRules['min_force'] ?? 200.0).toDouble();
            autoStatus = minForce < limit ? 'Rejected' : 'Approved';
          } else {
            autoStatus = 'Approved';
          }
        } else if (_testName == 'Function Test') {
          final l1 = int.tryParse(_functionLevel1Controller.text.trim()) ?? 0;
          final l2 = int.tryParse(_functionLevel2Controller.text.trim()) ?? 0;
          final l3 = int.tryParse(_functionLevel3Controller.text.trim()) ?? 0;
          final l4 = int.tryParse(_functionLevel4Controller.text.trim()) ?? 0;
          autoStatus = _calculateFunctionTestStatus(l1: l1, l2: l2, l3: l3, l4: l4);
        } else if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
          final epv = widget.adminRules['epvat'] ?? {};
          final bool threeSigmaEnabled = epv['enable_three_sigma_pressure'] == true;
          final bool tempDeltaEnabled = epv['enable_temp_velocity_delta'] == true;
          final double maxTempDelta = ((epv['temp_velocity_delta_max'] ?? 30.0) as num).toDouble();
          
          if (_epvatPressureType == 'Overall') {
            final temps = ['+21', '+52', '-54'];
            final activeTemp = temps[_activeEpvatTempTabIndex];
            final activeEpv = _getEpvatRulesForCaliber(activeTemp);
            
            final double velMin = (activeEpv['vel_min'] ?? 900.0).toDouble();
            final double velMax = (activeEpv['vel_max'] ?? 930.0).toDouble();
            final double p1Max = (activeEpv['p1_max'] ?? 3800.0).toDouble();
            final double p2Min = (activeEpv['p2_min'] ?? 200.0).toDouble();
            
            final double? vMean = double.tryParse(_overallEpvatControllers[activeTemp]!['vel_mean']!.text.trim());
            final double? p1MaxVal = double.tryParse(_overallEpvatControllers[activeTemp]!['p1_max']!.text.trim());
            final double? p2MinVal = double.tryParse(_overallEpvatControllers[activeTemp]!['p2_min']!.text.trim());
            final double? p1MeanVal = double.tryParse(_overallEpvatControllers[activeTemp]!['p1_mean']!.text.trim());
            final double? p1SdVal = double.tryParse(_overallEpvatControllers[activeTemp]!['p1_sd']!.text.trim());
            
            bool rejected = false;
            
            if ((vMean != null && (vMean < velMin || vMean > velMax)) ||
                (p1MaxVal != null && p1MaxVal > p1Max) ||
                (p2MinVal != null && p2MinVal < p2Min)) {
              rejected = true;
            }
            
            if (!rejected && threeSigmaEnabled && p1MeanVal != null && p1SdVal != null) {
              if ((p1MeanVal + 3.0 * p1SdVal) > p1Max) {
                rejected = true;
              }
            }
            
            if (!rejected && tempDeltaEnabled) {
              final double? v52 = double.tryParse(_overallEpvatControllers['+52']!['vel_mean']!.text.trim());
              final double? v54 = double.tryParse(_overallEpvatControllers['-54']!['vel_mean']!.text.trim());
              if (v52 != null && v54 != null && (v52 - v54).abs() > maxTempDelta) {
                rejected = true;
              }
            }
            
            autoStatus = rejected ? 'Rejected' : 'Approved';
          } else {
            final tempKey = _cartridgeTempController.text.trim();
            final activeEpv = _getEpvatRulesForCaliber(tempKey);
            
            final double velMin = (activeEpv['vel_min'] ?? 900.0).toDouble();
            final double velMax = (activeEpv['vel_max'] ?? 930.0).toDouble();
            final double p1Max = (activeEpv['p1_max'] ?? 3800.0).toDouble();
            final double p2Min = (activeEpv['p2_min'] ?? 200.0).toDouble();
            
            final double? vMean = double.tryParse(_meanVelController.text.trim());
            final double? p1MaxVal = double.tryParse(_epvatMaxPressureController.text.trim());
            final double? p2MinVal = double.tryParse(_epvatP2MinPressureController.text.trim());
            final double? p1MeanVal = double.tryParse(_epvatMeanPressureController.text.trim());
            final double? p1SdVal = double.tryParse(_epvatSDPressureController.text.trim());
            
            bool rejected = false;
            
            if ((vMean != null && (vMean < velMin || vMean > velMax)) ||
                (p1MaxVal != null && p1MaxVal > p1Max) ||
                (p2MinVal != null && p2MinVal < p2Min)) {
              rejected = true;
            }
            
            if (!rejected && threeSigmaEnabled && p1MeanVal != null && p1SdVal != null) {
              if ((p1MeanVal + 3.0 * p1SdVal) > p1Max) {
                rejected = true;
              }
            }
            
            autoStatus = rejected ? 'Rejected' : 'Approved';
          }
        }

        if (autoStatus != null && _status != autoStatus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _status = autoStatus!;
              });
            }
          });
        }

        Color statusBgColor;
        Color statusBorderColor;
        Color statusTextColor = Colors.white;
        
        if (_status == 'Approved' || _status == 'Approved with condition') {
          statusBgColor = const Color(0xFF10B981); // Full Green
          statusBorderColor = const Color(0xFF059669);
        } else if (_status == 'Rejected') {
          statusBgColor = const Color(0xFFEF4444); // Full Red
          statusBorderColor = const Color(0xFFDC2626);
        } else if (_status == 'Retest' || _status == 'Pending Review') {
          statusBgColor = const Color(0xFFF59E0B); // Full Yellow
          statusBorderColor = const Color(0xFFD97706);
        } else {
          statusBgColor = const Color(0xFFE0F2FE);
          statusBorderColor = const Color(0xFF7DD3FC);
          statusTextColor = const Color(0xFF0C2A4D);
        }

        return _buildFlexibleField(
          flex: flex,
          label: 'Quality Status',
          child: DropdownButtonFormField<String>(
            value: _status,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            icon: Icon(Icons.arrow_drop_down, color: statusTextColor),
            style: TextStyle(color: statusTextColor, fontSize: 13.5, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: statusBgColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: statusBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: statusBorderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: statusBorderColor, width: 2.0),
              ),
            ),
            items: const ['Approved', 'Pending Review', 'Rejected', 'Retest', 'Approved with condition'].map((s) {
              Color itemColor = Colors.white;
              if (s == 'Approved') itemColor = const Color(0xFF34D399);
              if (s == 'Rejected') itemColor = const Color(0xFFF87171);
              if (s == 'Retest') itemColor = const Color(0xFFFBBF24);
              return DropdownMenuItem<String>(
                value: s,
                child: Text(s, style: TextStyle(color: itemColor, fontWeight: FontWeight.bold)),
              );
            }).toList(),
            onChanged: (autoStatus != null && autoStatus != 'Approved') 
                ? null 
                : (v) => setState(() => _status = v!),
          ),
        );
      },
    );
  }

  Widget _buildSampleLocationField({int flex = 3}) {
    return _buildFlexibleField(
      flex: flex,
      label: 'Sampling Location',
      child: Row(
        children: [
          Expanded(
            child: _buildDropdownField(
              value: _locationController.text.isNotEmpty && _allSampleLocations.contains(_locationController.text)
                  ? _locationController.text
                  : (_allSampleLocations.isNotEmpty ? _allSampleLocations.first : ''),
              items: _allSampleLocations,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _locationController.text = v);
                }
              },
            ),
          ),
          const SizedBox(width: 6.0),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF0284C7), size: 18),
              tooltip: 'Admin: Add new sample location',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              onPressed: _showAddLocationDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedRow2() {
    if (_testName == 'Waterproof Test') {
      return _buildFormRow([
        _buildFlexibleField(
          key: _producedFieldKey,
          flex: 3,
          label: 'Quantity Tested (Rounds)',
          isRequired: true,
          child: _buildTextField(
            controller: _producedController,
            focusNode: _producedFocusNode,
            hint: '0',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (int.tryParse(v) == null) return 'Must be integer';
              if (int.parse(v) < 0) return 'Cannot be negative';
              return null;
            },
          ),
        ),
        _buildFlexibleField(
          flex: 3,
          label: 'Viscosity (seconds)',
          child: _buildTextField(
            controller: _viscosityController,
            hint: 'e.g., 40',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          ),
        ),
        _buildSampleLocationField(flex: 4),
        _buildFlexibleField(
          flex: 3,
          label: 'Pressure (Bar) - Caliber Fixed',
          child: _buildTextField(
            controller: _pressureController,
            readOnly: true,
            hint: (_caliber.contains('M82') || _caliber.contains('M200')) ? '0.14' : '0.5',
          ),
        ),
        _buildQualityStatusField(flex: 3),
      ], lockSingleRow: true);
    }

    if (_testName == 'Accuracy Test') {
      return _buildFormRow([
        _buildFlexibleField(
          key: _producedFieldKey,
          flex: 3,
          label: 'Quantity Tested (Rounds)',
          isRequired: true,
          child: _buildTextField(
            controller: _producedController,
            focusNode: _producedFocusNode,
            hint: '0',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (int.tryParse(v) == null) return 'Must be integer';
              if (int.parse(v) < 0) return 'Cannot be negative';
              return null;
            },
          ),
        ),
        _buildFlexibleField(
          key: _barrelFieldKey,
          flex: 4,
          label: 'Accuracy Barrel Test Serial',
          isRequired: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdownField(
                focusNode: _barrelFocusNode,
                value: _accuracyBarrels.contains(_barrelSNController.text)
                    ? _barrelSNController.text
                    : (_accuracyBarrels.isNotEmpty ? _accuracyBarrels.first : ''),
                items: _accuracyBarrels,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _barrelSNController.text = v);
                  }
                },
              ),
              const SizedBox(height: 4.0),
              Text(
                '${_getAssetRounds(_barrelSNController.text)} cumulative rounds fired',
                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        _buildSampleLocationField(flex: 3),
        _buildFlexibleField(
          key: _distanceFieldKey,
          flex: 2,
          label: 'Distance of Velocity (m)',
          isRequired: true,
          child: _buildTextField(
            controller: _distanceController,
            focusNode: _distanceFocusNode,
            hint: 'e.g., 25',
          ),
        ),
        _buildQualityStatusField(flex: 3),
      ], lockSingleRow: true);
    }

    if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
      final matchingPropellantRecords = widget.componentPropellantRecords.where((r) {
        final c = r.caliber.toLowerCase();
        final curr = _caliber.toLowerCase();
        return c == curr || c.contains(curr) || curr.contains(c);
      }).toList();
      final propellantLotOptions = matchingPropellantRecords
          .map((r) => r.propellantLot.isNotEmpty ? r.propellantLot : r.lotNumber)
          .where((l) => l.isNotEmpty)
          .toSet()
          .toList();

      final matchingPrimerRecords = widget.componentPrimerRecords.where((r) {
        final c = r.caliber.toLowerCase();
        final curr = _caliber.toLowerCase();
        return c == curr || c.contains(curr) || curr.contains(c);
      }).toList();
      final primerLotOptions = matchingPrimerRecords
          .map((r) => r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber)
          .where((l) => l.isNotEmpty)
          .toSet()
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // EPVAT ROW 1: Temp eval mode, Quantity tested, Propellant (dropdown), Propellant code (dropdown), Propellant lot (dropdown), Primer supplier (dropdown), Primer lot (dropdown)
          _buildFormRow([
            _buildFlexibleField(
              flex: 3,
              label: 'Temp Evaluation Mode',
              child: Column(
                children: [
                  _buildDropdownField(
                    value: _isCaliberSingleTempOnly || !_isThreeTemperatureMode
                        ? 'Single Temperature'
                        : 'All 3 Temperatures (+21, +52, -54 °C)',
                    items: _isCaliberSingleTempOnly
                        ? const ['Single Temperature']
                        : const [
                            'Single Temperature',
                            'All 3 Temperatures (+21, +52, -54 °C)',
                          ],
                    onChanged: (v) {
                      if (v != null) _onTemperatureModeChanged(v);
                    },
                  ),
                  if (!_isThreeTemperatureMode) ...[
                    const SizedBox(height: 4.0),
                    _buildDropdownField(
                      value: _selectedTemperatureDisplay,
                      items: const ['+21 °C', '+52 °C', '-54 °C'],
                      onChanged: (v) {
                        if (v != null) _onSelectedTemperatureChanged(v);
                      },
                    ),
                  ],
                ],
              ),
            ),
            _buildFlexibleField(
              key: _producedFieldKey,
              flex: 2,
              label: 'Quantity Tested',
              isRequired: true,
              child: _buildTextField(
                controller: _producedController,
                focusNode: _producedFocusNode,
                hint: '0',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Integer';
                  return null;
                },
              ),
            ),
            _buildFlexibleField(
              flex: 2,
              label: 'Propellant',
              isRequired: true,
              child: _buildDropdownField(
                value: _propellantSuppliers.contains(_propellantSupplier)
                    ? _propellantSupplier
                    : (_propellantSuppliers.isNotEmpty ? _propellantSuppliers.first : ''),
                items: _propellantSuppliers,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _propellantSupplier = v;
                      final codes = _currentSupplierPropellantCodes;
                      if (codes.isNotEmpty && codes.first != 'Other') {
                        _propellantCodeController.text = codes.first;
                      }
                    });
                  }
                },
              ),
            ),
            _buildFlexibleField(
              flex: 2,
              label: 'Propellant Code',
              isRequired: true,
              child: _buildDropdownField(
                value: _currentSupplierPropellantCodes.contains(_propellantCodeController.text.trim())
                    ? _propellantCodeController.text.trim()
                    : (_currentSupplierPropellantCodes.isNotEmpty ? _currentSupplierPropellantCodes.first : 'Other'),
                items: _currentSupplierPropellantCodes,
                onChanged: (v) {
                  if (v != null && v != 'Other') {
                    setState(() => _propellantCodeController.text = v);
                  }
                },
              ),
            ),
            _buildFlexibleField(
              flex: 3,
              label: 'Propellant Lot No.',
              isRequired: true,
              child: propellantLotOptions.isNotEmpty
                  ? DropdownButtonFormField<String>(
                      value: propellantLotOptions.contains(_propellantLotController.text.trim())
                          ? _propellantLotController.text.trim()
                          : propellantLotOptions.first,
                      isExpanded: true,
                      dropdownColor: const Color(0xFFE0F2FE),
                      style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.0, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFE0F2FE),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF7DD3FC))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF7DD3FC))),
                      ),
                      items: propellantLotOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedComponentPropellantLot = v;
                            _propellantLotController.text = v;
                          });
                        }
                      },
                    )
                  : _buildTextField(
                      controller: _propellantLotController,
                      hint: 'e.g. 90124',
                      keyboardType: TextInputType.text,
                    ),
            ),
            _buildFlexibleField(
              flex: 2,
              label: 'Primer Supplier',
              isRequired: true,
              child: _buildDropdownField(
                value: _primerSuppliers.contains(_primerSupplier)
                    ? _primerSupplier
                    : (_primerSuppliers.isNotEmpty ? _primerSuppliers.first : ''),
                items: _primerSuppliers,
                onChanged: (v) {
                  if (v != null) setState(() => _primerSupplier = v);
                },
              ),
            ),
            _buildFlexibleField(
              flex: 3,
              label: 'Primer Lot',
              isRequired: true,
              child: primerLotOptions.isNotEmpty
                  ? DropdownButtonFormField<String>(
                      value: primerLotOptions.contains(_primerLotController.text.trim())
                          ? _primerLotController.text.trim()
                          : primerLotOptions.first,
                      isExpanded: true,
                      dropdownColor: const Color(0xFFE0F2FE),
                      style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.0, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFE0F2FE),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF7DD3FC))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF7DD3FC))),
                      ),
                      items: primerLotOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedComponentPrimerLot = v;
                            _primerLotController.text = v;
                          });
                        }
                      },
                    )
                  : _buildTextField(
                      controller: _primerLotController,
                      hint: 'e.g. CBC-2026-01',
                    ),
            ),
          ], lockSingleRow: true),
          const SizedBox(height: 14.0),

          // EPVAT ROW 2: Barrel Serial No., GP6 (1) Chamber, GP6 (2) Port, Velocity distance, Sampling location, Quality status
          _buildFormRow([
            _buildFlexibleField(
              key: _barrelFieldKey,
              flex: 3,
              label: 'Barrel Serial No.',
              isRequired: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownField(
                    focusNode: _barrelFocusNode,
                    value: _epvatBarrels.contains(_barrelSNController.text)
                        ? _barrelSNController.text
                        : (_epvatBarrels.isNotEmpty ? _epvatBarrels.first : ''),
                    items: _epvatBarrels,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _barrelSNController.text = v);
                      }
                    },
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    '${_getAssetRounds(_barrelSNController.text)} rounds fired',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            _buildFlexibleField(
              flex: 3,
              label: 'GP6 (1) Chamber',
              isRequired: true,
              child: Row(
                children: [
                  Expanded(
                    child: _manualGP1Entry
                        ? _buildTextField(
                            controller: _epvatSensor1Controller,
                            hint: 'e.g., GP1-001 (PCB 119B)',
                          )
                        : _buildDropdownField(
                            value: _gp1Transducers.contains(_epvatSensor1Controller.text)
                                ? _epvatSensor1Controller.text
                                : (_gp1Transducers.isNotEmpty ? _gp1Transducers.first : ''),
                            items: _gp1Transducers,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _epvatSensor1Controller.text = v);
                              }
                            },
                          ),
                  ),
                  const SizedBox(width: 4.0),
                  IconButton(
                    icon: Icon(_manualGP1Entry ? Icons.list : Icons.edit_note, size: 18, color: const Color(0xFF06B6D4)),
                    tooltip: _manualGP1Entry ? 'Select from registered list' : 'Type custom transducer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() => _manualGP1Entry = !_manualGP1Entry),
                  ),
                ],
              ),
            ),
            if (!_isCaliber9mm)
              _buildFlexibleField(
                key: _gp6FieldKey,
                flex: 3,
                label: 'GP6 (2) Port',
                isRequired: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropdownField(
                      focusNode: _gp6FocusNode,
                      value: _gp6Serials.contains(_gp6SerialController.text)
                          ? _gp6SerialController.text
                          : (_gp6Serials.isNotEmpty ? _gp6Serials.first : ''),
                      items: _gp6Serials,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _gp6SerialController.text = v;
                            _epvatSensor2Controller.text = v;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '${_getAssetRounds(_gp6SerialController.text)} rounds fired',
                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            _buildSampleLocationField(flex: 3),
            _buildFlexibleField(
              key: _distanceFieldKey,
              flex: 2,
              label: 'Velocity distance (m)',
              isRequired: true,
              child: _buildTextField(
                controller: _distanceController,
                focusNode: _distanceFocusNode,
                hint: 'e.g., 25',
              ),
            ),
            _buildQualityStatusField(flex: 3),
          ], lockSingleRow: true),
        ],
      );
    }

    if (_testName == 'Function Test') {
      return _buildFormRow([
        _buildFlexibleField(
          key: _producedFieldKey,
          flex: 3,
          label: 'Quantity Tested (Rounds)',
          isRequired: true,
          child: _buildTextField(
            controller: _producedController,
            focusNode: _producedFocusNode,
            hint: '0',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (int.tryParse(v) == null) return 'Must be integer';
              if (int.parse(v) < 0) return 'Cannot be negative';
              return null;
            },
          ),
        ),
        _buildFlexibleField(
          flex: 2,
          label: 'Total Defects',
          child: _buildTextField(
            controller: _defectsController,
            hint: '0',
            readOnly: true,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (int.tryParse(v) == null) return 'Must be integer';
              if (int.parse(v) < 0) return 'Cannot be negative';
              return null;
            },
          ),
        ),
        _buildSampleLocationField(flex: 3),
        _buildFlexibleField(
          flex: 4,
          label: 'Temperature Evaluation Mode',
          child: _buildDropdownField(
            value: _isCaliberSingleTempOnly || !_isThreeTemperatureMode
                ? 'Single Temperature'
                : 'All 3 Temperatures (+21, +52, $_functionColdTempLabel)',
            items: _isCaliberSingleTempOnly
                ? const ['Single Temperature']
                : [
                    'Single Temperature',
                    'All 3 Temperatures (+21, +52, $_functionColdTempLabel)',
                  ],
            onChanged: (v) {
              if (v != null) _onTemperatureModeChanged(v);
            },
          ),
        ),
        if (!_isThreeTemperatureMode)
          _buildFlexibleField(
            flex: 3,
            label: 'Selected Temperature',
            child: _buildDropdownField(
              value: _selectedTemperatureDisplay,
              items: ['+21 °C', '+52 °C', _functionColdTempLabel],
              onChanged: (v) {
                if (v != null) _onSelectedTemperatureChanged(v);
              },
            ),
          ),
        _buildQualityStatusField(flex: 3),
      ], lockSingleRow: true);
    }

    // Default row for Primer Sensitivity Test, Residual Stress Test, Extraction Force Test, etc.
    return _buildFormRow([
      _buildFlexibleField(
        key: _producedFieldKey,
        flex: 3,
        label: 'Quantity Tested (Rounds)',
        isRequired: true,
        child: _buildTextField(
          controller: _producedController,
          focusNode: _producedFocusNode,
          hint: '0',
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (int.tryParse(v) == null) return 'Must be integer';
            if (int.parse(v) < 0) return 'Cannot be negative';
            return null;
          },
        ),
      ),
      _buildSampleLocationField(flex: 3),
      if (_testHasTemperatureEvaluation) ...[
        _buildFlexibleField(
          flex: 4,
          label: 'Temperature Evaluation Mode',
          child: _buildDropdownField(
            value: _isCaliberSingleTempOnly || !_isThreeTemperatureMode
                ? 'Single Temperature'
                : 'All 3 Temperatures (+21, +52, ${_testName == 'Function Test' ? _functionColdTempLabel : '-54 °C'})',
            items: _isCaliberSingleTempOnly
                ? const ['Single Temperature']
                : [
                    'Single Temperature',
                    'All 3 Temperatures (+21, +52, ${_testName == 'Function Test' ? _functionColdTempLabel : '-54 °C'})',
                  ],
            onChanged: (v) {
              if (v != null) _onTemperatureModeChanged(v);
            },
          ),
        ),
        if (!_isThreeTemperatureMode)
          _buildFlexibleField(
            flex: 3,
            label: 'Selected Temperature',
            child: _buildDropdownField(
              value: _selectedTemperatureDisplay,
              items: const ['+21 °C', '+52 °C', '-54 °C'],
              onChanged: (v) {
                if (v != null) _onSelectedTemperatureChanged(v);
              },
            ),
          ),
      ],
      _buildQualityStatusField(flex: 3),
    ], lockSingleRow: true);
  }

  void _syncPrimerSensitivityMetrics(BallisticRecord match) {
    _primerLotController.text = match.primerLot.isNotEmpty ? match.primerLot : match.lotNo;
    _primerSupplier = match.primerSupplier;
    _primerInsertionDepthController.text = match.primerInsertionDepth;
    if (match.primerHbar.isNotEmpty) _primerHbarController.text = match.primerHbar;
    if (match.primerSD.isNotEmpty) _primerSDController.text = match.primerSD;
    if (match.primerAllFireH.isNotEmpty) {
      _primerHbarPlus5SController.text = match.primerAllFireH;
    } else {
      final h = double.tryParse(_primerHbarController.text.trim());
      final s = double.tryParse(_primerSDController.text.trim());
      if (h != null && s != null) {
        _primerHbarPlus5SController.text = (h + 5 * s).toStringAsFixed(2);
      }
    }
    if (match.primerNoFireH.isNotEmpty) {
      _primerHbarMinus2SController.text = match.primerNoFireH;
    } else {
      final h = double.tryParse(_primerHbarController.text.trim());
      final s = double.tryParse(_primerSDController.text.trim());
      if (h != null && s != null) {
        _primerHbarMinus2SController.text = (h - 2 * s).toStringAsFixed(2);
      }
    }
    if (match.produced > 0) _producedController.text = match.produced.toString();
    if (match.defects >= 0) _primerMisfiresCountController.text = match.defects.toString();
    if (match.status.isNotEmpty) _status = match.status;
    if (match.samplingLocation.isNotEmpty) _locationController.text = match.samplingLocation;
  }

  Widget _buildComponentAndPrimerFieldsCard() {
    final bool isComponent = widget.currentModule == 'Component Test';
    final bool isLotAcceptance = widget.currentModule == 'Lot Acceptance Test';

    if (isComponent && _testName == 'Primer Sensitivity Test') {
      final depthText = _primerInsertionDepthController.text.trim();
      final depthNum = double.tryParse(depthText);
      final bool isOutOfSpec = depthText.isNotEmpty && (depthNum == null || depthNum < 0.05 || depthNum > 0.20);
      final bool isInSpec = depthText.isNotEmpty && depthNum != null && depthNum >= 0.05 && depthNum <= 0.20;

      return Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF23364F),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isOutOfSpec ? const Color(0xFFEF4444) : const Color(0xFFEC4899).withOpacity(0.3),
            width: isOutOfSpec ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grain_rounded, color: Color(0xFFEC4899), size: 18.0),
                const SizedBox(width: 8.0),
                const Text(
                  'Component Primer Specifications',
                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isOutOfSpec)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 14.0),
                        SizedBox(width: 4.0),
                        Text(
                          'OUT OF SPECIFICATION (Limit: 0.05 - 0.20 mm)',
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else if (isInSpec)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 14.0),
                        SizedBox(width: 4.0),
                        Text(
                          'IN SPECIFICATION (0.05 - 0.20 mm)',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14.0),
            _buildFormRow([
              _buildFlexibleField(
                flex: 1,
                label: 'Primer Supplier',
                isRequired: true,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        value: _primerSuppliers.contains(_primerSupplier)
                            ? _primerSupplier
                            : (_primerSuppliers.isNotEmpty ? _primerSuppliers.first : ''),
                        items: _primerSuppliers,
                        onChanged: (v) {
                          if (v != null) setState(() => _primerSupplier = v);
                        },
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(width: 6.0),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.4)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFFEC4899)),
                          tooltip: 'Admin: Add Primer Supplier',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          onPressed: _showAddPrimerSupplierDialog,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildFlexibleField(
                flex: 1,
                label: 'Average Insertion Depth (mm) [0.05 - 0.20 mm]',
                isRequired: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _primerInsertionDepthController,
                      hint: 'e.g., 0.15 (0.05 - 0.20)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      onChanged: (_) {
                        setState(() {});
                        _scheduleAutoSave();
                      },
                    ),
                    if (isOutOfSpec)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          '⚠️ Out of specification (Allowed limit: 0.05 mm to 0.20 mm)',
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 11.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              _buildFlexibleField(
                flex: 1,
                label: 'Primer Lot Number',
                isRequired: true,
                child: _buildTextField(
                  controller: _primerLotController,
                  hint: 'Type primer lot number (e.g., PR-2026-01)',
                  onChanged: (_) => _scheduleAutoSave(),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    if (isComponent && _testName == 'Propellant Test') {
      return Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF23364F),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department_rounded, color: Color(0xFFF97316), size: 18.0),
                SizedBox(width: 8.0),
                Text(
                  'Component Propellant Specifications',
                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14.0),
            _buildFormRow([
              _buildFlexibleField(
                flex: 1,
                label: 'Propellant Supplier',
                isRequired: true,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        value: _propellantSuppliers.contains(_propellantSupplier)
                            ? _propellantSupplier
                            : (_propellantSuppliers.isNotEmpty ? _propellantSuppliers.first : ''),
                        items: _propellantSuppliers,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _propellantSupplier = v;
                              final codes = _currentSupplierPropellantCodes;
                              if (codes.isNotEmpty && codes.first != 'Other') {
                                _propellantCodeController.text = codes.first;
                              }
                            });
                            _scheduleAutoSave();
                          }
                        },
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(width: 6.0),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFFF97316)),
                          tooltip: 'Admin: Add Propellant Supplier',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          onPressed: _showAddPropellantSupplierDialog,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildFlexibleField(
                flex: 1,
                label: 'Powder Code',
                isRequired: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropdownField(
                      value: _currentSupplierPropellantCodes.contains(_propellantCodeController.text.trim())
                          ? _propellantCodeController.text.trim()
                          : (_currentSupplierPropellantCodes.isNotEmpty ? _currentSupplierPropellantCodes.first : 'Other'),
                      items: _currentSupplierPropellantCodes,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            if (v != 'Other') {
                              _propellantCodeController.text = v;
                            }
                          });
                          _scheduleAutoSave();
                        }
                      },
                    ),
                    if (_propellantCodeController.text.trim().isEmpty || !_currentSupplierPropellantCodes.contains(_propellantCodeController.text.trim()) || _propellantCodeController.text.trim() == 'Other') ...[
                      const SizedBox(height: 6.0),
                      _buildTextField(
                        controller: _propellantCodeController,
                        hint: 'Type custom powder code',
                        onChanged: (_) => _scheduleAutoSave(),
                      ),
                    ],
                  ],
                ),
              ),
              _buildFlexibleField(
                flex: 1,
                label: 'Powder Charge in Gram (number only)',
                isRequired: true,
                child: _buildTextField(
                  controller: _propellantChargeController,
                  hint: 'e.g., 1.62',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: (_) => _scheduleAutoSave(),
                ),
              ),
              _buildFlexibleField(
                flex: 1,
                label: 'Propellant Lot Number (number only)',
                isRequired: true,
                child: _buildTextField(
                  controller: _propellantLotController,
                  hint: 'e.g., 90124',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _scheduleAutoSave(),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    if (isLotAcceptance && _testName == 'Primer Sensitivity Test') {
      final matchingRecords = widget.componentPrimerRecords.where((r) => r.caliber == _caliber).toList();
      final lotOptions = matchingRecords
          .map((r) => r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber)
          .where((l) => l.isNotEmpty)
          .toSet()
          .toList();

      // Auto-synchronize first available lot if not yet selected
      if (lotOptions.isNotEmpty && (_selectedComponentPrimerLot == null || _selectedComponentPrimerLot!.isEmpty || !lotOptions.contains(_selectedComponentPrimerLot))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && lotOptions.isNotEmpty) {
            final defaultLot = lotOptions.first;
            setState(() {
              _selectedComponentPrimerLot = defaultLot;
              final match = matchingRecords.firstWhere(
                (r) => (r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber) == defaultLot,
                orElse: () => matchingRecords.first,
              );
              _syncPrimerSensitivityMetrics(match);
            });
          }
        });
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF23364F),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.link_rounded, color: Color(0xFF38BDF8), size: 18.0),
                SizedBox(width: 8.0),
                Text(
                  'Associated Component Primer Lot Selection',
                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            const Text(
              'Select the verified Primer Lot from the Component module. All sensitivity metrics (H̄, S, H̄+5S, H̄-2S, Drop Weight, Quantity, Misfires, Supplier, and Depth) synchronize automatically and are locked for Lot Acceptance.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
            ),
            const SizedBox(height: 14.0),
            if (lotOptions.isEmpty)
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No submitted Primer lots found in Component Test for caliber "$_caliber". You can submit one in the Component Test module or enter primer lot details manually.',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12.0),
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildFormRow([
                _buildFlexibleField(
                  flex: 1,
                  label: 'Submitted Primer Lot (from Component Module)',
                  isRequired: true,
                  child: _buildDropdownField(
                    value: lotOptions.contains(_selectedComponentPrimerLot)
                        ? _selectedComponentPrimerLot!
                        : lotOptions.first,
                    items: lotOptions,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedComponentPrimerLot = v;
                          final match = matchingRecords.firstWhere(
                            (r) => (r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber) == v,
                            orElse: () => matchingRecords.first,
                          );
                          _syncPrimerSensitivityMetrics(match);
                        });
                      }
                    },
                  ),
                ),
              ]),
            const SizedBox(height: 12.0),
            _buildFormRow([
              _buildFlexibleField(
                flex: 1,
                label: 'Primer Lot (Synchronized & Read-Only)',
                child: _buildTextField(
                  controller: _primerLotController,
                  readOnly: true,
                  hint: 'Selected Primer Lot',
                ),
              ),
              _buildFlexibleField(
                flex: 1,
                label: 'Primer Supplier (Auto-populated)',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: const Color(0xFF1E3A8A)),
                  ),
                  child: Text(
                    _primerSupplier.isNotEmpty ? _primerSupplier : 'Not Specified',
                    style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _buildFlexibleField(
                flex: 1,
                label: 'Avg. Insertion Depth (mm) (Auto-populated)',
                child: _buildTextField(
                  controller: _primerInsertionDepthController,
                  readOnly: true,
                  hint: '0.00 mm',
                ),
              ),
            ]),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAdminInstructionsCard() {
    String specText = '';
    String instructionsText = '';
    
    if (_testName == 'Waterproof Test') {
      final wpRules = _getWaterproofRulesForCaliber();
      final int retestLimit = wpRules['retest_limit'] ?? 4;
      final int rejectLimit = wpRules['reject_limit'] ?? 7;
      
      specText = 'Caliber: $_caliber\n'
          'Limits: Retest if Leaks >= $retestLimit, Reject if Leaks >= $rejectLimit.';
      instructionsText = wpRules['instructions'] ?? 'Follow waterproof leakage inspection protocol. Inspect primer and mouth sealings.';
    } else if (_testName == 'Residual Stress Test') {
      final rsRules = _getResidualStressRulesForCaliber();
      final int retestLimit = rsRules['retest_limit'] ?? 1;
      final int rejectLimit = rsRules['reject_limit'] ?? 3;
      
      specText = 'Caliber: $_caliber\n'
          'Splits/Cracks limits: Retest if total splits >= $retestLimit, Reject if total splits >= $rejectLimit.';
      instructionsText = rsRules['instructions'] ?? 'Examine splits on Neck, Shoulder, Body, and Head. No pressure applied.';
    } else if (_testName == 'Extraction Force Test') {
      final extRules = _getExtractionRulesForCaliber();
      final double limit = (extRules['min_force'] ?? 200.0).toDouble();
      specText = 'Caliber: $_caliber\n'
          'Minimum Extraction Force: ${limit.toStringAsFixed(1)} N.';
      instructionsText = extRules['instructions'] ?? 'Perform pull-out test of bullet and record peak force.';
    } else if (_testName == 'Accuracy Test') {
      final accRules = _getAccuracyRulesForCaliber();
      final double maxMeanRadius = (accRules['max_mean_radius'] ?? 50.0).toDouble();
      final double maxSD = (accRules['max_sd'] ?? 200.0).toDouble();
      final double condSD = (accRules['cond_sd'] ?? 170.0).toDouble();
      final double velMin = (accRules['vel_min'] ?? 700.0).toDouble();
      final double velMax = (accRules['vel_max'] ?? 900.0).toDouble();
      
      specText = 'Caliber: $_caliber\n'
          'Velocity Range: ${velMin.toStringAsFixed(1)} - ${velMax.toStringAsFixed(1)} m/s\n'
          'Max Mean Radius: ${maxMeanRadius.toStringAsFixed(1)} mm\n'
          'Max SD (X/Y): ${maxSD.toStringAsFixed(1)} mm, Conditional SD threshold: ${condSD.toStringAsFixed(1)} mm';
      instructionsText = accRules['instructions'] ?? 'Assess group sizing at target distance and mean velocity bounds.';
    } else if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
      final activeTemp = _epvatPressureType == 'Overall' 
          ? ['+21', '+52', '-54'][_activeEpvatTempTabIndex]
          : _cartridgeTempController.text.trim();
      
      final activeEpv = _getEpvatRulesForCaliber(activeTemp);
      final double velMin = (activeEpv['vel_min'] ?? 900.0).toDouble();
      final double velMax = (activeEpv['vel_max'] ?? 930.0).toDouble();
      final double p1Max = (activeEpv['p1_max'] ?? 3800.0).toDouble();
      final double p2Min = (activeEpv['p2_min'] ?? 200.0).toDouble();
      
      specText = 'Caliber: $_caliber | Temperature: $activeTemp °C\n'
          '- Velocity: ${velMin.toStringAsFixed(1)} - ${velMax.toStringAsFixed(1)} m/s\n'
          '- P1 Chamber Max: ${p1Max.toStringAsFixed(1)} bar\n'
          '- P2 Port Min: ${p2Min.toStringAsFixed(1)} bar';
      instructionsText = _getEpvatInstructionsForCaliber();
    } else if (_testName == 'Primer Sensitivity Test') {
      final prRules = _getPrimerRulesForCaliber();
      final double dropWeight = ((prRules['drop_weight'] ?? 55.0) as num).toDouble();
      final double hbarMin = ((prRules['hbar_min'] ?? 250.0) as num).toDouble();
      final double hbarMax = ((prRules['hbar_max'] ?? 450.0) as num).toDouble();
      final double allFireLimit = ((prRules['all_fire_h'] ?? 500.0) as num).toDouble();
      final double noFireLimit = ((prRules['no_fire_h'] ?? 150.0) as num).toDouble();
      final double maxSD = ((prRules['max_sd'] ?? 60.0) as num).toDouble();

      specText = 'Caliber: $_caliber | Drop Ball Weight: ${dropWeight.toStringAsFixed(1)} g\n'
          '- Mean Height H̄ Range: ${hbarMin.toStringAsFixed(1)} - ${hbarMax.toStringAsFixed(1)} mm\n'
          '- All Fire (H̄ + 5S) Max Limit: ${allFireLimit.toStringAsFixed(1)} mm\n'
          '- No Fire (H̄ - 2S) Min Limit: ${noFireLimit.toStringAsFixed(1)} mm\n'
          '- Max Allowable SD (S): ${maxSD.toStringAsFixed(1)} mm';
      instructionsText = prRules['instructions'] ?? 'Perform drop ball sensitivity test. Record drop height (mm) and Fire/Misfire outcome for each round.';
    } else {
      return const SizedBox();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 18.0),
              SizedBox(width: 8.0),
              Text(
                'Quality Specifications & Admin Instructions',
                style: TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            'Requirements:\n$specText',
            style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, height: 1.4),
          ),
          if (instructionsText.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            Text(
              'Remarks/Instructions:\n$instructionsText',
              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontStyle: FontStyle.italic, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class FormRowField extends StatelessWidget {
  final int flex;
  final String label;
  final Widget child;
  final bool isRequired;

  const FormRowField({
    Key? key,
    required this.flex,
    required this.label,
    required this.child,
    this.isRequired = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          style: const TextStyle(
            color: Color(0xFF8E96A3),
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 8.0),
        child,
      ],
    );
  }
}

class FormulaEvaluator {
  final Map<String, double> variables;
  FormulaEvaluator(this.variables);

  double evaluate(String expression) {
    // Basic cleanup
    String expr = expression.replaceAll(' ', '').toLowerCase();
    int index = 0;

    // Declare as late so they can reference each other
    late double Function() parseExpression;
    late double Function() parseTerm;
    late double Function() parseFactor;

    parseFactor = () {
      if (index >= expr.length) return 0.0;
      if (expr[index] == '(') {
        index++; // consume '('
        double val = parseExpression();
        if (index < expr.length && expr[index] == ')') {
          index++; // consume ')'
        }
        return val;
      }

      // Check for numeric values or variables
      StringBuffer sb = StringBuffer();
      if (expr[index] == '-' || expr[index] == '+') {
        sb.write(expr[index]);
        index++;
      }
      while (index < expr.length && (RegExp(r'[a-z0-9_\.]').hasMatch(expr[index]))) {
        sb.write(expr[index]);
        index++;
      }
      String token = sb.toString();
      if (token.isEmpty) return 0.0;
      
      final numVal = double.tryParse(token);
      if (numVal != null) {
        return numVal;
      }
      
      return variables[token] ?? 0.0;
    };

    parseTerm = () {
      double val = parseFactor();
      while (index < expr.length) {
        if (expr[index] == '*') {
          index++;
          val *= parseFactor();
        } else if (expr[index] == '/') {
          index++;
          double denom = parseFactor();
          val = denom != 0 ? val / denom : 0.0;
        } else {
          break;
        }
      }
      return val;
    };

    parseExpression = () {
      double val = parseTerm();
      while (index < expr.length) {
        if (expr[index] == '+') {
          index++;
          val += parseTerm();
        } else if (expr[index] == '-') {
          index++;
          val -= parseTerm();
        } else {
          break;
        }
      }
      return val;
    };

    try {
      return parseExpression();
    } catch (_) {
      return 0.0;
    }
  }
}

