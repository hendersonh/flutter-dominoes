import 'platform_helper.dart';

class UnsupportedPlatformHelper implements PlatformHelper {
}

PlatformHelper getPlatformHelper() => UnsupportedPlatformHelper();
