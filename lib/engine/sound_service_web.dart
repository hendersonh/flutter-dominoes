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
    print("WebSoundService.initialize() called.");

    // Using centralized AudioEngine.context
    print(
      "WebSoundService using AudioEngine.context. State: ${AudioEngine.context.state}",
    );

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

    print("Pre-loading ${sounds.length} sound assets via fetch...");
    await Future.wait(sounds.map((s) => _preload(s)));
  }

  Future<void> _preload(String assetPath) async {
    if (_bufferCache.containsKey(assetPath)) return;

    try {
      // For WASM/Web, assets are nested in assets/assets/
      final String webPath = 'assets/$assetPath';
      print("Fetching asset: $webPath");

      final web.Response response = await web.window.fetch(webPath.toJS).toDart;
      if (!response.ok) {
        throw Exception("HTTP Error ${response.status} fetching $webPath");
      }

      final JSArrayBuffer arrayBuffer = await response.arrayBuffer().toDart;
      final web.AudioBuffer audioBuffer = await AudioEngine.context
          .decodeAudioData(arrayBuffer)
          .toDart;

      _bufferCache[assetPath] = audioBuffer;
      print("Preloaded sound: $assetPath (webPath: $webPath)");
    } catch (e) {
      print("Error preloading sound $assetPath: $e");
    }
  }

  @override
  void playSfx(String assetPath) {
    // Check if context is suspended (common on web autoplay)
    if (AudioEngine.context.state == 'suspended') {
      print(
        "AudioContext suspended, attempting to resume before playing: $assetPath",
      );
      AudioEngine.context
          .resume()
          .toDart
          .then((_) {
            print(
              "AudioContext resumed successfully. State: ${AudioEngine.context.state}",
            );
            _doPlay(assetPath);
          })
          .catchError((e) {
            print("Failed to resume AudioContext: $e");
          });
      return;
    }

    _doPlay(assetPath);
  }

  void _doPlay(String assetPath) {
    final buffer = _bufferCache[assetPath];
    if (buffer == null) {
      print(
        "Sound buffer not found in cache for $assetPath. Attempting lazy load...",
      );
      _preload(assetPath).then((_) => _doPlay(assetPath));
      return;
    }

    try {
      print(
        "Starting playback for $assetPath (Duration: ${buffer.duration}s, Context: ${AudioEngine.context.state})",
      );
      final source = AudioEngine.context.createBufferSource();
      source.buffer = buffer;
      source.connect(AudioEngine.context.destination);
      source.start();
    } catch (e) {
      print("Error in _doPlay for $assetPath: $e");
    }
  }

  /// Diagnostic tool to play a 440Hz tone for 0.5 seconds.
  @override
  void testPlayTone() {
    print("WebSoundService: Triggering diagnostic Sine wave tone...");
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
        print("Sine wave started. Context: ${AudioEngine.context.state}");

        // Stop after 0.5s
        web.window.setTimeout(
          () {
            osc.stop();
            print("Sine wave stopped.");
          }.toJS,
          500.toJS,
        );
      } catch (e) {
        print("Error playing test tone: $e");
      }
    });
  }
}

SoundService getSoundService() => WebSoundService();
