import 'sound_service_unsupported.dart'
    if (dart.library.js_interop) 'sound_service_web.dart'
    if (dart.library.io) 'sound_service_mobile.dart';

abstract class SoundService {
  /// Initialize the sound service (pre-loading assets, setting up context, etc.)
  Future<void> initialize();

  /// Play a sound effect from the given asset path.
  void playSfx(String assetPath);

  /// Explicitly resume the audio context (required for web autoplay gestures).
  Future<void> resume();

  /// Diagnostic tool to play a test tone.
  void testPlayTone();

  /// Factory constructor that returns the correct implementation for the current platform.
  factory SoundService() {
    final service = getSoundService();
    return service;
  }
}
