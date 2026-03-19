import 'sound_service_unsupported.dart'
    if (dart.library.html) 'sound_service_web.dart';

abstract class SoundService {
  static SoundService? _instance;

  static SoundService get instance {
    _instance ??= getSoundService();
    return _instance!;
  }

  Future<void> init();
  Future<void> playTilePlace();
  Future<void> playDrawTile();
  Future<void> playHendyWin();
  Future<void> playHumanWin();
  Future<void> playAiRoundWin();
  Future<void> playHumanRoundWin();
  Future<void> warmUp();
  void dispose();
}
