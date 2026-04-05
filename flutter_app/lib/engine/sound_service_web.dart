import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'audio_engine.dart';
import 'sound_service_base.dart';

class WebSoundService implements SoundService {
  final Map<String, web.AudioBuffer> _bufferCache = {};

  static final WebSoundService _instance = WebSoundService._internal();
  factory WebSoundService() => _instance;
  WebSoundService._internal();

  @override
  Future<void> initialize() async {
    // Pre-load all available sounds
    final List<String> sounds = [
      'assets/sounds/draw_tile.wav',
      'assets/sounds/hendy_win.wav',
      'assets/sounds/human_win.wav',
      'assets/sounds/i_won_round.wav',
      'assets/sounds/tile_place.wav',
      'assets/sounds/tile_knock.wav',
      'assets/sounds/you_won_round.wav',
    ];

    await Future.wait(sounds.map((s) => _preload(s)));
  }

  Future<void> _preload(String assetPath) async {
    if (_bufferCache.containsKey(assetPath)) return;

    try {
      // For WASM/Web, assets are nested in assets/assets/
      final String webPath = 'assets/$assetPath';

      final web.Response response = await web.window.fetch(webPath.toJS).toDart;
      if (!response.ok) {
        throw Exception("HTTP Error ${response.status} fetching $webPath");
      }

      final JSArrayBuffer arrayBuffer = await response.arrayBuffer().toDart;
      final web.AudioBuffer audioBuffer = await AudioEngine.context
          .decodeAudioData(arrayBuffer)
          .toDart;

      _bufferCache[assetPath] = audioBuffer;
    } catch (e) {
      // Ignore preloading errors
    }
  }

  @override
  void playSfx(String assetPath) {
    // Check if context is suspended (common on web autoplay)
    if (AudioEngine.context.state == 'suspended') {
      AudioEngine.context
          .resume()
          .toDart
          .then((_) {
            _doPlay(assetPath);
          })
          .catchError((e) {
          });
      return;
    }

    _doPlay(assetPath);
  }

  void _doPlay(String assetPath) {
    final buffer = _bufferCache[assetPath];
    if (buffer == null) {
      _preload(assetPath).then((_) => _doPlay(assetPath));
      return;
    }

    try {
      final source = AudioEngine.context.createBufferSource();
      source.buffer = buffer;
      source.connect(AudioEngine.context.destination);
      source.start();
    } catch (e) {
      // Ignore playback errors
    }
  }

  @override
  Future<void> resume() async {
    try {
      await AudioEngine.context.resume().toDart;
    } catch (e) {
      // Ignore resume errors
    }
  }

  /// Diagnostic tool to play a 440Hz tone for 0.5 seconds.
  @override
  void testPlayTone() {
    AudioEngine.context.resume().toDart.then((_) {
      try {
        final web.OscillatorNode osc = AudioEngine.context.createOscillator();
        final web.GainNode gain = AudioEngine.context.createGain();

        osc.type = 'sine';
        osc.frequency.value = 440;

        gain.gain.value = 0.1; // 10% volume

        osc.connect(gain);
        gain.connect(AudioEngine.context.destination);

        osc.start();

        // Stop after 0.5s
        web.window.setTimeout(
          () {
            osc.stop();
          }.toJS,
          500.toJS,
        );
      } catch (e) {
        // Ignore test tone errors
      }
    });
  }
}

SoundService getSoundService() => WebSoundService();
