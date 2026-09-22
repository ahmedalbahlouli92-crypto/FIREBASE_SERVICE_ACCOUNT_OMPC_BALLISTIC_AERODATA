import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApkUpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String apkDownloadUrl;
  final String releaseNotes;

  ApkUpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.apkDownloadUrl,
    required this.releaseNotes,
  });
}

class ApkUpdateService {
  static const String currentAppVersion = '1.5.0';
  static const String repoOwner = 'ahmedalbahlouli92-crypto';
  static const String repoName = 'FIREBASE_SERVICE_ACCOUNT_OMPC_BALLISTIC_AERODATA';

  static Future<ApkUpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] ?? '').toString().replaceAll('v', '').replaceAll('V', '').trim();
      final body = (data['body'] ?? '').toString();

      if (rawTag.isEmpty) return null;

      // Find APK asset
      String apkUrl = '';
      if (data['assets'] is List) {
        for (final asset in data['assets']) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (name.endsWith('.apk')) {
            apkUrl = (asset['browser_download_url'] ?? '').toString();
            break;
          }
        }
      }
      if (apkUrl.isEmpty) {
        apkUrl = (data['html_url'] ?? '').toString();
      }

      final hasUpdate = _isVersionGreater(rawTag, currentAppVersion);

      return ApkUpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: rawTag,
        currentVersion: currentAppVersion,
        apkDownloadUrl: apkUrl,
        releaseNotes: body,
      );
    } catch (e) {
      if (kDebugMode) print("Update check error: $e");
      return null;
    }
  }

  static bool _isVersionGreater(String remote, String local) {
    try {
      final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final localParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final maxLen = remoteParts.length > localParts.length ? remoteParts.length : localParts.length;

      for (int i = 0; i < maxLen; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (_) {
      return remote != local;
    }
  }
}
