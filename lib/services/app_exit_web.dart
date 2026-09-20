import 'dart:html' as html;

void exitApplication() {
  try {
    html.HttpRequest.getString('/api/exit').catchError((_) => '');
    html.window.close();
  } catch (_) {}
}
