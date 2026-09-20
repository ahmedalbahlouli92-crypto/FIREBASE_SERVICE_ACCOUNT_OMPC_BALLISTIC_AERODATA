import 'app_exit_stub.dart'
    if (dart.library.html) 'app_exit_web.dart' as impl;

void closeApplication() {
  impl.exitApplication();
}
