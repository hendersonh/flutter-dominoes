# WASM Research: Sound & Build Deployment

## 1. Sound Issues on Mobile Browsers (WASM)

### Autoplay Policies
- **Core Issue**: Mobile browsers (iOS Safari, Android Chrome) block any audio playback that is not triggered by an explicit user gesture (e.g., tap, click).
- **WASM Impact**: In a WASM build, the audio logic is often encapsulated in a way that might not "bridge" perfectly to the initial user gesture if there's significant latency in the WASM-to-JS interop layer.
- **Solution**: Explicitly "unlock" the AudioContext on the first user interaction (e.g., a "Start Game" button) using a **Master Unlock** listener.

### WASM Compatibility
- **Requirement**: Must use packages migrated to `package:web`- **Async AI**: AI turns are handled in background workers/isolates using `Isolate.run`. This is critical for WASM (Skwasm) to prevent `memory access out of bounds` traps during UI transitions.
- **WASM Optimization**:
    - **Background Offloading**: MCTS is isolated from the main thread's memory heap.
    - **Hardened Headers**: COOP/COEP (`require-corp`) enabled for reliable worker/shared memory support.
- **Federated Service Pattern (Conditional Imports)**: Used to handle platform-specific implementations (Web vs. Native) while maintaining a single codebase. This allows for specialized logic (like the Web Audio context unlock for mobile browsers) or different library usage (e.g., `package:web` on Web vs. `audioplayers` on Native) to be swapped at compile-time.
 based on the target platform libraries.

### Architecture Overview
1.  **Interface (`sound_service_base.dart`)**: Defines the abstract `SoundService` contract and a factory constructor.
2.  **Web Implementation (`sound_service_web.dart`)**: Uses `package:web` and `dart:js_interop` for low-latency Web Audio logic and the **Master Unlock** for mobile browsers.
3.  **Native Implementation (`sound_service_mobile.dart`)**: Uses standard plugins like `audioplayers` for iOS/Android/Desktop Native.
4.  **Switcher (`sound_service.dart`)**: Employs conditional exports to select the correct implementation:
    ```dart
    export 'sound_service_mobile.dart' 
      if (dart.library.js_interop) 'sound_service_web.dart';
    ```

### Why this is the preferred solution:
- **Zero Bloat**: Only the code for the target platform is compiled into the binary.
- **Wasm Compatibility**: Using `if (dart.library.js_interop)` ensures modern `dart2wasm` support.
- **Isolation**: Specialized Web Audio logic (like the mobile browser unlock) stays isolated and doesn't affect native builds.

---

## 3. Serving on Cloudflare Pages

1.  **Deployment**:
    - With the Federated Service Pattern, a single **WASM build** (`flutter build web --wasm`) can intelligently handle its environment. 
    - However, if distinct "web" vs "mobile web" UI builds are still required, Cloudflare **Redirect Rules** can route users based on the `CF-Device-Type` header (e.g., `/mobile/` vs `/desktop/`).
2.  **Optimized Headers**:
    Include a `_headers` file in your project root for COOP/COEP compliance:
    ```text
    /*
      Cross-Origin-Opener-Policy: same-origin
      Cross-Origin-Embedder-Policy: require-corp
    ```

---

## 5. Build Output & Asset Loading for WASM

When running `flutter build web --wasm`, Flutter bundles audio files as standard assets into the `build/web/` distribution directory.

### Build Output Structure
Flutter maintains a consistent asset hierarchy, but in recent versions, the internal path is often nested as `assets/assets/`. For example:
- Source path: `assets/audio/domino_clack.wav`
- Build distribution: `build/web/assets/assets/audio/domino_clack.wav`

### Accessing Assets via Fetch
To load sounds in a `dart2wasm` compatible way using `package:web`, fetch them using their relative URL (e.g., `assets/assets/audio/filename.wav`).

```dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<web.AudioBuffer> loadSound(web.AudioContext context, String assetPath) async {
  // 1. Fetch the file as an ArrayBuffer
  // Note: assetPath should be 'assets/assets/audio/clack.wav'
  final response = await web.window.fetch(assetPath.toJS).toDart;
  final arrayBuffer = await response.arrayBuffer().toDart;

  // 2. Decode the audio data into a buffer
  final audioBuffer = await context.decodeAudioData(arrayBuffer).toDart;
  
  return audioBuffer;
}
```

### Key Considerations
*   **CORS**: Ensure the server sends `Access-Control-Allow-Origin` headers if assets are on a different domain.
*   **Case Sensitivity**: Web servers are case-sensitive; ensure path strings match the file system exactly.
*   **MIME Types**: Servers must serve `.wav` files with `audio/wav` or `audio/x-wav` MIME types.
### Verification Success
- **Result**: Successfully played `tile_place.wav` in a Chrome WASM/Debug session. Confirmed all pre-loaded sounds trigger as expected.
- **Cleanup**: Removed diagnostic `testPlayTone()` (sine wave) from `main.dart` once verification was complete.
- **Confirmed Path**: The relative fetch URL `assets/assets/sounds/tile_place.wav` is valid for development and reflects the correctly nested build output structure.
- **Master Unlock**: Confirmed that the `AudioContext` resumes successfully upon the first user interaction, allowing subsequent sounds to play without further intervention.

---

---

## 7. WASM Memory Access & Skwasm Worker Stability

### Root Cause: Rendering/Main-Thread Conflict
- **Error**: `skwasm.wasm` `memory access out of bounds` at `$surface_resizeOnWorker`.
- **Diagnosis**: The specialized **Skwasm** renderer uses multiple Web Workers for Skia/CanvasKit rendering. When the main UI thread is heavily blocked (e.g., by the synchronous IS-MCTS AI turn) AND then tries to perform a complex UI transition (like the round-end Glassy Progress overlay), the renderer hits a WASM memory trap. This is likely due to the JS/WASM heap resizing while the main thread is unresponsive or under high memory pressure from millions of MCTS node allocations.

### Solution: Background AI Offloading
- **Mechanism**: Use `Isolate.run` uniformly for all `getBestActionAsync` calls.
- **Web Implementation**: In Flutter 3.24+, `Isolate.run` on Web is backed by **Web Workers**. This moves the processor-intensive AI computation to a separate thread, freeing the main thread to handle rendering and layout updates synchronously with the Skwasm workers.
- **Header Hardening**: Switched COEP from `credentialless` to `require-corp` to ensure robust `SharedArrayBuffer` support across all browsers, which is essential for multi-threaded WASM.

## 8. Final Architecture Recommendations
1.  **AI Isolate**: Always run MCTS in an isolate/worker using `Isolate.run`.
2.  **Renderer Selection**: Although the WASM build supports Skwasm, we **force the CanvasKit renderer** in `web/flutter_bootstrap.js` for stability. Skwasm is prone to `memory access out of bounds` errors when complex UI animations and background workers compete for rendering priority.
3.  **COOP/COEP**: Mandatory headers for any app using background isolates/workers for shared memory performance.
