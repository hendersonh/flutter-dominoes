import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class SoundService {
  static final SoundService instance = SoundService._internal();

  final AudioPlayer _tilePlayer = AudioPlayer();
  final AudioPlayer _drawPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _humanWinPlayer = AudioPlayer();
  final AudioPlayer _aiRoundWinPlayer = AudioPlayer();
  final AudioPlayer _humanRoundWinPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isWarmedUp = false;

  bool get isWarmedUp => _isWarmedUp;

  SoundService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Pre-set sources to reduce latency on first play
      await _tilePlayer.setSource(AssetSource('sounds/tile_place.wav'));
      await _drawPlayer.setSource(AssetSource('sounds/draw_tile.wav'));
      await _winPlayer.setSource(AssetSource('sounds/hendy_win.wav'));

      try {
        await _humanWinPlayer.setSource(AssetSource('sounds/human_win.wav'));
        await _humanWinPlayer.stop();
      } catch (e) {
        debugPrint("SoundService: Human win sound asset not found yet: $e");
      }

      try {
        await _aiRoundWinPlayer.setSource(AssetSource('sounds/i_won_round.wav'));
        await _aiRoundWinPlayer.stop();
      } catch (e) {
        debugPrint("SoundService: AI round win sound asset not found yet: $e");
      }

      try {
        await _humanRoundWinPlayer.setSource(AssetSource('sounds/you_won_round.wav'));
        await _humanRoundWinPlayer.stop();
      } catch (e) {
        debugPrint("SoundService: Human round win sound asset not found yet: $e");
      }

      await _tilePlayer.stop();
      await _drawPlayer.stop();
      await _winPlayer.stop();

      _isInitialized = true;
      debugPrint("SoundService: Optimized sound assets ready.");
    } catch (e) {
      debugPrint("SoundService: Error initializing sound assets: $e");
    }
  }

  Future<void> playTilePlace() async {
    try {
      if (!_isWarmedUp && kIsWeb) warmUp();
      await _tilePlayer.stop();
      await _tilePlayer.play(AssetSource('sounds/tile_place.wav'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing tile place sound: $e");
    }
  }

  Future<void> playDrawTile() async {
    try {
      if (!_isWarmedUp && kIsWeb) warmUp();
      await _drawPlayer.stop();
      await _drawPlayer.play(AssetSource('sounds/draw_tile.wav'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing draw tile sound: $e");
    }
  }

  Future<void> playHendyWin() async {
    try {
      if (!_isWarmedUp && kIsWeb) warmUp();
      await _winPlayer.stop();
      await _winPlayer.play(AssetSource('sounds/hendy_win.wav'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing Hendy win sound: $e");
    }
  }

  Future<void> playHumanWin() async {
    try {
      if (!_isWarmedUp && kIsWeb) warmUp();
      await _humanWinPlayer.stop();
      await _humanWinPlayer.play(AssetSource('sounds/human_win.wav'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing Human win sound: $e");
    }
  }

  Future<void> playAiRoundWin() async {
    try {
      if (!_isWarmedUp && kIsWeb) warmUp();
      await _aiRoundWinPlayer.stop();
      await _aiRoundWinPlayer.play(AssetSource('sounds/i_won_round.wav'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing AI round win sound: $e");
    }
  }

  Future<void> playHumanRoundWin() async {
    try {
      if (!_isWarmedUp && kIsWeb) warmUp();
      await _humanRoundWinPlayer.stop();
      await _humanRoundWinPlayer.play(AssetSource('sounds/you_won_round.wav'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing Human round win sound: $e");
    }
  }

  /// Synchronously attempts to unlock the AudioContext and warm up players.
  /// This must be called from a user gesture (tap/click).
  void warmUp() {
    if (_isWarmedUp) return;
    
    debugPrint("SoundService: Synchronous warm-up triggered...");

    if (kIsWeb) {
      try {
        // Surgical Phase 3: Call the Master Audio Unlocker.
        // This unblocks both the AudioContext and the HTML5 Audio session.
        js.context.callMethod('masterAudioUnlock');
      } catch (e) {
        debugPrint("SoundService: JS nudge failed: $e");
      }
    }

    if (!_isInitialized) {
      // If not initialized, try to init and THEN warm up, but fire off one sync play NOW if possible.
      init().then((_) => _doWarmUpPlayback());
    } else {
      _doWarmUpPlayback();
    }
    
    // Optimistically set to true to allow UI to advance. 
    // Manual recovery icon in AppBar handles edge cases.
    _isWarmedUp = true; 
  }

  /// Explicitly resumes the audio context. Useful for visibility recovery.
  void resume() {
    if (kIsWeb) {
      try {
        js.context.callMethod('eval', [
          """
          (function() {
            var AudioContext = window.AudioContext || window.webkitAudioContext;
            if (AudioContext) {
              var c = new AudioContext();
              c.resume().then(function() { c.close(); });
            }
          })();
          """
        ]);
      } catch (e) {
        debugPrint("SoundService: Resume nudge failed: $e");
      }
    }
  }

  void _doWarmUpPlayback() {
    final players = [
      _tilePlayer,
      _drawPlayer,
      _winPlayer,
      _humanWinPlayer,
      _aiRoundWinPlayer,
      _humanRoundWinPlayer,
    ];

    // Fire all warm-up sounds synchronously in the eyes of the browser.
    // We don't await because that breaks the gesture window on some mobile browsers.
    for (var player in players) {
      player.play(AssetSource('sounds/tile_place.wav'), volume: 0.001).catchError((e) {
        debugPrint("SoundService: Play warm-up failed for a player: $e");
      });
    }

    debugPrint("SoundService: Warm-up sequence initiated.");
  }

  void dispose() {
    _tilePlayer.dispose();
    _drawPlayer.dispose();
    _winPlayer.dispose();
    _humanWinPlayer.dispose();
    _aiRoundWinPlayer.dispose();
    _humanRoundWinPlayer.dispose();
  }
}
