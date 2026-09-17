import 'attachment_stub_helper.dart'
    if (dart.library.js) 'attachment_web_helper.dart' as impl;

abstract class AttachmentHelper {
  Future<Map<String, String>?> pickFileAsBase64({String accept = 'image/*,.pdf,.doc,.docx'});
}

AttachmentHelper getAttachmentHelper() => impl.getAttachmentHelper();
