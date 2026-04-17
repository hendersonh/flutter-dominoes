# Build & Deployment Instructions

This document records the exact, verified commands and configurations required to build and deploy the HendyDom application.

## 1. Web Deployment (WASM + CanvasKit)

We use the **WASM** build for performance, but force the **CanvasKit** renderer to avoid Skia memory traps (`memory access out of bounds`) that occur with Skwasm during complex UI updates.

### Build Command
Run from the `flutter_app/` directory:
```bash
flutter build web --wasm
```

### Renderer Configuration
**IMPORTANT**: The renderer is NOT controlled by a build flag for WASM. It is controlled by initialization in `web/flutter_bootstrap.js`.

Ensure `web/flutter_bootstrap.js` exists and contains:
```javascript
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    renderer: "canvaskit",
  },
});
```

### Cloudflare Pages Deployment
Run from the `flutter_app/` directory:
```bash
npx wrangler pages deploy build/web --project-name cut-throat-dom
```

## 2. Environment Setup

### Required Headers
For WASM/Workers to function correctly (Multi-threading/SharedArrayBuffer), the following headers must be served:
```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```
These are configured in `web/_headers`.

## 3. Local Development (Chrome)

For testing the WASM build locally:
```bash
flutter run -d chrome --wasm
```

## 4. Troubleshooting

### "memory access out of bounds"
- **Cause**: Likely running with the `skwasm` renderer.
- **Fix**: Verify `web/flutter_bootstrap.js` is forcing `renderer: "canvaskit"`.
