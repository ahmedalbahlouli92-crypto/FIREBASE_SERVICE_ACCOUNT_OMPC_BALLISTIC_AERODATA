import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/ballistic_record.dart';
import '../services/attachment_helper.dart';
import '../services/epvat_formula_helper.dart';
import '../services/storage_service.dart';
import '../services/report_generator.dart';
import '../services/report_helper.dart';
import '../services/test_result_extractor.dart';

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

/// Formatter allowing signed decimal numbers (e.g. -12.5, -0.8, 5.2, -, etc.)
class SignedDecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text
        .replaceAll('\u2212', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2011', '-')
        .replaceAll('\u00AD', '-');
    if (text.isEmpty || text == '-') {
      return newValue.copyWith(text: text);
    }
    final regExp = RegExp(r'^-?\d*\.?\d*$');
    if (regExp.hasMatch(text)) {
      return newValue.copyWith(text: text);
    }
    return oldValue;
  }
}

/// Model representing a single row in the Primer Sensitivity drop table (H, F, M, PI)
class _PrimerDropTableRow {
  final TextEditingController h;
  final TextEditingController f;
  final TextEditingController m;
  final TextEditingController pi;

  _PrimerDropTableRow({
    required String hVal,
    required String fVal,
    required String mVal,
    required String piVal,
  })  : h = TextEditingController(text: hVal),
        f = TextEditingController(text: fVal),
        m = TextEditingController(text: mVal),
        pi = TextEditingController(text: piVal);

