import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight cross-platform image text extractor (OCR)
/// On Windows desktop: Utilizes native WinRT Windows.Media.Ocr (offline, fast, supports en-US and ar-SA)
/// On Web / mobile: Gracefully provides string inspection or empty fallback
class ImageTextExtractor {
  static Future<String> extractText(List<int> bytes, [String filename = 'image.png']) async {
    if (bytes.isEmpty) return '';

    if (!kIsWeb && Platform.isWindows) {
      try {
        final tempDir = Directory.systemTemp;
        final ext = filename.contains('.') ? filename.substring(filename.lastIndexOf('.')) : '.png';
        final tempFile = File('${tempDir.path}\\ocr_${DateTime.now().millisecondsSinceEpoch}$ext');
        await tempFile.writeAsBytes(bytes);

        final psScript = '''
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  [Windows.Media.Ocr.OcrEngine, Windows.Foundation.Diagnostics, ContentType = WindowsRuntime] | Out-Null
  [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
  [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null

  \$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 
      \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.IsGenericMethod 
  })[0]

  function Await-WinRt(\$winRtOp, [type]\$t) {
      \$m = \$asTaskGeneric.MakeGenericMethod(\$t)
      \$tTask = \$m.Invoke(\$null, @(\$winRtOp))
      \$tTask.Wait(-1) | Out-Null
      return \$tTask.Result
  }

  \$resolvedPath = '${tempFile.path.replaceAll("'", "''")}'
  \$fileStream = [System.IO.File]::OpenRead(\$resolvedPath)
  \$stream = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream(\$fileStream)

  \$decoderOp = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync(\$stream)
  \$decoder = Await-WinRt \$decoderOp ([Windows.Graphics.Imaging.BitmapDecoder])

  \$bitmapOp = \$decoder.GetSoftwareBitmapAsync()
  \$bitmap = Await-WinRt \$bitmapOp ([Windows.Graphics.Imaging.SoftwareBitmap])

  \$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
  if (-not \$engine) {
      \$lang = [Windows.Globalization.Language]::new('en-US')
      \$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage(\$lang)
  }

  \$ocrOp = \$engine.RecognizeAsync(\$bitmap)
  \$ocrResult = Await-WinRt \$ocrOp ([Windows.Media.Ocr.OcrResult])

  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  foreach (\$line in \$ocrResult.Lines) {
      [Console]::WriteLine(\$line.Text)
  }
  \$fileStream.Close()
} catch {
  exit 1
}
''';

        final process = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          psScript,
        ]);

        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}

        if (process.exitCode == 0) {
          final out = process.stdout.toString().trim();
          if (out.isNotEmpty) return out;
        }
      } catch (e) {
        debugPrint('ImageTextExtractor Windows OCR error: $e');
      }
    }

    return '';
  }
}
