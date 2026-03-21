import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'sound_service.dart';

class WebSoundService implements SoundService {
  late web.AudioContext _context;
  final Map<String, web.AudioBuffer> _buffers = {};
  bool _isInitialized = false;

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _context = web.AudioContext();
      _setupMasterUnlock();

      await Future.wait([
        _loadBuffer('tile_place', 'assets/assets/sounds/tile_place.wav'),
        _loadBuffer('draw_tile', 'assets/assets/sounds/draw_tile.wav'),
        _loadBuffer('hendy_win', 'assets/assets/sounds/hendy_win.wav'),
        _loadBuffer('human_win', 'assets/assets/sounds/human_win.wav'),
        _loadBuffer('ai_round_win', 'assets/assets/sounds/i_won_round.wav'),
        _loadBuffer('human_round_win', 'assets/assets/sounds/you_won_round.wav'),
      ]);

      _isInitialized = true;
      debugPrint("WebSoundService: Initialized.");
    } catch (e) {
      debugPrint("WebSoundService: Init error: $e");
    }
  }

  Future<void> _loadBuffer(String key, String url) async {
    try {
      final response = await web.window.fetch(url.toJS).toDart;
      final arrayBuffer = await response.arrayBuffer().toDart;
      _buffers[key] = await _context.decodeAudioData(arrayBuffer).toDart;
    } catch (e) {
      debugPrint("WebSoundService: Load failed for $url: $e");
    }
  }

  void _setupMasterUnlock() {
    final unlockHandler = (web.Event e) {
      if (_context.state == 'suspended') _context.resume();
    }.toJS;
    
    web.window.addEventListener('touchstart', unlockHandler, web.AddEventListenerOptions(once: true));
    web.window.addEventListener('mousedown', unlockHandler, web.AddEventListenerOptions(once: true));
    web.window.addEventListener('keydown', unlockHandler, web.AddEventListenerOptions(once: true));
  }

  void _play(String key) {
    if (!_isInitialized) return;
    if (_context.state == 'suspended') _context.resume();
    
    final buffer = _buffers[key];
    if (buffer == null) return;

    final source = _context.createBufferSource();
    source.buffer = buffer;
    source.connect(_context.destination);
    source.start();
  }

  @override
  Future<void> warmUp() async => _context.resume().toDart;

  @override
  Future<void> playTilePlace() async => _play('tile_place');

  @override
  Future<void> playDrawTile() async => _play('draw_tile');

  @override
  Future<void> playHendyWin() async => _play('hendy_win');

  @override
  Future<void> playHumanWin() async => _play('human_win');

  @override
  Future<void> playAiRoundWin() async => _play('ai_round_win');

  @override
  Future<void> playHumanRoundWin() async => _play('human_round_win');

  @override
  void dispose() {
    _context.close();
    _buffers.clear();
  }
}

SoundService getSoundService() => WebSoundService();

