import 'report_helper_stub.dart'
    if (dart.library.js) 'report_web_helper.dart'
    if (dart.library.io) 'report_io_helper.dart';

abstract class ReportHelper {
  static ReportHelper get instance => getHelper();

  Future<void> downloadCsv({required String content, required String filename});
  Future<void> downloadDoc({required String content, required String filename});
  Future<void> printHtml({required String htmlContent});
}
