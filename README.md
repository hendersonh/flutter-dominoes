# HendyDom (Cut-Throat Dominoes)

HendyDom is a high-quality, interactive Dominoes game built seamlessly for Web (via Flutter WebAssembly). It features traditional Jamaican scoring modes, powerful AI opponents, and a premium "Six-Love" championship system.

## Key Features

- **Robust AI Strategy**: 4 difficulty levels driven by an IS-MCTS algorithm (Novice to Legendary).
- **Match Setup Options**: Play standard "100 Points" games or traditional Jamaican "Six-Love" games (first to 6 wins, with Game Bruk tracking).
- **Interactive UI**: Drag-and-drop mechanics, interactive boards, and realtime stats updating on the HUD.
- **WASM Performance**: The game compiles into high-performance WASM using CanvasKit.

## Building and Deployment

The primary game project is located entirely in the `flutter_app/` directory. 

For full build instructions, deployment commands, and troubleshooting, please refer to the [Build Instructions](build_instructions.md) guide.

### Quick Start (Local Run)

You will need a working Flutter environment. From inside the `flutter_app/` directory:

```bash
cd flutter_app
flutter run -d chrome --wasm
```

### Deployment

The game deploys to Cloudflare Pages as a static WebAssembly package. To build and deploy:

```bash
cd flutter_app
flutter build web --wasm
npx wrangler pages deploy build/web --project-name cut-throat-dom
```
