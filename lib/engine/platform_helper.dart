
import 'platform_helper_unsupported.dart'
    if (dart.library.html) 'platform_helper_web.dart';

abstract class PlatformHelper {

}

PlatformHelper getPlatformHelper() => throw UnsupportedError('Cannot create a PlatformHelper');
