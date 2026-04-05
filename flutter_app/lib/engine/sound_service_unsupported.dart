import 'sound_service_base.dart';

class UnsupportedSoundService implements SoundService {
  static final UnsupportedSoundService _instance =
      UnsupportedSoundService._internal();
  factory UnsupportedSoundService() => _instance;
  UnsupportedSoundService._internal();

  @override
  Future<void> initialize() async {}

  @override
  void playSfx(String assetPath) {}

  @override
  void testPlayTone() {}

  @override
  Future<void> resume() async {}
}

SoundService getSoundService() => UnsupportedSoundService();
