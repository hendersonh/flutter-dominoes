import 'sound_service_stub.dart'
    if (dart.library.js_interop) 'sound_service_web.dart'
    if (dart.library.io) 'sound_service_native.dart';

abstract class SoundService {
  static SoundService? _instance;
  static SoundService get instance {
    _instance ??= getSoundService();
    return _instance!;
  }

  Future<void> init();
  Future<void> warmUp();
  Future<void> playTilePlace();
  Future<void> playDrawTile();
  Future<void> playHendyWin();
  Future<void> playHumanWin();
  Future<void> playAiRoundWin();
  Future<void> playHumanRoundWin();
  void dispose();
}
