import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UpdateService extends ChangeNotifier {
  UpdateService();

  String? _currentVersion;
  bool _isUpdateAvailable = false;
  Timer? _pollingTimer;

  bool get isUpdateAvailable => _isUpdateAvailable;

  /// Initializes the update service by capturing the version at startup.
  Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      _currentVersion = await _fetchVersion();
      debugPrint('UpdateService: Initialized with version $_currentVersion');
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => checkForUpdates());
    } catch (e) {
      debugPrint('UpdateService: Failed to initialize: $e');
    }
  }

  Future<String?> _fetchVersion() async {
    try {
      final response = await http.get(
        Uri.parse('version.json?cb=${DateTime.now().millisecondsSinceEpoch}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['version']?.toString();
      }
    } catch (e) {
      debugPrint('UpdateService: Error fetching version: $e');
    }
    return null;
  }

  Future<void> checkForUpdates() async {
    if (!kIsWeb || _currentVersion == null || _isUpdateAvailable) return;

    final newVersion = await _fetchVersion();
    if (newVersion != null && newVersion != _currentVersion) {
      debugPrint('UpdateService: New version detected! $newVersion (was $_currentVersion)');
      _isUpdateAvailable = true;
      notifyListeners();
    }
  }

  /// Triggers a hard reload of the page.
  /// Overridden on web platforms.
  void performUpdate() {
    debugPrint('UpdateService: performUpdate called (no-op on this platform)');
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
