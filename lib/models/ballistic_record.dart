import 'dart:math' as math;

class BallisticRecord {
  static String generateUuid() {
    final random = math.Random();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10
    return [
      values.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      values.sublist(10, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    ].join('-');
  }

  final String? id;
  final String timestamp;
  final String operators;
  final String shift;
  final String caliber;
  final String lotNo;
  final int produced;
  final int defects;
  final String notes;
  final String status;
  final String testName;
  final String pressureBar;
  final String viscosity;
  final String testTime;
  final String samplingLocation;
  final int mouthSlow;
  final int mouthFast;
  final int primerSlow;
  final int primerFast;
  final String hopperNo;
  final String boxNo;
  final String requirement;

  // New Accuracy Test fields
  final String barrelSN;
  final String barrelType;
  final String velocityDistance;
  final String accMeanX;
  final String accMaxX;
  final String accMinX;
  final String accRangeX;
  final String accSDX;
  final String accMeanY;
  final String accMaxY;
  final String accMinY;
  final String accRangeY;
  final String accSDY;
  final String velMean;
  final String velMin;
  final String velMax;
  final String velRange;
  final String velSD;
  final String accMeanRadius;
  final String accLargestDistance;

  // New fields for EPVAT & Extraction Force details
  final String extractionForceType;
  final String extractionForceRounds;
  final String cartridgeTemp;
  final String epvatPressureType;
  final String epvatPressureUnit;
  final String epvatPressureRounds;
  final String epvatMeanPressure;
  final String epvatMaxPressure;
  final String epvatMinPressure;
  final String epvatRangePressure;
  final String epvatSDPressure;
  
  // New fields for EPVAT P2 pressure and individual rounds
  final String epvatP2MeanPressure;
  final String epvatP2MaxPressure;
  final String epvatP2MinPressure;
  final String epvatP2RangePressure;
  final String epvatP2SDPressure;
  final String epvatP2PressureRounds;
  final String epvatVelRounds;

  // EPVAT Sensor fields (near barrel)
  final String epvatSensor1;
  final String epvatSensor2;

  // Cyclic Rate Test fields
  final String cyclicRateWeaponType;
  final String cyclicRateAmmoType; // 'Linked' or 'Loose'
  final String cyclicRateValue;
  final String cyclicRateMin;
  final String cyclicRateMax;

  // Terminal Effect Test fields
  final String terminalHoleDiameter;    // Yes/No
  final String terminalSteelPenetration; // Yes/No
  final String terminalAluminumPenetration; // Yes/No
  final String terminalVelocity;         // optional m/s

  // New fields for Residual Stress Test
  final int neckSlow;
  final int neckFast;
  final int shoulderSlow;
  final int shoulderFast;
  final int bodySlow;
  final int bodyFast;
  final int headSlow;
  final int headFast;
  final String roomTemp;

  // Fields for Function Test (4-Level Defect Classification)
  final int functionLevel1; // Critical defect
  final int functionLevel2; // Major defect
  final int functionLevel3; // Minor defect
  final int functionLevel4; // Level 4 defect

  // Attachment fields
  final String attachmentName;
  final String attachmentBase64;

  // Fields for EPVAT Action Time
  final String actionTimeMean;
  final String actionTimeMin;
  final String actionTimeMax;
  final String actionTimeRange;
  final String actionTimeSD;
  final String actionTimeRounds;

  // Fields for Primer Sensitivity Test
  final String primerDropHeights;
  final String primerFireResults;
  final String primerHbar;
  final String primerSD;
  final String primerAllFireH;
  final String primerNoFireH;

  // Selected defect items detail string
  final String functionDefectDetails;

  // Equipment Asset & User Role Tracking
  final String gp6Serial;
  final String userRole;
  final String module;

  // Primer & Propellant Component / Acceptance Tracking
  final String primerLot;
  final String primerSupplier;
  final String primerInsertionDepth;
  final String propellantSupplier;
  final String propellantCode;
  final String propellantLot;
  final String propellantCharge;

  // Retest tracking fields
  final bool isRetest;
  final String retestTimestamp;
  final String retestOperator;
  final String retestNotes;
  final String retestStatus;
  final String originalStatus;
 
  BallisticRecord({
    String? id,
    required this.timestamp,
    required this.operators,
    required this.shift,
    required this.caliber,
    required this.lotNo,
    required this.produced,
    required this.defects,
    required this.notes,
    required this.status,
    required this.testName,
    required this.pressureBar,
    required this.viscosity,
    required this.testTime,
    required this.samplingLocation,
    required this.mouthSlow,
    required this.mouthFast,
    required this.primerSlow,
    required this.primerFast,
    required this.hopperNo,
    required this.boxNo,
    required this.requirement,
    this.barrelSN = '',
    this.barrelType = '',
    this.velocityDistance = '',
    this.accMeanX = '',
    this.accMaxX = '',
    this.accMinX = '',
    this.accRangeX = '',
    this.accSDX = '',
    this.accMeanY = '',
    this.accMaxY = '',
    this.accMinY = '',
    this.accRangeY = '',
    this.accSDY = '',
    this.velMean = '',
    this.velMin = '',
    this.velMax = '',
    this.velRange = '',
    this.velSD = '',
    this.accMeanRadius = '',
    this.accLargestDistance = '',
    this.extractionForceType = '',
    this.extractionForceRounds = '',
    this.cartridgeTemp = '',
    this.epvatPressureType = '',
    this.epvatPressureUnit = '',
    this.epvatPressureRounds = '',
    this.epvatMeanPressure = '',
    this.epvatMaxPressure = '',
    this.epvatMinPressure = '',
    this.epvatRangePressure = '',
    this.epvatSDPressure = '',
    this.epvatP2MeanPressure = '',
    this.epvatP2MaxPressure = '',
    this.epvatP2MinPressure = '',
    this.epvatP2RangePressure = '',
    this.epvatP2SDPressure = '',
    this.epvatP2PressureRounds = '',
    this.epvatVelRounds = '',
    this.epvatSensor1 = '',
    this.epvatSensor2 = '',
    this.cyclicRateWeaponType = '',
    this.cyclicRateAmmoType = '',
    this.cyclicRateValue = '',
    this.cyclicRateMin = '',
    this.cyclicRateMax = '',
    this.terminalHoleDiameter = '',
    this.terminalSteelPenetration = '',
    this.terminalAluminumPenetration = '',
    this.terminalVelocity = '',
    this.neckSlow = 0,
    this.neckFast = 0,
    this.shoulderSlow = 0,
    this.shoulderFast = 0,
    this.bodySlow = 0,
    this.bodyFast = 0,
    this.headSlow = 0,
    this.headFast = 0,
    this.roomTemp = '',
    this.functionLevel1 = 0,
    this.functionLevel2 = 0,
    this.functionLevel3 = 0,
    this.functionLevel4 = 0,
    this.attachmentName = '',
    this.attachmentBase64 = '',
    this.functionDefectDetails = '',
    this.actionTimeMean = '',
    this.actionTimeMin = '',
    this.actionTimeMax = '',
    this.actionTimeRange = '',
    this.actionTimeSD = '',
    this.actionTimeRounds = '',
    this.primerDropHeights = '',
    this.primerFireResults = '',
    this.primerHbar = '',
    this.primerSD = '',
    this.primerAllFireH = '',
    this.primerNoFireH = '',
    this.gp6Serial = '',
    this.userRole = 'Operator',
    this.module = 'Lot Acceptance Test',
    this.primerLot = '',
    this.primerSupplier = '',
    this.primerInsertionDepth = '',
    this.propellantSupplier = '',
    this.propellantCode = '',
    this.propellantLot = '',
    this.propellantCharge = '',
    this.isRetest = false,
    this.retestTimestamp = '',
    this.retestOperator = '',
    this.retestNotes = '',
    this.retestStatus = '',
    this.originalStatus = '',
  }) : id = (id != null && id.isNotEmpty) ? id : generateUuid();

  // Backward compatibility getter
  String get lotNumber => lotNo;

  // Yield Rate calculation (percent conforming rounds)
  double get yieldRate {
    if (produced <= 0) return 100.00;
    return ((produced - defects) / produced) * 100.0;
  }

  // Compile to formatted CSV row
  String toCsvRow() {
    final cleanOps = operators.replaceAll('"', '""').replaceAll(',', ' & ');
    final cleanLot = lotNo.replaceAll('"', '""').replaceAll(',', '-');
    final cleanNotes = notes.replaceAll('"', '""').replaceAll(',', ' ').replaceAll('\n', ' ');
    final cleanTestName = testName.replaceAll('"', '""').replaceAll(',', ' - ');
    final cleanPressure = pressureBar.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanViscosity = viscosity.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanTestTime = testTime.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanLoc = samplingLocation.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanHopper = hopperNo.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanBox = boxNo.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanRequirement = requirement.replaceAll('"', '""').replaceAll(',', ' ').replaceAll('\n', ' ');

    final cleanBarrelSN = barrelSN.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanBarrelType = barrelType.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanVelDist = velocityDistance.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMeanX = accMeanX.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMaxX = accMaxX.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMinX = accMinX.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanRangeX = accRangeX.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanSDX = accSDX.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMeanY = accMeanY.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMaxY = accMaxY.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMinY = accMinY.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanRangeY = accRangeY.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanSDY = accSDY.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanVelMean = velMean.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanVelMin = velMin.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanVelMax = velMax.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanVelRange = velRange.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanVelSD = velSD.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMeanRadius = accMeanRadius.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanAccLargestDist = accLargestDistance.replaceAll('"', '""').replaceAll(',', ' ');
    
    final cleanExtType = extractionForceType.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanExtRounds = extractionForceRounds.replaceAll('"', '""');
    final cleanCartTemp = cartridgeTemp.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanEpvType = epvatPressureType.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanEpvUnit = epvatPressureUnit.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanEpvRounds = epvatPressureRounds.replaceAll('"', '""');
    final cleanMeanP = epvatMeanPressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMaxP = epvatMaxPressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanMinP = epvatMinPressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanRangeP = epvatRangePressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanSDP = epvatSDPressure.replaceAll('"', '""').replaceAll(',', ' ');

    final cleanP2Mean = epvatP2MeanPressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanP2Max = epvatP2MaxPressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanP2Min = epvatP2MinPressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanP2Range = epvatP2RangePressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanP2SD = epvatP2SDPressure.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanP2Rounds = epvatP2PressureRounds.replaceAll('"', '""');
    final cleanVelRounds = epvatVelRounds.replaceAll('"', '""');
    final cleanSensor1 = epvatSensor1.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanSensor2 = epvatSensor2.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanCyclicWeapon = cyclicRateWeaponType.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanCyclicAmmo = cyclicRateAmmoType.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanCyclicVal = cyclicRateValue.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanCyclicMin = cyclicRateMin.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanCyclicMax = cyclicRateMax.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanTermHole = terminalHoleDiameter.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanTermSteel = terminalSteelPenetration.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanTermAlum = terminalAluminumPenetration.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanTermVel = terminalVelocity.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanRoomTemp = roomTemp.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanAttName = attachmentName.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanAttBase64 = attachmentBase64.replaceAll('"', '""');
    final cleanFuncDefects = functionDefectDetails.replaceAll('"', '""').replaceAll('\n', ' ');
    final cleanActionTimeMean = actionTimeMean.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanActionTimeMin = actionTimeMin.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanActionTimeMax = actionTimeMax.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanActionTimeRange = actionTimeRange.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanActionTimeSD = actionTimeSD.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanActionTimeRounds = actionTimeRounds.replaceAll('"', '""');
    final cleanPrimerHeights = primerDropHeights.replaceAll('"', '""');
    final cleanPrimerResults = primerFireResults.replaceAll('"', '""');
    final cleanPrimerHbar = primerHbar.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPrimerSD = primerSD.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPrimerAllFire = primerAllFireH.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPrimerNoFire = primerNoFireH.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanGp6Serial = gp6Serial.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanUserRole = userRole.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanModule = module.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPrimerLot = primerLot.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPrimerSupplier = primerSupplier.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPrimerDepth = primerInsertionDepth.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPropSupplier = propellantSupplier.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPropCode = propellantCode.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPropLot = propellantLot.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanPropCharge = propellantCharge.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanIsRetest = isRetest ? '1' : '0';
    final cleanRetestTs = retestTimestamp.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanRetestOp = retestOperator.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanRetestNotes = retestNotes.replaceAll('"', '""').replaceAll(',', ' ').replaceAll('\n', ' ');
    final cleanRetestStatus = retestStatus.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanOrigStatus = originalStatus.replaceAll('"', '""').replaceAll(',', ' ');
    final cleanId = (id ?? '').replaceAll('"', '""').replaceAll(',', ' ');

    return '"$timestamp","$cleanOps","$cleanShiftTime","$caliber","$cleanLot",$produced,$defects,"$cleanNotes","$status","$cleanTestName","$cleanPressure","$cleanViscosity","$cleanTestTime","$cleanLoc",$mouthSlow,$mouthFast,$primerSlow,$primerFast,"$cleanHopper","$cleanBox","$cleanRequirement","$cleanBarrelSN","$cleanBarrelType","$cleanVelDist","$cleanMeanX","$cleanMaxX","$cleanMinX","$cleanRangeX","$cleanSDX","$cleanMeanY","$cleanMaxY","$cleanMinY","$cleanRangeY","$cleanSDY","$cleanVelMean","$cleanVelMin","$cleanVelMax","$cleanVelRange","$cleanVelSD","$cleanMeanRadius","$cleanExtType","$cleanExtRounds","$cleanCartTemp","$cleanEpvType","$cleanEpvUnit","$cleanEpvRounds","$cleanMeanP","$cleanMaxP","$cleanMinP","$cleanRangeP","$cleanSDP","$cleanP2Mean","$cleanP2Max","$cleanP2Min","$cleanP2Range","$cleanP2SD","$cleanP2Rounds","$cleanVelRounds",$neckSlow,$neckFast,$shoulderSlow,$shoulderFast,$bodySlow,$bodyFast,$headSlow,$headFast,"$cleanRoomTemp","$cleanSensor1","$cleanSensor2","$cleanCyclicWeapon","$cleanCyclicAmmo","$cleanCyclicVal","$cleanCyclicMin","$cleanCyclicMax","$cleanTermHole","$cleanTermSteel","$cleanTermAlum","$cleanTermVel",$functionLevel1,$functionLevel2,$functionLevel3,$functionLevel4,"$cleanAttName","$cleanAttBase64","$cleanFuncDefects","$cleanActionTimeMean","$cleanActionTimeMin","$cleanActionTimeMax","$cleanActionTimeRange","$cleanActionTimeSD","$cleanActionTimeRounds","$cleanPrimerHeights","$cleanPrimerResults","$cleanPrimerHbar","$cleanPrimerSD","$cleanPrimerAllFire","$cleanPrimerNoFire","$cleanGp6Serial","$cleanUserRole","$cleanModule","$cleanAccLargestDist","$cleanPrimerLot","$cleanPrimerSupplier","$cleanPrimerDepth","$cleanPropSupplier","$cleanPropCode","$cleanPropLot","$cleanPropCharge","$cleanIsRetest","$cleanRetestTs","$cleanRetestOp","$cleanRetestNotes","$cleanRetestStatus","$cleanOrigStatus","$cleanId"\n';
  }

  // Helper getter to clean commas from shift time
  String get cleanShiftTime => shift.replaceAll('"', '""').replaceAll(',', ' ');

  factory BallisticRecord.empty() {
    return BallisticRecord(
      timestamp: '',
      operators: '',
      shift: '',
      caliber: '',
      lotNo: '',
      produced: 0,
      defects: 0,
      notes: '',
      status: '',
      testName: '',
      pressureBar: '',
      viscosity: '',
      testTime: '',
      samplingLocation: '',
      mouthSlow: 0,
      mouthFast: 0,
      primerSlow: 0,
      primerFast: 0,
      hopperNo: '',
      boxNo: '',
      requirement: '',
    );
  }

  // Parse a CSV row back to a BallisticRecord object
  factory BallisticRecord.fromCsvRow(String csvLine) {
    final List<String> fields = [];
    final StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < csvLine.length; i++) {
      final char = csvLine[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(currentField.toString());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }
    fields.add(currentField.toString());

    // Clean formatting and fallbacks
    final String timestamp = fields.isNotEmpty ? fields[0].replaceAll('"', '').trim() : '';
    final String operators = fields.length > 1 ? fields[1].replaceAll('"', '').trim() : '';
    final String shift = fields.length > 2 ? fields[2].replaceAll('"', '').trim() : 'Day';
    final String caliber = fields.length > 3 ? fields[3].replaceAll('"', '').trim() : '5.56x45 SS109';
    final String lotNumber = fields.length > 4 ? fields[4].replaceAll('"', '').trim() : '';
    final int produced = fields.length > 5 ? int.tryParse(fields[5].trim()) ?? 0 : 0;
    final int defects = fields.length > 6 ? int.tryParse(fields[6].trim()) ?? 0 : 0;
    final String notes = fields.length > 7 ? fields[7].replaceAll('"', '').trim() : '';
    final String status = fields.length > 8 ? fields[8].replaceAll('"', '').trim() : 'Approved';
    final String testName = fields.length > 9 ? fields[9].replaceAll('"', '').trim() : 'Accuracy Test';
    final String pressureBar = fields.length > 10 ? fields[10].replaceAll('"', '').trim() : '';
    final String viscosity = fields.length > 11 ? fields[11].replaceAll('"', '').trim() : '';
    final String testTime = fields.length > 12 ? fields[12].replaceAll('"', '').trim() : '';
    final String samplingLocation = fields.length > 13 ? fields[13].replaceAll('"', '').trim() : '';
    final int mouthSlow = fields.length > 14 ? int.tryParse(fields[14].trim()) ?? 0 : 0;
    final int mouthFast = fields.length > 15 ? int.tryParse(fields[15].trim()) ?? 0 : 0;
    final int primerSlow = fields.length > 16 ? int.tryParse(fields[16].trim()) ?? 0 : 0;
    final int primerFast = fields.length > 17 ? int.tryParse(fields[17].trim()) ?? 0 : 0;
    final String hopperNo = fields.length > 18 ? fields[18].replaceAll('"', '').trim() : '';
    final String boxNo = fields.length > 19 ? fields[19].replaceAll('"', '').trim() : '';
    final String requirement = fields.length > 20 ? fields[20].replaceAll('"', '').trim() : '';

    final String barrelSN = fields.length > 21 ? fields[21].replaceAll('"', '').trim() : '';
    final String barrelType = fields.length > 22 ? fields[22].replaceAll('"', '').trim() : '';
    final String velocityDistance = fields.length > 23 ? fields[23].replaceAll('"', '').trim() : '';
    final String accMeanX = fields.length > 24 ? fields[24].replaceAll('"', '').trim() : '';
    final String accMaxX = fields.length > 25 ? fields[25].replaceAll('"', '').trim() : '';
    final String accMinX = fields.length > 26 ? fields[26].replaceAll('"', '').trim() : '';
    final String accRangeX = fields.length > 27 ? fields[27].replaceAll('"', '').trim() : '';
    final String accSDX = fields.length > 28 ? fields[28].replaceAll('"', '').trim() : '';
    final String accMeanY = fields.length > 29 ? fields[29].replaceAll('"', '').trim() : '';
    final String accMaxY = fields.length > 30 ? fields[30].replaceAll('"', '').trim() : '';
    final String accMinY = fields.length > 31 ? fields[31].replaceAll('"', '').trim() : '';
    final String accRangeY = fields.length > 32 ? fields[32].replaceAll('"', '').trim() : '';
    final String accSDY = fields.length > 33 ? fields[33].replaceAll('"', '').trim() : '';
    final String velMean = fields.length > 34 ? fields[34].replaceAll('"', '').trim() : '';
    final String velMin = fields.length > 35 ? fields[35].replaceAll('"', '').trim() : '';
    final String velMax = fields.length > 36 ? fields[36].replaceAll('"', '').trim() : '';
    final String velRange = fields.length > 37 ? fields[37].replaceAll('"', '').trim() : '';
    final String velSD = fields.length > 38 ? fields[38].replaceAll('"', '').trim() : '';
    final String accMeanRadius = fields.length > 39 ? fields[39].replaceAll('"', '').trim() : '';
    
    final String extractionForceType = fields.length > 40 ? fields[40].replaceAll('"', '').trim() : '';
    final String extractionForceRounds = fields.length > 41 ? fields[41].replaceAll('"', '').trim() : '';
    final String cartridgeTemp = fields.length > 42 ? fields[42].replaceAll('"', '').trim() : '';
    final String epvatPressureType = fields.length > 43 ? fields[43].replaceAll('"', '').trim() : '';
    final String epvatPressureUnit = fields.length > 44 ? fields[44].replaceAll('"', '').trim() : '';
    final String epvatPressureRounds = fields.length > 45 ? fields[45].replaceAll('"', '').trim() : '';
    final String epvatMeanPressure = fields.length > 46 ? fields[46].replaceAll('"', '').trim() : '';
    final String epvatMaxPressure = fields.length > 47 ? fields[47].replaceAll('"', '').trim() : '';
    final String epvatMinPressure = fields.length > 48 ? fields[48].replaceAll('"', '').trim() : '';
    final String epvatRangePressure = fields.length > 49 ? fields[49].replaceAll('"', '').trim() : '';
    final String epvatSDPressure = fields.length > 50 ? fields[50].replaceAll('"', '').trim() : '';

    final String epvatP2MeanPressure = fields.length > 51 ? fields[51].replaceAll('"', '').trim() : '';
    final String epvatP2MaxPressure = fields.length > 52 ? fields[52].replaceAll('"', '').trim() : '';
    final String epvatP2MinPressure = fields.length > 53 ? fields[53].replaceAll('"', '').trim() : '';
    final String epvatP2RangePressure = fields.length > 54 ? fields[54].replaceAll('"', '').trim() : '';
    final String epvatP2SDPressure = fields.length > 55 ? fields[55].replaceAll('"', '').trim() : '';
    final String epvatP2PressureRounds = fields.length > 56 ? fields[56].replaceAll('"', '').trim() : '';
    final String epvatVelRounds = fields.length > 57 ? fields[57].replaceAll('"', '').trim() : '';

    final int neckSlow = fields.length > 58 ? int.tryParse(fields[58].trim()) ?? 0 : 0;
    final int neckFast = fields.length > 59 ? int.tryParse(fields[59].trim()) ?? 0 : 0;
    final int shoulderSlow = fields.length > 60 ? int.tryParse(fields[60].trim()) ?? 0 : 0;
    final int shoulderFast = fields.length > 61 ? int.tryParse(fields[61].trim()) ?? 0 : 0;
    final int bodySlow = fields.length > 62 ? int.tryParse(fields[62].trim()) ?? 0 : 0;
    final int bodyFast = fields.length > 63 ? int.tryParse(fields[63].trim()) ?? 0 : 0;
    final int headSlow = fields.length > 64 ? int.tryParse(fields[64].trim()) ?? 0 : 0;
    final int headFast = fields.length > 65 ? int.tryParse(fields[65].trim()) ?? 0 : 0;
    final String roomTemp = fields.length > 66 ? fields[66].replaceAll('"', '').trim() : '';
    final String epvatSensor1 = fields.length > 67 ? fields[67].replaceAll('"', '').trim() : '';
    final String epvatSensor2 = fields.length > 68 ? fields[68].replaceAll('"', '').trim() : '';
    final String cyclicRateWeaponType = fields.length > 69 ? fields[69].replaceAll('"', '').trim() : '';
    final String cyclicRateAmmoType = fields.length > 70 ? fields[70].replaceAll('"', '').trim() : '';
    final String cyclicRateValue = fields.length > 71 ? fields[71].replaceAll('"', '').trim() : '';
    final String cyclicRateMin = fields.length > 72 ? fields[72].replaceAll('"', '').trim() : '';
    final String cyclicRateMax = fields.length > 73 ? fields[73].replaceAll('"', '').trim() : '';
    final String terminalHoleDiameter = fields.length > 74 ? fields[74].replaceAll('"', '').trim() : '';
    final String terminalSteelPenetration = fields.length > 75 ? fields[75].replaceAll('"', '').trim() : '';
    final String terminalAluminumPenetration = fields.length > 76 ? fields[76].replaceAll('"', '').trim() : '';
    final String terminalVelocity = fields.length > 77 ? fields[77].replaceAll('"', '').trim() : '';
    final int functionLevel1 = fields.length > 78 ? int.tryParse(fields[78].trim()) ?? 0 : 0;
    final int functionLevel2 = fields.length > 79 ? int.tryParse(fields[79].trim()) ?? 0 : 0;
    final int functionLevel3 = fields.length > 80 ? int.tryParse(fields[80].trim()) ?? 0 : 0;
    final int functionLevel4 = fields.length > 81 ? int.tryParse(fields[81].trim()) ?? 0 : 0;
    final String attachmentName = fields.length > 82 ? fields[82].replaceAll('"', '').trim() : '';
    final String attachmentBase64 = fields.length > 83 ? fields[83].replaceAll('"', '').trim() : '';
    final String functionDefectDetails = fields.length > 84 ? fields[84].replaceAll('"', '').trim() : '';
    final String actionTimeMean = fields.length > 85 ? fields[85].replaceAll('"', '').trim() : '';
    final String actionTimeMin = fields.length > 86 ? fields[86].replaceAll('"', '').trim() : '';
    final String actionTimeMax = fields.length > 87 ? fields[87].replaceAll('"', '').trim() : '';
    final String actionTimeRange = fields.length > 88 ? fields[88].replaceAll('"', '').trim() : '';
    final String actionTimeSD = fields.length > 89 ? fields[89].replaceAll('"', '').trim() : '';
    final String actionTimeRounds = fields.length > 90 ? fields[90].replaceAll('"', '').trim() : '';
    final String primerDropHeights = fields.length > 91 ? fields[91].replaceAll('"', '').trim() : '';
    final String primerFireResults = fields.length > 92 ? fields[92].replaceAll('"', '').trim() : '';
    final String primerHbar = fields.length > 93 ? fields[93].replaceAll('"', '').trim() : '';
    final String primerSD = fields.length > 94 ? fields[94].replaceAll('"', '').trim() : '';
    final String primerAllFireH = fields.length > 95 ? fields[95].replaceAll('"', '').trim() : '';
    final String primerNoFireH = fields.length > 96 ? fields[96].replaceAll('"', '').trim() : '';
    final String gp6Serial = fields.length > 97 ? fields[97].replaceAll('"', '').trim() : '';
    final String userRole = fields.length > 98 ? fields[98].replaceAll('"', '').trim() : 'Operator';
    final String module = fields.length > 99 ? fields[99].replaceAll('"', '').trim() : 'Lot Acceptance Test';
    final String accLargestDistance = fields.length > 100 ? fields[100].replaceAll('"', '').trim() : '';
    final String primerLot = fields.length > 101 ? fields[101].replaceAll('"', '').trim() : '';
    final String primerSupplier = fields.length > 102 ? fields[102].replaceAll('"', '').trim() : '';
    final String primerInsertionDepth = fields.length > 103 ? fields[103].replaceAll('"', '').trim() : '';
    final String propellantSupplier = fields.length > 104 ? fields[104].replaceAll('"', '').trim() : '';
    final String propellantCode = fields.length > 105 ? fields[105].replaceAll('"', '').trim() : '';
    final String propellantLot = fields.length > 106 ? fields[106].replaceAll('"', '').trim() : '';
    final String propellantCharge = fields.length > 107 ? fields[107].replaceAll('"', '').trim() : '';
    final bool isRetest = fields.length > 108 ? fields[108].replaceAll('"', '').trim() == '1' || fields[108].toLowerCase().contains('true') : false;
    final String retestTimestamp = fields.length > 109 ? fields[109].replaceAll('"', '').trim() : '';
    final String retestOperator = fields.length > 110 ? fields[110].replaceAll('"', '').trim() : '';
    final String retestNotes = fields.length > 111 ? fields[111].replaceAll('"', '').trim() : '';
    final String retestStatus = fields.length > 112 ? fields[112].replaceAll('"', '').trim() : '';
    final String originalStatus = fields.length > 113 ? fields[113].replaceAll('"', '').trim() : '';
    final String rowId = fields.length > 114 ? fields[114].replaceAll('"', '').trim() : '';
 
    return BallisticRecord(
      id: rowId.isNotEmpty ? rowId : null,
      timestamp: timestamp,
      operators: operators,
      shift: shift,
      caliber: caliber,
      lotNo: lotNumber,
      produced: produced,
      defects: defects,
      notes: notes,
      status: status,
      testName: testName,
      pressureBar: pressureBar,
      viscosity: viscosity,
      testTime: testTime,
      samplingLocation: samplingLocation,
      mouthSlow: mouthSlow,
      mouthFast: mouthFast,
      primerSlow: primerSlow,
      primerFast: primerFast,
      hopperNo: hopperNo,
      boxNo: boxNo,
      requirement: requirement,
      barrelSN: barrelSN,
      barrelType: barrelType,
      velocityDistance: velocityDistance,
      accMeanX: accMeanX,
      accMaxX: accMaxX,
      accMinX: accMinX,
      accRangeX: accRangeX,
      accSDX: accSDX,
      accMeanY: accMeanY,
      accMaxY: accMaxY,
      accMinY: accMinY,
      accRangeY: accRangeY,
      accSDY: accSDY,
      velMean: velMean,
      velMin: velMin,
      velMax: velMax,
      velRange: velRange,
      velSD: velSD,
      accMeanRadius: accMeanRadius,
      accLargestDistance: accLargestDistance,
      extractionForceType: extractionForceType,
      extractionForceRounds: extractionForceRounds,
      cartridgeTemp: cartridgeTemp,
      epvatPressureType: epvatPressureType,
      epvatPressureUnit: epvatPressureUnit,
      epvatPressureRounds: epvatPressureRounds,
      epvatMeanPressure: epvatMeanPressure,
      epvatMaxPressure: epvatMaxPressure,
      epvatMinPressure: epvatMinPressure,
      epvatRangePressure: epvatRangePressure,
      epvatSDPressure: epvatSDPressure,
      epvatP2MeanPressure: epvatP2MeanPressure,
      epvatP2MaxPressure: epvatP2MaxPressure,
      epvatP2MinPressure: epvatP2MinPressure,
      epvatP2RangePressure: epvatP2RangePressure,
      epvatP2SDPressure: epvatP2SDPressure,
      epvatP2PressureRounds: epvatP2PressureRounds,
      epvatVelRounds: epvatVelRounds,
      neckSlow: neckSlow,
      neckFast: neckFast,
      shoulderSlow: shoulderSlow,
      shoulderFast: shoulderFast,
      bodySlow: bodySlow,
      bodyFast: bodyFast,
      headSlow: headSlow,
      headFast: headFast,
      roomTemp: roomTemp,
      epvatSensor1: epvatSensor1,
      epvatSensor2: epvatSensor2,
      cyclicRateWeaponType: cyclicRateWeaponType,
      cyclicRateAmmoType: cyclicRateAmmoType,
      cyclicRateValue: cyclicRateValue,
      cyclicRateMin: cyclicRateMin,
      cyclicRateMax: cyclicRateMax,
      terminalHoleDiameter: terminalHoleDiameter,
      terminalSteelPenetration: terminalSteelPenetration,
      terminalAluminumPenetration: terminalAluminumPenetration,
      terminalVelocity: terminalVelocity,
      functionLevel1: functionLevel1,
      functionLevel2: functionLevel2,
      functionLevel3: functionLevel3,
      functionLevel4: functionLevel4,
      attachmentName: attachmentName,
      attachmentBase64: attachmentBase64,
      functionDefectDetails: functionDefectDetails,
      actionTimeMean: actionTimeMean,
      actionTimeMin: actionTimeMin,
      actionTimeMax: actionTimeMax,
      actionTimeRange: actionTimeRange,
      actionTimeSD: actionTimeSD,
      actionTimeRounds: actionTimeRounds,
      primerDropHeights: primerDropHeights,
      primerFireResults: primerFireResults,
      primerHbar: primerHbar,
      primerSD: primerSD,
      primerAllFireH: primerAllFireH,
      primerNoFireH: primerNoFireH,
      gp6Serial: gp6Serial,
      userRole: userRole,
      module: module.isNotEmpty ? module : 'Lot Acceptance Test',
      primerLot: primerLot,
      primerSupplier: primerSupplier,
      primerInsertionDepth: primerInsertionDepth,
      propellantSupplier: propellantSupplier,
      propellantCode: propellantCode,
      propellantLot: propellantLot,
      propellantCharge: propellantCharge,
      isRetest: isRetest,
      retestTimestamp: retestTimestamp,
      retestOperator: retestOperator,
      retestNotes: retestNotes,
      retestStatus: retestStatus,
      originalStatus: originalStatus,
    );
  }

  /// Convert BallisticRecord to a Map matching the Supabase ballistic_records schema
  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'timestamp': timestamp,
      'operators': operators,
      'shift': shift,
      'caliber': caliber,
      'lot_no': lotNo,
      'produced': produced,
      'defects': defects,
      'notes': notes,
      'status': status,
      'test_name': testName,
      'pressure_bar': pressureBar,
      'viscosity': viscosity,
      'test_time': testTime,
      'sampling_location': samplingLocation,
      'mouth_slow': mouthSlow,
      'mouth_fast': mouthFast,
      'primer_slow': primerSlow,
      'primer_fast': primerFast,
      'hopper_no': hopperNo,
      'box_no': boxNo,
      'requirement': requirement,
      'barrel_sn': barrelSN,
      'barrel_type': barrelType,
      'velocity_distance': velocityDistance,
      'acc_mean_x': accMeanX,
      'acc_max_x': accMaxX,
      'acc_min_x': accMinX,
      'acc_range_x': accRangeX,
      'acc_sd_x': accSDX,
      'acc_mean_y': accMeanY,
      'acc_max_y': accMaxY,
      'acc_min_y': accMinY,
      'acc_range_y': accRangeY,
      'acc_sd_y': accSDY,
      'vel_mean': velMean,
      'vel_min': velMin,
      'vel_max': velMax,
      'vel_range': velRange,
      'vel_sd': velSD,
      'acc_mean_radius': accMeanRadius,
      'extraction_force_type': extractionForceType,
      'extraction_force_rounds': extractionForceRounds,
      'cartridge_temp': cartridgeTemp,
      'epvat_pressure_type': epvatPressureType,
      'epvat_pressure_unit': epvatPressureUnit,
      'epvat_pressure_rounds': epvatPressureRounds,
      'epvat_mean_pressure': epvatMeanPressure,
      'epvat_max_pressure': epvatMaxPressure,
      'epvat_min_pressure': epvatMinPressure,
      'epvat_range_pressure': epvatRangePressure,
      'epvat_sd_pressure': epvatSDPressure,
      'epvat_p2_mean_pressure': epvatP2MeanPressure,
      'epvat_p2_max_pressure': epvatP2MaxPressure,
      'epvat_p2_min_pressure': epvatP2MinPressure,
      'epvat_p2_range_pressure': epvatP2RangePressure,
      'epvat_p2_sd_pressure': epvatP2SDPressure,
      'epvat_p2_pressure_rounds': epvatP2PressureRounds,
      'epvat_vel_rounds': epvatVelRounds,
      'epvat_sensor_1': epvatSensor1,
      'epvat_sensor_2': epvatSensor2,
      'cyclic_rate_weapon_type': cyclicRateWeaponType,
      'cyclic_rate_ammo_type': cyclicRateAmmoType,
      'cyclic_rate_value': cyclicRateValue,
      'cyclic_rate_min': cyclicRateMin,
      'cyclic_rate_max': cyclicRateMax,
      'terminal_hole_diameter': terminalHoleDiameter,
      'terminal_steel_penetration': terminalSteelPenetration,
      'terminal_aluminum_penetration': terminalAluminumPenetration,
      'terminal_velocity': terminalVelocity,
      'neck_slow': neckSlow,
      'neck_fast': neckFast,
      'shoulder_slow': shoulderSlow,
      'shoulder_fast': shoulderFast,
      'body_slow': bodySlow,
      'body_fast': bodyFast,
      'head_slow': headSlow,
      'head_fast': headFast,
      'room_temp': roomTemp,
      'function_level1': functionLevel1,
      'function_level2': functionLevel2,
      'function_level3': functionLevel3,
      'function_level4': functionLevel4,
      'attachment_name': attachmentName,
      'attachment_base64': attachmentBase64,
      'function_defect_details': functionDefectDetails,
      'action_time_mean': actionTimeMean,
      'action_time_min': actionTimeMin,
      'action_time_max': actionTimeMax,
      'action_time_range': actionTimeRange,
      'action_time_sd': actionTimeSD,
      'action_time_rounds': actionTimeRounds,
      'primer_drop_heights': primerDropHeights,
      'primer_fire_results': primerFireResults,
      'primer_hbar': primerHbar,
      'primer_sd': primerSD,
      'primer_all_fire_h': primerAllFireH,
      'primer_no_fire_h': primerNoFireH,
      'gp6_serial': gp6Serial,
      'user_role': userRole,
      'module': module,
      'primer_lot': primerLot,
      'primer_supplier': primerSupplier,
      'primer_insertion_depth': primerInsertionDepth,
      'propellant_supplier': propellantSupplier,
      'propellant_code': propellantCode,
      'propellant_lot': propellantLot,
      'propellant_charge': propellantCharge,
      'is_retest': isRetest,
      'retest_timestamp': retestTimestamp,
      'retest_operator': retestOperator,
      'retest_notes': retestNotes,
      'retest_status': retestStatus,
      'original_status': originalStatus,
    };
    if (id != null && id!.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  /// Construct BallisticRecord from a Supabase row map
  factory BallisticRecord.fromSupabaseMap(Map<String, dynamic> map) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    String toStr(dynamic v) {
      if (v == null) return '';
      return v.toString();
    }

    bool isRetest = map['is_retest'] == true || map['is_retest']?.toString() == '1';
    String retestTimestamp = toStr(map['retest_timestamp']);
    String retestOperator = toStr(map['retest_operator']);
    String retestNotes = toStr(map['retest_notes']);
    String retestStatus = toStr(map['retest_status']);
    String originalStatus = toStr(map['original_status']);

    final String rawNotes = toStr(map['notes']);
    if (!isRetest && rawNotes.contains('[RETEST|')) {
      isRetest = true;
      try {
        final startIndex = rawNotes.indexOf('[RETEST|');
        final tag = rawNotes.substring(startIndex + 8);
        final endTag = tag.indexOf(']');
        final content = endTag != -1 ? tag.substring(0, endTag) : tag;
        final parts = content.split('|');
        for (final part in parts) {
          if (part.startsWith('op:')) retestOperator = part.substring(3);
          else if (part.startsWith('ts:')) retestTimestamp = part.substring(3);
          else if (part.startsWith('stat:')) retestStatus = part.substring(5);
          else if (part.startsWith('orig:')) originalStatus = part.substring(5);
          else if (part.startsWith('notes:')) retestNotes = part.substring(6);
        }
      } catch (_) {}
    }

    return BallisticRecord(
      id: map['id']?.toString(),
      timestamp: toStr(map['timestamp']),
      operators: toStr(map['operators']),
      shift: toStr(map['shift']),
      caliber: toStr(map['caliber']),
      lotNo: toStr(map['lot_no']),
      produced: toInt(map['produced']),
      defects: toInt(map['defects']),
      notes: rawNotes,
      status: toStr(map['status']),
      testName: toStr(map['test_name']),
      pressureBar: toStr(map['pressure_bar']),
      viscosity: toStr(map['viscosity']),
      testTime: toStr(map['test_time']),
      samplingLocation: toStr(map['sampling_location']),
      mouthSlow: toInt(map['mouth_slow']),
      mouthFast: toInt(map['mouth_fast']),
      primerSlow: toInt(map['primer_slow']),
      primerFast: toInt(map['primer_fast']),
      hopperNo: toStr(map['hopper_no']),
      boxNo: toStr(map['box_no']),
      requirement: toStr(map['requirement']),
      barrelSN: toStr(map['barrel_sn']),
      barrelType: toStr(map['barrel_type']),
      velocityDistance: toStr(map['velocity_distance']),
      accMeanX: toStr(map['acc_mean_x']),
      accMaxX: toStr(map['acc_max_x']),
      accMinX: toStr(map['acc_min_x']),
      accRangeX: toStr(map['acc_range_x']),
      accSDX: toStr(map['acc_sd_x']),
      accMeanY: toStr(map['acc_mean_y']),
      accMaxY: toStr(map['acc_max_y']),
      accMinY: toStr(map['acc_min_y']),
      accRangeY: toStr(map['acc_range_y']),
      accSDY: toStr(map['acc_sd_y']),
      velMean: toStr(map['vel_mean']),
      velMin: toStr(map['vel_min']),
      velMax: toStr(map['vel_max']),
      velRange: toStr(map['vel_range']),
      velSD: toStr(map['vel_sd']),
      accMeanRadius: toStr(map['acc_mean_radius']),
      accLargestDistance: toStr(map['acc_largest_distance']),
      extractionForceType: toStr(map['extraction_force_type']),
      extractionForceRounds: toStr(map['extraction_force_rounds']),
      cartridgeTemp: toStr(map['cartridge_temp']),
      epvatPressureType: toStr(map['epvat_pressure_type']),
      epvatPressureUnit: toStr(map['epvat_pressure_unit']),
      epvatPressureRounds: toStr(map['epvat_pressure_rounds']),
      epvatMeanPressure: toStr(map['epvat_mean_pressure']),
      epvatMaxPressure: toStr(map['epvat_max_pressure']),
      epvatMinPressure: toStr(map['epvat_min_pressure']),
      epvatRangePressure: toStr(map['epvat_range_pressure']),
      epvatSDPressure: toStr(map['epvat_sd_pressure']),
      epvatP2MeanPressure: toStr(map['epvat_p2_mean_pressure']),
      epvatP2MaxPressure: toStr(map['epvat_p2_max_pressure']),
      epvatP2MinPressure: toStr(map['epvat_p2_min_pressure']),
      epvatP2RangePressure: toStr(map['epvat_p2_range_pressure']),
      epvatP2SDPressure: toStr(map['epvat_p2_sd_pressure']),
      epvatP2PressureRounds: toStr(map['epvat_p2_pressure_rounds']),
      epvatVelRounds: toStr(map['epvat_vel_rounds']),
      epvatSensor1: toStr(map['epvat_sensor_1']),
      epvatSensor2: toStr(map['epvat_sensor_2']),
      cyclicRateWeaponType: toStr(map['cyclic_rate_weapon_type']),
      cyclicRateAmmoType: toStr(map['cyclic_rate_ammo_type']),
      cyclicRateValue: toStr(map['cyclic_rate_value']),
      cyclicRateMin: toStr(map['cyclic_rate_min']),
      cyclicRateMax: toStr(map['cyclic_rate_max']),
      terminalHoleDiameter: toStr(map['terminal_hole_diameter']),
      terminalSteelPenetration: toStr(map['terminal_steel_penetration']),
      terminalAluminumPenetration: toStr(map['terminal_aluminum_penetration']),
      terminalVelocity: toStr(map['terminal_velocity']),
      neckSlow: toInt(map['neck_slow']),
      neckFast: toInt(map['neck_fast']),
      shoulderSlow: toInt(map['shoulder_slow']),
      shoulderFast: toInt(map['shoulder_fast']),
      bodySlow: toInt(map['body_slow']),
      bodyFast: toInt(map['body_fast']),
      headSlow: toInt(map['head_slow']),
      headFast: toInt(map['head_fast']),
      roomTemp: toStr(map['room_temp']),
      functionLevel1: toInt(map['function_level1']),
      functionLevel2: toInt(map['function_level2']),
      functionLevel3: toInt(map['function_level3']),
      functionLevel4: toInt(map['function_level4']),
      attachmentName: toStr(map['attachment_name']),
      attachmentBase64: toStr(map['attachment_base64']),
      functionDefectDetails: toStr(map['function_defect_details']),
      actionTimeMean: toStr(map['action_time_mean']),
      actionTimeMin: toStr(map['action_time_min']),
      actionTimeMax: toStr(map['action_time_max']),
      actionTimeRange: toStr(map['action_time_range']),
      actionTimeSD: toStr(map['action_time_sd']),
      actionTimeRounds: toStr(map['action_time_rounds']),
      primerDropHeights: toStr(map['primer_drop_heights']),
      primerFireResults: toStr(map['primer_fire_results']),
      primerHbar: toStr(map['primer_hbar']),
      primerSD: toStr(map['primer_sd']),
      primerAllFireH: toStr(map['primer_all_fire_h']),
      primerNoFireH: toStr(map['primer_no_fire_h']),
      gp6Serial: toStr(map['gp6_serial']),
      userRole: toStr(map['user_role']).isEmpty ? 'Operator' : toStr(map['user_role']),
      module: toStr(map['module']).isEmpty ? 'Lot Acceptance Test' : toStr(map['module']),
      primerLot: toStr(map['primer_lot']),
      primerSupplier: toStr(map['primer_supplier']),
      primerInsertionDepth: toStr(map['primer_insertion_depth']),
      propellantSupplier: toStr(map['propellant_supplier']),
      propellantCode: toStr(map['propellant_code']),
      propellantLot: toStr(map['propellant_lot']),
      propellantCharge: toStr(map['propellant_charge']),
      isRetest: isRetest,
      retestTimestamp: retestTimestamp,
      retestOperator: retestOperator,
      retestNotes: retestNotes,
      retestStatus: retestStatus,
      originalStatus: originalStatus,
    );
  }

