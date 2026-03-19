import 'dart:html' as html;
import 'dart:js' as js;
import 'platform_helper.dart';

class WebPlatformHelper implements PlatformHelper {
  @override
  void reloadPage() {
    // Call the robust JS utility defined in index.html
    js.context.callMethod('forceAppUpdate');
  }
}

PlatformHelper getPlatformHelper() => WebPlatformHelper();
