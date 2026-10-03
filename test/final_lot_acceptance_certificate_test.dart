import 'package:flutter_test/flutter_test.dart';
import 'package:ompc_ballistic_aerodata/models/ballistic_record.dart';
import 'package:ompc_ballistic_aerodata/services/report_generator.dart';

void main() {
  group('Final Lot Acceptance Certificate Formatting & Organization Tests', () {
    final sampleRecords = [
      BallisticRecord.empty().copyWith(
        testName: 'Primer Sensitivity Test',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC/26',
        produced: 175,
        primerAllFireH: '360.50',
        primerNoFireH: '114.10',
        status: 'Approved',
        referenceNo: 'REF:01',
      ),
      BallisticRecord.empty().copyWith(
        testName: 'EPVAT test',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC/26',
        produced: 90,
        cartridgeTemp: '+21',
        epvatMeanPressure: '3424.0',
        epvatP2MeanPressure: '1201.5',
        status: 'Approved',
        referenceNo: 'REF:01',
      ),
      BallisticRecord.empty().copyWith(
        testName: 'Function Test',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC/26',
        produced: 500,
        defects: 0,
        status: 'Approved',
        referenceNo: 'REF:01',
      ),
      BallisticRecord.empty().copyWith(
        testName: 'Residual Stress Test',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC/26',
        produced: 50,
        status: 'Approved',
        referenceNo: 'REF:01',
      ),
      BallisticRecord.empty().copyWith(
        testName: 'Accuracy Test',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC/26',
        produced: 30,
        accSDX: '105.5',
        accSDY: '119.3',
        status: 'Approved',
        referenceNo: 'REF:01',
      ),
      BallisticRecord.empty().copyWith(
        testName: 'Extraction Force Test',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC/26',
        produced: 20,
        accMinX: '474.2',
        status: 'Approved',
        referenceNo: 'REF:01',
      ),
      BallisticRecord.empty().copyWith(
        testName: 'Waterproof Test',
        caliber: '5.56x45 SS109',
        lotNo: '001 OMPC/26',
        produced: 20,
        status: 'Approved',
        referenceNo: 'REF:01',
      ),
    ];

    test('1. Certificate HTML contains organized header, centered items, and no jagged nbsp', () {
      final html = ReportGenerator.generateHtml(
        sampleRecords,
        'All',
        'Lot Acceptance Test',
        loggedInUser: 'Test Inspector',
      );

      // Header matches clean reference format
      expect(html.contains('Final Lot Acceptance Certificate'), isTrue);
      expect(html.contains('5.56X45 SS109'), isTrue);
      expect(html.contains('Lot N.O: 001 OMPC/26'), isTrue);

      // No jagged &nbsp;&nbsp;&nbsp;&nbsp; in results
      expect(html.contains('&nbsp;&nbsp;&nbsp;&nbsp;'), isFalse);

      // Clean structured lines
      expect(html.contains('H̄+5SD:'), isTrue);
      expect(html.contains('360.50 mm'), isTrue);
      expect(html.contains('Mean Chamber:'), isTrue);
      expect(html.contains('3424.0 bar'), isTrue);
      expect(html.contains('SD X:'), isTrue);
      expect(html.contains('105.5 mm'), isTrue);
      expect(html.contains('Min Force:'), isTrue);
      expect(html.contains('474.2 N'), isTrue);

      // Overall status is placed ABOVE signatures table
      final statusIdx = html.indexOf('Overall Lot Acceptance Status:');
      final sigIdx = html.indexOf('Signatures Table');
      expect(statusIdx, isNonNegative);
      expect(sigIdx, isNonNegative);
      expect(statusIdx < sigIdx, isTrue, reason: 'Overall status must be above names and signatures');

      // Prepared By, Approved By, Authorized By
      expect(html.contains('Prepared By:'), isTrue);
      expect(html.contains('Approved By:'), isTrue);
      expect(html.contains('Authorized By:'), isTrue);

      // Single-page print styling
      expect(html.contains('@page {'), isTrue);
      expect(html.contains('size: A4 portrait;'), isTrue);
    });

    test('2. Certificate Word (.doc) export preserves complete CSS styling', () {
      final word = ReportGenerator.generateWordHtml(
        sampleRecords,
        'All',
        'Lot Acceptance Test',
        loggedInUser: 'Test Inspector',
      );

      expect(word.contains('Final Lot Acceptance Certificate'), isTrue);
      expect(word.contains('results-table'), isTrue);
      expect(word.contains('test-name-cell'), isTrue);
      expect(word.contains('Overall Lot Acceptance Status:'), isTrue);
      expect(word.contains('Prepared By:'), isTrue);
      expect(word.contains('Approved By:'), isTrue);
      expect(word.contains('Authorized By:'), isTrue);
    });
  });
}
