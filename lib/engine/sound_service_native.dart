import 'package:audioplayers/audioplayers.dart';
import 'sound_service.dart';

class NativeSoundService implements SoundService {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> init() async {
    // Native platforms handle pre-caching effectively during playback
  }

  @override
  Future<void> warmUp() async {
    // No explicit warming required on native mobile/desktop
  }

  Future<void> _play(String asset) async {
    await _player.play(AssetSource('sounds/$asset'));
  }

  @override
  Future<void> playTilePlace() async => _play('tile_place.wav');

  @override
  Future<void> playDrawTile() async => _play('draw_tile.wav');

  @override
  Future<void> playHendyWin() async => _play('hendy_win.wav');

  @override
  Future<void> playHumanWin() async => _play('human_win.wav');

  @override
  Future<void> playAiRoundWin() async => _play('i_won_round.wav');

  @override
  Future<void> playHumanRoundWin() async => _play('you_won_round.wav');

  @override
  void dispose() {
    _player.dispose();
  }
}

SoundService getSoundService() => NativeSoundService();
