import 'dart:html' as html;
import 'platform_helper.dart';

class WebPlatformHelper implements PlatformHelper {
  @override
  void reloadPage() {
    // Clear all named caches before reloading
    html.window.caches?.keys().then((keys) {
      if (keys != null) {
        for (final key in keys) {
          html.window.caches?.delete(key);
        }
      }
    }).then((_) {
      // Force hard reload by appending timestamp
      final uri = Uri.parse(html.window.location.href);
      final newUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'f': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      html.window.location.replace(newUri.toString());
    });
  }
}

PlatformHelper getPlatformHelper() => WebPlatformHelper();
