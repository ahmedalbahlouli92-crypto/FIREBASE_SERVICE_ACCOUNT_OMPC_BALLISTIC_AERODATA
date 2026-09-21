import 'dart:io';
import 'report_helper.dart';
import 'storage_service.dart';

class ReportHelperImpl implements ReportHelper {
  final _storage = StorageService();

  @override
  Future<void> downloadCsv({required String content, required String filename}) async {
    final dirPath = await _storage.getDirectoryPath();
    final reportsDir = Directory('$dirPath/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final file = File('${reportsDir.path}/$filename');
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<void> downloadDoc({required String content, required String filename}) async {
    final dirPath = await _storage.getDirectoryPath();
    final reportsDir = Directory('$dirPath/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final file = File('${reportsDir.path}/$filename');
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<void> printHtml({required String htmlContent}) async {
    final dirPath = await _storage.getDirectoryPath();
    final reportsDir = Directory('$dirPath/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final file = File('${reportsDir.path}/report_preview.html');
    await file.writeAsString(htmlContent, flush: true);
  }

  @override
  Future<void> openUrl({required String url}) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  }
}

ReportHelper getHelper() => ReportHelperImpl();
