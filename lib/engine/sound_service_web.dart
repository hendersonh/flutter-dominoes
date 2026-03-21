import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'sound_service.dart';

class WebSoundService implements SoundService {
  late web.AudioContext _context;
  final Map<String, web.AudioBuffer> _buffers = {};
  bool _isInitialized = false;
  bool _isUnlocked = false;

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _context = web.AudioContext();
      _setupUnlockListener();

      // Pre-load all sound assets
      await Future.wait([
        _loadBuffer('tile_place', 'assets/sounds/tile_place.wav'),
        _loadBuffer('draw_tile', 'assets/sounds/draw_tile.wav'),
        _loadBuffer('hendy_win', 'assets/sounds/hendy_win.wav'),
        _loadBuffer('human_win', 'assets/sounds/human_win.wav'),
        _loadBuffer('ai_round_win', 'assets/sounds/i_won_round.wav'),
        _loadBuffer('human_round_win', 'assets/sounds/you_won_round.wav'),
      ]);

      _isInitialized = true;
      debugPrint("WebSoundService: AudioContext and buffers initialized.");
    } catch (e) {
      debugPrint("WebSoundService: Error initializing audio: $e");
    }
  }

  Future<void> _loadBuffer(String key, String url) async {
    try {
      final response = await web.window.fetch(url.toJS).toDart;
      final arrayBuffer = await response.arrayBuffer().toDart;
      final audioBuffer = await _context.decodeAudioData(arrayBuffer).toDart;
      _buffers[key] = audioBuffer;
    } catch (e) {
      debugPrint("WebSoundService: Failed to load $url: $e");
    }
  }

  void _setupUnlockListener() {
    final unlockHandler = (web.Event e) {
      _attemptUnlock();
    }.toJS;

    web.window.addEventListener('touchstart', unlockHandler);
    web.window.addEventListener('mousedown', unlockHandler);
    web.window.addEventListener('keydown', unlockHandler);
  }

  void _attemptUnlock() async {
    if (_isUnlocked) return;

    if (_context.state == 'suspended') {
      await _context.resume().toDart;
    }

    if (_context.state == 'running') {
      _isUnlocked = true;
      debugPrint("WebSoundService: Audio Context Unlocked!");
    }
  }

  void _playSound(String key) {
    if (!_isInitialized) return;
    final buffer = _buffers[key];
    if (buffer == null) return;

    try {
      // Create a one-time use source node
      final source = _context.createBufferSource();
      source.buffer = buffer;
      source.connect(_context.destination);
      source.start();
    } catch (e) {
      debugPrint("WebSoundService: Playback failed for $key: $e");
    }
  }

  @override
  Future<void> playTilePlace() async => _playSound('tile_place');

  @override
  Future<void> playDrawTile() async => _playSound('draw_tile');

  @override
  Future<void> playHendyWin() async => _playSound('hendy_win');

  @override
  Future<void> playHumanWin() async => _playSound('human_win');

  @override
  Future<void> playAiRoundWin() async => _playSound('ai_round_win');

  @override
  Future<void> playHumanRoundWin() async => _playSound('human_round_win');

  @override
  Future<void> warmUp() async {
    if (!_isInitialized) await init();
    _attemptUnlock();
  }

  @override
  void dispose() {
    _context.close();
    _buffers.clear();
  }
}

SoundService getSoundService() => WebSoundService();

