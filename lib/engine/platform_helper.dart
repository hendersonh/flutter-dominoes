import 'package:flutter/foundation.dart';
import 'platform_helper_unsupported.dart'
    if (dart.library.html) 'platform_helper_web.dart';

abstract class PlatformHelper {
  static void forceReload() {
    if (kIsWeb) {
      getPlatformHelper().reloadPage();
    }
  }

  void reloadPage();
}

PlatformHelper getPlatformHelper() => throw UnsupportedError('Cannot create a PlatformHelper');
