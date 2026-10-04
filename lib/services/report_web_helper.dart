import 'dart:convert';
import 'dart:js' as js;
import 'report_helper.dart';

class ReportHelperImpl implements ReportHelper {
  @override
  Future<void> downloadCsv({required String content, required String filename}) async {
    final bomContent = content.startsWith('\uFEFF') ? content : '\uFEFF$content';
    final base64Content = base64Encode(utf8.encode(bomContent));
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
    final bomContent = content.startsWith('\uFEFF') ? content : '\uFEFF$content';
    final base64Content = base64Encode(utf8.encode(bomContent));
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
  Future<void> printHtml({required String htmlContent, String? filename}) async {
    final base64Html = base64Encode(utf8.encode(htmlContent));
    final safeFilename = (filename ?? '').replaceAll("'", "\\'").replaceAll('"', '\\"');
    js.context.callMethod('eval', [
      '''
      (function() {
        var bin = atob('$base64Html');
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) {
          bytes[i] = bin.charCodeAt(i);
        }
        var html = new TextDecoder('utf-8').decode(bytes);
        var iframe = document.getElementById('__ompc_print_frame__');
        if (!iframe) {
          iframe = document.createElement('iframe');
          iframe.id = '__ompc_print_frame__';
          iframe.style.position = 'fixed';
          iframe.style.right = '0';
          iframe.style.bottom = '0';
          iframe.style.width = '0';
          iframe.style.height = '0';
          iframe.style.border = '0';
          iframe.style.visibility = 'hidden';
          document.body.appendChild(iframe);
        }
        var doc = iframe.contentWindow.document;
        doc.open();
        doc.write(html);
        doc.close();

        var isCert = html.toLowerCase().indexOf('lot acceptance certificate') !== -1 || '$safeFilename'.toLowerCase().indexOf('certificate') !== -1;
        var origTitle = document.title;
        if (isCert) {
          doc.title = '';
          document.title = '';
          var style = doc.createElement('style');
          style.innerHTML = '@page { margin: 0 !important; } @media print { @page { margin: 0 !important; } }';
          doc.head.appendChild(style);
        } else if ('$safeFilename') {
          doc.title = '$safeFilename';
          document.title = '$safeFilename';
        }

        setTimeout(function() {
          iframe.contentWindow.focus();
          iframe.contentWindow.print();
          setTimeout(function() {
            document.title = origTitle;
          }, 3000);
        }, 500);
      })()
      '''
    ]);
  }

  @override
  Future<void> openReport({required String htmlContent, String? title}) async {
    final base64Html = base64Encode(utf8.encode(htmlContent));
    final safeTitle = (title ?? 'Inspection Report').replaceAll("'", "\\'").replaceAll('"', '\\"');
    js.context.callMethod('eval', [
      '''
      (function() {
        var bin = atob('$base64Html');
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) {
          bytes[i] = bin.charCodeAt(i);
        }
        var html = new TextDecoder('utf-8').decode(bytes);
        var blob = new Blob([html], {type: 'text/html;charset=utf-8;'});
        var url = URL.createObjectURL(blob);
        var w = window.open(url, '_blank');
        if (w) {
          w.document.title = '$safeTitle';
          w.focus();
        } else {
          window.location.href = url;
        }
      })()
      '''
    ]);
  }

  @override
  Future<void> openUrl({required String url}) async {
    js.context.callMethod('open', [url, '_blank']);
  }
}

ReportHelper getHelper() => ReportHelperImpl();
