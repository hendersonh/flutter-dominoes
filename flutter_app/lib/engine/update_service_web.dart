import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'update_service_base.dart' as base;

class UpdateService extends base.UpdateService {
  UpdateService() : super();

  @override
  void performUpdate() {
    debugPrint('UpdateService: Performing hard reload (Web)...');
    // Use both reload and assign to ensure browsers force a fresh load
    web.window.location.reload();
    // Fallback for some mobile browsers that might ignore reload()
    web.window.location.assign(web.window.location.href);
  }
}
