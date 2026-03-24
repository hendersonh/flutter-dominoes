import 'sound_service_base.dart';

class UnsupportedSoundService implements SoundService {
  static final UnsupportedSoundService _instance =
      UnsupportedSoundService._internal();
  factory UnsupportedSoundService() => _instance;
  UnsupportedSoundService._internal();

  @override
  Future<void> initialize() async {
    print("SoundService not supported on this platform.");
  }

  @override
  void playSfx(String assetPath) {
    print("Sound cannot be played: $assetPath (Unsupported Platform)");
  }

  @override
  void testPlayTone() {
    print("testPlayTone not supported on this platform.");
  }
}

SoundService getSoundService() => UnsupportedSoundService();
