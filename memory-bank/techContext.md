# Technical Context

## Tech Stack
- **Framework**: Flutter
- **Target Platforms**: Web (WASM), Android, iOS.
- **Environment**: Windows development machine.

## Constraints & Dependencies
- **WASM Support**: Must maintain compatibility with Flutter's WASM build. See [wasmResearch.md](file:///e:/antigravity/dominoes/memory-bank/wasmResearch.md) for detailed findings.
- **IS-MCTS AI**: Asynchronous AI calculation via `Isolate.run` to prevent main thread blocking, specifically optimized for Skwasm compatibility.
- **Federated Service Pattern**: Primary mechanism for cross-platform differentiation without custom environment variables.
- **Local Persistence**: `SharedPreferences` used for persisting match data (Six-Love), lifetime statistics, and AI difficulty settings.
- **Web Audio Policy**: Browser autoplay restrictions require an explicit `AudioContext.resume()` call triggered by a user gesture. This is managed via a dedicated UI overlay and platform-specific `SoundService` logic.
- **Performance**: High priority on smooth animations and UI responsiveness.
- **Storage**: Project technical files and state are stored in `e:/anitigravity/dominoes/flutter_app`.
- **Memory Bank**: Per-project memory is stored in `E:/antigravity/dominoes/memory-bank/`.
- **Automated Workflow**: I (Antigravity) am authorized to use any non-destructive PowerShell/terminal command (Git, Flutter, Build, Deploy) and **autonomously maintain the Memory Bank**. These updates are mandatory background tasks and do not require user approval before modification.

## Terminal & Shell
- **Primary Shell**: PowerShell (`pwsh`) is the ONLY authorized shell for this project.
- **Rule**: ALWAYS use PowerShell-native cmdlets or provided MCP tools.
- **Restriction**: **NEVER use Unix-style commands** (e.g., `grep`, `find`, `ls -a`).
- **Authorized Search Methods**:
    1. **`grep_search` tool**: Use for finding text strings, logs, or UI content.
    2. **`resolve_workspace_symbol` tool**: Use for finding classes, methods, and variables.
    3. **`list_dir` / `view_file`**: Use for structural exploration and reading.

## Key UI Components 
- **_EdgeScore**: Board-level HUD component displaying player stats, pulsing active turn indicators, and the **Lifetime Leader / Six-Love Champion crown**.
- **ReviewBoardOverlay & _MiniHand**: Post-round summary screen featuring high-legibility unplayed tiles and consistent leader branding.
- **_MatchSetupView**: Mobile-optimized modal for match configuration and target score selection (100, 150, 200). Now optionally skippable via the "PLAY AGAIN" flow.
- **GameController**: Centralized state management using `ChangeNotifier` and `SharedPreferences` for persistence. Updated `resetMatch` and `restartGame` with `goToSetup` logic for continuous sessions.

## Deployment
- **Production URL**: [https://hendy-dominoes.pages.dev](https://hendy-dominoes.pages.dev)
- **Legacy URL**: [https://cut-throat-dom.pages.dev](https://cut-throat-dom.pages.dev) (kept for migration)
- **Testing URL**: [https://test.cut-throat-dom.pages.dev](https://test.cut-throat-dom.pages.dev)
