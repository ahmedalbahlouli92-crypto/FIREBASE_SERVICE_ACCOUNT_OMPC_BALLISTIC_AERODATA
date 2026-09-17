import 'dart:convert';
import 'dart:js' as js;
import 'report_helper.dart';

class ReportHelperImpl implements ReportHelper {
  @override
  Future<void> downloadCsv({required String content, required String filename}) async {
    final base64Content = base64Encode(utf8.encode(content));
    js.context.callMethod('eval', [
      '''
      (function() {
        var base64 = '$base64Content';
        var bin = atob(base64);
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) {
          bytes[i] = bin.charCodeAt(i);
        }
        var blob = new Blob([bytes], {type: 'text/csv;charset=utf-8;'});
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = '$filename';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      })()
      '''
    ]);
  }

  @override
  Future<void> downloadDoc({required String content, required String filename}) async {
    final base64Content = base64Encode(utf8.encode(content));
    js.context.callMethod('eval', [
      '''
      (function() {
        var base64 = '$base64Content';
        var bin = atob(base64);
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) {
          bytes[i] = bin.charCodeAt(i);
        }
        var blob = new Blob([bytes], {type: 'application/msword;charset=utf-8;'});
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = '$filename';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      })()
      '''
    ]);
  }

  @override
  Future<void> printHtml({required String htmlContent}) async {
    final base64Html = base64Encode(utf8.encode(htmlContent));
    js.context.callMethod('eval', [
      '''
      (function() {
        var html = atob('$base64Html');
        var win = window.open('', '_blank');
        win.document.write(html);
        win.document.close();
        win.focus();
        setTimeout(function() {
          win.print();
          win.close();
        }, 500);
      })()
      '''
    ]);
  }
}

ReportHelper getHelper() => ReportHelperImpl();