  void dispose() {
    h.dispose();
    f.dispose();
    m.dispose();
    pi.dispose();
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
  final String base64Logo;

  const EntryTab({
    Key? key,
    required this.currentModule,
    required this.onSubmit,
    this.loggedInUser = '',
    this.records = const [],
    this.componentPrimerRecords = const [],
    this.componentPropellantRecords = const [],
    this.userRole = 'Operator',
    this.base64Logo = '',
    required this.initialCaliber,
    required this.initialTestName,
    required this.onCaliberChanged,
    required this.onTestNameChanged,
    required this.adminRules,
    this.onOpenEpvatRulesInControl,
  }) : super(key: key);

  final VoidCallback? onOpenEpvatRulesInControl;

  static const List<String> defaultCalibers = [
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

  static List<String> calibers = List<String>.from(defaultCalibers);

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
  bool _isInstructionsExpanded = false;

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
  final _technicianController = TextEditingController();
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
  final _propellantCodeController = TextEditingController();
  String _primerSupplier = '';
  String _propellantSupplier = '';
  late final _epvatAdminPropellantSupplierController = TextEditingController();
  late final _epvatAdminPrimerSupplierController = TextEditingController();
  String? _selectedComponentPrimerLot;
  String? _selectedComponentPropellantLot;
  List<String> _registeredTechnicians = ['Ahmed Al Bahlouli', 'Said Al Siyabi'];
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
  final List<String> _localAddedBulletSuppliers = [];
  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  final _bulletSupplierController = TextEditingController();
  final _bulletGrainSizeController = TextEditingController();
  String _sampleLoadingMethod = 'Manually Loaded';
  late final _sampleReceivedDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  String _bulletSampleLocation = 'QC';
  String _epvatSingleSubMode = 'Stats Only';

  bool get _isCaliber9mm => _caliber.toLowerCase().contains('9mm') || _caliber.toLowerCase().contains('9x19');
  bool _isSameCaliberFamily(String calA, String calB) {
    final a = calA.toLowerCase().replaceAll(' ', '').replaceAll(',', '.').replaceAll('mm', '');
    final b = calB.toLowerCase().replaceAll(' ', '').replaceAll(',', '.').replaceAll('mm', '');
    if (a.isEmpty || b.isEmpty) return true;
    if (a == b || a.contains(b) || b.contains(a)) return true;
    // 5.56 and .223 are the same
    final is556A = a.contains('5.56') || a.contains('223') || a.contains('ss109') || a.contains('m193') || a.contains('m200');
    final is556B = b.contains('5.56') || b.contains('223') || b.contains('ss109') || b.contains('m193') || b.contains('m200');
    if (is556A && is556B) return true;
    // 7.62 and .308 are the same
    final is762A = a.contains('7.62') || a.contains('308') || a.contains('m80');
    final is762B = b.contains('7.62') || b.contains('308') || b.contains('m80');
    if (is762A && is762B) return true;
    // 9mm and 9x19 are the same
    final is9mmA = a.contains('9x19') || a.contains('9') || a.contains('luger') || a.contains('para');
    final is9mmB = b.contains('9x19') || b.contains('9') || b.contains('luger') || b.contains('para');
    if (is9mmA && is9mmB) return true;
    return false;
  }
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

  // Collapsible reference diagrams to prevent vertical overflow
  bool _showResidualDiagram = false;
  bool _showFunctionDiagram = false;

  // Sample Location state
  final List<String> _defaultSampleLocations = [
    'After Packing machine',
    'Priming machine',
    'PC530',
    'PB31/14',
    'PD26',
    'After visual inspection',
    'After link machine',
  ];
  final List<String> _customSampleLocations = [];
  List<String> get _allSampleLocations {
    final adminLocs = widget.adminRules['sample_locations'];
    if (adminLocs is List && adminLocs.isNotEmpty) {
      final Set<String> locs = {};
      for (final l in adminLocs) {
        if (l != null && l.toString().trim().isNotEmpty) {
          locs.add(l.toString().trim());
        }
      }
      for (final cl in _customSampleLocations) {
        if (cl.trim().isNotEmpty) locs.add(cl.trim());
      }
      return locs.toList();
    }
    final Set<String> locs = {
      ..._defaultSampleLocations,
    };
    for (final cl in _customSampleLocations) {
      if (cl.trim().isNotEmpty) locs.add(cl.trim());
    }
    return locs.toList();
  }

  String _getDefaultSamplingLocation({required String module, required String test}) {
    if (module == 'Lot Acceptance Test') {
      if (test == 'Primer Sensitivity Test') {
        return 'Priming machine';
      }
      return 'After Packing machine';
    } else if (module == 'Daily Test') {
      if (test == 'Accuracy Test') {
        return 'PB31/14';
      }
      // Waterproof, Extraction, EPVAT, Function, terminal, cyclic rate and Residual stress
      return 'PC530';
    }
    // Component test or other
    if (test == 'Primer Sensitivity Test') {
      return 'Priming machine';
    }
    return 'After Packing machine';
  }

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
  String _functionSelectedCategory = '';
  String _functionSelectedModel = '';
  String _functionSelectedSerial = '';
  final _functionCustomModelController = TextEditingController();
  final _functionCustomSerialController = TextEditingController();

  String _shift = 'Morning';
  final Map<int, List<String>> _customLevelDefects = {};
  late String _caliber;
  late String _testName;
  String _status = 'Approved';
  bool _isManualStatusSelected = false;
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

  // t4 state controllers for EPVAT
  final _t4MeanController = TextEditingController();
  final _t4MaxController = TextEditingController();
  final _t4MinController = TextEditingController();
  final _t4RangeController = TextEditingController();
  final _t4SDController = TextEditingController();
  final List<TextEditingController> _t4RoundsControllers = [];
  final Map<String, List<TextEditingController>> _overallEpvatT4RoundsControllers = {};

  String get _formattedVelocityDistance {
    final raw = _distanceController.text.trim();
    final d = double.tryParse(raw);
    if (d != null) return d.toStringAsFixed(2);
    return raw.isNotEmpty ? raw : '24.00';
  }

  // Primer Sensitivity Test state
  final _primerDropWeightController = TextEditingController(text: '55');
  final List<TextEditingController> _primerDropHeightControllers = [];
  final List<String> _primerFireResults = []; // 'Fire' or 'Misfire'
  final _primerHbarController = TextEditingController();
  final _primerSDController = TextEditingController();
  final _primerHbarPlus5SController = TextEditingController();
  final _primerHbarMinus2SController = TextEditingController();
  final _primerMisfiresCountController = TextEditingController(text: '0');
  final _primerAlpha3Controller = TextEditingController();
  final _primerEmaxController = TextEditingController();
  final _primerEminController = TextEditingController();
  final List<_PrimerDropTableRow> _primerDropTableRows = [];

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
  final Map<String, int> _functionWeaponRounds = {};
  final _currentWeaponRoundsController = TextEditingController();
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

    Map<String, dynamic>? match;
    if (calibersMap.containsKey(_caliber)) {
      match = Map<String, dynamic>.from(calibersMap[_caliber]);
    } else {
      final cLower = _caliber.toLowerCase();
      for (final entry in calibersMap.entries) {
        final k = entry.key.toString().toLowerCase();
        if ((cLower.contains('5.56') || cLower.contains('223')) && (k.contains('5.56') || k.contains('223'))) {
          match = Map<String, dynamic>.from(entry.value);
          break;
        } else if ((cLower.contains('7.62') || cLower.contains('308')) && (k.contains('7.62') || k.contains('308'))) {
          match = Map<String, dynamic>.from(entry.value);
          break;
        } else if ((cLower.contains('9mm') || cLower.contains('9x19')) && (k.contains('9mm') || k.contains('9x19'))) {
          match = Map<String, dynamic>.from(entry.value);
          break;
        }
      }
    }
    final calRules = match ?? Map<String, dynamic>.from(calibersMap['default'] ?? func);

    const defL1 = 'Split case at points K, L or M, Bullet in Bore, Blown primer, Primer puncture, Misfire, Hangfire, Complete case rupture, Primer through, Primer drop, Loose primer, Pierced primer, No fire, Primer protrusion';
    const defL2 = 'Hard Extraction, Fail to eject, Fail to Extract, Fail to cock, Split case at points A, B, C, D, E, F, G, H, I or J, Perforated primer, Bolt over case';
    const defL3 = 'Double Feed, Fail to fire, Fail to feed, Fail to chamber, Fail to unlock, Light strike';
    const defL4 = 'Dented case, Scratched case, Damaged bullet, Damaged tip, Cosmetic blemish';

    final l1 = Map<String, dynamic>.from(calRules['level1'] ?? func['level1'] ?? {});
    if ((l1['description'] ?? '').toString().trim().isEmpty) l1['description'] = defL1;
    final l2 = Map<String, dynamic>.from(calRules['level2'] ?? func['level2'] ?? {});
    if ((l2['description'] ?? '').toString().trim().isEmpty) l2['description'] = defL2;
    final l3 = Map<String, dynamic>.from(calRules['level3'] ?? func['level3'] ?? {});
    if ((l3['description'] ?? '').toString().trim().isEmpty) l3['description'] = defL3;
    final l4 = Map<String, dynamic>.from(calRules['level4'] ?? func['level4'] ?? {});
    if ((l4['description'] ?? '').toString().trim().isEmpty) l4['description'] = defL4;

    return {
      'schema_type': calRules['schema_type'] ?? 'levels',
      'categories': calRules['categories'] ?? {},
      'level1': l1,
      'level2': l2,
      'level3': l3,
      'level4': l4,
    };
  }

  List<String> _getDefectItemsForLevel(int level) {
    final rules = _currentFunctionCaliberRules;
    final lvlMap = rules['level$level'] ?? {};
    final desc = (lvlMap['description'] ?? '').toString();
    final items = desc.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Also load defects configured by Admin in adminRules
    final adminCustom = widget.adminRules['function_custom_defects'];
    if (adminCustom is Map) {
      final list = adminCustom['level$level'] ?? adminCustom['$level'];
      if (list is List) {
        for (final it in list) {
          final s = it.toString().trim();
          if (s.isNotEmpty && !items.contains(s)) items.add(s);
        }
      }
    }

    final customList = _customLevelDefects[level] ?? [];
    for (final c in customList) {
      if (!items.contains(c)) items.add(c);
    }
    return items;
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

  void _promptAddCustomDefect(int level, TextEditingController controller, String tempKey) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access restricted: Only Admin can add new defect types.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF38BDF8)),
        ),
        title: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 8),
            Text('Admin: Add Defect Type (Level $level)', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the defect type name. Once added by Admin, users will select it directly from the list:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Broken extractor pin, Jammed casing',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop();
                setState(() {
                  _customLevelDefects.putIfAbsent(level, () => []).add(name);
                  _incrementDefect(name, tempKey, level, controller);
                });

                // Persist new defect type to adminRules
                try {
                  final updatedRules = Map<String, dynamic>.from(widget.adminRules);
                  final customMap = Map<String, dynamic>.from(updatedRules['function_custom_defects'] as Map? ?? {});
                  final lvlList = List<String>.from((customMap['level$level'] as List? ?? []).map((e) => e.toString()));
                  if (!lvlList.contains(name)) {
                    lvlList.add(name);
                    customMap['level$level'] = lvlList;
                    updatedRules['function_custom_defects'] = customMap;
                    await _storageService.saveRules(updatedRules);
                  }
                } catch (_) {}
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
            child: const Text('Add & Select', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showZoomDiagramDialog(String assetPath, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 800,
          height: 650,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.zoom_in, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('Image unavailable'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _functionDefectDetails {
    final entries = _funcDefectItemCounts.entries.where((e) => e.value > 0).map((e) => '${e.key} (${e.value})').toList();
    return entries.join(', ');
  }

  void _updateCategoryBasedDefects() {
    int sum = 0;
    _funcDefectItemCounts.forEach((k, v) => sum += v);
    _defectsController.text = '$sum';
  }

  String _calculateFunctionTestStatus({required int l1, required int l2, required int l3, required int l4}) {
    final rules = _currentFunctionCaliberRules;
    final schemaType = rules['schema_type'] ?? 'levels';

    if (schemaType == 'categories') {
      final categories = Map<String, dynamic>.from(rules['categories'] ?? {});
      bool hasReject = false;
      bool hasRetest = false;

      categories.forEach((catName, catData) {
        if (catData is Map) {
          final retestLim = (catData['retest_limit'] as num?)?.toInt() ?? 0;
          final rejectLim = (catData['reject_limit'] as num?)?.toInt() ?? 1;
          final items = (catData['items'] as List?)?.map((e) => e.toString()).toList() ??
              catData['description'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          int catCount = 0;
          for (var it in items) {
            _funcDefectItemCounts.forEach((k, v) {
              final rawName = k.contains(':') ? k.split(':')[1] : k;
              if (rawName == it) {
                catCount += v;
              }
            });
          }
          if (rejectLim > 0 && catCount >= rejectLim) hasReject = true;
          if (retestLim > 0 && catCount >= retestLim) hasRetest = true;
        }
      });
      if (hasReject) return 'Rejected';
      if (hasRetest) return 'Retest';
      return 'Approved';
    }

    final int l1Retest = rules['level1']?['retest_limit'] ?? 0;
    final int l1Reject = rules['level1']?['reject_limit'] ?? 1;
    final int l2Retest = rules['level2']?['retest_limit'] ?? 0;
    final int l2Reject = rules['level2']?['reject_limit'] ?? 1;
    final int l3Retest = rules['level3']?['retest_limit'] ?? 2;
    final int l3Reject = rules['level3']?['reject_limit'] ?? 3;
    final int l4Retest = rules['level4']?['retest_limit'] ?? 4;
    final int l4Reject = rules['level4']?['reject_limit'] ?? 6;

    if (l1 >= l1Reject || l2 >= l2Reject || l3 >= l3Reject || l4 >= l4Reject) return 'Rejected';
    if ((l1Retest > 0 && l1 >= l1Retest) || (l2Retest > 0 && l2 >= l2Retest) || (l3Retest > 0 && l3 >= l3Retest) || (l4Retest > 0 && l4 >= l4Retest)) {
      return 'Retest';
    }

    final int l1Max = rules['level1']?['max_allowed'] ?? 0;
    final int l2Max = rules['level2']?['max_allowed'] ?? 0;
    final int l3Max = rules['level3']?['max_allowed'] ?? 2;
    final int l4Max = rules['level4']?['max_allowed'] ?? 5;
    if (l1 > l1Max || l2 > l2Max) return 'Rejected';
    if (l3 > l3Max || l4 > l4Max) return 'Retest';
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

  // Unified GP6 Transducers pool (admin registers all in one field, user selects GP6 (1) and GP6 (2))
  List<String> get _allGp6Transducers {
    final Set<String> result = {};
    final listUnified = widget.adminRules['gp6_transducers'];
    if (listUnified is List) {
      for (final e in listUnified) {
        final s = e.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    for (final key in ['gp6_serials', 'gp1_transducers']) {
      final list = widget.adminRules[key];
      if (list is List) {
        for (final e in list) {
          final s = e.toString().trim();
          if (s.isNotEmpty) result.add(s);
        }
      }
    }
    final gp = widget.adminRules['gp_transducers'];
    if (gp is Map) {
      for (final sub in ['gp1', 'gp2']) {
        final list = gp[sub];
        if (list is List) {
          for (final e in list) {
            final s = e.toString().trim();
            if (s.isNotEmpty) result.add(s);
          }
        }
      }
    }
    if (result.isNotEmpty) return result.toList();
    return ['GP6-001 (PCB 119B)', 'GP6-002 (PCB 119B)', 'GP6-003 (PCB 119B)'];
  }

  List<String> get _gp1Transducers => _allGp6Transducers;

  List<String> get _gp2Transducers => _allGp6Transducers;

  // Equipment lists & Round counting
  List<String> get _accuracyBarrels {
    final Set<String> result = {};
    final byCal = widget.adminRules['accuracy_barrels_by_caliber'];
    if (byCal is Map && byCal.containsKey(_caliber)) {
      final list = byCal[_caliber];
      if (list is List && list.isNotEmpty) {
        for (final e in list) {
          final s = e.toString().trim();
          if (s.isNotEmpty) result.add(s);
        }
        if (result.isNotEmpty) return result.toList();
      }
    }
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
    final byCal = widget.adminRules['epvat_barrels_by_caliber'];
    if (byCal is Map && byCal.containsKey(_caliber)) {
      final list = byCal[_caliber];
      if (list is List && list.isNotEmpty) {
        for (final e in list) {
          final s = e.toString().trim();
          if (s.isNotEmpty) result.add(s);
        }
        if (result.isNotEmpty) return result.toList();
      }
    }
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

  List<String> get _gp6Serials => _allGp6Transducers;


  List<String> get _primerSuppliers {
    final list = widget.adminRules['primer_suppliers'];
    final base = <String>[];
    if (list is List && list.isNotEmpty) {
      base.addAll(list.map((e) => e.toString()));
    } else {
      base.addAll(['CBC', 'UNIS "GINEX"', 'S&B', 'MD']);
    }
    for (final s in _localAddedPrimerSuppliers) {
      if (!base.contains(s)) base.add(s);
    }
    // Strict normalization: remove UNIS GINEX / UNIS "GINIX" and ensure UNIS "GINEX" is present
    final normalized = <String>[];
    for (final s in base) {
      final lower = s.trim().toLowerCase();
      if (lower == 'unis ginex' || lower == 'unis "ginix"' || lower == 'unis ginix') {
        if (!normalized.contains('UNIS "GINEX"')) normalized.add('UNIS "GINEX"');
      } else if (lower.contains('ginex')) {
        if (!normalized.contains('UNIS "GINEX"')) normalized.add('UNIS "GINEX"');
      } else {
        if (!normalized.contains(s.trim())) normalized.add(s.trim());
      }
    }
    if (!normalized.contains('UNIS "GINEX"')) normalized.add('UNIS "GINEX"');
    return normalized;
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

  List<String> get _bulletSuppliers {
    final list = widget.adminRules['bullet_suppliers'];
    final base = <String>[];
    if (list is List && list.isNotEmpty) {
      base.addAll(list.map((e) => e.toString()));
    } else {
      base.addAll(['Sierra', 'Hornady', 'CBC', 'OMPC', 'Nosler', 'Lapua']);
    }
    for (final s in _localAddedBulletSuppliers) {
      if (!base.contains(s)) base.add(s);
    }
    final cur = _bulletSupplierController.text.trim();
    if (cur.isNotEmpty && !base.contains(cur)) {
      base.add(cur);
    }
    return base;
  }

  void _showAddBulletSupplierDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Text('Add Bullet Supplier', style: TextStyle(color: Colors.white, fontSize: 16.0)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isEmpty) return;
              setState(() {
                if (!_localAddedBulletSuppliers.contains(val)) {
                  _localAddedBulletSuppliers.add(val);
                }
                final currentList = List<String>.from(_bulletSuppliers);
                if (!currentList.contains(val)) currentList.add(val);
                widget.adminRules['bullet_suppliers'] = currentList;
                _bulletSupplierController.text = val;
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

  void _showAddCustomPrimerLotDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C3351),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Text('Enter Custom Primer Lot', style: TextStyle(color: Colors.white, fontSize: 16.0)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Primer Lot Number',
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isEmpty) return;
              setState(() {
                _primerLotController.text = val;
                _selectedComponentPrimerLot = val;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Set Lot', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<String> _getPrimerSuppliersForCaliber(String cal) {
    final List<String> list = [];
    for (final s in _primerSuppliers) {
      if (!list.contains(s)) list.add(s);
    }
    for (final r in widget.componentPrimerRecords) {
      if (cal.isEmpty || _isSameCaliberFamily(r.caliber, cal)) {
        final s = r.primerSupplier.trim();
        if (s.isNotEmpty && !list.contains(s)) list.add(s);
      }
    }
    for (final r in widget.records) {
      if (cal.isEmpty || _isSameCaliberFamily(r.caliber, cal)) {
        final s = r.primerSupplier.trim();
        if (s.isNotEmpty && !list.contains(s)) list.add(s);
      }
    }
    return list;
  }

  List<String> _getPrimerLotsForCaliberAndSupplier(String cal, String supplier) {
    final Set<String> lots = {};
    for (final r in widget.componentPrimerRecords) {
      final matchCal = cal.isEmpty || _isSameCaliberFamily(r.caliber, cal);
      final matchSup = supplier.isEmpty || r.primerSupplier.trim().toLowerCase() == supplier.trim().toLowerCase();
      if (matchCal && matchSup) {
        final l = r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber;
        if (l.trim().isNotEmpty) lots.add(l.trim());
      }
    }
    for (final r in widget.records) {
      final matchCal = cal.isEmpty || _isSameCaliberFamily(r.caliber, cal);
      final matchSup = supplier.isEmpty || r.primerSupplier.trim().toLowerCase() == supplier.trim().toLowerCase();
      if (matchCal && matchSup) {
        final l = r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber;
        if (l.trim().isNotEmpty) lots.add(l.trim());
      }
    }
    if (_primerLotController.text.trim().isNotEmpty) {
      lots.add(_primerLotController.text.trim());
    }
    return lots.toList()..sort();
  }

  Future<void> _loadTechnicians() async {
    try {
      final ops = await _storageService.loadOperators();
      final techs = ops
          .where((o) => (o['role'] ?? '').toLowerCase() == 'technician' || (o['name'] ?? '').toLowerCase().contains('technician'))
          .map((o) => (o['name'] ?? o['email'] ?? '').trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      // Strictly maintain registered technicians: Ahmed Al Bahlouli & Said Al Siyabi
      _registeredTechnicians = ['Ahmed Al Bahlouli', 'Said Al Siyabi'];
    } catch (_) {}
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

  bool _weaponMatchesCaliber(Map<String, String> w, String currentCaliber) {
    final c = currentCaliber.toLowerCase().trim();
    if (c.isEmpty) return true;

    final wCal = (w['caliber'] ?? '').trim().toLowerCase();
    final model = (w['model'] ?? '').trim().toLowerCase();
    final raw = (w['raw'] ?? '').trim().toLowerCase();
    final type = (w['type'] ?? '').trim().toLowerCase();
    final combined = '$wCal $model $raw $type';

    // 1. Explicit weapon caliber matching
    if (wCal.isNotEmpty) {
      if (c.contains('5.56') || c.contains('.223')) {
        return wCal.contains('5.56') || wCal.contains('.223');
      }
      if (c.contains('7.62') || c.contains('.308')) {
        return wCal.contains('7.62') || wCal.contains('.308');
      }
      if (c.contains('9mm') || c.contains('9x19')) {
        return wCal.contains('9mm') || wCal.contains('9x19') || wCal.contains('9 mm') || wCal.contains('luger') || wCal.contains('para');
      }
      if (c.contains('12.7') || c.contains('.50')) {
        return wCal.contains('12.7') || wCal.contains('.50');
      }
      return wCal == c;
    }

    // 2. Strict model/name deduction when caliber property is unassigned
    if (c.contains('5.56') || c.contains('.223')) {
      final is556 = combined.contains('5.56') ||
          combined.contains('223') ||
          combined.contains('aug') ||
          combined.contains('steyr') ||
          combined.contains('m16') ||
          combined.contains('m4') ||
          combined.contains('scar-l') ||
          combined.contains('m249') ||
          combined.contains('saw') ||
          combined.contains('ar-15') ||
          combined.contains('ar15') ||
          combined.contains('hk416') ||
          combined.contains('g36') ||
          (combined.contains('minimi') && !combined.contains('7.62'));
      final is762or9 = combined.contains('7.62') || combined.contains('308') || combined.contains('m240') || combined.contains('g3') || combined.contains('mg3') || combined.contains('glock') || combined.contains('beretta') || combined.contains('9mm') || combined.contains('9x19');
      return is556 && !is762or9;
    }

    if (c.contains('7.62') || c.contains('.308')) {
      final is762 = combined.contains('7.62') ||
          combined.contains('308') ||
          combined.contains('g3') ||
          combined.contains('scar-h') ||
          combined.contains('m240') ||
          combined.contains('mg3') ||
          combined.contains('m60') ||
          combined.contains('m14') ||
          combined.contains('fal') ||
          combined.contains('hk417') ||
          combined.contains('mag') ||
          combined.contains('ssg') ||
          combined.contains('ak-47') ||
          combined.contains('akm') ||
          (combined.contains('minimi') && combined.contains('7.62'));
      final is556or9 = combined.contains('5.56') || combined.contains('223') || combined.contains('m16') || combined.contains('m4') || combined.contains('aug') || combined.contains('m249') || combined.contains('glock') || combined.contains('beretta') || combined.contains('9mm');
      return is762 && !is556or9;
    }

    if (c.contains('9mm') || c.contains('9x19')) {
      final is9mm = combined.contains('9mm') ||
          combined.contains('9x19') ||
          combined.contains('luger') ||
          combined.contains('para') ||
          combined.contains('glock') ||
          combined.contains('beretta') ||
          combined.contains('92fs') ||
          combined.contains('m9') ||
          combined.contains('p226') ||
          combined.contains('sig') ||
          combined.contains('cz 75') ||
          combined.contains('cz75') ||
          combined.contains('mp9') ||
          combined.contains('mp5') ||
          combined.contains('browning');
      return is9mm;
    }

    if (c.contains('12.7') || c.contains('.50')) {
      return combined.contains('12.7') || combined.contains('.50') || combined.contains('m82') || combined.contains('m200');
    }

    return true;
  }

  List<Map<String, String>> get _weaponsForCurrentCaliber {
    return _fleetWeaponsDetailed.where((w) => _weaponMatchesCaliber(w, _caliber)).toList();
  }

  List<String> get _allowedWeaponCategoriesForCaliber {
    final cats = _weaponsForCurrentCaliber
        .map((w) => w['category'] ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    if (cats.isNotEmpty) return cats;

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
      String caliber = '',
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
      } else if (checkCat == 'machine gun' || checkCat == 'linked' || checkCat.contains('machine') || checkCat.contains('mg') || checkText.contains('machine gun') || checkText.contains('machinegun') || checkText.contains('saw') || checkText.contains('m249') || checkText.contains('m60') || checkText.contains('m240') || checkText.contains('mg3') || checkText.contains('mg-3') || checkText.contains('fn mag') || checkText.contains('mag 58') || checkText.contains('pkm') || checkText.contains('gpmg') || checkText.contains('minimi')) {
        cleanCat = 'Machine Gun';
      } else if (checkCat == 'rifle' || checkText.contains('rifle') || checkText.contains('carbine') || checkText.contains('m4') || checkText.contains('m16') || checkText.contains('aug') || checkText.contains('steyr')) {
        cleanCat = 'Rifle';
      } else {
        if (caliber.toLowerCase().contains('m80') || caliber.toLowerCase().contains('7.62') || checkText.contains('7.62') || checkText.contains('m80') || checkText.contains('mg3')) {
          cleanCat = 'Machine Gun';
        } else {
          cleanCat = 'Rifle';
        }
      }

      final key = '$cleanCat|$cleanModel|$cleanSerial'.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        items.add({
          'category': cleanCat,
          'model': cleanModel,
          'serial': cleanSerial,
          'raw': cleanSerial.isNotEmpty ? '$cleanModel (SN: $cleanSerial)' : cleanModel,
          'caliber': caliber.trim(),
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
          final cal = (e['caliber'] ?? '').toString().trim();
          String modelName = m.isNotEmpty ? m : t;
          if (mfg.isNotEmpty && mfg != 'Other' && !modelName.toLowerCase().startsWith(mfg.toLowerCase())) {
            modelName = '$mfg $modelName';
          }
          addWeaponItem(category: c, model: modelName, serial: s, raw: t.isNotEmpty ? t : modelName, caliber: cal);
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
      addWeaponItem(category: 'Rifle', model: 'Steyr AUG A3', serial: 'ST-556-01', raw: 'Steyr AUG A3 (SN: ST-556-01)', caliber: '5.56x45 SS109');
      addWeaponItem(category: 'Rifle', model: 'M4A1 Carbine', serial: 'W-9012', raw: 'M4A1 Carbine (SN: W-9012)', caliber: '5.56x45 M193');
      addWeaponItem(category: 'Rifle', model: 'M16A4 Rifle', serial: 'W-9015', raw: 'M16A4 Rifle (SN: W-9015)', caliber: '5.56x45 SS109');
      addWeaponItem(category: 'Machine Gun', model: 'M240B', serial: 'W-2401', raw: 'M240B (SN: W-2401)', caliber: '7.62x51 M80');
      addWeaponItem(category: 'Machine Gun', model: 'MG3 Machine Gun', serial: 'MG3-001', raw: 'MG3 Machine Gun (SN: MG3-001)', caliber: '7.62x51 M80');
      addWeaponItem(category: 'Machine Gun', model: 'M249 SAW', serial: 'W-4401', raw: 'M249 SAW (SN: W-4401)', caliber: '5.56x45 SS109');
      addWeaponItem(category: 'Pistol', model: 'Beretta M9 Pistol', serial: 'W-1102', raw: 'Beretta M9 Pistol (SN: W-1102)', caliber: '9x19mm Para');
      addWeaponItem(category: 'Pistol', model: 'Beretta 92FS', serial: 'B-9201', raw: 'Beretta 92FS (SN: B-9201)', caliber: '9x19mm Para');
      addWeaponItem(category: 'Pistol', model: 'Glock 17', serial: 'G-1701', raw: 'Glock 17 (SN: G-1701)', caliber: '9x19mm Para');
    }

    return items;
  }

  List<String> get _weaponsList {
    return _weaponsForCurrentCaliber.map((w) => w['raw']!).toSet().toList();
  }

  List<String> _getModelsForCategory(String category) {
    if (category.isEmpty) return [];
    if (category == 'Rifle' && (_caliber.toLowerCase().contains('m80') || _caliber.toLowerCase().contains('7.62x51'))) {
      // Per instruction 9: there is no rifle under M80 caliber, show nothing in rifle model
      return [];
    }
    final models = _weaponsForCurrentCaliber
        .where((w) => w['category'] == category)
        .map((w) => w['model']!)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    return models;
  }

  List<String> _getSerialsForModel(String category, String model) {
    if (category.isEmpty || model.isEmpty || model == '[+ Custom Model]') return [];
    return _weaponsForCurrentCaliber
        .where((w) => w['category'] == category && w['model'] == model && w['serial']!.isNotEmpty)
        .map((w) => w['serial']!)
        .toSet()
        .toList();
  }

  void _syncFunctionWeaponState({bool resetSelections = false}) {
    if (resetSelections) {
      _functionSelectedCategory = '';
      _functionSelectedModel = '';
      _functionSelectedSerial = '';
      _functionWeapon = '';
      _selectedFunctionWeapons = [];
      return;
    }

    final allowedCats = _allowedWeaponCategoriesForCaliber;
    if (_functionSelectedCategory.isNotEmpty && !allowedCats.contains(_functionSelectedCategory)) {
      _functionSelectedCategory = '';
      _functionSelectedModel = '';
      _functionSelectedSerial = '';
    }

    if (_functionSelectedCategory.isNotEmpty) {
      final models = _getModelsForCategory(_functionSelectedCategory);
      if (_functionSelectedModel.isNotEmpty && !models.contains(_functionSelectedModel) && _functionSelectedModel != '[+ Custom Model]') {
        _functionSelectedModel = '';
        _functionSelectedSerial = '';
      }
    }

    if (_functionSelectedCategory.isNotEmpty && _functionSelectedModel.isNotEmpty) {
      final serials = _getSerialsForModel(_functionSelectedCategory, _functionSelectedModel);
      if (_functionSelectedSerial.isNotEmpty && !serials.contains(_functionSelectedSerial) && _functionSelectedSerial != '[+ Enter Custom Serial]') {
        _functionSelectedSerial = '';
      }
    }

    final activeModel = _functionSelectedModel == '[+ Custom Model]'
        ? _functionCustomModelController.text.trim()
        : _functionSelectedModel;
    final activeSerial = _functionSelectedSerial == '[+ Enter Custom Serial]'
        ? _functionCustomSerialController.text.trim()
        : _functionSelectedSerial;

    final composed = (activeModel.isNotEmpty && activeSerial.isNotEmpty)
        ? '$activeModel (SN: $activeSerial)'
        : activeModel;

    if (_selectedFunctionWeapons.isNotEmpty) {
      _functionWeapon = _selectedFunctionWeapons.join('; ');
    } else {
      _functionWeapon = '';
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
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access restricted: Only Admin can add new sampling locations.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
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
    } else if (_isAccuracyOrBullet) {
      if (widget.currentModule == 'Component Test') {
        if (_bulletSupplierController.text.trim().isEmpty) {
          notifyMissing('Bullet Supplier');
          return false;
        }
        if (_bulletGrainSizeController.text.trim().isEmpty) {
          notifyMissing('Grain Size');
          return false;
        }
        if (_propellantChargeController.text.trim().isEmpty) {
          notifyMissing('Powder Charge');
          return false;
        }
      }
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
      if (_testName == 'Propellant Test') {
        if (_propellantSupplier.isEmpty) {
          notifyMissing('Propellant Supplier');
          return false;
        }
        if (_propellantCodeController.text.trim().isEmpty) {
          notifyMissing('Powder Code');
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
      final bool isBlank = _caliber.contains('M82') || _caliber.contains('M200') || _caliber.toLowerCase().contains('blank');
      if (_epvatPressureType == 'Overall') {
        const temps = ['+21', '+52', '-54'];
        final hasAnyData = temps.any((t) {
          final p1 = _overallEpvatControllers[t]?['p1_mean']?.text.trim() ?? '';
          final p2 = _overallEpvatControllers[t]?['p2_mean']?.text.trim() ?? '';
          final v = _overallEpvatControllers[t]?['vel_mean']?.text.trim() ?? '';
          final hasRounds = (_overallEpvatP1RoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false) ||
                            (_overallEpvatVelRoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false);
          return p1.isNotEmpty || p2.isNotEmpty || v.isNotEmpty || hasRounds;
        });

        final tempsToCheck = hasAnyData
            ? temps.where((t) {
                final p1 = _overallEpvatControllers[t]?['p1_mean']?.text.trim() ?? '';
                final p2 = _overallEpvatControllers[t]?['p2_mean']?.text.trim() ?? '';
                final v = _overallEpvatControllers[t]?['vel_mean']?.text.trim() ?? '';
                final hasRounds = (_overallEpvatP1RoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false) ||
                                  (_overallEpvatVelRoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false);
                return p1.isNotEmpty || p2.isNotEmpty || v.isNotEmpty || hasRounds;
              }).toList()
            : [temps[_activeEpvatTempTabIndex]];

        for (final t in tempsToCheck) {
          if (_overallEpvatControllers[t]?['p1_mean']?.text.trim().isEmpty ?? true) {
            notifyMissing((_isCaliber9mm ? 'Chamber Pressure Mean (' : 'GP1 Chamber Pressure Mean (') + t + '°C)');
            return false;
          }
          if (!_isCaliber9mm && !isBlank && (_overallEpvatControllers[t]?['p2_mean']?.text.trim().isEmpty ?? true)) {
            notifyMissing('GP2 Port Pressure Mean (' + t + '°C)');
            return false;
          }
          if (_overallEpvatControllers[t]?['action_time_mean']?.text.trim().isEmpty ?? true) {
            notifyMissing('Action Time Mean (' + t + '°C)');
            return false;
          }
          if (!isBlank && (_overallEpvatControllers[t]?['vel_mean']?.text.trim().isEmpty ?? true)) {
            notifyMissing('Velocity Mean (' + t + '°C)');
            return false;
          }
        }
      } else {
        if (_cartridgeTempController.text.trim().isEmpty) {
          notifyMissing('Cartridge Temperature');
          return false;
        }
        if (_epvatMeanPressureController.text.trim().isEmpty) {
          notifyMissing(_isCaliber9mm ? 'Mean Chamber Pressure' : 'GP1 Mean Chamber Pressure');
          return false;
        }
        if (!_isCaliber9mm && !isBlank && _epvatP2MeanPressureController.text.trim().isEmpty) {
          notifyMissing('GP2 Mean Port Pressure');
          return false;
        }
        if (_actionTimeMeanController.text.trim().isEmpty) {
          notifyMissing('Mean Action Time');
          return false;
        }
        if (!isBlank && _meanVelController.text.trim().isEmpty) {
          notifyMissing('Mean Velocity');
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
      if (_selectedFunctionWeapons.isEmpty) {
        jumpTo(_weaponFieldKey, _weaponFocusNode, 'Weapon Type, Serial & Rounds Fired');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select weapon serial and enter rounds fired in each weapon.')),
        );
        return false;
      }
      _functionWeapon = _selectedFunctionWeapons.join('; ');
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
      _locationController.text = _getDefaultSamplingLocation(module: widget.currentModule, test: _testName);
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

  bool get _isAccuracyOrBullet => _testName == 'Accuracy Test' || _testName == 'Bullet components';

  // calibers and testNames are now on EntryTab widget class
  List<String> get calibers {
    if (widget.currentModule == 'Component Test') {
      if (_isAccuracyOrBullet) {
        return const [
          '5.56x45 .223 55 grains',
          '5.56x45 .223 69 grains',
          '5.56x45 .223 77 grains',
          '7.62x51 .308',
          '9x19mm 124 grains CMJ',
        ];
      }
      return const ['5.56', '5.45', '7.62', '9mm'];
    }
    return EntryTab.calibers;
  }
  List<String> get testNames {
    if (widget.currentModule == 'Daily Test' || widget.currentModule == 'Daily Test Report') {
      return EntryTab.testNames.where((t) => t != 'Primer Sensitivity Test' && t != 'Propellant Test').toList();
    }
    if (widget.currentModule == 'Component Test') {
      return const ['Primer Sensitivity Test', 'Propellant Test', 'Bullet components'];
    }
    return EntryTab.testNames.where((t) => t != 'Propellant Test').toList();
  }

  // Caliber-specific test matrix and sample sizing
  bool _isTestAllowedForCaliber(String test, String cal) {
    if (widget.currentModule == 'Component Test') {
      if (test == 'Accuracy Test' || test == 'Bullet components') {
        final c = cal.toLowerCase().replaceAll(',', '.');
        return c.contains('.223') || c.contains('.308') || (c.contains('124') && c.contains('cmj'));
      }
      return test == 'Propellant Test' || test == 'Primer Sensitivity Test';
    }
    if (test == 'Propellant Test') return false;
    if ((widget.currentModule == 'Daily Test' || widget.currentModule == 'Daily Test Report') && test == 'Primer Sensitivity Test') {
      return false;
    }

    final c = cal.toLowerCase().replaceAll(',', '.');
    if (test == 'Waterproof Test') {
      if (c.contains('.223') || c.contains('69 grain') || c.contains('55 grain') || c.contains('77 grain') ||
          c.contains('.308') || c.contains('match') || c.contains('luger')) {
        return false;
      }
    } else if (test == 'Extraction Force Test') {
      if (c.contains('m200') || c.contains('m82')) return false;
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
      if (!c.contains('ss109')) return false;
    } else if (test == 'Firing Rate Cycle Test') {
      if (!(c.contains('m82') || c.contains('m200'))) return false;
    }
    return true;
  }

  List<String> _allowedTestsForCaliber(String cal) {
    if (widget.currentModule == 'Component Test') {
      return testNames;
    }
    return testNames.where((t) => _isTestAllowedForCaliber(t, cal)).toList();
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
    if (test == 'Accuracy Test' || test == 'Bullet components') {
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
        _locationController.text = _getDefaultSamplingLocation(
          module: widget.currentModule,
          test: _testName,
        );
      }
      if (_isCaliberSingleTempOnly) {
        _epvatPressureType = 'Individual';
        _functionTempMode = 'Single';
        _cartridgeTempController.text = '+21';
        _functionSingleTemp = '+21';
      }
      if (widget.currentModule == 'Component Test' && _isAccuracyOrBullet) {
        if (newCaliber.contains('55 grains')) {
          _bulletGrainSizeController.text = '55 grains';
        } else if (newCaliber.contains('69 grains')) {
          _bulletGrainSizeController.text = '69 grains';
        } else if (newCaliber.contains('77 grains')) {
          _bulletGrainSizeController.text = '77 grains';
        } else if (newCaliber.contains('124 grains')) {
          _bulletGrainSizeController.text = '124 grains';
        } else if (newCaliber.contains('.308')) {
          _bulletGrainSizeController.text = '175 grains';
        }
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
        _selectedComponentPrimerLot = null;
        _clearPrimerFields();
      }
      if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
        _recalculateEpvatStats();
      }
      _syncFunctionWeaponState(resetSelections: true);
    });
    widget.onCaliberChanged(newCaliber);
    _scheduleAutoSave();
  }

  void _clearTestSpecificParameters() {
    _functionWeapon = '';
    _functionSelectedCategory = '';
    _functionSelectedModel = '';
    _functionSelectedSerial = '';
    _selectedFunctionWeapons = [];
    _functionCustomModelController.clear();
    _functionCustomSerialController.clear();
    _funcDefectItemCounts.clear();
    _functionLevel1Controller.text = '0';
    _functionLevel2Controller.text = '0';
    _functionLevel3Controller.text = '0';
    _functionLevel4Controller.text = '0';
    for (var c in _funcAllL1Controllers.values) c.text = '0';
    for (var c in _funcAllL2Controllers.values) c.text = '0';
    for (var c in _funcAllL3Controllers.values) c.text = '0';
    for (var c in _funcAllL4Controllers.values) c.text = '0';
    _defectsController.text = '0';

    _mouthSlowController.text = '0';
    _mouthFastController.text = '0';
    _primerSlowController.text = '0';
    _primerFastController.text = '0';
    _pressureController.clear();

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
    _accLargestDistanceController.clear();

    _primerHbarController.clear();
    _primerSDController.clear();
    _primerHbarPlus5SController.clear();
    _primerHbarMinus2SController.clear();
    _primerMisfiresCountController.text = '0';

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
    _meanVelController.clear();
    _maxVelController.clear();
    _minVelController.clear();
    _rangeVelController.clear();
    _sdVelController.clear();

    _actionTimeMeanController.clear();
    _actionTimeMaxController.clear();
    _actionTimeMinController.clear();
    _actionTimeRangeController.clear();
    _actionTimeSDController.clear();

    _t4MeanController.clear();
    _t4MaxController.clear();
    _t4MinController.clear();
    _t4RangeController.clear();
    _t4SDController.clear();
    for (var c in _t4RoundsControllers) {
      c.clear();
    }

    _primerAlpha3Controller.clear();
    _primerEmaxController.clear();
    _primerEminController.clear();
    for (var row in _primerDropTableRows) {
      row.f.clear();
      row.m.clear();
      row.pi.clear();
    }
  }

  String get _draftScope => '${widget.currentModule}_$_testName';

  void _onTestNameSelected(String newTest) {
    setState(() {
      _testName = newTest;
      _clearTestSpecificParameters();
      _locationController.text = _getDefaultSamplingLocation(
        module: widget.currentModule,
        test: newTest,
      );
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
      if (widget.currentModule == 'Component Test') {
        if (newTest == 'Accuracy Test' || newTest == 'Bullet components') {
          final c = _caliber.toLowerCase().replaceAll(',', '.');
          final isAllowedBulletCal = c.contains('.223') || c.contains('.308') || (c.contains('124') && c.contains('cmj'));
          if (!isAllowedBulletCal) {
            _caliber = '5.56x45 .223 55 grains';
            widget.onCaliberChanged(_caliber);
          }
          if (_caliber.contains('55 grains')) {
            _bulletGrainSizeController.text = '55 grains';
          } else if (_caliber.contains('69 grains')) {
            _bulletGrainSizeController.text = '69 grains';
          } else if (_caliber.contains('77 grains')) {
            _bulletGrainSizeController.text = '77 grains';
          } else if (_caliber.contains('124 grains')) {
            _bulletGrainSizeController.text = '124 grains';
          } else if (_caliber.contains('.308')) {
            _bulletGrainSizeController.text = '175 grains';
          }
        } else {
          if (_caliber.contains('grains') || _caliber.contains('.308') || _caliber.contains('CMJ')) {
            _caliber = '5.56';
            widget.onCaliberChanged(_caliber);
          }
        }
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
        _selectedComponentPrimerLot = null;
        _clearPrimerFields();
      }
    });
    widget.onTestNameChanged(newTest);
    _loadSavedDraft();
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
        'accLargestDistance': _accLargestDistanceController.text,
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
        't4Mean': _t4MeanController.text,
        't4Max': _t4MaxController.text,
        't4Min': _t4MinController.text,
        't4Range': _t4RangeController.text,
        't4SD': _t4SDController.text,
        't4Rounds': _t4RoundsControllers.map((c) => c.text).toList(),
        'primerAlpha3': _primerAlpha3Controller.text,
        'primerEmax': _primerEmaxController.text,
        'primerEmin': _primerEminController.text,
        'primerDropTable': _serializePrimerDropTable(),
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
        'epvatSingleSubMode': _epvatSingleSubMode,
        'bulletSupplier': _bulletSupplierController.text,
        'bulletGrainSize': _bulletGrainSizeController.text,
        'sampleLoadingMethod': _sampleLoadingMethod,
        'sampleReceivedDate': _sampleReceivedDateController.text,
        'bulletSampleLocation': _bulletSampleLocation,
        'propellantCharge': _propellantChargeController.text,
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
          't4': (_overallEpvatT4RoundsControllers[t] ?? []).map((c) => c.text).toList(),
          'p1': (_overallEpvatP1RoundsControllers[t] ?? []).map((c) => c.text).toList(),
          'p2': (_overallEpvatP2RoundsControllers[t] ?? []).map((c) => c.text).toList(),
        };
      }
      draft['overallEpvatRounds'] = overallRoundsData;

      await _storageService.saveFormDraft(draft, scope: _draftScope);
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
    if (_testName.isEmpty) return;
    try {
      final draft = await _storageService.loadFormDraft(scope: _draftScope);
      if (draft == null || draft.isEmpty || !mounted) return;
      
      setState(() {
        if (draft['caliber'] != null) _caliber = draft['caliber'];
        if (draft['testName'] != null) _testName = draft['testName'];
        if (draft['shift'] != null) {
          final s = draft['shift'].toString();
          _shift = (s == 'Afternoon' || s == 'Night') ? 'Afternoon' : 'Morning';
        }
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
        if (draft['accLargestDistance'] != null) _accLargestDistanceController.text = draft['accLargestDistance'];
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

        if (draft['t4Mean'] != null) _t4MeanController.text = draft['t4Mean'];
        if (draft['t4Max'] != null) _t4MaxController.text = draft['t4Max'];
        if (draft['t4Min'] != null) _t4MinController.text = draft['t4Min'];
        if (draft['t4Range'] != null) _t4RangeController.text = draft['t4Range'];
        if (draft['t4SD'] != null) _t4SDController.text = draft['t4SD'];
        if (draft['t4Rounds'] is List && (draft['t4Rounds'] as List).isNotEmpty) {
          final list = draft['t4Rounds'] as List;
          _t4RoundsControllers.clear();
          for (var item in list) {
            _t4RoundsControllers.add(TextEditingController(text: item.toString()));
          }
        }

        if (draft['primerAlpha3'] != null) _primerAlpha3Controller.text = draft['primerAlpha3'];
        if (draft['primerEmax'] != null) _primerEmaxController.text = draft['primerEmax'];
        if (draft['primerEmin'] != null) _primerEminController.text = draft['primerEmin'];
        if (draft['primerDropTable'] != null && draft['primerDropTable'].toString().isNotEmpty) {
          _loadPrimerDropTableFromJson(draft['primerDropTable'].toString());
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

        if (draft['epvatSingleSubMode'] != null) _epvatSingleSubMode = draft['epvatSingleSubMode'].toString();
        if (draft['bulletSupplier'] != null) _bulletSupplierController.text = draft['bulletSupplier'].toString();
        if (draft['bulletGrainSize'] != null) _bulletGrainSizeController.text = draft['bulletGrainSize'].toString();
        if (draft['sampleLoadingMethod'] != null) _sampleLoadingMethod = draft['sampleLoadingMethod'].toString();
        if (draft['sampleReceivedDate'] != null) _sampleReceivedDateController.text = draft['sampleReceivedDate'].toString();
        if (draft['bulletSampleLocation'] != null) _bulletSampleLocation = draft['bulletSampleLocation'].toString();
        if (draft['propellantCharge'] != null) _propellantChargeController.text = draft['propellantCharge'].toString();

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
      if (_testName == 'Accuracy Test') {
        _testName = 'Bullet components';
      }
      if (_testName != 'Propellant Test' && _testName != 'Primer Sensitivity Test' && _testName != 'Bullet components') {
        _testName = 'Primer Sensitivity Test';
      }
    } else if ((widget.currentModule == 'Daily Test' || widget.currentModule == 'Daily Test Report') && _testName.isNotEmpty) {
      if (_testName == 'Primer Sensitivity Test' || _testName == 'Propellant Test') {
        _testName = 'Waterproof Test';
      }
    }
    _operatorsController.text = widget.loggedInUser;
    _locationController.text = '';
    _barrelSNController.text = '';
    _gp6SerialController.text = '';
    _terminalBarrelSNController.text = '';
    _epvatSensor1Controller.text = '';
    _epvatSensor2Controller.text = '';
    _selectedRegisteredWeapon = '';
    _functionWeapon = '';
    _selectedFunctionWeapons = [];
    _syncFunctionWeaponState(resetSelections: true);

    final adminTech = (widget.adminRules['technician_name'] ?? widget.adminRules['cert_technician_name'] ?? '').toString().trim();
    if (adminTech.isNotEmpty) {
      _technicianController.text = adminTech;
    } else if (widget.userRole.toLowerCase() == 'technician') {
      _technicianController.text = widget.loggedInUser.isNotEmpty ? widget.loggedInUser : 'Ballistics Technician';
    } else {
      _loadTechnicians();
    }
    
    // Initialize test date and time locked to opening time (allows manual edit or defaults to submission time)
    _autoGenerateTime(force: true);
    
    // Initialize 20 round controllers for Extraction Force Test
    for (int i = 0; i < 20; i++) {
      final ctrl = TextEditingController();
      ctrl.addListener(() {
        _recalculateExtractionStats();
        _scheduleAutoSave();
      });
      _extractionRoundsControllers.add(ctrl);
    }
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

    // Initialize round controllers for EPVAT Test & Action Time & t4
    _epvatRoundsControllers.add(TextEditingController());
    _epvatP2RoundsControllers.add(TextEditingController());
    _epvatVelRoundsControllers.add(TextEditingController());
    _actionTimeRoundsControllers.add(TextEditingController());
    _t4RoundsControllers.add(TextEditingController());

    _epvatMaxPressureController.addListener(() => _calculateRange(_epvatMaxPressureController, _epvatMinPressureController, _epvatRangePressureController));
    _epvatMinPressureController.addListener(() => _calculateRange(_epvatMaxPressureController, _epvatMinPressureController, _epvatRangePressureController));

    _epvatP2MaxPressureController.addListener(() => _calculateRange(_epvatP2MaxPressureController, _epvatP2MinPressureController, _epvatP2RangePressureController));
    _epvatP2MinPressureController.addListener(() => _calculateRange(_epvatP2MaxPressureController, _epvatP2MinPressureController, _epvatP2RangePressureController));

    _actionTimeMaxController.addListener(() => _calculateRange(_actionTimeMaxController, _actionTimeMinController, _actionTimeRangeController));
    _actionTimeMinController.addListener(() => _calculateRange(_actionTimeMaxController, _actionTimeMinController, _actionTimeRangeController));

    _t4MaxController.addListener(() => _calculateRange(_t4MaxController, _t4MinController, _t4RangeController));
    _t4MinController.addListener(() => _calculateRange(_t4MaxController, _t4MinController, _t4RangeController));

    // Initialize Primer Sensitivity Test round & drop table
    _primerDropHeightControllers.add(TextEditingController());
    _primerFireResults.add('Fire');
    _primerHbarController.addListener(_onManualPrimerHbarOrSDChanged);
    _primerSDController.addListener(_onManualPrimerHbarOrSDChanged);
    _initPrimerDropTable();

    // Initialize overall EPVAT controllers map for three temperatures (+21, +52, -54)
    final temps = ['+21', '+52', '-54'];
    final metrics = ['vel', 'action_time', 'p1', 'p2', 't4'];
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
      _overallEpvatT4RoundsControllers[t] = List.generate(50, (_) => TextEditingController());
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
        _overallEpvatT4RoundsControllers[t]![i].addListener(() {
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

  @override
  void didUpdateWidget(covariant EntryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loggedInUser != widget.loggedInUser) {
      _operatorsController.text = widget.loggedInUser;
    }
    if (oldWidget.currentModule != widget.currentModule) {
      final allowed = _allowedTestsForCaliber(_caliber);
      if (allowed.isNotEmpty) {
        final newTest = allowed.first;
        setState(() {
          _testName = newTest;
          _clearTestSpecificParameters();
          _locationController.text = _getDefaultSamplingLocation(
            module: widget.currentModule,
            test: newTest,
          );
        });
        widget.onTestNameChanged(newTest);
      }
    }
    if (oldWidget.adminRules != widget.adminRules) {
      final adminTech = (widget.adminRules['technician_name'] ?? widget.adminRules['cert_technician_name'] ?? '').toString().trim();
      if (adminTech.isNotEmpty && _technicianController.text != adminTech) {
        _technicianController.text = adminTech;
      }
      _syncFunctionWeaponState();
      if (_accuracyBarrels.isNotEmpty && (_barrelSNController.text.isEmpty || !_accuracyBarrels.contains(_barrelSNController.text))) {
        if (_isAccuracyOrBullet) _barrelSNController.text = _accuracyBarrels.first;
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
    if (!_isAccuracyOrBullet && _testName != 'EPVAT test') return;
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
  void dispose() {
    _liveClockTimer?.cancel();
    _operatorsController.dispose();
    _technicianController.dispose();
    _lotController.dispose();
    _primerInsertionDepthController.dispose();
    _primerLotController.dispose();
    _propellantLotController.dispose();
    _propellantChargeController.dispose();
    _propellantCodeController.dispose();
    _bulletSupplierController.dispose();
    _bulletGrainSizeController.dispose();
    _sampleReceivedDateController.dispose();
    _epvatAdminPropellantSupplierController.dispose();
    _epvatAdminPrimerSupplierController.dispose();
    _lotThreeDigitsController.dispose();
    _lotYearController.dispose();
    _producedController.dispose();
    _defectsController.dispose();
    _notesController.dispose();
    _requirementController.dispose();
    _pressureController.dispose();
    _viscosityController.dispose();
    _currentWeaponRoundsController.dispose();
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

    _t4MeanController.dispose();
    _t4MaxController.dispose();
    _t4MinController.dispose();
    _t4RangeController.dispose();
    _t4SDController.dispose();
    for (var ctrl in _t4RoundsControllers) {
      ctrl.dispose();
    }
    _overallEpvatT4RoundsControllers.forEach((_, list) {
      for (var ctrl in list) {
        ctrl.dispose();
      }
    });

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
    _primerAlpha3Controller.dispose();
    _primerEmaxController.dispose();
    _primerEminController.dispose();
    for (var row in _primerDropTableRows) {
      row.dispose();
    }
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
    calcMetrics(_overallEpvatT4RoundsControllers[temp] ?? [], 't4');
    calcMetrics(_overallEpvatP1RoundsControllers[temp] ?? [], 'p1');
    calcMetrics(_overallEpvatP2RoundsControllers[temp] ?? [], 'p2');

    if (mounted) {
      setState(() {});
    }
  }

  _PrimerDropTableRow _createPrimerDropRow(String h, String f, String m, String pi) {
    final row = _PrimerDropTableRow(hVal: h, fVal: f, mVal: m, piVal: pi);
    row.f.addListener(_recalculatePrimerDropStats);
    row.m.addListener(_recalculatePrimerDropStats);
    return row;
  }

  void _initPrimerDropTable() {
    if (_primerDropTableRows.isNotEmpty) return;
    final defaultHeights = ['130.0', '155.0', '180.0', '205.0', '230.0', '255.0'];
    for (final h in defaultHeights) {
      _primerDropTableRows.add(_createPrimerDropRow(h, '', '', ''));
    }
  }

  void _recalculatePrimerDropStats() {
    int totalF = 0;
    int totalM = 0;
    for (final row in _primerDropTableRows) {
      final f = int.tryParse(row.f.text.trim()) ?? 0;
      final m = int.tryParse(row.m.text.trim()) ?? 0;
      totalF += f;
      totalM += m;
      if (f + m > 0) {
        final piVal = m / (f + m);
        row.pi.text = piVal.toStringAsFixed(3);
      } else if (row.f.text.trim().isNotEmpty || row.m.text.trim().isNotEmpty) {
        row.pi.text = '0.000';
      }
    }
    if (totalF > 0 || totalM > 0) {
      _producedController.text = '${totalF + totalM}';
      _primerMisfiresCountController.text = '$totalM';
      _defectsController.text = '$totalM';
    }
  }

  String _serializePrimerDropTable() {
    final list = _primerDropTableRows.map((r) => {
      'h': double.tryParse(r.h.text.trim()) ?? r.h.text.trim(),
      'f': int.tryParse(r.f.text.trim()) ?? r.f.text.trim(),
      'm': int.tryParse(r.m.text.trim()) ?? r.m.text.trim(),
      'pi': double.tryParse(r.pi.text.trim()) ?? r.pi.text.trim(),
    }).toList();
    return jsonEncode(list);
  }

  void _loadPrimerDropTableFromJson(String jsonStr) {
    if (jsonStr.isEmpty) return;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List && decoded.isNotEmpty) {
        for (var r in _primerDropTableRows) {
          r.dispose();
        }
        _primerDropTableRows.clear();
        for (final item in decoded) {
          if (item is Map) {
            final hVal = item['h']?.toString() ?? '';
            final fVal = item['f']?.toString() ?? '';
            final mVal = item['m']?.toString() ?? '';
            final piVal = item['pi']?.toString() ?? '';
            _primerDropTableRows.add(_createPrimerDropRow(hVal, fVal, mVal, piVal));
          }
        }
        _recalculatePrimerDropStats();
      }
    } catch (e) {
      debugPrint('Error loading primer drop table: $e');
    }
  }

  BallisticRecord _buildCurrentRecord({String refNo = 'PREVIEW'}) {
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

    final String calculatedStatus = _getCalculatedStatus();
    final String finalStatus;
    if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
      finalStatus = calculatedStatus; // strictly decided by auto calculation
    } else {
      finalStatus = _isManualStatusSelected && _status.isNotEmpty ? _status : calculatedStatus;
    }
    final producedStr = _producedController.text.trim();
    final defectsStr = _defectsController.text.trim();
    final int produced = int.tryParse(producedStr) ?? 0;
    final int defects = int.tryParse(defectsStr) ?? 0;

    final assignedRefNo = refNo;

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
          final p1m = _overallEpvatControllers[t]?['p1_mean']?.text.trim() ?? '';
          final p1max = _overallEpvatControllers[t]?['p1_max']?.text.trim() ?? '';
          final p1min = _overallEpvatControllers[t]?['p1_min']?.text.trim() ?? '';
          final p1sd = _overallEpvatControllers[t]?['p1_sd']?.text.trim() ?? '';

          final p2m = _overallEpvatControllers[t]?['p2_mean']?.text.trim() ?? '';
          final p2max = _overallEpvatControllers[t]?['p2_max']?.text.trim() ?? '';
          final p2min = _overallEpvatControllers[t]?['p2_min']?.text.trim() ?? '';
          final p2sd = _overallEpvatControllers[t]?['p2_sd']?.text.trim() ?? '';

          final vm = _overallEpvatControllers[t]?['vel_mean']?.text.trim() ?? '';
          final vmax = _overallEpvatControllers[t]?['vel_max']?.text.trim() ?? '';
          final vmin = _overallEpvatControllers[t]?['vel_min']?.text.trim() ?? '';
          final vsd = _overallEpvatControllers[t]?['vel_sd']?.text.trim() ?? '';

          final atm = _overallEpvatControllers[t]?['action_time_mean']?.text.trim() ?? '';
          final atmax = _overallEpvatControllers[t]?['action_time_max']?.text.trim() ?? '';
          final atmin = _overallEpvatControllers[t]?['action_time_min']?.text.trim() ?? '';
          final atsd = _overallEpvatControllers[t]?['action_time_sd']?.text.trim() ?? '';

          tempDetails.add('$t°C ($count rds: P1=$p1m, Max=$p1max, P1Min=$p1min, SD=$p1sd, P2=$p2m, P2Max=$p2max, P2Min=$p2min, P2SD=$p2sd, V=$vm, VMax=$vmax, VMin=$vmin, VSD=$vsd, AT=$atm, ATMax=$atmax, ATMin=$atmin, ATSD=$atsd)');
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

        final baseT4Mean = _overallEpvatControllers[baselineTemp]!['t4_mean']?.text.trim() ?? '';
        final baseT4Max = _overallEpvatControllers[baselineTemp]!['t4_max']?.text.trim() ?? '';
        final baseT4Min = _overallEpvatControllers[baselineTemp]!['t4_min']?.text.trim() ?? '';
        final baseT4Range = _overallEpvatControllers[baselineTemp]!['t4_range']?.text.trim() ?? '';
        final baseT4SD = _overallEpvatControllers[baselineTemp]!['t4_sd']?.text.trim() ?? '';

        final customNotes = _notesController.text.trim();
        final tempsStr = tempDetails.isNotEmpty ? 'Temps: ${tempDetails.join('; ')}' : '';
        final combinedNotes = customNotes.isNotEmpty
            ? (tempsStr.isNotEmpty ? '$customNotes | $tempsStr' : customNotes)
            : tempsStr;

        String getOverallP1Rounds(String t) {
          final rds = (_overallEpvatP1RoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',');
          if (rds.isNotEmpty) return rds;
          if (tempsToSave.length > 1) {
            final m = _overallEpvatControllers[t]?['p1_mean']?.text.trim() ?? '';
            final max = _overallEpvatControllers[t]?['p1_max']?.text.trim() ?? '';
            final min = _overallEpvatControllers[t]?['p1_min']?.text.trim() ?? '';
            final sd = _overallEpvatControllers[t]?['p1_sd']?.text.trim() ?? '';
            if (m.isNotEmpty || max.isNotEmpty || min.isNotEmpty || sd.isNotEmpty) {
              return 'STAT:P1=$m,Max=$max,Min=$min,SD=$sd';
            }
          }
          return '';
        }

        String getOverallP2Rounds(String t) {
          final rds = (_overallEpvatP2RoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',');
          if (rds.isNotEmpty) return rds;
          if (tempsToSave.length > 1) {
            final m = _overallEpvatControllers[t]?['p2_mean']?.text.trim() ?? '';
            final max = _overallEpvatControllers[t]?['p2_max']?.text.trim() ?? '';
            final min = _overallEpvatControllers[t]?['p2_min']?.text.trim() ?? '';
            final sd = _overallEpvatControllers[t]?['p2_sd']?.text.trim() ?? '';
            if (m.isNotEmpty || max.isNotEmpty || min.isNotEmpty || sd.isNotEmpty) {
              return 'STAT:P2=$m,Max=$max,Min=$min,SD=$sd';
            }
          }
          return '';
        }

        String getOverallVelRounds(String t) {
          final rds = (_overallEpvatVelRoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',');
          if (rds.isNotEmpty) return rds;
          if (tempsToSave.length > 1) {
            final m = _overallEpvatControllers[t]?['vel_mean']?.text.trim() ?? '';
            final max = _overallEpvatControllers[t]?['vel_max']?.text.trim() ?? '';
            final min = _overallEpvatControllers[t]?['vel_min']?.text.trim() ?? '';
            final sd = _overallEpvatControllers[t]?['vel_sd']?.text.trim() ?? '';
            if (m.isNotEmpty || max.isNotEmpty || min.isNotEmpty || sd.isNotEmpty) {
              return 'STAT:V=$m,Max=$max,Min=$min,SD=$sd';
            }
          }
          return '';
        }

        String getOverallActRounds(String t) {
          final rds = (_overallEpvatActionTimeRoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',');
          if (rds.isNotEmpty) return rds;
          if (tempsToSave.length > 1) {
            final m = _overallEpvatControllers[t]?['action_time_mean']?.text.trim() ?? '';
            final max = _overallEpvatControllers[t]?['action_time_max']?.text.trim() ?? '';
            final min = _overallEpvatControllers[t]?['action_time_min']?.text.trim() ?? '';
            final sd = _overallEpvatControllers[t]?['action_time_sd']?.text.trim() ?? '';
            if (m.isNotEmpty || max.isNotEmpty || min.isNotEmpty || sd.isNotEmpty) {
              return 'STAT:AT=$m,Max=$max,Min=$min,SD=$sd';
            }
          }
          return '';
        }

        String getOverallT4Rounds(String t) {
          final rds = (_overallEpvatT4RoundsControllers[t] ?? []).map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',');
          if (rds.isNotEmpty) return rds;
          if (tempsToSave.length > 1) {
            final m = _overallEpvatControllers[t]?['t4_mean']?.text.trim() ?? '';
            final max = _overallEpvatControllers[t]?['t4_max']?.text.trim() ?? '';
            final min = _overallEpvatControllers[t]?['t4_min']?.text.trim() ?? '';
            final sd = _overallEpvatControllers[t]?['t4_sd']?.text.trim() ?? '';
            if (m.isNotEmpty || max.isNotEmpty || min.isNotEmpty || sd.isNotEmpty) {
              return 'STAT:T4=$m,Max=$max,Min=$min,SD=$sd';
            }
          }
          return '';
        }

        final p1Joined = tempsToSave.map(getOverallP1Rounds).join(';');
        final p2Joined = tempsToSave.map(getOverallP2Rounds).join(';');
        final velJoined = tempsToSave.map(getOverallVelRounds).join(';');
        final actJoined = tempsToSave.map(getOverallActRounds).join(';');
        final t4Joined = tempsToSave.map(getOverallT4Rounds).join(';');

        final record = BallisticRecord(
          module: widget.currentModule,
          referenceNo: assignedRefNo,
          timestamp: formattedDate,
          operators: _operatorsController.text.trim(),
          technicianName: _technicianController.text.trim(),
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
          t4Mean: baseT4Mean,
          t4Max: baseT4Max,
          t4Min: baseT4Min,
          t4Range: baseT4Range,
          t4SD: baseT4SD,
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
          epvatPressureRounds: p1Joined.replaceAll(';', '').trim().isNotEmpty ? p1Joined : '',
          epvatP2PressureRounds: p2Joined.replaceAll(';', '').trim().isNotEmpty ? p2Joined : '',
          epvatVelRounds: velJoined.replaceAll(';', '').trim().isNotEmpty ? velJoined : '',
          actionTimeRounds: actJoined.replaceAll(';', '').trim().isNotEmpty ? actJoined : '',
          t4Rounds: t4Joined.replaceAll(';', '').trim().isNotEmpty ? t4Joined : '',
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
        return record;
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
        final combinedNotes = customNotes;

        final record = BallisticRecord(
          module: widget.currentModule,
          referenceNo: assignedRefNo,
          timestamp: formattedDate,
          operators: _operatorsController.text.trim(),
          technicianName: _technicianController.text.trim(),
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
          cyclicRateWeaponType: _selectedFunctionWeapons.isNotEmpty ? _selectedFunctionWeapons.join('; ') : _functionWeapon,
          barrelSN: _selectedFunctionWeapons.isNotEmpty ? _selectedFunctionWeapons.join('; ') : _functionWeapon,
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
        return record;
      } else {
        String customRecordNotes = _notesController.text.trim();

        // Individual or other test name
        final record = BallisticRecord(
          module: widget.currentModule,
          referenceNo: assignedRefNo,
          timestamp: formattedDate,
          operators: _operatorsController.text.trim(),
          technicianName: _technicianController.text.trim(),
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
          notes: customRecordNotes,
          status: finalStatus,
          testName: _testName,
          pressureBar: _testName == 'Waterproof Test' ? _pressureController.text.trim() : '',
          viscosity: _testName == 'Waterproof Test' ? _viscosityController.text.trim() : '',
          testTime: _testTimeController.text.trim().isNotEmpty ? _testTimeController.text.trim() : formattedDate,
          gp6Serial: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _gp6SerialController.text.trim() : '',
          userRole: widget.userRole,
          samplingLocation: (widget.currentModule == 'Component Test' && _isAccuracyOrBullet)
              ? _bulletSampleLocation
              : (_locationController.text.trim().isNotEmpty ? _locationController.text.trim() : (_allSampleLocations.isNotEmpty ? _allSampleLocations.first : '')),
          mouthSlow: _testName == 'Waterproof Test' ? (int.tryParse(_mouthSlowController.text.trim()) ?? 0) : 0,
          mouthFast: _testName == 'Waterproof Test' ? (int.tryParse(_mouthFastController.text.trim()) ?? 0) : 0,
          primerSlow: _testName == 'Waterproof Test' ? (int.tryParse(_primerSlowController.text.trim()) ?? 0) : 0,
          primerFast: _testName == 'Waterproof Test' ? (int.tryParse(_primerFastController.text.trim()) ?? 0) : 0,
          hopperNo: (widget.currentModule == 'Daily Test' || widget.currentModule == 'Daily Test Report') ? finalLotNo : '',
          boxNo: '',
          requirement: _requirementController.text.trim(),
          barrelSN: _testName == 'Function Test'
              ? (_selectedFunctionWeapons.isNotEmpty ? _selectedFunctionWeapons.join('; ') : _functionWeapon)
              : (_isAccuracyOrBullet || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _barrelSNController.text.trim() : (_testName == 'Terminal Effect Test' ? _terminalBarrelSNController.text.trim() : '')),
          barrelType: '',
          velocityDistance: _isAccuracyOrBullet || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _distanceController.text.trim() : (_testName == 'Terminal Effect Test' ? _terminalDistanceController.text.trim() : ''),
          accMeanX: (_isAccuracyOrBullet && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _meanXController.text.trim() : '',
          accMaxX: (_isAccuracyOrBullet && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _maxXController.text.trim() : '',
          accMinX: (_isAccuracyOrBullet && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _minXController.text.trim() : '',
          accRangeX: (_isAccuracyOrBullet && _caliber != '5.56x45 M193') || _testName == 'Extraction Force Test' ? _rangeXController.text.trim() : '',
          accSDX: _isAccuracyOrBullet || _testName == 'Extraction Force Test' ? _sdXController.text.trim() : '',
          accMeanY: _isAccuracyOrBullet && _caliber != '5.56x45 M193' ? _meanYController.text.trim() : '',
          accMaxY: _isAccuracyOrBullet && _caliber != '5.56x45 M193' ? _maxYController.text.trim() : '',
          accMinY: _isAccuracyOrBullet && _caliber != '5.56x45 M193' ? _minYController.text.trim() : '',
          accRangeY: _isAccuracyOrBullet && _caliber != '5.56x45 M193' ? _rangeYController.text.trim() : '',
          accSDY: _isAccuracyOrBullet ? _sdYController.text.trim() : '',
          velMean: _isAccuracyOrBullet || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _meanVelController.text.trim() : '',
          velMin: _isAccuracyOrBullet || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _minVelController.text.trim() : '',
          velMax: _isAccuracyOrBullet || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _maxVelController.text.trim() : '',
          velRange: _isAccuracyOrBullet || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _rangeVelController.text.trim() : '',
          velSD: _isAccuracyOrBullet || _testName == 'EPVAT test' || _testName == 'Propellant Test' ? _sdVelController.text.trim() : '',
          accMeanRadius: _isAccuracyOrBullet ? _meanRadiusController.text.trim() : '',
          accLargestDistance: _isAccuracyOrBullet ? _accLargestDistanceController.text.trim() : '',
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
          t4Mean: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _t4MeanController.text.trim() : '',
          t4Max: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _t4MaxController.text.trim() : '',
          t4Min: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _t4MinController.text.trim() : '',
          t4Range: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _t4RangeController.text.trim() : '',
          t4SD: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _t4SDController.text.trim() : '',
          t4Rounds: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _t4RoundsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          primerDropHeights: _testName == 'Primer Sensitivity Test' ? _primerDropHeightControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(',') : '',
          primerFireResults: _testName == 'Primer Sensitivity Test' ? _primerFireResults.take(_primerDropHeightControllers.length).join(',') : '',
          primerHbar: _testName == 'Primer Sensitivity Test' ? _primerHbarController.text.trim() : '',
          primerSD: _testName == 'Primer Sensitivity Test' ? _primerSDController.text.trim() : '',
          primerAllFireH: _testName == 'Primer Sensitivity Test' ? _primerHbarPlus5SController.text.trim() : '',
          primerNoFireH: _testName == 'Primer Sensitivity Test' ? _primerHbarMinus2SController.text.trim() : '',
          primerAlpha3: _testName == 'Primer Sensitivity Test' ? _primerAlpha3Controller.text.trim() : '',
          primerEmax: _testName == 'Primer Sensitivity Test' ? _primerEmaxController.text.trim() : '',
          primerEmin: _testName == 'Primer Sensitivity Test' ? _primerEminController.text.trim() : '',
          primerDropTable: _testName == 'Primer Sensitivity Test' ? _serializePrimerDropTable() : '',
          epvatSensor1: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatSensor1Controller.text.trim() : '',
          epvatSensor2: (_testName == 'EPVAT test' || _testName == 'Propellant Test') ? _epvatSensor2Controller.text.trim() : '',
          cyclicRateWeaponType: _testName == 'Firing Rate Cycle Test'
              ? _cyclicRateWeaponType
              : (_testName == 'Function Test' ? (_selectedFunctionWeapons.isNotEmpty ? _selectedFunctionWeapons.join('; ') : _functionWeapon) : ''),
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
              ? (_selectedComponentPrimerLot ?? (_primerLotController.text.trim().isNotEmpty ? _primerLotController.text.trim() : _lotController.text.trim()))
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
          propellantCharge: (_testName == 'Propellant Test' || _testName == 'EPVAT test' || (_isAccuracyOrBullet && widget.currentModule == 'Component Test'))
              ? _propellantChargeController.text.trim()
              : '',
          bulletSupplier: (widget.currentModule == 'Component Test' && _isAccuracyOrBullet)
              ? _bulletSupplierController.text.trim()
              : '',
          bulletGrainSize: (widget.currentModule == 'Component Test' && _isAccuracyOrBullet)
              ? _bulletGrainSizeController.text.trim()
              : '',
          sampleLoadingMethod: (widget.currentModule == 'Component Test' && _isAccuracyOrBullet)
              ? _sampleLoadingMethod
              : '',
          sampleReceivedDate: (widget.currentModule == 'Component Test' && _isAccuracyOrBullet)
              ? _sampleReceivedDateController.text.trim()
              : '',
        );
        return record;
      }
    }

  void _openReportWithoutSaving() async {
    final record = _buildCurrentRecord(refNo: 'PREVIEW');
    final htmlContent = ReportGenerator.generateHtml(
      [record],
      record.testName,
      widget.currentModule,
      base64Logo: widget.base64Logo,
      adminRules: widget.adminRules,
      loggedInUser: widget.loggedInUser.isNotEmpty ? widget.loggedInUser : record.operators,
    );
    final cleanCaliber = record.caliber.replaceAll(';', ' ').trim();
    final cleanLotNo = record.lotNo.trim();
    final previewFilename = '${cleanCaliber}_${record.testName}_Preview_$cleanLotNo'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await ReportHelper.instance.printHtml(
      htmlContent: htmlContent,
      filename: previewFilename,
    );
  }

  bool _hasResultsFilled() {
    switch (_testName) {
      case 'Accuracy Test':
        if (_caliber.contains('M193')) {
          return _meanRadiusController.text.trim().isNotEmpty;
        }
        return _meanXController.text.trim().isNotEmpty ||
            _maxXController.text.trim().isNotEmpty ||
            _meanYController.text.trim().isNotEmpty ||
            _meanRadiusController.text.trim().isNotEmpty ||
            _accLargestDistanceController.text.trim().isNotEmpty ||
            _meanVelController.text.trim().isNotEmpty;

      case 'EPVAT test':
      case 'Propellant Test':
        if (_epvatPressureType == 'Overall') {
          for (final t in ['+21', '+52', '-54']) {
            final m = _overallEpvatControllers[t];
            if (m != null && m.values.any((c) => c.text.trim().isNotEmpty)) return true;
            if (_overallEpvatP1RoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false) return true;
            if (_overallEpvatVelRoundsControllers[t]?.any((c) => c.text.trim().isNotEmpty) ?? false) return true;
          }
          return false;
        } else {
          return _epvatMeanPressureController.text.trim().isNotEmpty ||
              _epvatMaxPressureController.text.trim().isNotEmpty ||
              _meanVelController.text.trim().isNotEmpty ||
              _actionTimeMeanController.text.trim().isNotEmpty ||
              _epvatRoundsControllers.any((c) => c.text.trim().isNotEmpty) ||
              _epvatVelRoundsControllers.any((c) => c.text.trim().isNotEmpty);
        }

      case 'Extraction Force Test':
        return _rangeXController.text.trim().isNotEmpty ||
            _sdXController.text.trim().isNotEmpty ||
            _extractionRoundsControllers.any((c) => c.text.trim().isNotEmpty);

      case 'Waterproof Test':
        return _pressureController.text.trim().isNotEmpty ||
            (int.tryParse(_mouthSlowController.text.trim()) ?? 0) > 0 ||
            (int.tryParse(_mouthFastController.text.trim()) ?? 0) > 0 ||
            (int.tryParse(_primerSlowController.text.trim()) ?? 0) > 0 ||
            (int.tryParse(_primerFastController.text.trim()) ?? 0) > 0;

      case 'Residual Stress Test':
        return _bodySlowController.text.trim().isNotEmpty ||
            _bodyFastController.text.trim().isNotEmpty ||
            _headSlowController.text.trim().isNotEmpty ||
            _headFastController.text.trim().isNotEmpty;

      case 'Primer Sensitivity Test':
        if (widget.currentModule == 'Lot Acceptance Test') {
          return (_selectedComponentPrimerLot != null && _selectedComponentPrimerLot!.isNotEmpty) ||
              _primerLotController.text.trim().isNotEmpty;
        }
        return _primerHbarController.text.trim().isNotEmpty ||
            _primerDropTableRows.any((r) =>
                (int.tryParse(r.f.text.trim()) ?? 0) > 0 ||
                (int.tryParse(r.m.text.trim()) ?? 0) > 0);

      case 'Function Test':
        final p = int.tryParse(_producedController.text.trim()) ?? 0;
        return p > 0;

      case 'Terminal Effect Test':
        return _terminalDistanceController.text.trim().isNotEmpty ||
            _terminalBarrelSNController.text.trim().isNotEmpty ||
            _notesController.text.trim().isNotEmpty;

      default:
        return _producedController.text.trim().isNotEmpty && _producedController.text.trim() != '0';
    }
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

    if (widget.userRole.toLowerCase() != 'technician') {
      if (_technicianController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Validation Error: Please select a registered Technician (Ahmed Al Bahlouli or Said Al Siyabi) for report signature.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    // Item 8: Prevent submission if test measurement results are empty
    if (!_hasResultsFilled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validation Error: Test measurement results cannot be empty. Please enter measurement results before submitting.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Item 9: Warn user if a report with the same lot number and test type has already been submitted
    final String currentLot = _lotController.text.trim();
    if (currentLot.isNotEmpty) {
      final existing = widget.records.where((r) {
        final matchesTest = r.testName.trim().toLowerCase() == _testName.trim().toLowerCase();
        final matchesCal = _isSameCaliberFamily(r.caliber, _caliber);
        final matchesLot = r.lotNo.trim().toLowerCase() == currentLot.toLowerCase() ||
            (widget.currentModule != 'Lot Acceptance Test' && r.hopperNo.trim().toLowerCase() == currentLot.toLowerCase());
        return matchesTest && matchesCal && matchesLot;
      }).toList();

      if (existing.isNotEmpty) {
        final prevRecord = existing.first;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24.0),
                SizedBox(width: 8.0),
                Text('Duplicate Submission Warning', style: TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'A report for Lot "$currentLot" and Test "$_testName" ($_caliber) has already been submitted on ${prevRecord.testTime.isNotEmpty ? prevRecord.testTime : prevRecord.timestamp}.\n\nAre you sure you want to proceed and submit another report for this lot?',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.0, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirm & Submit'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final refNum = await StorageService().getNextReferenceNumber();
      final assignedRefNo = 'REF:${refNum.toString().padLeft(2, '0')}';
      final record = _buildCurrentRecord(refNo: assignedRefNo);
      await widget.onSubmit(record);

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
        _isManualStatusSelected = false;
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

  void _showAutoExtractModal([String? initialText]) {
    final textController = TextEditingController(text: initialText ?? '');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF6366F1))),
            title: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 22),
                const SizedBox(width: 8),
                Text('Auto-Extract Test Results ($_testName)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 550,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload a test data file (PDF, CSV, TSV, JSON, TXT) or paste raw test machine readings below to automatically populate the test form fields.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final res = await getAttachmentHelper().pickFileAsBase64();
                        if (res != null && res['data'] != null) {
                          String rawData = res['data']!.toString().trim();
                          if (rawData.contains(',')) {
                            rawData = rawData.substring(rawData.indexOf(',') + 1);
                          }
                          rawData = rawData.replaceAll(RegExp(r'\s+'), '');
                          final bytes = base64Decode(rawData);
                          final filename = res['name']?.toString() ?? '';
                          final isPdf = filename.toLowerCase().endsWith('.pdf') ||
                              (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46);
                          if (isPdf) {
                            final pdfText = PdfTextExtractor.extractText(bytes);
                            textController.text = pdfText;
                          } else {
                            final text = utf8.decode(bytes, allowMalformed: true);
                            textController.text = text;
                          }
                          setDialogState(() {});
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error reading file: $e')));
                      }
                    },
                    icon: const Icon(Icons.file_upload, size: 16),
                    label: const Text('Choose File to Upload (PDF/CSV/TSV/JSON/TXT)'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 10),
                  const Text('Or Paste File Content / Machine Raw Output:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'e.g. Mean Vel: 915.2, SD: 2.4, Max: 920, Min: 910...\nor paste CSV / TSV table',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF475569))),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.of(ctx).pop();
                  _applyExtractedResults(text);
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Extract & Apply Values'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyExtractedResults(String content) {
    final extractionRes = TestResultExtractor.extract(
      content: content,
      preferredTestName: (_testName.isNotEmpty && _testName != 'Ballistic Tests') ? _testName : null,
    );
    final parsed = extractionRes.fields;
    dynamic getVal(String k1, [String? k2, String? k3, String? k4, String? k5, String? k6]) {
      for (final k in [k1, k2, k3, k4, k5, k6]) {
        if (k != null && parsed.containsKey(k) && parsed[k] != null) return parsed[k];
      }
      return null;
    }
    int count = 0;

    setState(() {
      if (extractionRes.detectedTest.isNotEmpty) {
        if (_testName != extractionRes.detectedTest) {
          if (testNames.contains(extractionRes.detectedTest) || _testName.isEmpty || _testName == 'Ballistic Tests') {
            _testName = extractionRes.detectedTest;
          }
        }
      }
      // 1. Caliber Specification
      final calVal = getVal('caliber', 'calibre')?.toString().trim();
      if (calVal != null && calVal.isNotEmpty) {
        final availableCalibers = calibers;
        final match = availableCalibers.firstWhere(
          (c) {
            final cLower = c.toLowerCase();
            final valLower = calVal.toLowerCase();
            if (cLower == valLower) return true;
            if (valLower.contains('5.56') && (cLower == '5.56' || cLower.contains('5.56x45 ss109') || cLower.contains('5.56'))) return true;
            if (valLower.contains('7.62') && (cLower == '7.62' || cLower.contains('7.62x51 m80') || cLower.contains('7.62'))) return true;
            if (valLower.contains('9mm') && (cLower == '9mm' || cLower.contains('9x19mm para') || cLower.contains('9mm'))) return true;
            if (valLower.contains('ss109') && cLower.contains('ss109')) return true;
            if (valLower.contains('m193') && cLower.contains('m193')) return true;
            return false;
          },
          orElse: () => availableCalibers.firstWhere(
            (c) => calVal.toLowerCase().contains(c.toLowerCase()),
            orElse: () => '',
          ),
        );
        if (match.isNotEmpty) {
          _caliber = match;
          count++;
        }
      }

      // 2. Extraction Force Test: Individual Rounds & Type
      if (_testName == 'Extraction Force Test') {
        final roundForcesStr = getVal('roundForces', 'round_forces', 'extractionForceRounds')?.toString();
        if (roundForcesStr != null && roundForcesStr.isNotEmpty) {
          final forcesList = roundForcesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          if (forcesList.isNotEmpty) {
            _extractionForceType = 'Individual';
            _extractionRoundsControllers.clear();
            for (final f in forcesList) {
              final ctrl = TextEditingController(text: f);
              ctrl.addListener(() {
                _recalculateExtractionStats();
                _scheduleAutoSave();
              });
              _extractionRoundsControllers.add(ctrl);
            }
            while (_extractionRoundsControllers.length < 20) {
              final ctrl = TextEditingController();
              ctrl.addListener(() {
                _recalculateExtractionStats();
                _scheduleAutoSave();
              });
              _extractionRoundsControllers.add(ctrl);
            }
            _producedController.text = '${forcesList.length}';
            _recalculateExtractionStats();
            count++;
          }
        }
      }

      final produced = getVal('produced', 'shot_count', 'primer_total_tested', 'primerTotalTested', 'primer_total_rounds', 'primerTotalRounds');
      if (produced != null && _testName != 'Extraction Force Test') {
        _producedController.text = produced.toString();
        count++;
      }
      final defects = getVal('defects');
      if (defects != null) {
        _defectsController.text = defects.toString();
        count++;
      }
      final velMean = getVal('vel_mean', 'velMean');
      if (velMean != null) {
        _meanVelController.text = velMean.toString();
        count++;
      }
      final velMin = getVal('vel_min', 'velMin');
      if (velMin != null) {
        _minVelController.text = velMin.toString();
        count++;
      }
      final velMax = getVal('vel_max', 'velMax');
      if (velMax != null) {
        _maxVelController.text = velMax.toString();
        count++;
      }
      final velSd = getVal('vel_sd', 'velSd');
      if (velSd != null) {
        _sdVelController.text = velSd.toString();
        count++;
      }
      final velRange = getVal('vel_range', 'velRange');
      if (velRange != null) {
        _rangeVelController.text = velRange.toString();
        count++;
      } else if (velMin != null && velMax != null) {
        final minD = double.tryParse(velMin.toString());
        final maxD = double.tryParse(velMax.toString());
        if (minD != null && maxD != null) {
          _rangeVelController.text = (maxD - minD).toStringAsFixed(2);
          count++;
        }
      }
      final meanRadius = getVal('acc_mean_radius', 'accMeanRadius');
      if (meanRadius != null) {
        _meanRadiusController.text = meanRadius.toString();
        count++;
      }
      final sdX = getVal('acc_sd_x', 'accSdX');
      if (sdX != null) {
        _sdXController.text = sdX.toString();
        count++;
      }
      final sdY = getVal('acc_sd_y', 'accSdY');
      if (sdY != null) {
        _sdYController.text = sdY.toString();
        count++;
      }
      final minX = getVal('acc_min_x', 'accMinX');
      if (minX != null) {
        _minXController.text = minX.toString();
        count++;
      }
      final maxX = getVal('acc_max_x', 'accMaxX');
      if (maxX != null) {
        _maxXController.text = maxX.toString();
        count++;
      }
      final meanX = getVal('acc_mean_x', 'accMeanX');
      if (meanX != null) {
        _meanXController.text = meanX.toString();
        count++;
      }
      final rangeX = getVal('acc_range_x', 'accRangeX');
      if (rangeX != null) {
        _rangeXController.text = rangeX.toString();
        count++;
      } else if (minX != null && maxX != null) {
        final minD = double.tryParse(minX.toString());
        final maxD = double.tryParse(maxX.toString());
        if (minD != null && maxD != null) {
          _rangeXController.text = (maxD - minD).toStringAsFixed(1);
          count++;
        }
      }
      final meanY = getVal('acc_mean_y', 'accMeanY');
      if (meanY != null) {
        _meanYController.text = meanY.toString();
        count++;
      }
      final minY = getVal('acc_min_y', 'accMinY');
      if (minY != null) {
        _minYController.text = minY.toString();
        count++;
      }
      final maxY = getVal('acc_max_y', 'accMaxY');
      if (maxY != null) {
        _maxYController.text = maxY.toString();
        count++;
      }
      final rangeY = getVal('acc_range_y', 'accRangeY');
      if (rangeY != null) {
        _rangeYController.text = rangeY.toString();
        count++;
      } else if (minY != null && maxY != null) {
        final minD = double.tryParse(minY.toString());
        final maxD = double.tryParse(maxY.toString());
        if (minD != null && maxD != null) {
          _rangeYController.text = (maxD - minD).toStringAsFixed(1);
          count++;
        }
      }
      final accLargestDist = getVal('acc_largest_distance', 'accLargestDistance', 'largest_distance') ??
          getVal('acc_extreme_spread', 'accExtremeSpread');
      if (accLargestDist != null) {
        _accLargestDistanceController.text = accLargestDist.toString();
        count++;
      }
      final distVal = getVal('distance', 'dist');
      if (distVal != null) {
        _distanceController.text = distVal.toString();
        count++;
      }
      // EPVAT Pressure & Velocity extraction
      final epvatMean = getVal('epvat_mean_pressure', 'epvatMeanPressure');
      if (epvatMean != null) {
        _epvatMeanPressureController.text = epvatMean.toString();
        count++;
      }
      final epvatMax = getVal('epvat_max_pressure', 'epvatMaxPressure');
      if (epvatMax != null) {
        _epvatMaxPressureController.text = epvatMax.toString();
        count++;
      }
      final epvatMin = getVal('epvat_min_pressure', 'epvatMinPressure');
      if (epvatMin != null) {
        _epvatMinPressureController.text = epvatMin.toString();
        count++;
      }
      final epvatRange = getVal('epvat_range_pressure', 'epvatRangePressure');
      if (epvatRange != null) {
        _epvatRangePressureController.text = epvatRange.toString();
        count++;
      }
      final epvatSd = getVal('epvat_sd_pressure', 'epvatSDPressure');
      if (epvatSd != null) {
        _epvatSDPressureController.text = epvatSd.toString();
        count++;
      }

      final epvatP2 = getVal('epvat_p2_mean', 'epvatP2MeanPressure', 'epvatP2Mean');
      if (epvatP2 != null) {
        _epvatP2MeanPressureController.text = epvatP2.toString();
        count++;
      }
      final epvatP2Max = getVal('epvat_p2_max', 'epvatP2MaxPressure', 'epvatP2Max');
      if (epvatP2Max != null) {
        _epvatP2MaxPressureController.text = epvatP2Max.toString();
        count++;
      }
      final epvatP2Min = getVal('epvat_p2_min', 'epvatP2MinPressure', 'epvatP2Min');
      if (epvatP2Min != null) {
        _epvatP2MinPressureController.text = epvatP2Min.toString();
        count++;
      }
      final epvatP2Range = getVal('epvat_p2_range', 'epvatP2RangePressure', 'epvatP2Range');
      if (epvatP2Range != null) {
        _epvatP2RangePressureController.text = epvatP2Range.toString();
        count++;
      }
      final epvatP2Sd = getVal('epvat_p2_sd', 'epvatP2SDPressure', 'epvatP2SD');
      if (epvatP2Sd != null) {
        _epvatP2SDPressureController.text = epvatP2Sd.toString();
        count++;
      }

      final actMean = getVal('action_time_mean', 'actionTimeMean');
      if (actMean != null) {
        _actionTimeMeanController.text = actMean.toString();
        count++;
      }
      final actMax = getVal('action_time_max', 'actionTimeMax');
      if (actMax != null) {
        _actionTimeMaxController.text = actMax.toString();
        count++;
      }
      final actMin = getVal('action_time_min', 'actionTimeMin');
      if (actMin != null) {
        _actionTimeMinController.text = actMin.toString();
        count++;
      }
      final actRange = getVal('action_time_range', 'actionTimeRange');
      if (actRange != null) {
        _actionTimeRangeController.text = actRange.toString();
        count++;
      }
      final actSd = getVal('action_time_sd', 'actionTimeSD');
      if (actSd != null) {
        _actionTimeSDController.text = actSd.toString();
        count++;
      }

      final t4MeanVal = getVal('t4_mean', 't4Mean');
      if (t4MeanVal != null) {
        _t4MeanController.text = t4MeanVal.toString();
        count++;
      }
      final t4MaxVal = getVal('t4_max', 't4Max');
      if (t4MaxVal != null) {
        _t4MaxController.text = t4MaxVal.toString();
        count++;
      }
      final t4MinVal = getVal('t4_min', 't4Min');
      if (t4MinVal != null) {
        _t4MinController.text = t4MinVal.toString();
        count++;
      }
      final t4RangeVal = getVal('t4_range', 't4Range');
      if (t4RangeVal != null) {
        _t4RangeController.text = t4RangeVal.toString();
        count++;
      }
      final t4SdVal = getVal('t4_sd', 't4SD');
      if (t4SdVal != null) {
        _t4SDController.text = t4SdVal.toString();
        count++;
      }

      final sensor1 = getVal('epvat_sensor1', 'epvatSensor1', 'transducer1', 'transducer_1')?.toString().trim();
      if (sensor1 != null && sensor1.isNotEmpty) {
        _epvatSensor1Controller.text = sensor1;
        count++;
      }
      final sensor2 = getVal('epvat_sensor2', 'epvatSensor2', 'transducer2', 'transducer_2')?.toString().trim();
      if (sensor2 != null && sensor2.isNotEmpty) {
        _epvatSensor2Controller.text = sensor2;
        count++;
      }

      final unitVal = getVal('epvat_pressure_unit', 'epvatPressureUnit')?.toString().trim();
      if (unitVal != null && unitVal.isNotEmpty) {
        if (unitVal.contains('kg/cm')) {
          _epvatPressureUnit = 'kg/cm²';
          count++;
        } else if (unitVal.toLowerCase() == 'bar') {
          _epvatPressureUnit = 'bar';
          count++;
        } else if (unitVal.toLowerCase() == 'mpa') {
          _epvatPressureUnit = 'MPa';
          count++;
        } else if (unitVal.toUpperCase() == 'PSI') {
          _epvatPressureUnit = 'PSI';
          count++;
        }
      }

      // Populate active temperature's controllers if in EPVAT Overall mode
      if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
        final cartridgeTemp = getVal('cartridge_temp', 'cartridgeTemp')?.toString().trim();
        if (cartridgeTemp != null && cartridgeTemp.isNotEmpty) {
          _cartridgeTempController.text = cartridgeTemp;
          if (cartridgeTemp.contains('21')) {
            _activeEpvatTempTabIndex = 0;
          } else if (cartridgeTemp.contains('52')) {
            _activeEpvatTempTabIndex = 1;
          } else if (cartridgeTemp.contains('54')) {
            _activeEpvatTempTabIndex = 2;
          }
          count++;
        }

        final currentTemp = ['+21', '+52', '-54'][_activeEpvatTempTabIndex];
        final tempCtrlMap = _overallEpvatControllers[currentTemp];
        if (tempCtrlMap != null) {
          if (epvatMean != null) tempCtrlMap['p1_mean']?.text = epvatMean.toString();
          if (epvatMax != null) tempCtrlMap['p1_max']?.text = epvatMax.toString();
          if (epvatMin != null) tempCtrlMap['p1_min']?.text = epvatMin.toString();
          if (epvatSd != null) tempCtrlMap['p1_sd']?.text = epvatSd.toString();
          if (epvatRange != null) tempCtrlMap['p1_range']?.text = epvatRange.toString();

          if (epvatP2 != null) tempCtrlMap['p2_mean']?.text = epvatP2.toString();
          if (epvatP2Max != null) tempCtrlMap['p2_max']?.text = epvatP2Max.toString();
          if (epvatP2Min != null) tempCtrlMap['p2_min']?.text = epvatP2Min.toString();
          if (epvatP2Sd != null) tempCtrlMap['p2_sd']?.text = epvatP2Sd.toString();
          if (epvatP2Range != null) tempCtrlMap['p2_range']?.text = epvatP2Range.toString();

          if (velMean != null) tempCtrlMap['vel_mean']?.text = velMean.toString();
          if (velMax != null) tempCtrlMap['vel_max']?.text = velMax.toString();
          if (velMin != null) tempCtrlMap['vel_min']?.text = velMin.toString();
          if (velSd != null) tempCtrlMap['vel_sd']?.text = velSd.toString();
          if (velRange != null) tempCtrlMap['vel_range']?.text = velRange.toString();

          if (actMean != null) tempCtrlMap['action_time_mean']?.text = actMean.toString();
          if (actMax != null) tempCtrlMap['action_time_max']?.text = actMax.toString();
          if (actMin != null) tempCtrlMap['action_time_min']?.text = actMin.toString();
          if (actSd != null) tempCtrlMap['action_time_sd']?.text = actSd.toString();
          if (actRange != null) tempCtrlMap['action_time_range']?.text = actRange.toString();

          if (t4MeanVal != null) tempCtrlMap['t4_mean']?.text = t4MeanVal.toString();
          if (t4MaxVal != null) tempCtrlMap['t4_max']?.text = t4MaxVal.toString();
          if (t4MinVal != null) tempCtrlMap['t4_min']?.text = t4MinVal.toString();
          if (t4SdVal != null) tempCtrlMap['t4_sd']?.text = t4SdVal.toString();
          if (t4RangeVal != null) tempCtrlMap['t4_range']?.text = t4RangeVal.toString();
        }

        // Individual Rounds Population
        final p1RoundsRaw = getVal('epvat_pressure_rounds', 'epvatPressureRounds')?.toString();
        final p2RoundsRaw = getVal('epvat_p2_pressure_rounds', 'epvatP2PressureRounds')?.toString();
        final taRoundsRaw = getVal('action_time_rounds', 'actionTimeRounds')?.toString();
        final velRoundsRaw = getVal('epvat_vel_rounds', 'epvatVelRounds')?.toString();
        final t4RoundsRaw = getVal('t4_rounds', 't4Rounds')?.toString();

        final p1List = p1RoundsRaw != null ? p1RoundsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : <String>[];
        final p2List = p2RoundsRaw != null ? p2RoundsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : <String>[];
        final taList = taRoundsRaw != null ? taRoundsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : <String>[];
        final velList = velRoundsRaw != null ? velRoundsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : <String>[];
        final t4List = t4RoundsRaw != null ? t4RoundsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : <String>[];

        if (p1List.isNotEmpty) {
          final shotCount = p1List.length;
          _syncIndividualRoundsControllers(shotCount);
          while (_t4RoundsControllers.length < shotCount) {
            _t4RoundsControllers.add(TextEditingController());
          }
          for (int i = 0; i < shotCount; i++) {
            if (i < _epvatRoundsControllers.length) _epvatRoundsControllers[i].text = p1List[i];
            if (i < p2List.length && i < _epvatP2RoundsControllers.length) _epvatP2RoundsControllers[i].text = p2List[i];
            if (i < taList.length && i < _actionTimeRoundsControllers.length) _actionTimeRoundsControllers[i].text = taList[i];
            if (i < velList.length && i < _epvatVelRoundsControllers.length) _epvatVelRoundsControllers[i].text = velList[i];
            if (i < t4List.length && i < _t4RoundsControllers.length) _t4RoundsControllers[i].text = t4List[i];
          }

          _epvatOverallRoundCount[currentTemp] = shotCount;
          _epvatOverallSubMode[currentTemp] = 'Individual Rounds';
          _epvatSingleSubMode = 'Individual Rounds';

          final p1CtrlList = _overallEpvatP1RoundsControllers[currentTemp];
          final p2CtrlList = _overallEpvatP2RoundsControllers[currentTemp];
          final taCtrlList = _overallEpvatActionTimeRoundsControllers[currentTemp];
          final velCtrlList = _overallEpvatVelRoundsControllers[currentTemp];
          final t4CtrlList = _overallEpvatT4RoundsControllers[currentTemp];

          if (p1CtrlList != null) {
            for (int i = 0; i < p1List.length && i < p1CtrlList.length; i++) {
              p1CtrlList[i].text = p1List[i];
            }
          }
          if (p2CtrlList != null) {
            for (int i = 0; i < p2List.length && i < p2CtrlList.length; i++) {
              p2CtrlList[i].text = p2List[i];
            }
          }
          if (taCtrlList != null) {
            for (int i = 0; i < taList.length && i < taCtrlList.length; i++) {
              taCtrlList[i].text = taList[i];
            }
          }
          if (velCtrlList != null) {
            for (int i = 0; i < velList.length && i < velCtrlList.length; i++) {
              velCtrlList[i].text = velList[i];
            }
          }
          if (t4CtrlList != null) {
            for (int i = 0; i < t4List.length && i < t4CtrlList.length; i++) {
              t4CtrlList[i].text = t4List[i];
            }
          }
          _producedController.text = '$shotCount';
          count += shotCount;
        }
      }
      final cyclicRpm = getVal('cyclic_rpm', 'cyclicRpm');
      if (cyclicRpm != null) {
        _cyclicRateController.text = cyclicRpm.toString();
        count++;
      }
      final primerTotalRounds = getVal('primer_total_rounds', 'primerTotalRounds', 'primer_total_tested', 'primerTotalTested');
      if (primerTotalRounds != null) {
        _producedController.text = primerTotalRounds.toString();
        count++;
      }
      final primerHbar = getVal('primer_hbar', 'primerHbar');
      if (primerHbar != null) {
        _primerHbarController.text = primerHbar.toString();
        count++;
      }
      final primerSd = getVal('primer_sd', 'primerSd');
      if (primerSd != null) {
        _primerSDController.text = primerSd.toString();
        count++;
      }
      final primerAllFire = getVal('primer_all_fire', 'primerAllFire');
      if (primerAllFire != null) {
        _primerHbarPlus5SController.text = primerAllFire.toString();
        count++;
      }
      final primerNoFire = getVal('primer_no_fire', 'primerNoFire');
      if (primerNoFire != null) {
        _primerHbarMinus2SController.text = primerNoFire.toString();
        count++;
      }
      if (_primerHbarController.text.isNotEmpty && _primerSDController.text.isNotEmpty) {
        final h = double.tryParse(_primerHbarController.text.trim());
        final s = double.tryParse(_primerSDController.text.trim());
        if (h != null && s != null) {
          if (_primerHbarPlus5SController.text.isEmpty) {
            _primerHbarPlus5SController.text = (h + 5 * s).toStringAsFixed(2);
          }
          if (_primerHbarMinus2SController.text.isEmpty) {
            _primerHbarMinus2SController.text = (h - 2 * s).toStringAsFixed(2);
          }
        }
      }

      final dropTableRaw = getVal('primer_drop_table', 'primerDropTable');
      if (dropTableRaw != null && dropTableRaw.toString().isNotEmpty) {
        _loadPrimerDropTableFromJson(dropTableRaw.toString());
        count++;
      }
      final alpha3 = getVal('primer_alpha3', 'primerAlpha3', 'alpha3');
      if (alpha3 != null) {
        _primerAlpha3Controller.text = alpha3.toString();
        count++;
      }
      final emax = getVal('primer_emax', 'primerEmax', 'emax');
      if (emax != null) {
        _primerEmaxController.text = emax.toString();
        count++;
      }
      final emin = getVal('primer_emin', 'primerEmin', 'emin');
      if (emin != null) {
        _primerEminController.text = emin.toString();
        count++;
      }

      final primerSup = getVal('primer_supplier', 'primerSupplier', 'supplier')?.toString().trim();
      if (primerSup != null && primerSup.isNotEmpty) {
        String effectiveSup = primerSup;
        final lowerSup = primerSup.toLowerCase();
        if (lowerSup == 'ug' || lowerSup.contains('ginex') || lowerSup.contains('ginix')) {
          effectiveSup = 'UNIS "GINEX"';
        }
        final existing = _primerSuppliers.firstWhere(
          (s) => s.toLowerCase() == effectiveSup.toLowerCase(),
          orElse: () => '',
        );
        if (existing.isNotEmpty) {
          _primerSupplier = existing;
        } else {
          if (!_localAddedPrimerSuppliers.contains(effectiveSup)) {
            _localAddedPrimerSuppliers.add(effectiveSup);
          }
          _primerSupplier = effectiveSup;
        }
        count++;
      }

      final pDepth = getVal('primer_insertion_depth', 'primerInsertionDepth')?.toString().trim();
      if (pDepth != null && pDepth.isNotEmpty) {
        _primerInsertionDepthController.text = pDepth;
        count++;
      }

      final pLot = getVal('primer_lot', 'primerLot', 'component_primer_lot')?.toString().trim();
      if (pLot != null && pLot.isNotEmpty) {
        _primerLotController.text = pLot;
        if (_lotController.text.isEmpty || _testName == 'Primer Sensitivity Test') {
          _lotController.text = pLot;
        }
        count++;
      }

      final pMisfires = getVal('primer_total_misfires', 'primerTotalMisfires', 'misfires');
      if (pMisfires != null) {
        _primerMisfiresCountController.text = pMisfires.toString();
        _defectsController.text = pMisfires.toString();
        count++;
      }

      final roomTemp = getVal('room_temp', 'roomTemp', 'cartridge_temp', 'cartridgeTemp')?.toString().trim();
      if (roomTemp != null && roomTemp.isNotEmpty) {
        _roomTempController.text = roomTemp;
        _cartridgeTempController.text = roomTemp;
        count++;
      }

      final testTimeVal = getVal('testTime', 'test_time', 'testDate', 'test_date')?.toString().trim();
      if (testTimeVal != null && testTimeVal.isNotEmpty) {
        _testTimeController.text = testTimeVal;
        count++;
      }

      final cartridgeTemp = getVal('cartridge_temp', 'cartridgeTemp');
      if (cartridgeTemp != null) {
        _cartridgeTempController.text = cartridgeTemp.toString();
        count++;
      }
      final barrelSn = getVal('barrel_sn', 'barrelSn');
      if (barrelSn != null && _barrelSNController.text.isEmpty) {
        _barrelSNController.text = barrelSn.toString();
        count++;
      }
      final lotDigits = getVal('lotDigits', 'lot_digits')?.toString().trim();
      final lotYear = getVal('lotYear', 'lot_year')?.toString().trim();
      final lotVal = getVal('lot_number', 'lotNo', 'lot')?.toString().trim();
      if (lotDigits != null && lotDigits.isNotEmpty) {
        _lotThreeDigitsController.text = lotDigits.padLeft(3, '0');
        _hopperThreeDigitsController.text = lotDigits.padLeft(3, '0');
        count++;
        if (lotYear != null && lotYear.isNotEmpty) {
          _lotYearController.text = lotYear;
          _hopperYearController.text = lotYear;
        }
        if (lotVal != null && lotVal.isNotEmpty) {
          _lotController.text = lotVal;
        }
      } else if (lotVal != null && lotVal.isNotEmpty) {
        final lotReg = RegExp(r'(?:Lot\s*)?(\d{1,4})\s*(?:OMPC[/\s]*)?(\d{2})?', caseSensitive: false).firstMatch(lotVal);
        if (lotReg != null) {
          final digits = lotReg.group(1);
          final yr = lotReg.group(2);
          if (digits != null) {
            _lotThreeDigitsController.text = digits.padLeft(3, '0');
            _hopperThreeDigitsController.text = digits.padLeft(3, '0');
            count++;
          }
          if (yr != null) {
            _lotYearController.text = yr;
            _hopperYearController.text = yr;
          }
        }
        if (_lotController.text.isEmpty) {
          _lotController.text = lotVal;
        }
      }
      final opVal = getVal('operator_name', 'operators', 'operator')?.toString().trim();
      if (opVal != null && opVal.isNotEmpty) {
        _operatorsController.text = opVal;
        count++;
      }
      final extractedNotes = getVal('notes', 'comments', 'comment');
      if (extractedNotes != null && extractedNotes.toString().isNotEmpty && _notesController.text.isEmpty) {
        _notesController.text = extractedNotes.toString();
        count++;
      }
    });

    if (count > 0) {
      if (extractionRes.detectedTest == 'Primer Sensitivity Test' && widget.currentModule == 'Lot Acceptance Test') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-extracted $count parameters from Primer Sensitivity report! Note: Primer sensitivity tests are recorded in the "Component Test" module. Switch tabs above to view or submit this component lot.'),
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 7),
          ),
        );
      } else if (extractionRes.detectedTest.isNotEmpty && extractionRes.detectedTest != 'Primer Sensitivity Test' && extractionRes.detectedTest != 'Propellant Test' && widget.currentModule == 'Component Test') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-extracted $count parameters from ${extractionRes.detectedTest} report! Note: Ballistic tests are recorded in the "Lot Acceptance Test" module. Switch tabs above to view or submit this ballistic lot.'),
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 7),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-extracted $count parameters for $_testName!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No matching parameters could be detected automatically. Opening paste dialog to inspect text.'),
          backgroundColor: Color(0xFFF59E0B),
          duration: Duration(seconds: 4),
        ),
      );
      _showAutoExtractModal(content);
    }
  }

  void _autoExtractFromAttachment(String filename, String rawBase64) {
    try {
      if (rawBase64.isEmpty) return;
      String cleanBase64 = rawBase64.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.substring(cleanBase64.indexOf(',') + 1);
      }
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(cleanBase64);
      final isPdf = filename.toLowerCase().endsWith('.pdf') ||
          (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46);

      String content = '';
      if (isPdf) {
        content = PdfTextExtractor.extractText(bytes);
      } else if (filename.toLowerCase().endsWith('.csv') ||
          filename.toLowerCase().endsWith('.tsv') ||
          filename.toLowerCase().endsWith('.txt') ||
          filename.toLowerCase().endsWith('.json') ||
          filename.toLowerCase().endsWith('.log')) {
        content = utf8.decode(bytes, allowMalformed: true);
      }

      if (content.trim().isNotEmpty) {
        _applyExtractedResults(content);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract text automatically from this file. Opening paste dialog...'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 4),
          ),
        );
        _showAutoExtractModal();
      }
    } catch (e) {
      debugPrint('Error auto-extracting from attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error auto-extracting from attachment: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Header with Cancel Test Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${widget.currentModule} Log Entry',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 12.0),
                        const Expanded(
                          child: Text(
                            'Log fresh ballistic trial, lot tolerances, and mechanical parameters',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Color(0xFF475569),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),
                ElevatedButton.icon(
                  onPressed: _showAutoExtractModal,
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                  label: const Text(
                    'Auto-Extract Results (Upload/Paste)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8.0),
                OutlinedButton.icon(
                  onPressed: _openReportWithoutSaving,
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0284C7), size: 15),
                  label: const Text(
                    'Open Report Without Saving',
                    style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7), width: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8.0),
                OutlinedButton.icon(
                  onPressed: _confirmCancelTest,
                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 15),
                  label: const Text(
                    'Cancel Test',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),

            // Form container card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFFB8CEE5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A1E3A8A),
                    blurRadius: 10.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auto-Save Status Banner
                  if (_autoSaveStatus.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6.0),
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
                    Builder(
                      builder: (context) {
                        final adminTech = (widget.adminRules['technician_name'] ?? widget.adminRules['cert_technician_name'] ?? '').toString().trim();
                        return _buildFlexibleField(
                          flex: 3,
                          label: 'Technician (for Report Signature)',
                          isRequired: false,
                          child: adminTech.isNotEmpty
                              ? _buildTextField(
                                  controller: _technicianController,
                                  readOnly: true,
                                  hint: adminTech,
                                )
                              : (widget.userRole.toLowerCase() == 'technician'
                                  ? _buildTextField(
                                      controller: _technicianController,
                                      readOnly: true,
                                      hint: widget.loggedInUser.isNotEmpty ? widget.loggedInUser : 'Ballistics Technician',
                                    )
                                  : _buildDropdownField(
                                      value: _technicianController.text,
                                      items: _registeredTechnicians,
                                      allowEmpty: true,
                                      hintText: 'Select Technician for Signature...',
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _technicianController.text = v);
                                        }
                                      },
                                    )),
                        );
                      },
                    ),
                    _buildFlexibleField(
                      key: _shiftFieldKey,
                      flex: 1,
                      label: 'Shift',
                      isRequired: true,
                      child: _buildDropdownField(
                        value: ['Morning', 'Afternoon'].contains(_shift) ? _shift : 'Morning',
                        items: ['Morning', 'Afternoon'],
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
                      flex: 2,
                      label: 'Caliber Specification',
                      isRequired: true,
                      child: _buildDropdownField(
                        value: _caliber,
                        items: calibers,
                        allowEmpty: true,
                        hintText: 'Select Caliber Specification...',
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
                              ? (_testName == 'Primer Sensitivity Test'
                                  ? 'Primer Lot No.'
                                  : (_testName == 'Accuracy Test' ? 'Lot of Shipment' : 'Propellant Lot No.'))
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
                        allowEmpty: true,
                        hintText: 'Select Test Name...',
                        onChanged: (v) {
                          if (v != null) _onTestNameSelected(v);
                        },
                      ),
                    ),
                  ], lockSingleRow: true),
                  const SizedBox(height: 4.0),
                  _buildComponentAndPrimerFieldsCard(),
                  _buildAdminInstructionsCard(),

                  if (_testName.isEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 20.0),
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.arrow_upward_rounded, color: Color(0xFF0284C7), size: 30.0),
                            SizedBox(height: 10.0),
                            Text(
                              'Please select Caliber Specification and Test Name in the header above to begin test entry.',
                              style: TextStyle(color: Color(0xFF0369A1), fontSize: 13.5, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Function Test Specifications Sub-Card (Dynamic)
                    if (_testName == 'Function Test') ...[
                      _buildFunctionTestSpecsCard(),
                      const SizedBox(height: 4.0),
                    ],

                    // Consolidated Row 2 (Viscosity, Sampling Location, Quality Status, Quantity Tested, Barrel Number, Transducers in 1 or max 2 rows)
                    _buildConsolidatedRow2(),
                    const SizedBox(height: 4.0),

                  // Function Test 4-Level Defects Section (Dynamic)
                  if (_testName == 'Function Test') ...[
                    _buildFunctionTestDefectsCard(),
                    const SizedBox(height: 4.0),
                  ],

                  // Waterproof Leakage Test Results Section (Dynamic)
                  if (_testName == 'Waterproof Test') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FB),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.list_alt_outlined, color: Color(0xFF0284C7), size: 16.0),
                              SizedBox(width: 6.0),
                              Text(
                                'Test Result (Waterproof Leaks)',
                                style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),

                          // TABLE HEADERS
                          Row(
                            children: const [
                              Expanded(
                                flex: 2,
                                child: Text('Location', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Slow Leak (Rounds)', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Fast Leak (Rounds)', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFFE2E8F0), height: 6.0),

                          // ROW 1: MOUTH
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Mouth', style: TextStyle(color: Color(0xFF1E293B), fontSize: 12.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _mouthSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _mouthFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),

                          // ROW 2: PRIMER
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Primer', style: TextStyle(color: Color(0xFF1E293B), fontSize: 12.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _primerSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _primerFastController),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFFE2E8F0), height: 6.0),

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
                                      fontSize: 12.0,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                                    decoration: BoxDecoration(
                                      color: isRed ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4.0),
                                      border: Border.all(color: isRed ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isRed) ...[
                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 12.0),
                                          const SizedBox(width: 4.0),
                                        ],
                                        Text(
                                          '$total Leaks',
                                          style: TextStyle(
                                            color: isRed ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
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
                    const SizedBox(height: 4.0),
                  ],

                  // Residual Stress Test UI (Dynamic)
                  if (_testName == 'Residual Stress Test') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FB),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.report_problem_outlined, color: Color(0xFF0284C7), size: 16.0),
                                  SizedBox(width: 6.0),
                                  Text(
                                    'Residual Stress Test (Splits/Cracks)',
                                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                  ),
                                ],
                              ),
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

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                                    decoration: BoxDecoration(
                                      color: isRed ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4.0),
                                      border: Border.all(color: isRed ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isRed) ...[
                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 12.0),
                                          const SizedBox(width: 4.0),
                                        ],
                                        Text(
                                          '$total Splits/Cracks',
                                          style: TextStyle(
                                            color: isRed ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            fontFamily: 'JetBrainsMono',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),
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
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
                                  if (_isAdmin) ...[
                                    const SizedBox(width: 6.0),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.0),
                                        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF0284C7), size: 16),
                                        tooltip: 'Admin: Add new sample location',
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        onPressed: _showAddLocationDialog,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4.0),

                          // TABLE HEADERS
                          Row(
                            children: const [
                              Expanded(
                                flex: 2,
                                child: Text('Crack Zone', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Hairline Crack (Minor)', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Split/Crack (Major)', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFFE2E8F0), height: 6.0),

                          // ROW 1: Neck (I zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Neck (I zone)', style: TextStyle(color: Color(0xFF1E293B), fontSize: 12.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _neckSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _neckFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),

                          // ROW 2: Shoulder (S zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Shoulder (S zone)', style: TextStyle(color: Color(0xFF1E293B), fontSize: 12.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _shoulderSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _shoulderFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),

                          // ROW 3: Body (J & K zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Body (J & K zone)', style: TextStyle(color: Color(0xFF1E293B), fontSize: 12.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _bodySlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _bodyFastController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),

                          // ROW 4: Head (L & M zone)
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('Head (L & M zone)', style: TextStyle(color: Color(0xFF1E293B), fontSize: 12.0, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _headSlowController),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildLeakTextField(controller: _headFastController),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4.0),

                    // Collapsible Cartridge Reference Diagram
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FB),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8.0),
                            onTap: () => setState(() => _showResidualDiagram = !_showResidualDiagram),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.photo_outlined, color: Color(0xFF0284C7), size: 16.0),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    _isCaliber9mm ? '9mm Residual Stress Reference Diagram' : '5.56 / 7.62 Residual Stress Reference Diagram',
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.0, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _showResidualDiagram ? 'Hide Diagram' : 'Show Diagram',
                                    style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.w600),
                                  ),
                                  Icon(
                                    _showResidualDiagram ? Icons.expand_less : Icons.expand_more,
                                    color: const Color(0xFF0284C7),
                                    size: 16.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showResidualDiagram) ...[
                            const Divider(color: Color(0xFFD6E4F0), height: 1.0),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(
                                child: Tooltip(
                                  message: 'Click to view diagram fullscreen / zoom',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8.0),
                                    onTap: () {
                                      final asset = _isCaliber9mm ? 'assets/cartridge_9mm.png' : 'assets/cartridge_bottleneck.png';
                                      final title = _isCaliber9mm ? '9mm Residual Stress Reference Diagram' : '5.56 / 7.62 Residual Stress Reference Diagram';
                                      _showZoomDiagramDialog(asset, title);
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.asset(
                                        _isCaliber9mm ? 'assets/cartridge_9mm.png' : 'assets/cartridge_bottleneck.png',
                                        height: 260,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4.0),
                  ],

                  // Cyclic Rate Test UI
                  if (_testName == 'Firing Rate Cycle Test') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FB),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.speed_outlined, color: Color(0xFF0284C7), size: 16.0),
                              SizedBox(width: 6.0),
                              Text('Firing Rate Cycle Test', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                            ],
                          ),
                          const SizedBox(height: 4.0),
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

                            return _buildFormRow([
                              _buildFlexibleField(
                                flex: 2,
                                label: 'Category',
                                child: Row(
                                  children: [
                                    _buildCyclicAmmoRadio('Rifle'),
                                    const SizedBox(width: 8.0),
                                    _buildCyclicAmmoRadio('Machine Gun'),
                                  ],
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 3,
                                label: 'Weapon Type',
                                child: weapons.isEmpty
                                    ? const Text('No weapons', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11.0))
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(6.0),
                                          border: Border.all(color: const Color(0xFF7DD3FC)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: weapons.any((w) => w['name'] == _cyclicRateWeaponType) ? _cyclicRateWeaponType : (weapons.isNotEmpty ? weapons.first['name'] as String : ''),
                                            isExpanded: true,
                                            dropdownColor: const Color(0xFFE0F2FE),
                                            style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.0, fontWeight: FontWeight.w600),
                                            onChanged: (val) => setState(() => _cyclicRateWeaponType = val ?? ''),
                                            items: weapons.map((w) => DropdownMenuItem<String>(value: w['name'] as String, child: Text(w['name'] ?? '', style: const TextStyle(color: Color(0xFF0C2A4D))))).toList(),
                                          ),
                                        ),
                                      ),
                              ),
                              _buildFlexibleField(
                                flex: 2,
                                label: 'Cyclic Rate (RPM)',
                                isRequired: true,
                                child: _buildTextField(
                                  controller: _cyclicRateController,
                                  hint: 'Measured RPM',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) => setState(() {}),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final val = double.tryParse(v.trim());
                                    if (val == null) return 'Must be a number';
                                    if (val < rpmMin || (rpmMax != null && val > rpmMax)) {
                                      return rpmMax == null ? '\u2265 $rpmMin' : '$rpmMin\u2013$rpmMax';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              _buildFlexibleField(
                                flex: 2,
                                label: 'Limit ($_cyclicRateAmmoType)',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                  decoration: BoxDecoration(
                                    color: isOutOfRange ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6.0),
                                    border: Border.all(color: isOutOfRange ? const Color(0xFFEF4444).withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isOutOfRange) ...const [
                                        Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 13.0),
                                        SizedBox(width: 4.0),
                                      ],
                                      Text(
                                        rpmMax == null ? '\u2265 $rpmMin RPM' : '$rpmMin \u2013 $rpmMax RPM',
                                        style: TextStyle(
                                          color: isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'JetBrainsMono',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4.0),
                  ],

                  // Terminal Effect Test UI
                  if (_testName == 'Terminal Effect Test') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FB),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.gps_fixed_outlined, color: Color(0xFF0284C7), size: 16.0),
                              SizedBox(width: 6.0),
                              Text('Terminal Effect Test', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                            ],
                          ),
                          const SizedBox(height: 4.0),
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
                          Builder(builder: (context) {
                            final termRules = (widget.adminRules['terminal_effect'] is Map) ? widget.adminRules['terminal_effect'] as Map : {};
                            final p1Mat = (termRules['plate1_material'] ?? 'Steel').toString().trim();
                            final p1Thick = (termRules['plate1_thickness'] ?? '3.5 mm').toString().trim();
                            final p2Mat = (termRules['plate2_material'] ?? 'Aluminum').toString().trim();
                            final p2Thick = (termRules['plate2_thickness'] ?? '0.5 mm').toString().trim();
                            final p1Header = '$p1Mat ($p1Thick)';
                            final p2Header = '$p2Mat ($p2Thick)';

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Table(
                                defaultColumnWidth: const FixedColumnWidth(120.0),
                                columnWidths: const {
                                  0: FixedColumnWidth(50.0),   // Round #
                                  1: FixedColumnWidth(150.0),  // Hole Diameter
                                  2: FixedColumnWidth(150.0),  // Plate 1 Penetration
                                  3: FixedColumnWidth(150.0),  // Plate 2 Penetration
                                  4: FixedColumnWidth(120.0),  // Velocity (m/s)
                                },
                                children: [
                                  // Table Header
                                  TableRow(
                                    children: [
                                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), child: Text('Round', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), child: Text('Hole > Bullet?', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), child: Text('$p1Header Penetration', style: const TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), child: Text('$p2Header Penetration', style: const TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), child: Text('Velocity (m/s)', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                // Table Rows
                                ...List.generate(_getTerminalVisibleRounds(), (idx) {
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
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Color(0xFF1E293B), fontSize: 12.0))),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: const Color(0xFF7DD3FC)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _terminalHoleDiameterRounds[idx],
                                              dropdownColor: const Color(0xFFE0F2FE),
                                              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 11.5, fontWeight: FontWeight.w600),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: const Color(0xFF7DD3FC)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _terminalSteelPenetrationRounds[idx],
                                              dropdownColor: const Color(0xFFE0F2FE),
                                              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 11.5, fontWeight: FontWeight.w600),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: const Color(0xFF7DD3FC)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _terminalAluminumPenetrationRounds[idx],
                                              dropdownColor: const Color(0xFFE0F2FE),
                                              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 11.5, fontWeight: FontWeight.w600),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
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
                          );
                        }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4.0),
                  ],

                  if (_isAccuracyOrBullet) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FB),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.gps_fixed_outlined, color: Color(0xFF0284C7), size: 16.0),
                              const SizedBox(width: 6.0),
                              const Text(
                                'Accuracy Test Specifications',
                                style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (_attachmentBase64.isNotEmpty && _attachmentName.toLowerCase().endsWith('.pdf')) {
                                    _autoExtractFromAttachment(_attachmentName, _attachmentBase64);
                                  } else {
                                    final res = await getAttachmentHelper().pickFileAsBase64();
                                    if (res != null && res['name'] != null && res['data'] != null) {
                                      setState(() {
                                        _attachmentName = res['name']!;
                                        _attachmentBase64 = res['data']!;
                                      });
                                      _autoExtractFromAttachment(res['name']!, res['data']!);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.picture_as_pdf, size: 14.0, color: Colors.white),
                                label: const Text('Auto-Extract from PDF Report', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                                  elevation: 1,
                                ),
                              ),
                            ],
                          ),
                          if (_caliber == '5.56x45 M193') ...[
                            const SizedBox(height: 4.0),
                            const Text(
                              'Coordinate Target Deviation / Mean Radius (mm)',
                              style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2.0),
                            _buildFormRow([
                              _buildFlexibleField(
                                flex: 1,
                                label: 'SD of X',
                                isRequired: true,
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
                                isRequired: true,
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
                                isRequired: true,
                                child: _buildTextField(
                                  controller: _meanRadiusController,
                                  hint: '0.0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                ),
                              ),
                            ]),
                          ] else ...[
                            const SizedBox(height: 6.0),
                            Builder(
                              builder: (ctx) {
                                final distRaw = _distanceController.text.trim();
                                final distNum = double.tryParse(distRaw);
                                final distStr = distNum != null ? distNum.toStringAsFixed(2) : (distRaw.isNotEmpty ? distRaw : '24.00');
                                final vHeader = 'V${distStr}_1 [m/s]';
                                return Container(
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Table Header
                                      Row(
                                        children: [
                                          const Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Statistic',
                                              style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 6.0),
                                          const Expanded(
                                            flex: 3,
                                            child: Text(
                                              'x_1 [mm]',
                                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.0, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 6.0),
                                          const Expanded(
                                            flex: 3,
                                            child: Text(
                                              'y_1 [mm]',
                                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.0, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 6.0),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              vHeader,
                                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.0, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 10.0, thickness: 1.0, color: Color(0xFFE2E8F0)),
                                      // MEAN Row
                                      _buildAccuracyMatrixRow(
                                        label: 'MEAN',
                                        ctrlX: _meanXController,
                                        ctrlY: _meanYController,
                                        ctrlVel: _meanVelController,
                                        readOnly: false,
                                      ),
                                      const SizedBox(height: 3.0),
                                      // MAX Row
                                      _buildAccuracyMatrixRow(
                                        label: 'MAX',
                                        ctrlX: _maxXController,
                                        ctrlY: _maxYController,
                                        ctrlVel: _maxVelController,
                                        readOnly: false,
                                      ),
                                      const SizedBox(height: 3.0),
                                      // MIN Row
                                      _buildAccuracyMatrixRow(
                                        label: 'MIN',
                                        ctrlX: _minXController,
                                        ctrlY: _minYController,
                                        ctrlVel: _minVelController,
                                        readOnly: false,
                                      ),
                                      const SizedBox(height: 3.0),
                                      // RANGE Row (strictly auto-calculated and read-only)
                                      _buildAccuracyMatrixRow(
                                        label: 'RANGE',
                                        ctrlX: _rangeXController,
                                        ctrlY: _rangeYController,
                                        ctrlVel: _rangeVelController,
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 3.0),
                                      // STDEV Row
                                      _buildAccuracyMatrixRow(
                                        label: 'STDEV',
                                        ctrlX: _sdXController,
                                        ctrlY: _sdYController,
                                        ctrlVel: _sdVelController,
                                        readOnly: false,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 4.0),
                          _buildFormRow([
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Largest Distance / Dispersion (mm)',
                              child: _buildTextField(
                                controller: _accLargestDistanceController,
                                hint: '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                            _buildFlexibleField(
                              flex: 1,
                              label: 'Mean Radius (mm)',
                              child: _buildTextField(
                                controller: _meanRadiusController,
                                hint: '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4.0),
                  ],

                  if (_testName == 'Extraction Force Test') ...[
                    _buildExtractionForceCard(),
                    const SizedBox(height: 4.0),
                  ],

                  if (_testName == 'EPVAT test' || _testName == 'Propellant Test') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FB),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.compress_outlined, color: Color(0xFF06B6D4), size: 18.0),
                              const SizedBox(width: 8.0),
                              const Text(
                                'EPVAT Pressure & Velocity Specifications',
                                style: TextStyle(color: Color(0xFF0F172A), fontSize: 13.0, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                              const SizedBox(width: 8.0),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (_attachmentBase64.isNotEmpty && _attachmentName.toLowerCase().endsWith('.pdf')) {
                                    _autoExtractFromAttachment(_attachmentName, _attachmentBase64);
                                  } else {
                                    final res = await getAttachmentHelper().pickFileAsBase64();
                                    if (res != null && res['name'] != null && res['data'] != null) {
                                      setState(() {
                                        _attachmentName = res['name']!;
                                        _attachmentBase64 = res['data']!;
                                      });
                                      _autoExtractFromAttachment(res['name']!, res['data']!);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.picture_as_pdf, size: 14.0, color: Colors.white),
                                label: const Text('Auto-Extract from PDF Report', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF06B6D4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                                  elevation: 1,
                                ),
                              ),
                              const Spacer(),
                              RichText(
                                text: const TextSpan(
                                  text: 'Unit',
                                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold),
                                  children: [
                                    TextSpan(
                                      text: ' *',
                                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 13.0, fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text: ': ',
                                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              _buildEpvatUnitRadioButton('bar', 'bar'),
                              const SizedBox(width: 6.0),
                              _buildEpvatUnitRadioButton('MPa', 'MPa'),
                              const SizedBox(width: 6.0),
                              _buildEpvatUnitRadioButton('kg/cm²', 'kg/cm²'),
                            ],
                          ),
                          const SizedBox(height: 6.0),
                          if (_epvatPressureType == 'Overall') ...[
                            Builder(
                              builder: (context) {
                                final tempKeys = ['+21', '+52', '-54'];
                                final labels = ['+21 °C', '+52 °C', '-54 °C'];
                                final t = tempKeys[_activeEpvatTempTabIndex];
                                final isIndividualMode = _epvatOverallSubMode[t] == 'Individual Rounds';

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ...List.generate(3, (idx) {
                                          final tKey = tempKeys[idx];
                                          final hasData = (_overallEpvatControllers[tKey]?['vel_mean']?.text.trim().isNotEmpty ?? false) ||
                                                          (_overallEpvatControllers[tKey]?['p1_mean']?.text.trim().isNotEmpty ?? false) ||
                                                          (_overallEpvatP1RoundsControllers[tKey]?.any((c) => c.text.trim().isNotEmpty) ?? false);
                                          final isSelected = _activeEpvatTempTabIndex == idx;
                                          return GestureDetector(
                                            onTap: () => setState(() => _activeEpvatTempTabIndex = idx),
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 6.0),
                                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(14.0),
                                                border: Border.all(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    labels[idx],
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                  if (hasData) ...[
                                                    const SizedBox(width: 4.0),
                                                    Icon(Icons.check_circle, size: 12.0, color: isSelected ? Colors.white : const Color(0xFF10B981)),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                        const Spacer(),
                                        const Text('Entry: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 4.0),
                                        ChoiceChip(
                                          visualDensity: VisualDensity.compact,
                                          label: const Text('Stats Only', style: TextStyle(fontSize: 11.0)),
                                          selected: _epvatOverallSubMode[t] == 'Stats Only',
                                          selectedColor: const Color(0xFF06B6D4),
                                          backgroundColor: const Color(0xFFE2E8F0),
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                _epvatOverallSubMode[t] = 'Stats Only';
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 6.0),
                                        ChoiceChip(
                                          visualDensity: VisualDensity.compact,
                                          label: const Text('Individual Rounds', style: TextStyle(fontSize: 11.0)),
                                          selected: _epvatOverallSubMode[t] == 'Individual Rounds',
                                          selectedColor: const Color(0xFF06B6D4),
                                          backgroundColor: const Color(0xFFE2E8F0),
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
                                    const SizedBox(height: 6.0),

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
                                              const Text('Rounds: ', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5)),
                                              const SizedBox(width: 6.0),
                                              DropdownButton<int>(
                                                value: _epvatOverallRoundCount[t] ?? 30,
                                                dropdownColor: Colors.white,
                                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5),
                                                isDense: true,
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
                                      const SizedBox(height: 4.0),
                                      Row(
                                        children: [
                                          const Expanded(flex: 1, child: Text('Round', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          Expanded(flex: 2, child: Text(_isCaliber9mm ? 'Chamber Pres.' : 'GP6 (1) Chamber', style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          if (!_isCaliber9mm)
                                            const Expanded(flex: 2, child: Text('GP6 (2) Port', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          const Expanded(flex: 2, child: Text('Action Time (ms)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                          const Expanded(flex: 2, child: Text('Velocity (m/s)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      const SizedBox(height: 4.0),
                                      Container(
                                        height: 180.0,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6.0),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                                          itemCount: _getOverallEpvatVisibleRounds(t),
                                          itemBuilder: (context, rIdx) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      'Round ${rIdx + 1}',
                                                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
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
                                                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                                        child: _buildTextField(
                                                          controller: _overallEpvatP2RoundsControllers[t]![rIdx],
                                                          hint: 'P2',
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        ),
                                                      ),
                                                    ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
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
                                                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                                      child: _buildTextField(
                                                        controller: _overallEpvatVelRoundsControllers[t]![rIdx],
                                                        hint: 'm/s',
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
                                      const SizedBox(height: 6.0),
                                    ],

                                    // 5x5 Transposed Specification Matrix Table
                                    _buildEpvatTransposedMatrixTable(
                                      meanP1Ctrl: _overallEpvatControllers[t]!['p1_mean']!,
                                      maxP1Ctrl: _overallEpvatControllers[t]!['p1_max']!,
                                      minP1Ctrl: _overallEpvatControllers[t]!['p1_min']!,
                                      rangeP1Ctrl: _overallEpvatControllers[t]!['p1_range']!,
                                      sdP1Ctrl: _overallEpvatControllers[t]!['p1_sd']!,

                                      meanP2Ctrl: _overallEpvatControllers[t]!['p2_mean']!,
                                      maxP2Ctrl: _overallEpvatControllers[t]!['p2_max']!,
                                      minP2Ctrl: _overallEpvatControllers[t]!['p2_min']!,
                                      rangeP2Ctrl: _overallEpvatControllers[t]!['p2_range']!,
                                      sdP2Ctrl: _overallEpvatControllers[t]!['p2_sd']!,

                                      meanT4Ctrl: _overallEpvatControllers[t]!['t4_mean']!,
                                      maxT4Ctrl: _overallEpvatControllers[t]!['t4_max']!,
                                      minT4Ctrl: _overallEpvatControllers[t]!['t4_min']!,
                                      rangeT4Ctrl: _overallEpvatControllers[t]!['t4_range']!,
                                      sdT4Ctrl: _overallEpvatControllers[t]!['t4_sd']!,

                                      meanTaCtrl: _overallEpvatControllers[t]!['action_time_mean']!,
                                      maxTaCtrl: _overallEpvatControllers[t]!['action_time_max']!,
                                      minTaCtrl: _overallEpvatControllers[t]!['action_time_min']!,
                                      rangeTaCtrl: _overallEpvatControllers[t]!['action_time_range']!,
                                      sdTaCtrl: _overallEpvatControllers[t]!['action_time_sd']!,

                                      meanVelCtrl: _overallEpvatControllers[t]!['vel_mean']!,
                                      maxVelCtrl: _overallEpvatControllers[t]!['vel_max']!,
                                      minVelCtrl: _overallEpvatControllers[t]!['vel_min']!,
                                      rangeVelCtrl: _overallEpvatControllers[t]!['vel_range']!,
                                      sdVelCtrl: _overallEpvatControllers[t]!['vel_sd']!,
                                      readOnly: isIndividualMode,
                                    ),

                                    // Kinetic Energy Display (only for +21°C tab)
                                    if (t == '+21') ...[
                                      const SizedBox(height: 4.0),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.bolt, color: Color(0xFF6366F1), size: 15.0),
                                              const SizedBox(width: 6.0),
                                              Expanded(
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                                    children: [
                                                      const TextSpan(text: 'Kinetic Energy (+21°C): '),
                                                      TextSpan(
                                                        text: '${ke.toStringAsFixed(1)} J',
                                                        style: const TextStyle(
                                                          color: Color(0xFF6366F1),
                                                          fontWeight: FontWeight.bold,
                                                          fontFamily: 'JetBrainsMono',
                                                          fontSize: 12.0,
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
                            // Single Temp mode layout: ChoiceChips for Stats Only vs Individual Rounds
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _epvatSingleSubMode == 'Individual Rounds'
                                          ? 'Individual Round Inputs (${_epvatPressureUnit})'
                                          : 'EPVAT Statistics (${_epvatPressureUnit})',
                                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    const Text('Entry: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 4.0),
                                    ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      label: const Text('Stats Only', style: TextStyle(fontSize: 11.0)),
                                      selected: _epvatSingleSubMode == 'Stats Only',
                                      selectedColor: const Color(0xFF06B6D4),
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() {
                                            _epvatSingleSubMode = 'Stats Only';
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 6.0),
                                    ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      label: const Text('Individual Rounds', style: TextStyle(fontSize: 11.0)),
                                      selected: _epvatSingleSubMode == 'Individual Rounds',
                                      selectedColor: const Color(0xFF06B6D4),
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() {
                                            _epvatSingleSubMode = 'Individual Rounds';
                                          });
                                          _recalculateEpvatStats();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6.0),
                                if (_epvatSingleSubMode == 'Individual Rounds') ...[
                                  Row(
                                    children: [
                                      const Expanded(flex: 1, child: Text('Round', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      const Expanded(flex: 2, child: Text('P max_1', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      if (!_isCaliber9mm)
                                        const Expanded(flex: 2, child: Text('P max_2', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      const Expanded(flex: 2, child: Text('t4 [ms]', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      const Expanded(flex: 2, child: Text('ta [ms]', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('V${_formattedVelocityDistance}_2', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                  const SizedBox(height: 4.0),
                                  ...List.generate(_getIndividualEpvatVisibleRounds(), (index) {
                                    // Ensure controller exists at index
                                    while (_t4RoundsControllers.length <= index) {
                                      _t4RoundsControllers.add(TextEditingController());
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              'Round ${index + 1}',
                                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 4.0),
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
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 4.0),
                                                child: _buildTextField(
                                                  controller: _epvatP2RoundsControllers[index],
                                                  hint: '0.0',
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  onChanged: (val) => _recalculateEpvatStats(),
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 4.0),
                                              child: _buildTextField(
                                                controller: _t4RoundsControllers[index],
                                                hint: '0.0',
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (val) => _recalculateEpvatStats(),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 4.0),
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
                                            child: _buildTextField(
                                              controller: _epvatVelRoundsControllers[index],
                                              hint: '0.0',
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              onChanged: (val) => _recalculateEpvatStats(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 6.0),
                                ],
                                // 5x5 Transposed Specification Matrix Table
                                _buildEpvatTransposedMatrixTable(
                                  meanP1Ctrl: _epvatMeanPressureController,
                                  maxP1Ctrl: _epvatMaxPressureController,
                                  minP1Ctrl: _epvatMinPressureController,
                                  rangeP1Ctrl: _epvatRangePressureController,
                                  sdP1Ctrl: _epvatSDPressureController,

                                  meanP2Ctrl: _epvatP2MeanPressureController,
                                  maxP2Ctrl: _epvatP2MaxPressureController,
                                  minP2Ctrl: _epvatP2MinPressureController,
                                  rangeP2Ctrl: _epvatP2RangePressureController,
                                  sdP2Ctrl: _epvatP2SDPressureController,

                                  meanT4Ctrl: _t4MeanController,
                                  maxT4Ctrl: _t4MaxController,
                                  minT4Ctrl: _t4MinController,
                                  rangeT4Ctrl: _t4RangeController,
                                  sdT4Ctrl: _t4SDController,

                                  meanTaCtrl: _actionTimeMeanController,
                                  maxTaCtrl: _actionTimeMaxController,
                                  minTaCtrl: _actionTimeMinController,
                                  rangeTaCtrl: _actionTimeRangeController,
                                  sdTaCtrl: _actionTimeSDController,

                                  meanVelCtrl: _meanVelController,
                                  maxVelCtrl: _maxVelController,
                                  minVelCtrl: _minVelController,
                                  rangeVelCtrl: _rangeVelController,
                                  sdVelCtrl: _sdVelController,
                                  readOnly: _epvatSingleSubMode == 'Individual Rounds',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    if (_testName == 'EPVAT test' || _testName == 'Propellant Test') ...[
                      _buildEpvatCustomCalculationsCard(),
                    ],
                  ],
                  if (_testName == 'Primer Sensitivity Test') ...[
                    _buildPrimerSensitivityCard(),
                  ],
                  const SizedBox(height: 4.0),

                  // Row 4: Remarks + Inline Attachment
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Remarks',
                              style: TextStyle(
                                color: Color(0xFF8E96A3),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3.0),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              autocorrect: true,
                              spellCheckConfiguration: kIsWeb ? const SpellCheckConfiguration() : const SpellCheckConfiguration.disabled(),
                              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.0),
                              decoration: InputDecoration(
                                hintText: 'Enter remarks, observations, or quality anomalies...',
                                hintStyle: const TextStyle(color: Color(0xFF6495BF), fontSize: 11.5),
                                filled: true,
                                fillColor: const Color(0xFFE0F2FE),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Attachment / Documentation',
                              style: TextStyle(
                                color: Color(0xFF8E96A3),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3.0),
                            _buildCompactInlineAttachment(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),

                  // Function Test Cartridge Classification Reference Diagram below Remarks
                  if (_testName == 'Function Test') ...[
                    _buildFunctionCartridgeReferenceDiagram(),
                    const SizedBox(height: 4.0),
                  ],
                  if (_testName == 'Extraction Force Test' && (_caliber.contains('M200') || _caliber.contains('M82'))) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16.0),
                          SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              'Extraction Force Test is not applicable for blank calibers (M200 / M82). Submission is disabled.',
                              style: TextStyle(color: Colors.white, fontSize: 12.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Submit and Cancel action buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _confirmCancelTest,
                        icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 16.0),
                        label: const Text(
                          'Cancel & Erase',
                          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                          minimumSize: const Size(0, 36.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      OutlinedButton.icon(
                        onPressed: _openReportWithoutSaving,
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF38BDF8), size: 16.0),
                        label: const Text(
                          'Open Report Without Saving',
                          style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                          minimumSize: const Size(0, 36.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: SizedBox(
                          height: 36.0,
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

        if (lockSingleRow && width >= (count * 125.0).clamp(550.0, 1920.0)) {
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
    final weaponsInCaliber = _weaponsForCurrentCaliber
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
                      _functionWeapon = _selectedFunctionWeapons.join('; ');
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
        : '';

    final bool isM80Rifle = currentCat == 'Rifle' && (_caliber.toLowerCase().contains('m80') || _caliber.toLowerCase().contains('7.62x51'));
    final modelsInCat = _getModelsForCategory(currentCat);
    final modelDropdownItems = isM80Rifle && modelsInCat.isEmpty
        ? <String>[]
        : <String>[
            ...modelsInCat,
            '[+ Custom Model]',
          ];
    final currentModel = currentCat.isNotEmpty && modelDropdownItems.contains(_functionSelectedModel)
        ? _functionSelectedModel
        : '';

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
          : '';
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
                allowEmpty: true,
                hintText: '-- Select Weapon Type --',
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _functionSelectedCategory = v;
                      _functionSelectedModel = '';
                      _functionSelectedSerial = '';
                      _syncFunctionWeaponState();
                    });
                  }
                },
              ),
            ),
            // 2. Weapon Model
            _buildFlexibleField(
              flex: 3,
              label: currentCat.isNotEmpty ? '$currentCat Model (Fleet)' : 'Weapon Model',
              isRequired: !isM80Rifle,
              child: _buildDropdownField(
                value: currentModel,
                items: currentCat.isNotEmpty ? modelDropdownItems : const [],
                allowEmpty: true,
                hintText: currentCat.isEmpty
                    ? '-- Select Type First --'
                    : (isM80Rifle && modelDropdownItems.isEmpty
                        ? '-- No Rifle Registered for M80 --'
                        : '-- Select Weapon Model --'),
                onChanged: (currentCat.isEmpty || modelDropdownItems.isEmpty) ? null : (v) {
                  if (v != null) {
                    setState(() {
                      _functionSelectedModel = v;
                      _functionSelectedSerial = '';
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
                  if (currentModel.isNotEmpty && hasRegisteredSerials && _functionSelectedSerial != '[+ Enter Custom Serial]')
                    _buildDropdownField(
                      value: _functionSelectedSerial,
                      items: serialDropdownItems,
                      allowEmpty: true,
                      hintText: '-- Select Serial --',
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
                      hint: hasRegisteredSerials ? 'Enter custom SN' : (currentModel.isEmpty ? 'Select model first' : 'e.g., SN-001'),
                      readOnly: currentModel.isEmpty,
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
            // 4. Rounds Fired in Weapon
            _buildFlexibleField(
              flex: 2,
              label: 'Rounds Fired in Weapon',
              isRequired: true,
              child: _buildTextField(
                controller: _currentWeaponRoundsController,
                hint: 'e.g., 100',
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            // 5. Add to Tested Weapons
            _buildFlexibleField(
              flex: 2,
              label: 'Add to Test',
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final toAdd = previewLabel.trim();
                    final rds = int.tryParse(_currentWeaponRoundsController.text.trim()) ?? 0;
                    if (toAdd.isEmpty || activeSerial.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select or enter the weapon serial number.')),
                      );
                      return;
                    }
                    if (rds <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter how many rounds were fired in this weapon.')),
                      );
                      return;
                    }
                    setState(() {
                      _functionWeaponRounds[toAdd] = rds;
                      final entryWithRds = '$toAdd [$rds rds]';
                      _selectedFunctionWeapons.removeWhere((w) => w.startsWith(toAdd));
                      _selectedFunctionWeapons.add(entryWithRds);
                      _functionWeapon = _selectedFunctionWeapons.join('; ');
                      _currentWeaponRoundsController.clear();
                      final totalRds = _functionWeaponRounds.values.fold(0, (s, r) => s + r);
                      if (totalRds > 0) {
                        _producedController.text = '$totalRds';
                      }
                    });
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
                      final baseWeapon = weapon.contains(' [') ? weapon.split(' [')[0] : weapon;
                      _functionWeaponRounds.remove(baseWeapon);
                      _functionWeapon = _selectedFunctionWeapons.join('; ');
                      final totalRds = _functionWeaponRounds.values.fold(0, (s, r) => s + r);
                      if (totalRds > 0) {
                        _producedController.text = '$totalRds';
                      }
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
          ],
      ),
    );
  }

  // ignore: unused_element
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
                  _autoExtractFromAttachment(res['name']!, res['data']!);
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
                        Row(
                          children: [
                            const Text(
                              'Ready to submit with record',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _autoExtractFromAttachment(_attachmentName, _attachmentBase64),
                              icon: const Icon(Icons.auto_awesome, size: 14.0, color: Color(0xFF06B6D4)),
                              label: const Text('Re-Extract Data', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                minimumSize: const Size(0, 24),
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
      if (_currentFunctionCaliberRules['schema_type'] == 'categories') {
        int catTotal = 0;
        _funcDefectItemCounts.forEach((k, v) => catTotal += v);
        totalAllDefects = catTotal;
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

            if (_currentFunctionCaliberRules['schema_type'] == 'categories') ...[
              ...((_currentFunctionCaliberRules['categories'] as Map? ?? {}).entries.map((entry) {
                final catName = entry.key.toString();
                final catData = entry.value as Map? ?? {};
                final items = (catData['items'] as List?)?.map((e) => e.toString()).toList() ??
                    catData['description'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final retestLimit = (catData['retest_limit'] as num?)?.toInt() ?? 0;
                final rejectLimit = (catData['reject_limit'] as num?)?.toInt() ?? 1;
                return _buildDefectCategoryTile(
                  categoryName: catName,
                  defectItems: items,
                  color: catName.contains('Misfire') || catName.contains('bore') ? const Color(0xFFEF4444) : (catName.contains('Primer') || catName.contains('Case') ? const Color(0xFFF97316) : const Color(0xFF6366F1)),
                  retestLimit: retestLimit,
                  rejectLimit: rejectLimit,
                  tempKey: activeTempKey,
                );
              }).toList())
            ] else ...[
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
            ],
            const Divider(color: Colors.white12, height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total No. of defect at $activeTempKey °C:',
                  style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 13.0, fontWeight: FontWeight.w600),
                ),
                Text(
                  _currentFunctionCaliberRules['schema_type'] == 'categories'
                      ? () {
                          int catCount = 0;
                          _funcDefectItemCounts.forEach((k, v) {
                            if (k.startsWith('$activeTempKey:')) catCount += v;
                          });
                          return '$catCount';
                        }()
                      : '${(int.tryParse(activeL1Ctrl.text) ?? 0) + (int.tryParse(activeL2Ctrl.text) ?? 0) + (int.tryParse(activeL3Ctrl.text) ?? 0) + (int.tryParse(activeL4Ctrl.text) ?? 0)}',
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
            _currentFunctionCaliberRules['schema_type'] == 'categories'
                ? 'Caliber: $_caliber • Defect Categories'
                : 'Caliber: $_caliber • Level 1 (Max: $l1Max) • Level 2 (Max: $l2Max) • Level 3 (Max: $l3Max) • Level 4 (Max: $l4Max)',
            style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5),
          ),
          const SizedBox(height: 16.0),
          if (_currentFunctionCaliberRules['schema_type'] == 'categories') ...[
            ...((_currentFunctionCaliberRules['categories'] as Map? ?? {}).entries.map((entry) {
              final catName = entry.key.toString();
              final catData = entry.value as Map? ?? {};
              final items = (catData['items'] as List?)?.map((e) => e.toString()).toList() ??
                  catData['description'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final retestLimit = (catData['retest_limit'] as num?)?.toInt() ?? 0;
              final rejectLimit = (catData['reject_limit'] as num?)?.toInt() ?? 1;
              return _buildDefectCategoryTile(
                categoryName: catName,
                defectItems: items,
                color: catName.contains('Misfire') || catName.contains('bore') ? const Color(0xFFEF4444) : (catName.contains('Primer') || catName.contains('Case') ? const Color(0xFFF97316) : const Color(0xFF6366F1)),
                retestLimit: retestLimit,
                rejectLimit: rejectLimit,
              );
            }).toList())
          ] else ...[
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
          ],
          const Divider(color: Colors.white12, height: 24.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total No. of defect:',
                style: TextStyle(color: Color(0xFF8E96A3), fontSize: 13.0, fontWeight: FontWeight.w600),
              ),
              Text(
                _currentFunctionCaliberRules['schema_type'] == 'categories'
                    ? () {
                        int catTotal = 0;
                        _funcDefectItemCounts.forEach((k, v) {
                          if (!k.contains(':')) catTotal += v;
                        });
                        return '$catTotal';
                      }()
                    : '${(int.tryParse(_functionLevel1Controller.text) ?? 0) + (int.tryParse(_functionLevel2Controller.text) ?? 0) + (int.tryParse(_functionLevel3Controller.text) ?? 0) + (int.tryParse(_functionLevel4Controller.text) ?? 0)}',
                style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefectCategoryTile({
    required String categoryName,
    required List<String> defectItems,
    required Color color,
    required int retestLimit,
    required int rejectLimit,
    String tempKey = '',
  }) {
    int catCount = 0;
    for (var it in defectItems) {
      catCount += _getDefectCount(it, tempKey);
    }
    final bool isReject = rejectLimit > 0 && catCount >= rejectLimit;
    final bool isRetest = retestLimit > 0 && catCount >= retestLimit;
    final Color statusCol = isReject ? const Color(0xFFEF4444) : (isRetest ? const Color(0xFFFBBF24) : color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: statusCol.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusCol, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    categoryName,
                    style: TextStyle(color: statusCol, fontSize: 13.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(Retest: >=$retestLimit, Reject: >=$rejectLimit)',
                    style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: statusCol.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: statusCol.withOpacity(0.4)),
                ),
                child: Text(
                  '$catCount defects',
                  style: TextStyle(color: statusCol, fontSize: 12.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: defectItems.map((item) {
              final count = _getDefectCount(item, tempKey);
              final isSelected = count > 0;
              return Container(
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.25) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10.0)),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          final key = tempKey.isNotEmpty ? '$tempKey:$item' : item;
                          setState(() {
                            if (count == 1) {
                              _funcDefectItemCounts.remove(key);
                            } else {
                              _funcDefectItemCounts[key] = count - 1;
                            }
                            _updateCategoryBasedDefects();
                          });
                        },
                        child: const Icon(Icons.remove_circle_outline, size: 15, color: Colors.white70),
                      ),
                    ],
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        final key = tempKey.isNotEmpty ? '$tempKey:$item' : item;
                        setState(() {
                          _funcDefectItemCounts[key] = count + 1;
                          _updateCategoryBasedDefects();
                        });
                      },
                      child: Icon(Icons.add_circle_outline, size: 15, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              );
            }).toList(),
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
    final defectItems = _getDefectItemsForLevel(level);

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
          const SizedBox(height: 8.0),
          Text('Select defect found (Click to increment count):', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: [
              ...defectItems.map((item) {
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
                                color: hasCount ? Colors.white : Colors.white.withOpacity(0.8),
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
              }),
              if (_isAdmin)
                InkWell(
                  borderRadius: BorderRadius.circular(6.0),
                  onTap: () => _promptAddCustomDefect(level, controller, tempKey),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 13.0, color: Color(0xFF38BDF8)),
                        SizedBox(width: 4.0),
                        Text(
                          '+ Add Defect',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateFunctionTestTotalDefects() {
    if (_currentFunctionCaliberRules['schema_type'] == 'categories') {
      int catTotal = 0;
      _funcDefectItemCounts.forEach((k, v) => catTotal += v);
      _defectsController.text = '$catTotal';
      if (_functionTempMode == 'All') {
        int totalProd = 0;
        for (var t in _functionTempList) {
          final p = int.tryParse(_funcAllProducedControllers[t]?.text.trim() ?? '') ?? 0;
          totalProd += p;
        }
        if (totalProd > 0) _producedController.text = '$totalProd';
      }
      return;
    }
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
            while (_extractionRoundsControllers.length < 20) {
              _extractionRoundsControllers.add(TextEditingController());
            }
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
              if (val == null) return;
              setState(() {
                _extractionForceType = val;
                _minXController.clear();
                _maxXController.clear();
                _rangeXController.clear();
                _sdXController.clear();
                _meanXController.clear();
                if (val == 'Individual') {
                  while (_extractionRoundsControllers.length < 20) {
                    _extractionRoundsControllers.add(TextEditingController());
                  }
                }
              });
            },
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              fontSize: 12.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractionForceCard() {
    final extRules = _getExtractionRulesForCaliber();
    final double limit = (extRules['min_force'] ?? 200.0).toDouble();

    // Ensure 20 controllers exist
    while (_extractionRoundsControllers.length < 20) {
      _extractionRoundsControllers.add(TextEditingController());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FB),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFFD6E4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center_outlined, color: Color(0xFF06B6D4), size: 18.0),
              const SizedBox(width: 8.0),
              const Text(
                'Extraction Force Test Specifications',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 13.0, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  'Min Limit: ${limit.toStringAsFixed(1)} N',
                  style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_attachmentBase64.isNotEmpty && _attachmentName.toLowerCase().endsWith('.pdf')) {
                    _autoExtractFromAttachment(_attachmentName, _attachmentBase64);
                  } else {
                    final res = await getAttachmentHelper().pickFileAsBase64();
                    if (res != null && res['name'] != null && res['data'] != null) {
                      setState(() {
                        _attachmentName = res['name']!;
                        _attachmentBase64 = res['data']!;
                      });
                      _autoExtractFromAttachment(res['name']!, res['data']!);
                    }
                  }
                },
                icon: const Icon(Icons.picture_as_pdf, size: 14.0, color: Colors.white),
                label: const Text('Auto-Extract from PDF Report', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Row(
            children: [
              const Text('Result Input Mode: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.0, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8.0),
              _buildModeRadioButton('Individual', 'Individual Samples (20)'),
              const SizedBox(width: 12.0),
              _buildModeRadioButton('Overall', 'Overall Summary'),
            ],
          ),
          const SizedBox(height: 8.0),
          if (_extractionForceType == 'Individual') ...[
            // 2-column side-by-side table matching the Test Report attachment (Samples 1-10 on Left, Samples 11-20 on Right)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Table: Samples 1 to 10
                    Expanded(
                      child: _buildExtractionSampleSubTable(
                        startIndex: 0,
                        endIndex: math.min(10, _extractionRoundsControllers.length),
                        limit: limit,
                      ),
                    ),
                    Container(width: 1, color: const Color(0xFFCBD5E1)),
                    // Right Table: Samples 11 to 20
                    Expanded(
                      child: _buildExtractionSampleSubTable(
                        startIndex: 10,
                        endIndex: math.min(20, _extractionRoundsControllers.length),
                        limit: limit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8.0),
          ],
          // Summary Statistics Table matching the report (Minimum, Maximum, Mean, SD, Units: N)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Summary Statistics',
                      style: TextStyle(color: Color(0xFF0284C7), fontSize: 12.0, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Text('Units: N', style: TextStyle(color: Color(0xFF475569), fontSize: 11.0, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(label: 'Minimum', controller: _minXController, readOnly: _extractionForceType == 'Individual'),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(label: 'Maximum', controller: _maxXController, readOnly: _extractionForceType == 'Individual'),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(label: 'Mean', controller: _meanXController, readOnly: _extractionForceType == 'Individual'),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(label: 'SD', controller: _sdXController, readOnly: _extractionForceType == 'Individual'),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(label: 'Range', controller: _rangeXController, readOnly: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractionSampleSubTable({required int startIndex, required int endIndex, required double limit}) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(5.0), topRight: Radius.circular(5.0)),
          ),
          child: Row(
            children: const [
              Expanded(flex: 3, child: Text('Calculation', style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold))),
              Expanded(flex: 4, child: Text('Extraction Force (N)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Overall result', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        for (int i = startIndex; i < endIndex; i++) ...[
          Builder(builder: (context) {
            final ctrl = _extractionRoundsControllers[i];
            final val = double.tryParse(ctrl.text.trim());
            final bool hasVal = ctrl.text.trim().isNotEmpty && val != null;
            final bool isPass = hasVal && val >= limit;
            final bool isFail = hasVal && val < limit;

            return Container(
              color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Sample ${i + 1}',
                      style: const TextStyle(color: Color(0xFF334155), fontSize: 11.0, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: _buildTextField(
                        controller: ctrl,
                        hint: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          _recalculateExtractionStats();
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: isPass
                              ? const Color(0xFFDCFCE7)
                              : isFail
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: isPass
                                ? const Color(0xFF86EFAC)
                                : isFail
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          isPass
                              ? 'PASS'
                              : isFail
                                  ? 'FAIL'
                                  : '-',
                          style: TextStyle(
                            color: isPass
                                ? const Color(0xFF16A34A)
                                : isFail
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (i < endIndex - 1) const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ],
      ],
    );
  }

  Widget _buildStatBox({required String label, required TextEditingController controller, required bool readOnly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2.0),
        _buildTextField(
          controller: controller,
          hint: '0.0',
          readOnly: readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) {
            _scheduleAutoSave();
            setState(() {});
          },
        ),
      ],
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
      autocorrect: true,
      spellCheckConfiguration: kIsWeb ? const SpellCheckConfiguration() : const SpellCheckConfiguration.disabled(),
      inputFormatters: inputFormatters ?? (
        keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : (keyboardType.signed == true)
                ? [SignedDecimalInputFormatter()]
                : (keyboardType == const TextInputType.numberWithOptions(decimal: true) || keyboardType.decimal == true)
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
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
        hintStyle: const TextStyle(color: Color(0xFF6495BF), fontSize: 12.0),
        filled: true,
        isDense: true,
        fillColor: readOnly ? const Color(0xFFC8E3F5) : const Color(0xFFE0F2FE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
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

  Widget _buildDropdownField({
    String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    FocusNode? focusNode,
    bool allowEmpty = false,
    String? hintText,
  }) {
    final String? selectedValue = (value != null && items.contains(value))
        ? value
        : (allowEmpty ? null : (items.isNotEmpty ? items.first : null));

    return DropdownButtonFormField<String>(
      value: selectedValue,
      focusNode: focusNode,
      isExpanded: true,
      onChanged: onChanged,
      hint: hintText != null ? Text(hintText, style: const TextStyle(color: Color(0xFF6495BF), fontSize: 12.0)) : null,
      style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.5, fontWeight: FontWeight.w500),
      dropdownColor: const Color(0xFFE0F2FE),
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF31B9F6), size: 20.0),
      decoration: InputDecoration(
        filled: true,
        isDense: true,
        fillColor: const Color(0xFFE0F2FE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
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
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.5)),
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
              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                hintText: '###',
                hintStyle: const TextStyle(color: Color(0xFF6495BF), fontSize: 12.0),
                filled: true,
                isDense: true,
                fillColor: const Color(0xFFE0F2FE),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 1.5),
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
          const SizedBox(width: 8.0),
          const Text(
            'OMPC/',
            style: TextStyle(
              color: Color(0xFF31B9F6),
              fontSize: 13.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8.0),
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
      final isAccuracy = _testName == 'Accuracy Test';
      final ctrl = isPrimer
          ? _primerLotController
          : (isAccuracy ? _lotController : _propellantLotController);
      return TextFormField(
        controller: ctrl,
        focusNode: focusNode,
        style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.5, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: isPrimer
              ? 'Enter Primer Lot (e.g. CBC-26-01)'
              : (isAccuracy ? 'Enter Lot of Shipment' : 'Enter Propellant Lot (e.g. 90124)'),
          hintStyle: const TextStyle(color: Color(0xFF6495BF), fontSize: 12.0),
          filled: true,
          isDense: true,
          fillColor: const Color(0xFFE0F2FE),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 1.5),
          ),
        ),
        onChanged: (val) {
          _lotController.text = val.trim();
        },
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return isPrimer
                ? 'Please enter Primer Lot'
                : (isAccuracy ? 'Please enter Lot of Shipment' : 'Please enter Propellant Lot');
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
              style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 12.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                hintText: '###',
                hintStyle: const TextStyle(color: Color(0xFF6495BF), fontSize: 12.0),
                filled: true,
                isDense: true,
                fillColor: const Color(0xFFE0F2FE),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  borderSide: const BorderSide(color: Color(0xFF7DD3FC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  borderSide: const BorderSide(color: Color(0xFF31B9F6), width: 1.5),
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

  Widget _buildEpvatTransposedMatrixTable({
    required TextEditingController meanP1Ctrl,
    required TextEditingController maxP1Ctrl,
    required TextEditingController minP1Ctrl,
    required TextEditingController rangeP1Ctrl,
    required TextEditingController sdP1Ctrl,

    required TextEditingController meanP2Ctrl,
    required TextEditingController maxP2Ctrl,
    required TextEditingController minP2Ctrl,
    required TextEditingController rangeP2Ctrl,
    required TextEditingController sdP2Ctrl,

    required TextEditingController meanT4Ctrl,
    required TextEditingController maxT4Ctrl,
    required TextEditingController minT4Ctrl,
    required TextEditingController rangeT4Ctrl,
    required TextEditingController sdT4Ctrl,

    required TextEditingController meanTaCtrl,
    required TextEditingController maxTaCtrl,
    required TextEditingController minTaCtrl,
    required TextEditingController rangeTaCtrl,
    required TextEditingController sdTaCtrl,

    required TextEditingController meanVelCtrl,
    required TextEditingController maxVelCtrl,
    required TextEditingController minVelCtrl,
    required TextEditingController rangeVelCtrl,
    required TextEditingController sdVelCtrl,
    required bool readOnly,
  }) {
    final vHeader = 'V${_formattedVelocityDistance}_2';
    final pUnit = _epvatPressureUnit.isNotEmpty ? _epvatPressureUnit : 'bar';

    final headers = [
      '',
      'P max_1\n[$pUnit]',
      _isCaliber9mm ? 'P max_2\n(N/A)' : 'P max_2\n[$pUnit]',
      't4 [ms]',
      'ta [ms]',
      '$vHeader\n[m/s]',
    ];

    final rows = [
      {
        'label': 'MEAN',
        'p1': meanP1Ctrl,
        'p2': meanP2Ctrl,
        't4': meanT4Ctrl,
        'ta': meanTaCtrl,
        'vel': meanVelCtrl,
      },
      {
        'label': 'MAX',
        'p1': maxP1Ctrl,
        'p2': maxP2Ctrl,
        't4': maxT4Ctrl,
        'ta': maxTaCtrl,
        'vel': maxVelCtrl,
      },
      {
        'label': 'MIN',
        'p1': minP1Ctrl,
        'p2': minP2Ctrl,
        't4': minT4Ctrl,
        'ta': minTaCtrl,
        'vel': minVelCtrl,
      },
      {
        'label': 'RANGE',
        'p1': rangeP1Ctrl,
        'p2': rangeP2Ctrl,
        't4': rangeT4Ctrl,
        'ta': rangeTaCtrl,
        'vel': rangeVelCtrl,
      },
      {
        'label': 'STDEV',
        'p1': sdP1Ctrl,
        'p2': sdP2Ctrl,
        't4': sdT4Ctrl,
        'ta': sdTaCtrl,
        'vel': sdVelCtrl,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 540),
            child: SizedBox(
              width: 620,
              child: Column(
                children: [
                  // Header Row
                  Container(
                    color: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: const Text(
                            'SPECIFICATION',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.0,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        for (int i = 1; i < headers.length; i++)
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Text(
                                headers[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: i == 5 ? const Color(0xFF38BDF8) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Matrix Data Rows (MEAN, MAX, MIN, RANGE, STDEV)
                  for (int rIdx = 0; rIdx < rows.length; rIdx++) ...[
                    Container(
                      color: rIdx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              rows[rIdx]['label'] as String,
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // P max_1
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: _buildTextField(
                                controller: rows[rIdx]['p1'] as TextEditingController,
                                hint: '0.0',
                                readOnly: readOnly,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) {
                                  _scheduleAutoSave();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          // P max_2
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: _isCaliber9mm
                                  ? Container(
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                                    )
                                  : _buildTextField(
                                      controller: rows[rIdx]['p2'] as TextEditingController,
                                      hint: '0.0',
                                      readOnly: readOnly,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) {
                                        _scheduleAutoSave();
                                        setState(() {});
                                      },
                                    ),
                            ),
                          ),
                          // t4 [ms]
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: _buildTextField(
                                controller: rows[rIdx]['t4'] as TextEditingController,
                                hint: '0.0',
                                readOnly: readOnly,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) {
                                  _scheduleAutoSave();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          // ta [ms]
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: _buildTextField(
                                controller: rows[rIdx]['ta'] as TextEditingController,
                                hint: '0.0',
                                readOnly: readOnly,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [ActionTimeInputFormatter()],
                                onChanged: (_) {
                                  _scheduleAutoSave();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          // V..._2 [m/s]
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: _buildTextField(
                                controller: rows[rIdx]['vel'] as TextEditingController,
                                hint: '0.0',
                                readOnly: readOnly,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) {
                                  _scheduleAutoSave();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rIdx < rows.length - 1)
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpvatTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              'Parameter',
              style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: Text(
              'Mean',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: Text(
              'Max',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: Text(
              'Min',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: Text(
              'Range',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: Text(
              'SD',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpvatMetricTableRow({
    required String parameterName,
    required TextEditingController meanCtrl,
    required TextEditingController maxCtrl,
    required TextEditingController minCtrl,
    required TextEditingController rangeCtrl,
    required TextEditingController sdCtrl,
    required bool readOnly,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onMeanChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              parameterName,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: meanCtrl,
              hint: '0.0',
              readOnly: readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: inputFormatters,
              onChanged: (_) {
                if (onMeanChanged != null) onMeanChanged();
                _scheduleAutoSave();
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: maxCtrl,
              hint: '0.0',
              readOnly: readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: inputFormatters,
              onChanged: (_) {
                _calculateRange(maxCtrl, minCtrl, rangeCtrl);
                _scheduleAutoSave();
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: minCtrl,
              hint: '0.0',
              readOnly: readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: inputFormatters,
              onChanged: (_) {
                _calculateRange(maxCtrl, minCtrl, rangeCtrl);
                _scheduleAutoSave();
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: rangeCtrl,
              hint: '0.0',
              readOnly: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: inputFormatters,
              onChanged: (_) {
                _scheduleAutoSave();
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: sdCtrl,
              hint: '0.0',
              readOnly: readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: inputFormatters,
              onChanged: (_) {
                _scheduleAutoSave();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyMatrixRow({
    required String label,
    required TextEditingController ctrlX,
    required TextEditingController ctrlY,
    required TextEditingController ctrlVel,
    required bool readOnly,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6.0),
        Expanded(
          flex: 3,
          child: _buildTextField(
            controller: ctrlX,
            hint: '0.0',
            readOnly: readOnly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            onChanged: (_) {
              _calculateRange(_maxXController, _minXController, _rangeXController);
              _scheduleAutoSave();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 6.0),
        Expanded(
          flex: 3,
          child: _buildTextField(
            controller: ctrlY,
            hint: '0.0',
            readOnly: readOnly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            onChanged: (_) {
              _calculateRange(_maxYController, _minYController, _rangeYController);
              _scheduleAutoSave();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 6.0),
        Expanded(
          flex: 3,
          child: _buildTextField(
            controller: ctrlVel,
            hint: '0.0',
            readOnly: readOnly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              _calculateRange(_maxVelController, _minVelController, _rangeVelController);
              _scheduleAutoSave();
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEpvatUnitRadioButton(String unit, String label) {
    final bool isSelected = _epvatPressureUnit == unit;
    return InkWell(
      onTap: () => _onPressureUnitChanged(unit),
      borderRadius: BorderRadius.circular(4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: unit,
              groupValue: _epvatPressureUnit,
              activeColor: const Color(0xFF0284C7),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) {
                if (val != null) _onPressureUnitChanged(val);
              },
            ),
            const SizedBox(width: 3.0),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionCartridgeReferenceDiagram() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8.0),
            onTap: () => setState(() => _showFunctionDiagram = !_showFunctionDiagram),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.photo_outlined, color: Color(0xFF0284C7), size: 16.0),
                  const SizedBox(width: 8.0),
                  Text(
                    _isCaliber9mm ? '9mm Cartridge Reference Diagram' : '5.56 / 7.62 Cartridge Reference Diagram',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.0, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    _showFunctionDiagram ? 'Hide Diagram' : 'Show Diagram',
                    style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.w600),
                  ),
                  Icon(
                    _showFunctionDiagram ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF0284C7),
                    size: 16.0,
                  ),
                ],
              ),
            ),
          ),
          if (_showFunctionDiagram) ...[
            const Divider(color: Color(0xFFBAE6FD), height: 1.0),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Tooltip(
                  message: 'Click to view diagram fullscreen / zoom',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () {
                      final asset = _isCaliber9mm ? 'assets/cartridge_9mm.png' : 'assets/cartridge_bottleneck.png';
                      final title = _isCaliber9mm ? '9mm Function Test Reference Diagram' : '5.56 / 7.62 Function Test Reference Diagram';
                      _showZoomDiagramDialog(asset, title);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.asset(
                        _isCaliber9mm ? 'assets/cartridge_9mm.png' : 'assets/cartridge_bottleneck.png',
                        height: 260,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    if (_epvatSingleSubMode == 'Stats Only') return;
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

    // 5. t4 stats
    final List<double> t4Values = [];
    for (var ctrl in _t4RoundsControllers) {
      final val = double.tryParse(ctrl.text.trim());
      if (val != null) t4Values.add(val);
    }
    _calculateStatsForValues(
      t4Values,
      _t4MeanController,
      _t4MaxController,
      _t4MinController,
      _t4RangeController,
      _t4SDController,
    );

    if (_epvatPressureType == 'Individual') {
      final maxRounds = math.max(p1Values.length, math.max(p2Values.length, math.max(velValues.length, t4Values.length)));
      if (maxRounds > 0) {
        _producedController.text = '$maxRounds';
      }
    }

    if (mounted) {
      setState(() {});
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
    
    final double testedQty = double.tryParse(_producedController.text.trim()) ?? 0.0;
    
    if (_epvatPressureType == 'Overall') {
      final double defaultPerTempN = testedQty > 0 ? (testedQty / 3.0).roundToDouble() : 30.0;
      for (var t in tempKeys) {
        final sfx = suffixMap[t]!;
        final nVal = (_epvatOverallRoundCount[t] != null && _epvatOverallRoundCount[t]! > 0)
            ? _epvatOverallRoundCount[t]!.toDouble()
            : defaultPerTempN;
        variables['n_$sfx'] = nVal;
        variables['count_$sfx'] = nVal;
        variables['sample_size_$sfx'] = nVal;
        variables['samplesize_$sfx'] = nVal;
        variables['size_$sfx'] = nVal;

        final metricsMap = _overallEpvatControllers[t] ?? {};
        metricsMap.forEach((key, ctrl) {
          final val = double.tryParse(ctrl.text.trim()) ?? 0.0;
          variables['${key}_${sfx}'] = val;
          if (sfx == '21') {
            variables.putIfAbsent(key, () => val);
          }
          if (key.startsWith('action_time_')) {
            final atKey = key.replaceFirst('action_time_', 'at_');
            variables['${atKey}_${sfx}'] = val;
            if (sfx == '21') {
              variables.putIfAbsent(atKey, () => val);
            }
          }
        });
      }
      final double overallN = testedQty > 0 ? testedQty : 90.0;
      variables['n'] = overallN;
      variables['count'] = overallN;
      variables['sample_size'] = overallN;
      variables['samplesize'] = overallN;
      variables['size'] = overallN;
    } else {
      final activeTemp = _cartridgeTempController.text.trim();
      final String sfx = activeTemp.contains('52') ? '52' : (activeTemp.contains('32') ? '32' : (activeTemp.contains('54') ? '54' : '21'));
      final double singleN = testedQty > 0
          ? testedQty
          : (_getIndividualEpvatVisibleRounds() > 0 ? _getIndividualEpvatVisibleRounds().toDouble() : 20.0);
      variables['n_$sfx'] = singleN;
      variables['count_$sfx'] = singleN;
      variables['sample_size_$sfx'] = singleN;
      variables['samplesize_$sfx'] = singleN;
      variables['size_$sfx'] = singleN;
      variables['n'] = singleN;
      variables['count'] = singleN;
      variables['sample_size'] = singleN;
      variables['samplesize'] = singleN;
      variables['size'] = singleN;
      variables.putIfAbsent('n_21', () => singleN);
      variables.putIfAbsent('count_21', () => singleN);
      variables.putIfAbsent('sample_size_21', () => singleN);
      
      final p1Mean = double.tryParse(_epvatMeanPressureController.text.trim()) ?? 0.0;
      final p1Max = double.tryParse(_epvatMaxPressureController.text.trim()) ?? 0.0;
      final p1Min = double.tryParse(_epvatMinPressureController.text.trim()) ?? 0.0;
      final p1Range = double.tryParse(_epvatRangePressureController.text.trim()) ?? 0.0;
      final p1Sd = double.tryParse(_epvatSDPressureController.text.trim()) ?? 0.0;

      final p2Mean = double.tryParse(_epvatP2MeanPressureController.text.trim()) ?? 0.0;
      final p2Max = double.tryParse(_epvatP2MaxPressureController.text.trim()) ?? 0.0;
      final p2Min = double.tryParse(_epvatP2MinPressureController.text.trim()) ?? 0.0;
      final p2Range = double.tryParse(_epvatP2RangePressureController.text.trim()) ?? 0.0;
      final p2Sd = double.tryParse(_epvatP2SDPressureController.text.trim()) ?? 0.0;

      final velMean = double.tryParse(_meanVelController.text.trim()) ?? 0.0;
      final velMax = double.tryParse(_maxVelController.text.trim()) ?? 0.0;
      final velMin = double.tryParse(_minVelController.text.trim()) ?? 0.0;
      final velRange = double.tryParse(_rangeVelController.text.trim()) ?? 0.0;
      final velSd = double.tryParse(_sdVelController.text.trim()) ?? 0.0;

      final actMean = double.tryParse(_actionTimeMeanController.text.trim()) ?? 0.0;
      final actMax = double.tryParse(_actionTimeMaxController.text.trim()) ?? 0.0;
      final actMin = double.tryParse(_actionTimeMinController.text.trim()) ?? 0.0;
      final actRange = double.tryParse(_actionTimeRangeController.text.trim()) ?? 0.0;
      final actSd = double.tryParse(_actionTimeSDController.text.trim()) ?? 0.0;

      variables['p1_mean_$sfx'] = p1Mean;
      variables['p1_max_$sfx'] = p1Max;
      variables['p1_max_individual_$sfx'] = p1Max;
      variables['p1_min_$sfx'] = p1Min;
      variables['p1_range_$sfx'] = p1Range;
      variables['p1_sd_$sfx'] = p1Sd;

      variables['p2_mean_$sfx'] = p2Mean;
      variables['p2_max_$sfx'] = p2Max;
      variables['p2_min_$sfx'] = p2Min;
      variables['p2_range_$sfx'] = p2Range;
      variables['p2_sd_$sfx'] = p2Sd;

      variables['vel_mean_$sfx'] = velMean;
      variables['vel_max_$sfx'] = velMax;
      variables['vel_min_$sfx'] = velMin;
      variables['vel_range_$sfx'] = velRange;
      variables['vel_sd_$sfx'] = velSd;

      variables['action_time_mean_$sfx'] = actMean;
      variables['action_time_max_$sfx'] = actMax;
      variables['action_time_min_$sfx'] = actMin;
      variables['action_time_range_$sfx'] = actRange;
      variables['action_time_sd_$sfx'] = actSd;

      // Un-suffixed fallbacks
      variables['p1_mean'] = p1Mean;
      variables['p1_max'] = p1Max;
      variables['p1_max_individual'] = p1Max;
      variables['p1_min'] = p1Min;
      variables['p1_range'] = p1Range;
      variables['p1_sd'] = p1Sd;

      variables['p2_mean'] = p2Mean;
      variables['p2_max'] = p2Max;
      variables['p2_min'] = p2Min;
      variables['p2_range'] = p2Range;
      variables['p2_sd'] = p2Sd;

      variables['vel_mean'] = velMean;
      variables['vel_max'] = velMax;
      variables['vel_min'] = velMin;
      variables['vel_range'] = velRange;
      variables['vel_sd'] = velSd;

      variables['action_time_mean'] = actMean;
      variables['action_time_max'] = actMax;
      variables['action_time_min'] = actMin;
      variables['action_time_range'] = actRange;
      variables['action_time_sd'] = actSd;

      variables.putIfAbsent('p1_mean_21', () => p1Mean);
      variables.putIfAbsent('p1_sd_21', () => p1Sd);
      variables.putIfAbsent('p2_mean_21', () => p2Mean);
      variables.putIfAbsent('p2_sd_21', () => p2Sd);
      variables.putIfAbsent('vel_mean_21', () => velMean);
      variables.putIfAbsent('vel_sd_21', () => velSd);
      variables.putIfAbsent('action_time_mean_21', () => actMean);
      variables.putIfAbsent('action_time_sd_21', () => actSd);
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
      final calClean = _caliber.toLowerCase().replaceAll(' ', '');
      String matchKey = '';
      for (final k in accLimits.keys) {
        final kClean = k.toString().toLowerCase().replaceAll(' ', '');
        if (kClean == calClean) {
          matchKey = k.toString();
          break;
        }
      }
      if (matchKey.isEmpty) {
        for (final k in accLimits.keys) {
          final kClean = k.toString().toLowerCase().replaceAll(' ', '');
          if ((calClean.contains('m193') && kClean.contains('m193')) ||
              (calClean.contains('ss109') && kClean.contains('ss109')) ||
              (calClean.contains('m80') && kClean.contains('m80')) ||
              (calClean.contains('69') && kClean.contains('69')) ||
              (calClean.contains('55') && kClean.contains('55')) ||
              (calClean.contains('77') && kClean.contains('77')) ||
              (calClean.contains('blank') && kClean.contains('blank')) ||
              (calClean.contains('9x19') && kClean.contains('9x19'))) {
            matchKey = k.toString();
            break;
          }
        }
      }
      if (matchKey.isEmpty) {
        matchKey = accLimits.keys.firstWhere(
          (k) => _caliber.toLowerCase().contains(k.toString().toLowerCase()) || k.toString().toLowerCase().contains(_caliber.toLowerCase()),
          orElse: () => '',
        );
      }
      if (matchKey.isNotEmpty) {
        limits = Map<String, dynamic>.from(accLimits[matchKey]);
      } else {
        limits = Map<String, dynamic>.from(accLimits['default'] ?? {});
      }
    }
    final double defaultTarget = _caliber.toLowerCase().contains('m193')
        ? 965.0
        : (_caliber.toLowerCase().contains('ss109')
            ? 915.0
            : (_caliber.toLowerCase().contains('m80')
                ? 830.0
                : (_caliber.toLowerCase().contains('9') ? 375.0 : 850.0)));
    final double defaultTol = _caliber.toLowerCase().contains('m193') ? 15.0 : 13.0;
    final double targetMean = ((limits['vel_target_mean'] ?? defaultTarget) as num).toDouble();
    final double tolerance = ((limits['vel_tolerance'] ?? defaultTol) as num).toDouble();
    final double velMin = limits['vel_min'] != null
        ? (limits['vel_min'] as num).toDouble()
        : (targetMean - tolerance);
    final double velMax = limits['vel_max'] != null
        ? (limits['vel_max'] as num).toDouble()
        : (targetMean + tolerance);

    return {
      'max_mean_radius': ((limits['max_mean_radius'] ?? 50.0) as num).toDouble(),
      'max_sd': ((limits['max_sd'] ?? 200.0) as num).toDouble(),
      'cond_sd': ((limits['cond_sd'] ?? 170.0) as num).toDouble(),
      'vel_target_mean': targetMean,
      'vel_tolerance': tolerance,
      'vel_min': velMin,
      'vel_max': velMax,
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
      'vel_min': (activeEpv['vel_min'] ?? 0.0).toDouble(),
      'vel_max': (activeEpv['vel_max'] ?? 9999.0).toDouble(),
      'p1_max': (activeEpv['p1_max'] ?? 9999.0).toDouble(),
      'p2_min': (activeEpv['p2_min'] ?? 0.0).toDouble(),
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
    final double defaultAllFire = is762 ? 500.0 : (is9mm ? 350.0 : 450.0);
    final double defaultNoFire = 75.0;
    return {
      'drop_weight': is762 ? 110.0 : 55.0,
      'hbar_min': is9mm ? 140.0 : (is762 ? 160.0 : 150.0),
      'hbar_max': is9mm ? 280.0 : (is762 ? 320.0 : 300.0),
      'all_fire_h': defaultAllFire,
      'min_all_fire_height': defaultAllFire,
      'no_fire_h': defaultNoFire,
      'max_no_fire_height': defaultNoFire,
      'max_sd': is762 ? 70.0 : (is9mm ? 50.0 : 60.0),
      'instructions': ps['instructions'] ?? 'Primer sensitivity test: HM+5SD and HM-2SD evaluations.',
    };
  }

  // ignore: unused_element
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
    
    if (_isAccuracyOrBullet) {
      final accRules = _getAccuracyRulesForCaliber();
      final double maxMeanRadius = (accRules['max_mean_radius'] ?? 50.0).toDouble();
      final double maxSD = (accRules['max_sd'] ?? 200.0).toDouble();
      final double condSD = (accRules['cond_sd'] ?? 170.0).toDouble();
      final double velMin = (accRules['vel_min'] as num).toDouble();
      final double velMax = (accRules['vel_max'] as num).toDouble();
      
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
      if (_functionTempMode == 'All') {
        int sumL1 = 0;
        int sumL2 = 0;
        int sumL3 = 0;
        int sumL4 = 0;
        for (var t in _functionTempList) {
          sumL1 += int.tryParse(_funcAllL1Controllers[t]?.text.trim() ?? '') ?? 0;
          sumL2 += int.tryParse(_funcAllL2Controllers[t]?.text.trim() ?? '') ?? 0;
          sumL3 += int.tryParse(_funcAllL3Controllers[t]?.text.trim() ?? '') ?? 0;
          sumL4 += int.tryParse(_funcAllL4Controllers[t]?.text.trim() ?? '') ?? 0;
        }
        return _calculateFunctionTestStatus(l1: sumL1, l2: sumL2, l3: sumL3, l4: sumL4);
      }
      final l1 = int.tryParse(_functionLevel1Controller.text.trim()) ?? 0;
      final l2 = int.tryParse(_functionLevel2Controller.text.trim()) ?? 0;
      final l3 = int.tryParse(_functionLevel3Controller.text.trim()) ?? 0;
      final l4 = int.tryParse(_functionLevel4Controller.text.trim()) ?? 0;
      return _calculateFunctionTestStatus(l1: l1, l2: l2, l3: l3, l4: l4);
    }

    if (_testName == 'Primer Sensitivity Test') {
      final prRules = _getPrimerRulesForCaliber();
      final is762 = _caliber.contains('7.62') || _caliber.contains('M80') || _caliber.contains('.308');
      final is9mm = _caliber.contains('9x19') || _caliber.contains('Para') || _caliber.contains('Luger');
      final double defaultAllFire = is762 ? 500.0 : (is9mm ? 350.0 : 450.0);
      final double defaultNoFire = 75.0;

      final double allFireLimit = ((prRules['all_fire_h'] ?? prRules['min_all_fire_height'] ?? defaultAllFire) as num).toDouble();
      final double noFireLimit = ((prRules['no_fire_h'] ?? prRules['max_no_fire_height'] ?? defaultNoFire) as num).toDouble();

      final double? hbar = double.tryParse(_primerHbarController.text.trim());
      final double? sd = double.tryParse(_primerSDController.text.trim());

      if (hbar == null || sd == null) {
        return 'Approved';
      }

      final allFireH = hbar + (5 * sd);
      final noFireH = hbar - (2 * sd);

      if (allFireH > allFireLimit || noFireH < noFireLimit) {
        return 'Rejected';
      }
      return 'Approved';
    }

    if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
      final epv = widget.adminRules['epvat'] ?? {};
      final bool isThreeTemp = _epvatPressureType == 'Overall';
      final formulasMap = Map<String, dynamic>.from(epv['custom_formulas'] ?? {});
      final list = EpvatFormulaHelper.getFormulasForCaliber(
        formulasMap,
        _caliber,
        isThreeTemp: isThreeTemp,
      );

      final defaultTemp = isThreeTemp
          ? '21'
          : (_cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim().isEmpty
              ? '21'
              : _cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim());

      final variables = _getEpvatVariablesMap();

      if (list.isNotEmpty) {
        for (int i = 0; i < list.length; i++) {
          final item = Map<String, dynamic>.from(list[i] as Map);
          final res = EpvatFormulaHelper.evaluateFormulaItem(
            item,
            variables,
            defaultTemp: defaultTemp,
            activePressureUnit: _epvatPressureUnit,
            formulaIndex: i + 1,
          );
          if (res.isApplicable && !res.isPassed) {
            return 'Rejected';
          }
        }
      }
      return 'Approved';
    }

    return 'Approved';
  }

  Widget _buildEpvatCustomCalculationsCard() {
    final epv = widget.adminRules['epvat'] ?? {};
    final formulasMap = Map<String, dynamic>.from(epv['custom_formulas'] ?? {});
    final list = EpvatFormulaHelper.getFormulasForCaliber(
      formulasMap,
      _caliber,
      isThreeTemp: _epvatPressureType == 'Overall',
    );
    
    if (list.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Color(0xFF8E96A3), size: 16.0),
                const SizedBox(width: 6.0),
                Text(
                  'No custom EPVAT evaluation formulas registered for "$_caliber".',
                  style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            if (widget.onOpenEpvatRulesInControl != null)
              InkWell(
                onTap: widget.onOpenEpvatRulesInControl,
                borderRadius: BorderRadius.circular(4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.tune_rounded, color: Color(0xFF818CF8), size: 12.0),
                      SizedBox(width: 4.0),
                      Text(
                        'Configure Rules in Control Module',
                        style: TextStyle(color: Color(0xFF818CF8), fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    final defaultTemp = _epvatPressureType == 'Overall'
        ? '21'
        : (_cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim().isEmpty
            ? '21'
            : _cartridgeTempController.text.trim().replaceAll('+', '').replaceAll('-', '').replaceAll('°C', '').trim());

    final variables = _getEpvatVariablesMap();
    final results = <EpvatFormulaResult>[];
    for (int i = 0; i < list.length; i++) {
      results.add(EpvatFormulaHelper.evaluateFormulaItem(
        Map<String, dynamic>.from(list[i] as Map),
        variables,
        defaultTemp: defaultTemp,
        activePressureUnit: _epvatPressureUnit,
        formulaIndex: i + 1,
      ));
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.0),
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
                  Icon(Icons.calculate_outlined, color: Color(0xFF06B6D4), size: 16.0),
                  SizedBox(width: 6.0),
                  Text(
                    'EPVAT Calculated Results & Formulas (Admin Defined)',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ],
              ),
              Row(
                children: [
                  if (widget.onOpenEpvatRulesInControl != null) ...[
                    InkWell(
                      onTap: widget.onOpenEpvatRulesInControl,
                      borderRadius: BorderRadius.circular(4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.tune_rounded, color: Color(0xFF818CF8), size: 11.0),
                            SizedBox(width: 4.0),
                            Text(
                              'Configure in Control Rules',
                              style: TextStyle(color: Color(0xFF818CF8), fontSize: 10.0, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Auto Calculated',
                      style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          ...results.map((res) {
            final isApp = res.isApplicable;
            final passed = res.isPassed;
            final Color cardBg = !isApp
                ? const Color(0xFF64748B).withOpacity(0.06)
                : (passed ? const Color(0xFF10B981).withOpacity(0.05) : const Color(0xFFEF4444).withOpacity(0.05));
            final Color cardBorder = !isApp
                ? const Color(0xFF64748B).withOpacity(0.2)
                : (passed ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.25));
            final Color badgeBg = !isApp
                ? const Color(0xFF64748B).withOpacity(0.15)
                : (passed ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15));
            final Color badgeBorder = !isApp
                ? const Color(0xFF64748B).withOpacity(0.4)
                : (passed ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4));
            final Color badgeText = !isApp
                ? const Color(0xFF94A3B8)
                : (passed ? const Color(0xFF10B981) : const Color(0xFFEF4444));
            final String statusLabel = !isApp ? 'NOT TESTED' : (passed ? 'PASSED' : 'FAILED');

            return Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: cardBorder),
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
                            children: isApp
                                ? [
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
                                  ]
                                : [
                                    const TextSpan(text: 'Calculation: ', style: TextStyle(color: Color(0xFF8E96A3))),
                                    const TextSpan(
                                      text: 'Not Tested (Temperature condition not evaluated in this entry)',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
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
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: badgeText,
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

    _initPrimerDropTable();

    // Compute live totals for display
    int totalF = 0;
    int totalM = 0;
    for (final r in _primerDropTableRows) {
      totalF += int.tryParse(r.f.text.trim()) ?? 0;
      totalM += int.tryParse(r.m.text.trim()) ?? 0;
    }
    final int totalTested = totalF + totalM;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FB),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFFD6E4F0)),
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
                    'Primer Sensitivity Test Specifications',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 13.0, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ],
              ),
              Row(
                children: [
                  if (!isLotPrimerLocked) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          final lastH = _primerDropTableRows.isNotEmpty ? (double.tryParse(_primerDropTableRows.last.h.text.trim()) ?? 255.0) + 15.0 : 130.0;
                          _primerDropTableRows.add(_createPrimerDropRow(lastH.toStringAsFixed(1), '', '', ''));
                        });
                      },
                      icon: const Icon(Icons.add, size: 14.0, color: Color(0xFF0284C7)),
                      label: const Text('Add Height Row', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                  ],
                  if (!isLotPrimerLocked)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final res = await getAttachmentHelper().pickFileAsBase64();
                        if (res != null && res['name'] != null && res['data'] != null) {
                          setState(() {
                            _attachmentName = res['name']!;
                            _attachmentBase64 = res['data']!;
                          });
                          _autoExtractFromAttachment(res['name']!, res['data']!);
                        } else if (_attachmentBase64.isNotEmpty) {
                          _autoExtractFromAttachment(_attachmentName, _attachmentBase64);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 14.0, color: Colors.white),
                      label: const Text('Auto-Extract from PDF Report', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          if (isLotPrimerLocked) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFF38BDF8), size: 16.0),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Lot Acceptance Module: Primer Sensitivity metrics are synchronized automatically from Component Primer Lot (${_selectedComponentPrimerLot ?? _primerLotController.text}) and locked against manual changes.',
                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. Drop Table Section matching laboratory test report
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(5.0), topRight: Radius.circular(5.0)),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('H (mm)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('F (Fires)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('M (Misfires)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('PI (Probability)', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontWeight: FontWeight.bold))),
                      SizedBox(width: 32.0, child: Text('', textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                // Rows
                for (int i = 0; i < _primerDropTableRows.length; i++) ...[
                  Builder(builder: (context) {
                    final row = _primerDropTableRows[i];
                    return Container(
                      color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                              child: _buildTextField(
                                controller: row.h,
                                hint: '0.0',
                                readOnly: isLotPrimerLocked,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) {
                                  _scheduleAutoSave();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                              child: _buildTextField(
                                controller: row.f,
                                hint: '0',
                                readOnly: isLotPrimerLocked,
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  _recalculatePrimerDropStats();
                                  _scheduleAutoSave();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                              child: _buildTextField(
                                controller: row.m,
                                hint: '0',
                                readOnly: isLotPrimerLocked,
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  _recalculatePrimerDropStats();
                                  _scheduleAutoSave();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                              child: _buildTextField(
                                controller: row.pi,
                                hint: '0.000',
                                readOnly: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32.0,
                            child: (!isLotPrimerLocked && _primerDropTableRows.length > 1)
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 14.0, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      setState(() {
                                        _primerDropTableRows.removeAt(i).dispose();
                                        _recalculatePrimerDropStats();
                                      });
                                    },
                                    tooltip: 'Remove row',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (i < _primerDropTableRows.length - 1)
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ],
                // Totals summary bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(5.0), bottomRight: Radius.circular(5.0)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Total Tested: $totalTested',
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      const SizedBox(width: 16.0),
                      Text(
                        'Total Fires: $totalF',
                        style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      const SizedBox(width: 16.0),
                      Text(
                        'Total Misfires: $totalM',
                        style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),

          // 2. Statistics Table Section (HM, SD, Alpha3, Emax, Emin, HM+5SD, HM-2SD)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Primer Sensitivity Statistics',
                  style: TextStyle(color: Color(0xFF0284C7), fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        label: 'HM (mm)',
                        controller: _primerHbarController,
                        readOnly: isLotPrimerLocked,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(
                        label: 'SD (mm)',
                        controller: _primerSDController,
                        readOnly: isLotPrimerLocked,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(
                        label: 'Alpha3',
                        controller: _primerAlpha3Controller,
                        readOnly: isLotPrimerLocked,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(
                        label: 'Emax',
                        controller: _primerEmaxController,
                        readOnly: isLotPrimerLocked,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(
                        label: 'Emin',
                        controller: _primerEminController,
                        readOnly: isLotPrimerLocked,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(
                        label: 'HM + 5SD (All Fire)',
                        controller: _primerHbarPlus5SController,
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: _buildStatBox(
                        label: 'HM - 2SD (No Fire)',
                        controller: _primerHbarMinus2SController,
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        } else if (_isAccuracyOrBullet) {
          final accRules = _getAccuracyRulesForCaliber();
          final double maxMeanRadius = (accRules['max_mean_radius'] ?? 50.0).toDouble();
          final double maxSD = (accRules['max_sd'] ?? 200.0).toDouble();
          final double condSD = (accRules['cond_sd'] ?? 170.0).toDouble();
          final double velMin = (accRules['vel_min'] as num).toDouble();
          final double velMax = (accRules['vel_max'] as num).toDouble();

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
          if (_functionTempMode == 'All') {
            int sumL1 = 0;
            int sumL2 = 0;
            int sumL3 = 0;
            int sumL4 = 0;
            for (var t in _functionTempList) {
              sumL1 += int.tryParse(_funcAllL1Controllers[t]?.text.trim() ?? '') ?? 0;
              sumL2 += int.tryParse(_funcAllL2Controllers[t]?.text.trim() ?? '') ?? 0;
              sumL3 += int.tryParse(_funcAllL3Controllers[t]?.text.trim() ?? '') ?? 0;
              sumL4 += int.tryParse(_funcAllL4Controllers[t]?.text.trim() ?? '') ?? 0;
            }
            autoStatus = _calculateFunctionTestStatus(l1: sumL1, l2: sumL2, l3: sumL3, l4: sumL4);
          } else {
            final l1 = int.tryParse(_functionLevel1Controller.text.trim()) ?? 0;
            final l2 = int.tryParse(_functionLevel2Controller.text.trim()) ?? 0;
            final l3 = int.tryParse(_functionLevel3Controller.text.trim()) ?? 0;
            final l4 = int.tryParse(_functionLevel4Controller.text.trim()) ?? 0;
            autoStatus = _calculateFunctionTestStatus(l1: l1, l2: l2, l3: l3, l4: l4);
          }
        } else if (_testName == 'EPVAT test' || _testName == 'Propellant Test') {
          // Quality status is decided strictly by auto calculation of EPVAT formulas.
          autoStatus = _getCalculatedStatus();
          if (_status != autoStatus) {
            _status = autoStatus!;
            _isManualStatusSelected = false;
          }
        }

        if (!_isManualStatusSelected && autoStatus != null && _status != autoStatus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (!_isManualStatusSelected || _testName == 'EPVAT test' || _testName == 'Propellant Test')) {
              setState(() {
                _status = autoStatus!;
              });
            }
          });
        }

        Color statusBgColor;
        Color statusBorderColor;
        Color statusTextColor = Colors.white;
        
        if (_status == 'Approved with condition') {
          statusBgColor = const Color(0xFF0284C7); // Sky-blue / Cyan for conditional approval
          statusBorderColor = const Color(0xFF0369A1);
        } else if (_status == 'Approved') {
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
          isRequired: true,
          child: DropdownButtonFormField<String>(
            value: _status,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            icon: Icon(Icons.arrow_drop_down, color: statusTextColor),
            style: TextStyle(color: statusTextColor, fontSize: 13.5, fontWeight: FontWeight.bold),
            selectedItemBuilder: (BuildContext context) {
              return ['Approved', 'Approved with condition', 'Pending Review', 'Rejected', 'Retest'].map((s) {
                final double fontSize = s == 'Approved with condition' ? 11.5 : 13.0;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: statusTextColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s,
                            maxLines: 1,
                            style: TextStyle(
                              color: statusTextColor,
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: statusBgColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
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
            items: const ['Approved', 'Approved with condition', 'Pending Review', 'Rejected', 'Retest'].map((s) {
              Color itemColor = Colors.white;
              if (s == 'Approved') itemColor = const Color(0xFF34D399);
              if (s == 'Approved with condition') itemColor = const Color(0xFF38BDF8);
              if (s == 'Rejected') itemColor = const Color(0xFFF87171);
              if (s == 'Retest') itemColor = const Color(0xFFFBBF24);
              if (s == 'Pending Review') itemColor = const Color(0xFFFCD34D);
              return DropdownMenuItem<String>(
                value: s,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: itemColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: itemColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _status = v;
                  _isManualStatusSelected = true;
                });
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSampleLocationField({int flex = 2}) {
    return _buildFlexibleField(
      flex: flex,
      label: 'Sampling Location',
      isRequired: true,
      child: Row(
        children: [
          Expanded(
            child: _buildDropdownField(
              value: _locationController.text,
              items: _allSampleLocations,
              allowEmpty: true,
              hintText: 'Select Sampling Location...',
              onChanged: (v) {
                if (v != null) {
                  setState(() => _locationController.text = v);
                }
              },
            ),
          ),
          if (_isAdmin) ...[
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
        ],
      ),
    );
  }

  Widget _buildConsolidatedRow2() {
    if (_testName == 'Waterproof Test') {
      return _buildFormRow([
        _buildFlexibleField(
          key: _producedFieldKey,
          flex: 2,
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
          label: 'Viscosity (seconds)',
          isRequired: true,
          child: _buildTextField(
            controller: _viscosityController,
            hint: 'e.g., 40',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          ),
        ),
        _buildSampleLocationField(flex: 2),
        _buildFlexibleField(
          flex: 2,
          label: 'Pressure (Bar) - Caliber Fixed',
          isRequired: true,
          child: _buildTextField(
            controller: _pressureController,
            readOnly: true,
            hint: (_caliber.contains('M82') || _caliber.contains('M200')) ? '0.14' : '0.5',
          ),
        ),
        _buildQualityStatusField(flex: 8),
      ], lockSingleRow: true);
    }

    if (_isAccuracyOrBullet) {
      return _buildFormRow([
        _buildFlexibleField(
          key: _producedFieldKey,
          flex: 2,
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
          flex: 3,
          label: 'Accuracy Barrel Test Serial',
          isRequired: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdownField(
                focusNode: _barrelFocusNode,
                value: _barrelSNController.text,
                items: _accuracyBarrels,
                allowEmpty: true,
                hintText: 'Select Barrel S.N...',
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
        _buildSampleLocationField(flex: 2),
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
        _buildQualityStatusField(flex: 8),
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
        final matchesCaliber = _isSameCaliberFamily(r.caliber, _caliber);
        if (_primerSupplier.isNotEmpty) {
          return matchesCaliber && r.primerSupplier.trim().toLowerCase() == _primerSupplier.trim().toLowerCase();
        }
        return matchesCaliber;
      }).toList();
      final primerLotOptions = matchingPrimerRecords
          .map((r) => r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber)
          .where((l) => l.isNotEmpty)
          .toSet()
          .toList();

      // Harvest from all historical records if component records are empty or missing this caliber family
      final fromHistory = widget.records.where((r) {
        final matchesCaliber = _isSameCaliberFamily(r.caliber, _caliber);
        if (_primerSupplier.isNotEmpty) {
          return matchesCaliber && r.primerSupplier.trim().toLowerCase() == _primerSupplier.trim().toLowerCase();
        }
        return matchesCaliber;
      }).map((r) => r.primerLot.isNotEmpty ? r.primerLot : r.lotNumber).where((l) => l.isNotEmpty).toSet();
      for (final h in fromHistory) {
        if (!primerLotOptions.contains(h)) primerLotOptions.add(h);
      }

      // If current controller has a lot, ensure it is in the dropdown choices
      if (_primerLotController.text.trim().isNotEmpty && !primerLotOptions.contains(_primerLotController.text.trim())) {
        primerLotOptions.insert(0, _primerLotController.text.trim());
      }





      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // EPVAT ROW 1: Temp eval mode, Quantity tested, Propellant (dropdown), Propellant code (dropdown), Propellant lot (dropdown), Primer supplier (dropdown), Primer lot (dropdown)
          _buildFormRow([
            _buildFlexibleField(
              flex: 3,
              label: 'Temp Evaluation Mode',
              isRequired: true,
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
              label: 'Powder Charge (g)',
              isRequired: true,
              child: _buildTextField(
                controller: _propellantChargeController,
                hint: 'e.g. 1.75',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Number';
                  return null;
                },
              ),
            ),
            _buildFlexibleField(
              flex: 2,
              label: 'Propellant',
              isRequired: true,
              child: _isAdmin
                  ? _buildTextField(
                      controller: _epvatAdminPropellantSupplierController,
                      hint: 'Supplier',
                      onChanged: (v) {
                        _propellantSupplier = v;
                      },
                    )
                  : _buildDropdownField(
                      value: _propellantSuppliers.contains(_propellantSupplier)
                          ? _propellantSupplier
                          : (_propellantSuppliers.isNotEmpty ? _propellantSuppliers.first : ''),
                      items: _propellantSuppliers,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _propellantSupplier = v;
                            _epvatAdminPropellantSupplierController.text = v;
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
              child: _isAdmin
                  ? _buildTextField(
                      controller: _propellantCodeController,
                      hint: 'Code',
                    )
                  : _buildDropdownField(
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
              child: (_isAdmin || propellantLotOptions.isEmpty)
                  ? _buildTextField(
                      controller: _propellantLotController,
                      hint: 'e.g. 90124',
                      keyboardType: TextInputType.text,
                    )
                  : DropdownButtonFormField<String>(
                      value: propellantLotOptions.contains(_propellantLotController.text.trim())
                          ? _propellantLotController.text.trim()
                          : propellantLotOptions.first,
                      isExpanded: true,
                      dropdownColor: const Color(0xFFE0F2FE),
                      style: const TextStyle(color: Color(0xFF0C2A4D), fontSize: 13.0, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFE0F2FE),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF7DD3FC))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF7DD3FC))),
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
                    ),
            ),
            _buildFlexibleField(
              flex: 2,
              label: 'Primer Supplier',
              isRequired: true,
              child: Builder(
                builder: (context) {
                  final suppliers = [
                    ..._getPrimerSuppliersForCaliber(_caliber),
                    '[+ Add Supplier]',
                  ];
                  return _buildDropdownField(
                    value: _primerSupplier,
                    items: suppliers,
                    allowEmpty: true,
                    hintText: 'Select Primer Supplier...',
                    onChanged: (v) {
                      if (v == null) return;
                      if (v == '[+ Add Supplier]') {
                        _showAddPrimerSupplierDialog();
                        return;
                      }
                      setState(() {
                        _primerSupplier = v;
                        _epvatAdminPrimerSupplierController.text = v;
                        final subLots = _getPrimerLotsForCaliberAndSupplier(_caliber, v);
                        if (subLots.isNotEmpty) {
                          _selectedComponentPrimerLot = subLots.first;
                          _primerLotController.text = subLots.first;
                        } else {
                          _selectedComponentPrimerLot = '';
                          _primerLotController.clear();
                        }
                      });
                    },
                  );
                },
              ),
            ),
            _buildFlexibleField(
              flex: 3,
              label: 'Primer Lot',
              isRequired: true,
              child: Builder(
                builder: (context) {
                  final lots = _getPrimerLotsForCaliberAndSupplier(_caliber, _primerSupplier);
                  final dropdownItems = [...lots, '[+ Add Custom Lot]'];
                  return _buildDropdownField(
                    value: _primerLotController.text.trim(),
                    items: dropdownItems,
                    allowEmpty: true,
                    hintText: 'Select Primer Lot...',
                    onChanged: (v) {
                      if (v == null) return;
                      if (v == '[+ Add Custom Lot]') {
                        _showAddCustomPrimerLotDialog();
                        return;
                      }
                      setState(() {
                        _selectedComponentPrimerLot = v;
                        _primerLotController.text = v;
                      });
                    },
                  );
                },
              ),
            ),
          ], lockSingleRow: true),
          const SizedBox(height: 14.0),

          // EPVAT ROW 2: Barrel Serial No., GP6 (1) Chamber, GP6 (2) Port, Velocity distance, Sampling location, Quality status
          _buildFormRow([
            _buildFlexibleField(
              key: _barrelFieldKey,
              flex: 2,
              label: 'Barrel Serial No.',
              isRequired: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownField(
                    focusNode: _barrelFocusNode,
                    value: _barrelSNController.text,
                    items: _epvatBarrels,
                    allowEmpty: true,
                    hintText: 'Select Barrel S.N...',
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
              flex: 2,
              label: 'GP6 (1) Chamber',
              isRequired: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _manualGP1Entry
                            ? _buildTextField(
                                controller: _epvatSensor1Controller,
                                hint: 'e.g., GP6-001 (PCB 119B)',
                              )
                            : _buildDropdownField(
                                value: _epvatSensor1Controller.text,
                                items: _gp1Transducers,
                                allowEmpty: true,
                                hintText: 'Select GP6 (1)...',
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
                  const SizedBox(height: 4.0),
                  Text(
                    '${_getAssetRounds(_epvatSensor1Controller.text)} rounds fired',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (!_isCaliber9mm)
              _buildFlexibleField(
                key: _gp6FieldKey,
                flex: 2,
                label: 'GP6 (2) Port',
                isRequired: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropdownField(
                      focusNode: _gp6FocusNode,
                      value: _gp6SerialController.text,
                      items: _gp6Serials,
                      allowEmpty: true,
                      hintText: 'Select GP6 (2)...',
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
            _buildSampleLocationField(flex: 2),
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
            _buildQualityStatusField(flex: 8),
          ], lockSingleRow: true),
        ],
      );
    }

    if (_testName == 'Function Test') {
      return _buildFormRow([
        _buildFlexibleField(
          key: _producedFieldKey,
          flex: 2,
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
        _buildSampleLocationField(flex: 2),
        _buildFlexibleField(
          flex: 3,
          label: 'Temperature Evaluation Mode',
          isRequired: true,
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
            flex: 2,
            label: 'Selected Temperature',
            isRequired: true,
            child: _buildDropdownField(
              value: _selectedTemperatureDisplay,
              items: ['+21 °C', '+52 °C', _functionColdTempLabel],
              onChanged: (v) {
                if (v != null) _onSelectedTemperatureChanged(v);
              },
            ),
          ),
        _buildQualityStatusField(flex: 8),
      ], lockSingleRow: true);
    }

    // Default row for Primer Sensitivity Test, Residual Stress Test, Extraction Force Test, etc.
    return _buildFormRow([
      _buildFlexibleField(
        key: _producedFieldKey,
        flex: 2,
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
      _buildSampleLocationField(flex: 2),
      if (_testHasTemperatureEvaluation) ...[
        _buildFlexibleField(
          flex: 3,
          label: 'Temperature Evaluation Mode',
          isRequired: true,
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
            flex: 2,
            label: 'Selected Temperature',
            isRequired: true,
            child: _buildDropdownField(
              value: _selectedTemperatureDisplay,
              items: const ['+21 °C', '+52 °C', '-54 °C'],
              onChanged: (v) {
                if (v != null) _onSelectedTemperatureChanged(v);
              },
            ),
          ),
      ],
      _buildQualityStatusField(flex: 8),
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

  void _clearPrimerFields() {
    _primerLotController.clear();
    _primerInsertionDepthController.clear();
    _primerHbarController.clear();
    _primerSDController.clear();
    _primerHbarPlus5SController.clear();
    _primerHbarMinus2SController.clear();
    _producedController.clear();
    _primerMisfiresCountController.clear();
    _notesController.clear();
  }

  Widget _buildComponentAndPrimerFieldsCard() {
    final bool isComponent = widget.currentModule == 'Component Test';
    final bool isLotAcceptance = widget.currentModule == 'Lot Acceptance Test';

    if (isComponent && _isAccuracyOrBullet) {
      return _buildComponentBulletAccuracyCard();
    }

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
                ElevatedButton.icon(
                  onPressed: () async {
                    final res = await getAttachmentHelper().pickFileAsBase64();
                    if (res != null && res['name'] != null && res['data'] != null) {
                      setState(() {
                        _attachmentName = res['name']!;
                        _attachmentBase64 = res['data']!;
                      });
                      _autoExtractFromAttachment(res['name']!, res['data']!);
                    } else if (_attachmentBase64.isNotEmpty) {
                      _autoExtractFromAttachment(_attachmentName, _attachmentBase64);
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 14.0, color: Colors.white),
                  label: const Text('Auto-Extract from PDF Report', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    elevation: 1,
                  ),
                ),
                if (isOutOfSpec || isInSpec) const SizedBox(width: 8.0),
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
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
      final allAvailablePrimerRecords = [
        ...widget.componentPrimerRecords,
        ...widget.records.where((r) => r.testName.toLowerCase().contains('primer') || r.primerLot.isNotEmpty),
      ];
      final matchingRecords = allAvailablePrimerRecords
          .where((r) => _isSameCaliberFamily(r.caliber, _caliber))
          .toList();

      // Collect suppliers that actually have records submitted for this caliber family
      final availableSuppliers = matchingRecords
          .map((r) => r.primerSupplier.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final supplierOptions = ['All Suppliers', ...availableSuppliers];
      final currentSupplier = supplierOptions.contains(_primerSupplier)
          ? _primerSupplier
          : 'All Suppliers';

      final recordsForSupplier = (currentSupplier == 'All Suppliers' || currentSupplier.isEmpty)
          ? matchingRecords
          : matchingRecords.where((r) => r.primerSupplier.trim().toLowerCase() == currentSupplier.trim().toLowerCase()).toList();
      final targetRecords = recordsForSupplier.isNotEmpty ? recordsForSupplier : matchingRecords;

      final lotOptions = targetRecords
          .map((r) => r.primerLot.isNotEmpty ? r.primerLot : (r.lotNo.isNotEmpty ? r.lotNo : r.lotNumber))
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.trim())
          .toSet()
          .toList()
        ..sort();

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
              'Select the verified Primer Supplier and Primer Lot from the Component module. All sensitivity metrics (H̄, S, H̄+5S, H̄-2S, Drop Weight, Quantity, Misfires, Supplier, and Depth) synchronize automatically and are locked for Lot Acceptance.',
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
            else ...[
              _buildFormRow([
                _buildFlexibleField(
                  flex: 1,
                  label: 'Primer Supplier',
                  isRequired: false,
                  child: _buildDropdownField(
                    value: currentSupplier,
                    items: supplierOptions,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _primerSupplier = v;
                          final recs = (v == 'All Suppliers' || v.isEmpty)
                              ? matchingRecords
                              : matchingRecords.where((r) => r.primerSupplier.trim().toLowerCase() == v.trim().toLowerCase()).toList();
                          final newLots = (recs.isNotEmpty ? recs : matchingRecords)
                              .map((r) => r.primerLot.isNotEmpty ? r.primerLot : (r.lotNo.isNotEmpty ? r.lotNo : r.lotNumber))
                              .where((l) => l.trim().isNotEmpty)
                              .map((l) => l.trim())
                              .toSet()
                              .toList();
                          if (_selectedComponentPrimerLot != null && !newLots.contains(_selectedComponentPrimerLot)) {
                            _selectedComponentPrimerLot = null;
                            _clearPrimerFields();
                          }
                        });
                      }
                    },
                  ),
                ),
                _buildFlexibleField(
                  flex: 1,
                  label: 'Submitted Primer Lot',
                  isRequired: true,
                  child: _buildDropdownField(
                    value: lotOptions.contains(_selectedComponentPrimerLot)
                        ? _selectedComponentPrimerLot
                        : null,
                    items: lotOptions,
                    allowEmpty: true,
                    hintText: lotOptions.isEmpty
                        ? '-- No Primer Lots Found --'
                        : '-- Select Primer Lot (${lotOptions.length} Available) --',
                    onChanged: (v) {
                      if (v != null && v.isNotEmpty) {
                        setState(() {
                          _selectedComponentPrimerLot = v;
                          final match = targetRecords.firstWhere(
                            (r) => (r.primerLot.isNotEmpty ? r.primerLot : (r.lotNo.isNotEmpty ? r.lotNo : r.lotNumber)).trim() == v.trim(),
                            orElse: () => targetRecords.first,
                          );
                          _syncPrimerSensitivityMetrics(match);
                        });
                      } else {
                        setState(() {
                          _selectedComponentPrimerLot = null;
                          _clearPrimerFields();
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
                  label: 'Avg. Insertion Depth (mm) (Auto-populated)',
                  child: _buildTextField(
                    controller: _primerInsertionDepthController,
                    readOnly: true,
                    hint: '0.00 mm',
                  ),
                ),
              ]),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildComponentBulletAccuracyCard() {
    if (_bulletSupplierController.text.trim().isEmpty && _bulletSuppliers.isNotEmpty) {
      _bulletSupplierController.text = _bulletSuppliers.first;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF23364F),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, color: Color(0xFF38BDF8), size: 18.0),
              const SizedBox(width: 8.0),
              const Text(
                'Component Bullet Accuracy Specifications',
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final res = await getAttachmentHelper().pickFileAsBase64();
                  if (res != null && res['name'] != null && res['data'] != null) {
                    setState(() {
                      _attachmentName = res['name']!;
                      _attachmentBase64 = res['data']!;
                    });
                    _autoExtractFromAttachment(res['name']!, res['data']!);
                  } else if (_attachmentBase64.isNotEmpty) {
                    _autoExtractFromAttachment(_attachmentName, _attachmentBase64);
                  }
                },
                icon: const Icon(Icons.picture_as_pdf, size: 14.0, color: Colors.white),
                label: const Text('Auto-Extract from Report', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  elevation: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          _buildFormRow([
            _buildFlexibleField(
              flex: 1,
              label: 'Bullet Supplier',
              isRequired: true,
              child: Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      value: _bulletSuppliers.contains(_bulletSupplierController.text.trim())
                          ? _bulletSupplierController.text.trim()
                          : (_bulletSuppliers.isNotEmpty ? _bulletSuppliers.first : ''),
                      items: _bulletSuppliers,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _bulletSupplierController.text = v;
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
                        color: const Color(0xFF38BDF8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF38BDF8)),
                        tooltip: 'Admin: Add Bullet Supplier',
                        padding: const EdgeInsets.all(6.0),
                        constraints: const BoxConstraints(),
                        onPressed: _showAddBulletSupplierDialog,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'Grain Size',
              isRequired: true,
              child: _buildTextField(
                controller: _bulletGrainSizeController,
                hint: 'e.g., 55 grains, 69 grains, 175 grains',
                onChanged: (_) => _scheduleAutoSave(),
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'Powder Charge in Gram',
              isRequired: true,
              child: _buildTextField(
                controller: _propellantChargeController,
                hint: 'e.g., 1.62',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                onChanged: (_) => _scheduleAutoSave(),
              ),
            ),
          ]),
          const SizedBox(height: 12.0),
          _buildFormRow([
            _buildFlexibleField(
              flex: 1,
              label: 'Sample Loading Method',
              isRequired: true,
              child: _buildDropdownField(
                value: ['Manually Loaded', 'From the Line'].contains(_sampleLoadingMethod)
                    ? _sampleLoadingMethod
                    : 'Manually Loaded',
                items: const ['Manually Loaded', 'From the Line'],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _sampleLoadingMethod = v);
                    _scheduleAutoSave();
                  }
                },
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'Sample Received Date',
              isRequired: true,
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _sampleReceivedDateController,
                      hint: 'yyyy-MM-dd',
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
                      tooltip: 'Pick sample received date',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () async {
                        final now = DateTime.now();
                        DateTime initialDate = now;
                        try {
                          if (_sampleReceivedDateController.text.trim().isNotEmpty) {
                            initialDate = DateTime.parse(_sampleReceivedDateController.text.trim());
                          }
                        } catch (_) {}
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _sampleReceivedDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                          _scheduleAutoSave();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            _buildFlexibleField(
              flex: 1,
              label: 'Sample Location',
              isRequired: true,
              child: _buildDropdownField(
                value: ['QC', 'Production', 'Inventory'].contains(_bulletSampleLocation)
                    ? _bulletSampleLocation
                    : 'QC',
                items: const ['QC', 'Production', 'Inventory'],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _bulletSampleLocation = v;
                      _locationController.text = v;
                    });
                    _scheduleAutoSave();
                  }
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCompactInlineAttachment() {
    if (_attachmentName.isEmpty) {
      return Container(
        height: 38.0,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6.0),
            onTap: () async {
              final res = await getAttachmentHelper().pickFileAsBase64();
              if (res != null && res['name'] != null && res['data'] != null) {
                setState(() {
                  _attachmentName = res['name']!;
                  _attachmentBase64 = res['data']!;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.upload_file, size: 15.0, color: Color(0xFF0284C7)),
                  SizedBox(width: 6.0),
                  Text('Attach File (Optional)', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 38.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color(0xFF0284C7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 15.0),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              _attachmentName,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.0, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14.0, color: Color(0xFFEF4444)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Remove Attachment',
            onPressed: () => setState(() {
              _attachmentName = '';
              _attachmentBase64 = '';
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminInstructionsCard() {
    String specText = '';
    String instructionsText = '';
    
    if (_testName == 'Waterproof Test') {
      final wpRules = _getWaterproofRulesForCaliber();
      final int retestLimit = wpRules['retest_limit'] ?? 4;
      final int rejectLimit = wpRules['reject_limit'] ?? 7;
      specText = 'Caliber: $_caliber | Limits: Retest if Leaks >= $retestLimit, Reject if Leaks >= $rejectLimit.';
      instructionsText = wpRules['instructions'] ?? 'Follow waterproof leakage inspection protocol.';
    } else if (_testName == 'Residual Stress Test') {
      final rsRules = _getResidualStressRulesForCaliber();
      final int retestLimit = rsRules['retest_limit'] ?? 1;
      final int rejectLimit = rsRules['reject_limit'] ?? 3;
      specText = 'Caliber: $_caliber | Splits/Cracks limits: Retest if total splits >= $retestLimit, Reject if total splits >= $rejectLimit.';
      instructionsText = rsRules['instructions'] ?? 'Examine splits on Neck, Shoulder, Body, and Head.';
    } else if (_testName == 'Extraction Force Test') {
      final extRules = _getExtractionRulesForCaliber();
      final double limit = (extRules['min_force'] ?? 200.0).toDouble();
      specText = 'Caliber: $_caliber | Min Extraction Force: ${limit.toStringAsFixed(1)} N.';
      instructionsText = extRules['instructions'] ?? 'Perform pull-out test of bullet and record peak force.';
    } else if (_isAccuracyOrBullet) {
      final accRules = _getAccuracyRulesForCaliber();
      final double maxMeanRadius = (accRules['max_mean_radius'] ?? 50.0).toDouble();
      final double maxSD = (accRules['max_sd'] ?? 200.0).toDouble();
      final double targetMean = (accRules['vel_target_mean'] ?? 915.0).toDouble();
      final double tolerance = (accRules['vel_tolerance'] ?? 13.0).toDouble();
      final double velMin = (accRules['vel_min'] as num).toDouble();
      final double velMax = (accRules['vel_max'] as num).toDouble();
      specText = 'Caliber: $_caliber | Mean Velocity: Target ${targetMean.toStringAsFixed(1)} ± ${tolerance.toStringAsFixed(1)} m/s [${velMin.toStringAsFixed(1)} - ${velMax.toStringAsFixed(1)} m/s] | Max Radius: ${maxMeanRadius.toStringAsFixed(1)} mm | Max SD: ${maxSD.toStringAsFixed(1)} mm';
      instructionsText = accRules['instructions'] ?? 'Assess group sizing at target distance.';
    } else if (_testName.toLowerCase().contains('epvat') || _testName.toLowerCase().contains('propellant')) {
      return const SizedBox.shrink();
    } else if (_testName == 'Primer Sensitivity Test') {
      final prRules = _getPrimerRulesForCaliber();
      final double dropWeight = ((prRules['drop_weight'] ?? 55.0) as num).toDouble();
      final double hbarMin = ((prRules['hbar_min'] ?? 250.0) as num).toDouble();
      final double hbarMax = ((prRules['hbar_max'] ?? 450.0) as num).toDouble();
      final double allFireLimit = ((prRules['all_fire_h'] ?? 500.0) as num).toDouble();
      specText = 'Caliber: $_caliber | Drop Ball Weight: ${dropWeight.toStringAsFixed(1)} g | H̄: ${hbarMin.toStringAsFixed(1)}-${hbarMax.toStringAsFixed(1)} mm | All Fire (H̄+5S) Max: ${allFireLimit.toStringAsFixed(1)} mm';
      instructionsText = prRules['instructions'] ?? 'Perform drop ball sensitivity test.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6.0),
          onTap: () => setState(() => _isInstructionsExpanded = !_isInstructionsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 14.0),
                    const SizedBox(width: 6.0),
                    Text(
                      (_testName == 'EPVAT test' || _testName == 'Propellant Test')
                          ? 'Specs & Admin Recommendation'
                          : 'Specs & Admin Instructions',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        specText.replaceAll('\n', ' | '),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _isInstructionsExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF94A3B8),
                      size: 16.0,
                    ),
                  ],
                ),
                if (_isInstructionsExpanded) ...[
                  const Divider(color: Color(0xFF334155), height: 10.0),
                  Text(
                    specText,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.0, height: 1.3),
                  ),
                  if (instructionsText.isNotEmpty) ...[
                    const SizedBox(height: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, color: Color(0xFF38BDF8), size: 14.0),
                              const SizedBox(width: 4.0),
                              Text(
                                (_testName == 'EPVAT test' || _testName == 'Propellant Test')
                                    ? 'Admin Recommendation (Advisory Only):'
                                    : 'Instructions:',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.0, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            instructionsText,
                            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.0, fontStyle: FontStyle.italic),
                          ),
                          if (_testName == 'EPVAT test' || _testName == 'Propellant Test') ...[
                            const SizedBox(height: 3.0),
                            const Text(
                              '* Note: Admin instruction is an advisory recommendation only. Quality status is determined strictly by EPVAT calculated results.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
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
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 3.0),
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

