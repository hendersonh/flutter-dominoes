import 'platform_helper.dart';

class UnsupportedPlatformHelper implements PlatformHelper {
  @override
  void reloadPage() {
    // No-op on mobile/desktop
  }
}

PlatformHelper getPlatformHelper() => UnsupportedPlatformHelper();