  /// Create a copy with modified fields
  BallisticRecord copyWith({
    String? id,
    String? timestamp,
    String? operators,
    String? shift,
    String? caliber,
    String? lotNo,
    int? produced,
    int? defects,
    String? notes,
    String? status,
    String? testName,
    String? pressureBar,
    String? viscosity,
    String? testTime,
    String? samplingLocation,
    int? mouthSlow,
    int? mouthFast,
    int? primerSlow,
    int? primerFast,
    String? hopperNo,
    String? boxNo,
    String? requirement,
    String? barrelSN,
    String? barrelType,
    String? velocityDistance,
    String? accMeanX,
    String? accMaxX,
    String? accMinX,
    String? accRangeX,
    String? accSDX,
    String? accMeanY,
    String? accMaxY,
    String? accMinY,
    String? accRangeY,
    String? accSDY,
    String? velMean,
    String? velMin,
    String? velMax,
    String? velRange,
    String? velSD,
    String? accMeanRadius,
    String? accLargestDistance,
    String? extractionForceType,
    String? extractionForceRounds,
    String? cartridgeTemp,
    String? epvatPressureType,
    String? epvatPressureUnit,
    String? epvatPressureRounds,
    String? epvatMeanPressure,
    String? epvatMaxPressure,
    String? epvatMinPressure,
    String? epvatRangePressure,
    String? epvatSDPressure,
    String? epvatP2MeanPressure,
    String? epvatP2MaxPressure,
    String? epvatP2MinPressure,
    String? epvatP2RangePressure,
    String? epvatP2SDPressure,
    String? epvatP2PressureRounds,
    String? epvatVelRounds,
    String? epvatSensor1,
    String? epvatSensor2,
    String? cyclicRateWeaponType,
    String? cyclicRateAmmoType,
    String? cyclicRateValue,
    String? cyclicRateMin,
    String? cyclicRateMax,
    String? terminalHoleDiameter,
    String? terminalSteelPenetration,
    String? terminalAluminumPenetration,
    String? terminalVelocity,
    int? neckSlow,
    int? neckFast,
    int? shoulderSlow,
    int? shoulderFast,
    int? bodySlow,
    int? bodyFast,
    int? headSlow,
    int? headFast,
    String? roomTemp,
    int? functionLevel1,
    int? functionLevel2,
    int? functionLevel3,
    int? functionLevel4,
    String? attachmentName,
    String? attachmentBase64,
    String? functionDefectDetails,
    String? actionTimeMean,
    String? actionTimeMin,
    String? actionTimeMax,
    String? actionTimeRange,
    String? actionTimeSD,
    String? actionTimeRounds,
    String? primerDropHeights,
    String? primerFireResults,
    String? primerHbar,
    String? primerSD,
    String? primerAllFireH,
    String? primerNoFireH,
    String? gp6Serial,
    String? userRole,
    String? module,
    String? primerLot,
    String? primerSupplier,
    String? primerInsertionDepth,
    String? propellantSupplier,
    String? propellantCode,
    String? propellantLot,
    String? propellantCharge,
    bool? isRetest,
    String? retestTimestamp,
    String? retestOperator,
    String? retestNotes,
    String? retestStatus,
    String? originalStatus,
  }) {
    return BallisticRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      operators: operators ?? this.operators,
      shift: shift ?? this.shift,
      caliber: caliber ?? this.caliber,
      lotNo: lotNo ?? this.lotNo,
      produced: produced ?? this.produced,
      defects: defects ?? this.defects,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      testName: testName ?? this.testName,
      pressureBar: pressureBar ?? this.pressureBar,
      viscosity: viscosity ?? this.viscosity,
      testTime: testTime ?? this.testTime,
      samplingLocation: samplingLocation ?? this.samplingLocation,
      mouthSlow: mouthSlow ?? this.mouthSlow,
      mouthFast: mouthFast ?? this.mouthFast,
      primerSlow: primerSlow ?? this.primerSlow,
      primerFast: primerFast ?? this.primerFast,
      hopperNo: hopperNo ?? this.hopperNo,
      boxNo: boxNo ?? this.boxNo,
      requirement: requirement ?? this.requirement,
      barrelSN: barrelSN ?? this.barrelSN,
      barrelType: barrelType ?? this.barrelType,
      velocityDistance: velocityDistance ?? this.velocityDistance,
      accMeanX: accMeanX ?? this.accMeanX,
      accMaxX: accMaxX ?? this.accMaxX,
      accMinX: accMinX ?? this.accMinX,
      accRangeX: accRangeX ?? this.accRangeX,
      accSDX: accSDX ?? this.accSDX,
      accMeanY: accMeanY ?? this.accMeanY,
      accMaxY: accMaxY ?? this.accMaxY,
      accMinY: accMinY ?? this.accMinY,
      accRangeY: accRangeY ?? this.accRangeY,
      accSDY: accSDY ?? this.accSDY,
      velMean: velMean ?? this.velMean,
      velMin: velMin ?? this.velMin,
      velMax: velMax ?? this.velMax,
      velRange: velRange ?? this.velRange,
      velSD: velSD ?? this.velSD,
      accMeanRadius: accMeanRadius ?? this.accMeanRadius,
      accLargestDistance: accLargestDistance ?? this.accLargestDistance,
      extractionForceType: extractionForceType ?? this.extractionForceType,
      extractionForceRounds: extractionForceRounds ?? this.extractionForceRounds,
      cartridgeTemp: cartridgeTemp ?? this.cartridgeTemp,
      epvatPressureType: epvatPressureType ?? this.epvatPressureType,
      epvatPressureUnit: epvatPressureUnit ?? this.epvatPressureUnit,
      epvatPressureRounds: epvatPressureRounds ?? this.epvatPressureRounds,
      epvatMeanPressure: epvatMeanPressure ?? this.epvatMeanPressure,
      epvatMaxPressure: epvatMaxPressure ?? this.epvatMaxPressure,
      epvatMinPressure: epvatMinPressure ?? this.epvatMinPressure,
      epvatRangePressure: epvatRangePressure ?? this.epvatRangePressure,
      epvatSDPressure: epvatSDPressure ?? this.epvatSDPressure,
      epvatP2MeanPressure: epvatP2MeanPressure ?? this.epvatP2MeanPressure,
      epvatP2MaxPressure: epvatP2MaxPressure ?? this.epvatP2MaxPressure,
      epvatP2MinPressure: epvatP2MinPressure ?? this.epvatP2MinPressure,
      epvatP2RangePressure: epvatP2RangePressure ?? this.epvatP2RangePressure,
      epvatP2SDPressure: epvatP2SDPressure ?? this.epvatP2SDPressure,
      epvatP2PressureRounds: epvatP2PressureRounds ?? this.epvatP2PressureRounds,
      epvatVelRounds: epvatVelRounds ?? this.epvatVelRounds,
      epvatSensor1: epvatSensor1 ?? this.epvatSensor1,
      epvatSensor2: epvatSensor2 ?? this.epvatSensor2,
      cyclicRateWeaponType: cyclicRateWeaponType ?? this.cyclicRateWeaponType,
      cyclicRateAmmoType: cyclicRateAmmoType ?? this.cyclicRateAmmoType,
      cyclicRateValue: cyclicRateValue ?? this.cyclicRateValue,
      cyclicRateMin: cyclicRateMin ?? this.cyclicRateMin,
      cyclicRateMax: cyclicRateMax ?? this.cyclicRateMax,
      terminalHoleDiameter: terminalHoleDiameter ?? this.terminalHoleDiameter,
      terminalSteelPenetration: terminalSteelPenetration ?? this.terminalSteelPenetration,
      terminalAluminumPenetration: terminalAluminumPenetration ?? this.terminalAluminumPenetration,
      terminalVelocity: terminalVelocity ?? this.terminalVelocity,
      neckSlow: neckSlow ?? this.neckSlow,
      neckFast: neckFast ?? this.neckFast,
      shoulderSlow: shoulderSlow ?? this.shoulderSlow,
      shoulderFast: shoulderFast ?? this.shoulderFast,
      bodySlow: bodySlow ?? this.bodySlow,
      bodyFast: bodyFast ?? this.bodyFast,
      headSlow: headSlow ?? this.headSlow,
      headFast: headFast ?? this.headFast,
      roomTemp: roomTemp ?? this.roomTemp,
      functionLevel1: functionLevel1 ?? this.functionLevel1,
      functionLevel2: functionLevel2 ?? this.functionLevel2,
      functionLevel3: functionLevel3 ?? this.functionLevel3,
      functionLevel4: functionLevel4 ?? this.functionLevel4,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentBase64: attachmentBase64 ?? this.attachmentBase64,
      functionDefectDetails: functionDefectDetails ?? this.functionDefectDetails,
      actionTimeMean: actionTimeMean ?? this.actionTimeMean,
      actionTimeMin: actionTimeMin ?? this.actionTimeMin,
      actionTimeMax: actionTimeMax ?? this.actionTimeMax,
      actionTimeRange: actionTimeRange ?? this.actionTimeRange,
      actionTimeSD: actionTimeSD ?? this.actionTimeSD,
      actionTimeRounds: actionTimeRounds ?? this.actionTimeRounds,
      primerDropHeights: primerDropHeights ?? this.primerDropHeights,
      primerFireResults: primerFireResults ?? this.primerFireResults,
      primerHbar: primerHbar ?? this.primerHbar,
      primerSD: primerSD ?? this.primerSD,
      primerAllFireH: primerAllFireH ?? this.primerAllFireH,
      primerNoFireH: primerNoFireH ?? this.primerNoFireH,
      gp6Serial: gp6Serial ?? this.gp6Serial,
      userRole: userRole ?? this.userRole,
      module: module ?? this.module,
      primerLot: primerLot ?? this.primerLot,
      primerSupplier: primerSupplier ?? this.primerSupplier,
      primerInsertionDepth: primerInsertionDepth ?? this.primerInsertionDepth,
      propellantSupplier: propellantSupplier ?? this.propellantSupplier,
      propellantCode: propellantCode ?? this.propellantCode,
      propellantLot: propellantLot ?? this.propellantLot,
      propellantCharge: propellantCharge ?? this.propellantCharge,
      isRetest: isRetest ?? this.isRetest,
      retestTimestamp: retestTimestamp ?? this.retestTimestamp,
      retestOperator: retestOperator ?? this.retestOperator,
      retestNotes: retestNotes ?? this.retestNotes,
      retestStatus: retestStatus ?? this.retestStatus,
      originalStatus: originalStatus ?? this.originalStatus,
    );
  }

  /// Consolidates split temperature records (EPVAT / Function Test) into single unified records
  /// where sample size is the sum of all temperature rounds.
  static List<BallisticRecord> consolidateRecords(List<BallisticRecord> records) {
    if (records.isEmpty) return records;
    final List<BallisticRecord> result = [];
    final Map<String, List<BallisticRecord>> epvatGroups = {};
    final Map<String, List<BallisticRecord>> funcGroups = {};
    final Map<String, BallisticRecord> seenGeneral = {};

    for (final r in records) {
      final isDaily = r.module == 'Daily Test' || r.module == 'Daily Test Report';
      final isEpvat = r.testName.contains('EPVAT');
      final isFunc = r.testName.toLowerCase().contains('function');

      // Group key: lotNo + date (first 10 chars of timestamp) + caliber
      final dateKey = r.timestamp.length >= 10 ? r.timestamp.substring(0, 10) : r.timestamp;

      if (!isDaily && isEpvat && (r.notes.contains('Multi-Temperature Consolidated') || r.cartridgeTemp.contains(','))) {
        // Already unified EPVAT - deduplicate using seenGeneral
        final cleanTs = r.timestamp.replaceAll('T', ' ').split('.').first.trim();
        final key = (r.id != null && r.id!.isNotEmpty) ? r.id! : 'EPVAT_${r.module}_${r.lotNo}_${r.caliber}_$cleanTs';
        if (!seenGeneral.containsKey(key)) {
          seenGeneral[key] = r;
        }
      } else if (!isDaily && isEpvat && r.cartridgeTemp.isNotEmpty) {
        // Individual temp record to consolidate in Lot Acceptance
        final key = '${r.lotNo}_${r.caliber}_$dateKey';
        epvatGroups.putIfAbsent(key, () => []).add(r);
      } else if (!isDaily && isFunc && (r.notes.contains('Consolidated Multi-Temperature') || r.cartridgeTemp.contains(','))) {
        // Already unified Function - deduplicate using seenGeneral
        final cleanTs = r.timestamp.replaceAll('T', ' ').split('.').first.trim();
        final key = (r.id != null && r.id!.isNotEmpty) ? r.id! : 'FUNC_${r.module}_${r.lotNo}_${r.caliber}_$cleanTs';
        if (!seenGeneral.containsKey(key)) {
          seenGeneral[key] = r;
        }
      } else if (!isDaily && isFunc && r.cartridgeTemp.isNotEmpty) {
        final key = '${r.lotNo}_${r.caliber}_$dateKey';
        funcGroups.putIfAbsent(key, () => []).add(r);
      } else {
        // Deduplicate general test records and Daily Test records
        final cleanTs = r.timestamp.replaceAll('T', ' ').split('.').first.trim();
        final lotOrHop = r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : (r.hopperNo.trim().isNotEmpty ? r.hopperNo.trim() : 'NOLOT');
        final key = (r.id != null && r.id!.isNotEmpty) ? r.id! : '${r.module}_${r.testName}_${lotOrHop}_${r.caliber}_$cleanTs';
        if (!seenGeneral.containsKey(key)) {
          seenGeneral[key] = r;
        } else {
          // If existing record lacks UUID and new one has it, replace with new one
          final existing = seenGeneral[key]!;
          if ((existing.id == null || existing.id!.isEmpty) && (r.id != null && r.id!.isNotEmpty)) {
            seenGeneral[key] = r;
          }
        }
      }
    }

    result.addAll(seenGeneral.values);

    // Merge EPVAT groups
    epvatGroups.forEach((key, group) {
      if (group.length == 1) {
        result.add(group.first);
      } else {
        final base = group.first;
        final totalSample = group.fold<int>(0, (sum, item) => sum + item.produced);
        final totalDefects = group.fold<int>(0, (sum, item) => sum + item.defects);
        final temps = group.map((e) => e.cartridgeTemp).where((t) => t.isNotEmpty).toSet().join(', ');
        final notes = 'Consolidated EPVAT ($temps) | Total: $totalSample rds';
        final anyRejected = group.any((e) => e.status.toUpperCase() == 'REJECTED');
        final anyHold = group.any((e) => e.status.toUpperCase() == 'HOLD');
        final status = anyRejected ? 'REJECTED' : (anyHold ? 'HOLD' : 'ACCEPTED');

        result.add(base.copyWith(
          produced: totalSample,
          defects: totalDefects,
          cartridgeTemp: temps,
          notes: notes,
          status: status,
        ));
      }
    });

    // Merge Function groups
    funcGroups.forEach((key, group) {
      if (group.length == 1) {
        result.add(group.first);
      } else {
        final base = group.first;
        final totalSample = group.fold<int>(0, (sum, item) => sum + item.produced);
        final totalDefects = group.fold<int>(0, (sum, item) => sum + item.defects);
        final totalL1 = group.fold<int>(0, (sum, item) => sum + item.functionLevel1);
        final totalL2 = group.fold<int>(0, (sum, item) => sum + item.functionLevel2);
        final totalL3 = group.fold<int>(0, (sum, item) => sum + item.functionLevel3);
        final totalL4 = group.fold<int>(0, (sum, item) => sum + item.functionLevel4);
        final temps = group.map((e) => e.cartridgeTemp).where((t) => t.isNotEmpty).toSet().join(', ');
        final anyRejected = group.any((e) => e.status.toUpperCase() == 'REJECTED');
        final anyHold = group.any((e) => e.status.toUpperCase() == 'HOLD');
        final status = anyRejected ? 'REJECTED' : (anyHold ? 'HOLD' : 'ACCEPTED');

        result.add(base.copyWith(
          produced: totalSample,
          defects: totalDefects,
          functionLevel1: totalL1,
          functionLevel2: totalL2,
          functionLevel3: totalL3,
          functionLevel4: totalL4,
          cartridgeTemp: temps,
          notes: 'Consolidated Function Test ($temps) - Total Sample: $totalSample rds, Defects: $totalDefects',
          status: status,
        ));
      }
    });

    // Final robust deduplication by ID or composite key
    final Map<String, BallisticRecord> finalMap = {};
    for (var r in result) {
      final cleanTs = r.timestamp.replaceAll('T', ' ').split('.').first.trim();
      final lotOrHop = r.lotNo.trim().isNotEmpty ? r.lotNo.trim() : (r.hopperNo.trim().isNotEmpty ? r.hopperNo.trim() : 'NOLOT');
      final key = (r.id != null && r.id!.isNotEmpty)
          ? r.id!
          : '${r.module}_${r.testName}_${lotOrHop}_${r.caliber}_$cleanTs';
      if (!finalMap.containsKey(key)) {
        finalMap[key] = r;
      } else {
        final existing = finalMap[key]!;
        if ((existing.id == null || existing.id!.isEmpty) && (r.id != null && r.id!.isNotEmpty)) {
          finalMap[key] = r;
        }
      }
    }

    final deduplicated = finalMap.values.toList();
    // Sort by timestamp desc
    deduplicated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return deduplicated;
  }
}

