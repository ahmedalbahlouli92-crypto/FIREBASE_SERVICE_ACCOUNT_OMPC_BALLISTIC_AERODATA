import 'dart:convert';
import 'dart:io';
import 'attachment_helper.dart';

class AttachmentStubHelper implements AttachmentHelper {
  @override
  Future<Map<String, String>?> pickFileAsBase64({String accept = 'image/*,.pdf,.doc,.docx'}) async {
    if (Platform.isWindows) {
      try {
        final psScript = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "Supported Files (*.pdf;*.csv;*.tsv;*.txt;*.json;*.png;*.jpg;*.jpeg;*.doc;*.docx)|*.pdf;*.csv;*.tsv;*.txt;*.json;*.png;*.jpg;*.jpeg;*.doc;*.docx|All Files (*.*)|*.*"
$dialog.Title = "Select File"
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output $dialog.FileName
}
''';
        final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript]);
        if (result.exitCode == 0) {
          final filePath = result.stdout.toString().trim();
          if (filePath.isNotEmpty && File(filePath).existsSync()) {
            final file = File(filePath);
            final bytes = await file.readAsBytes();
            final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'file';
            return {
              'name': fileName,
              'data': base64Encode(bytes),
            };
          }
        }
      } catch (e) {
        // Fallback gracefully if PowerShell or Windows Forms is not accessible
      }
    }
    return null;
  }
}

AttachmentHelper getAttachmentHelper() => AttachmentStubHelper();
