import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web; // For reload

class UpdateService extends ChangeNotifier {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  String? _currentVersion;
  bool _isUpdateAvailable = false;
  Timer? _pollingTimer;

  bool get isUpdateAvailable => _isUpdateAvailable;

  /// Initializes the update service by capturing the version at startup.
  Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      // Capture the version that is served right now as our "current" version
      _currentVersion = await _fetchVersion();
      debugPrint('UpdateService: Initialized with version $_currentVersion');
      
      // Start a lazy polling timer (every 5 seconds for testing)
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => checkForUpdates());
    } catch (e) {
      debugPrint('UpdateService: Failed to initialize: $e');
    }
  }

  /// Fetches the version.json from the server with a cache-buster.
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

  /// Manually trigger an update check.
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
  void performUpdate() {
    if (kIsWeb) {
      debugPrint('UpdateService: Performing hard reload...');
      // Use both reload and assign to ensure browsers force a fresh load
      web.window.location.reload();
      // Fallback for some mobile browsers that might ignore reload()
      web.window.location.assign(web.window.location.href);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
