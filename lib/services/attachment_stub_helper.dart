import 'attachment_helper.dart';

class AttachmentStubHelper implements AttachmentHelper {
  @override
  Future<Map<String, String>?> pickFileAsBase64({String accept = 'image/*,.pdf,.doc,.docx'}) async {
    return null;
  }
}

AttachmentHelper getAttachmentHelper() => AttachmentStubHelper();
