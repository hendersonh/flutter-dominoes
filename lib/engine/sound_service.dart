import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService instance = SoundService._internal();
  
  final AudioPlayer _tilePlayer = AudioPlayer();
  final AudioPlayer _drawPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _humanWinPlayer = AudioPlayer();
  final AudioPlayer _aiRoundWinPlayer = AudioPlayer();
  final AudioPlayer _humanRoundWinPlayer = AudioPlayer();
  bool _isInitialized = false;

  SoundService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Pre-set sources to reduce latency on first play
      await _tilePlayer.setSource(AssetSource('sounds/tile_place.wav'));
      await _drawPlayer.setSource(AssetSource('sounds/draw_tile.mp3'));
      await _winPlayer.setSource(AssetSource('sounds/hendy_win.mp3'));
      
      // Note: human_win.mp3 will be loaded if it exists, otherwise it might throw 
      // but we catch it here to keep the service running.
      try {
        await _humanWinPlayer.setSource(AssetSource('sounds/human_win.mp3'));
        await _humanWinPlayer.stop();
      } catch (e) {
        debugPrint("SoundService: Human win sound asset not found yet: $e");
      }

      try {
        await _aiRoundWinPlayer.setSource(AssetSource('sounds/i_won_round.mp3'));
        await _aiRoundWinPlayer.stop();
      } catch (e) {
        debugPrint("SoundService: AI round win sound asset not found yet: $e");
      }

      try {
        await _humanRoundWinPlayer.setSource(AssetSource('sounds/you_won_round.mp3'));
        await _humanRoundWinPlayer.stop();
      } catch (e) {
        debugPrint("SoundService: Human round win sound asset not found yet: $e");
      }
      
      // Ensure they don't play on init (though setSource shouldn't play anyway)
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
      // Seek to beginning and play on the dedicated player
      await _tilePlayer.stop();
      await _tilePlayer.play(AssetSource('sounds/tile_place.wav'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing tile place sound: $e");
    }
  }

  Future<void> playDrawTile() async {
    try {
      await _drawPlayer.stop();
      await _drawPlayer.play(AssetSource('sounds/draw_tile.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing draw tile sound: $e");
    }
  }

  Future<void> playHendyWin() async {
    try {
      debugPrint("SoundService: Triggering Hendy win sound...");
      await _winPlayer.stop();
      await _winPlayer.play(AssetSource('sounds/hendy_win.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing Hendy win sound: $e");
    }
  }

  Future<void> playHumanWin() async {
    try {
      debugPrint("SoundService: Triggering Human win sound...");
      await _humanWinPlayer.stop();
      await _humanWinPlayer.play(AssetSource('sounds/human_win.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing Human win sound: $e");
    }
  }

  Future<void> playAiRoundWin() async {
    try {
      debugPrint("SoundService: Triggering AI round win sound...");
      await _aiRoundWinPlayer.stop();
      await _aiRoundWinPlayer.play(AssetSource('sounds/i_won_round.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing AI round win sound: $e");
    }
  }

  Future<void> playHumanRoundWin() async {
    try {
      debugPrint("SoundService: Triggering Human round win sound...");
      await _humanRoundWinPlayer.stop();
      await _humanRoundWinPlayer.play(AssetSource('sounds/you_won_round.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("SoundService: Error playing Human round win sound: $e");
    }
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
