import 'dart:async';
import 'dart:html' as html;
import 'attachment_helper.dart';

class AttachmentWebHelper implements AttachmentHelper {
  @override
  Future<Map<String, String>?> pickFileAsBase64({String accept = 'image/*,.pdf,.doc,.docx'}) {
    final completer = Completer<Map<String, String>?>();

    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = accept;
    uploadInput.style.display = 'none';
    html.document.body?.children.add(uploadInput);

    void cleanup() {
      try {
        uploadInput.remove();
      } catch (_) {}
    }

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.onLoadEnd.listen((e) {
          final result = reader.result;
          cleanup();
          if (result is String) {
            var sizeStr = '${(file.size / 1024).toStringAsFixed(1)} KB';
            if (file.size > 1024 * 1024) {
              sizeStr = '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB';
            }
            completer.complete({
              'name': file.name,
              'data': result,
              'size': sizeStr,
            });
          } else {
            completer.complete(null);
          }
        });
        reader.onError.listen((_) {
          cleanup();
          completer.complete(null);
        });
        reader.readAsDataUrl(file);
      } else {
        cleanup();
        completer.complete(null);
      }
    });

    uploadInput.click();

    return completer.future;
  }
}

AttachmentHelper getAttachmentHelper() => AttachmentWebHelper();
