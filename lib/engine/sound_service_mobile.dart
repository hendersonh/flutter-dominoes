import 'package:audioplayers/audioplayers.dart';
import 'sound_service_base.dart';

class MobileSoundService implements SoundService {
  final AudioPlayer _player = AudioPlayer();

  static final MobileSoundService _instance = MobileSoundService._internal();
  factory MobileSoundService() => _instance;
  MobileSoundService._internal();

  @override
  Future<void> initialize() async {
    // Standard audioplayers initialization if needed
    await _player.setSource(AssetSource('sounds/tile_place.wav'));
  }

  @override
  void playSfx(String assetPath) {
    // audioplayers uses 'sounds/file.wav' relative to assets/
    String relativePath = assetPath.replaceFirst('assets/', '');
    _player.play(AssetSource(relativePath));
  }

  @override
  void testPlayTone() {
    // No-op on mobile for now
  }
}

SoundService getSoundService() => MobileSoundService();
