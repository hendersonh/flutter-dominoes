import 'package:web/web.dart' as web;
import 'dart:js_interop';

class AudioEngine {
  static web.AudioContext? _context;

  static web.AudioContext get context => _context ??= web.AudioContext();

  /// Call this from a button in your Flutter UI (e.g., 'Start' or 'Unmute').
  /// MUST be triggered by a synchronous user tap.
  static Future<void> unlockAudio() async {
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
  }
}
