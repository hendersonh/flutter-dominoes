import 'sound_service.dart';

class UnsupportedSoundService implements SoundService {
  @override
  Future<void> init() async {}

  @override
  Future<void> playTilePlace() async {}

  @override
  Future<void> playDrawTile() async {}

  @override
  Future<void> playHendyWin() async {}

  @override
  Future<void> playHumanWin() async {}

  @override
  Future<void> playAiRoundWin() async {}

  @override
  Future<void> playHumanRoundWin() async {}

  @override
  Future<void> warmUp() async {}

  @override
  void dispose() {}
}

SoundService getSoundService() => UnsupportedSoundService();
