class AudioEngine {
  /// Dummy context for non-web platforms.
  static dynamic get context => null;

  /// No-op unlock for non-web platforms.
  static Future<void> unlockAudio() async {
    // No-op on VM/mobile
  }
}
