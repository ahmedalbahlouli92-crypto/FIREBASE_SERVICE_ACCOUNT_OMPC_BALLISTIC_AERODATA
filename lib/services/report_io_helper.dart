import 'dart:io';
import 'report_helper.dart';
import 'storage_service.dart';

import 'package:url_launcher/url_launcher.dart';

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
    final bomContent = content.startsWith('\uFEFF') ? content : '\uFEFF$content';
    await file.writeAsString(bomContent, flush: true);
  }

  @override
  Future<void> downloadDoc({required String content, required String filename}) async {
    final dirPath = await _storage.getDirectoryPath();
    final reportsDir = Directory('$dirPath/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final file = File('${reportsDir.path}/$filename');
    final bomContent = content.startsWith('\uFEFF') ? content : '\uFEFF$content';
    await file.writeAsString(bomContent, flush: true);
  }

  @override
  Future<void> printHtml({required String htmlContent, String? filename}) async {
    final dirPath = await _storage.getDirectoryPath();
    final reportsDir = Directory('$dirPath/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final name = (filename != null && filename.isNotEmpty) ? '$filename.html' : 'report_preview.html';
    final file = File('${reportsDir.path}/$name');
    await file.writeAsString(htmlContent, flush: true);
  }

  @override
  Future<void> openReport({required String htmlContent, String? title}) async {
    final tempDir = Directory.systemTemp;
    final cleanTitle = (title != null && title.isNotEmpty ? title : 'Inspection_Report')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final tempFile = File('${tempDir.path}/view_${DateTime.now().millisecondsSinceEpoch}_$cleanTitle.html');
    await tempFile.writeAsString(htmlContent, flush: true);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', tempFile.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [tempFile.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [tempFile.path]);
    }
  }

  @override
  Future<void> openUrl({required String url}) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {}
    }
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
