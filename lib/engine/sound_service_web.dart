import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'sound_service.dart';

class WebSoundService implements SoundService {
  html.AudioElement? _tilePlayer;
  html.AudioElement? _drawPlayer;
  html.AudioElement? _winPlayer;
  html.AudioElement? _humanWinPlayer;
  html.AudioElement? _aiRoundWinPlayer;
  html.AudioElement? _humanRoundWinPlayer;
  bool _isInitialized = false;

  html.AudioElement _createPlayer(String src) {
    final player = html.AudioElement(src)..preload = 'auto';
    html.document.body?.append(player);
    return player;
  }

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _tilePlayer = _createPlayer('assets/sounds/tile_place.wav');
      _drawPlayer = _createPlayer('assets/sounds/draw_tile.wav');
      _winPlayer = _createPlayer('assets/sounds/hendy_win.wav');
      _humanWinPlayer = _createPlayer('assets/sounds/human_win.wav');
      _aiRoundWinPlayer = _createPlayer('assets/sounds/i_won_round.wav');
      _humanRoundWinPlayer = _createPlayer('assets/sounds/you_won_round.wav');

      _isInitialized = true;
      debugPrint("WebSoundService: HTML5 Audio assets initialized.");
    } catch (e) {
      debugPrint("WebSoundService: Error initializing sound assets: $e");
    }
  }

  void _playSound(html.AudioElement? player) {
    if (player != null) {
      player.currentTime = 0;
      player.play().catchError((e) {
        debugPrint("WebSoundService: Play failed: $e");
      });
    }
  }

  @override
  Future<void> playTilePlace() async => _playSound(_tilePlayer);

  @override
  Future<void> playDrawTile() async => _playSound(_drawPlayer);

  @override
  Future<void> playHendyWin() async => _playSound(_winPlayer);

  @override
  Future<void> playHumanWin() async => _playSound(_humanWinPlayer);

  @override
  Future<void> playAiRoundWin() async => _playSound(_aiRoundWinPlayer);

  @override
  Future<void> playHumanRoundWin() async => _playSound(_humanRoundWinPlayer);

  bool _isWarmedUp = false;

  @override
  Future<void> warmUp() async {
    if (_isWarmedUp) return;
    if (!_isInitialized) await init();
    
    try {
      debugPrint("WebSoundService: Warming up HTML5 Audio...");
      if (_tilePlayer != null) {
        _tilePlayer!.volume = 0.001;
        _tilePlayer!.play().catchError((e) => null);
      }
      _isWarmedUp = true;
    } catch (e) {
      debugPrint("WebSoundService: Warmup failed: $e");
    }
  }

  @override
  void dispose() {
    _tilePlayer?.remove();
    _drawPlayer?.remove();
    _winPlayer?.remove();
    _humanWinPlayer?.remove();
    _aiRoundWinPlayer?.remove();
    _humanRoundWinPlayer?.remove();
  }
}

SoundService getSoundService() => WebSoundService();
