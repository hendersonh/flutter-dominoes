# System Patterns

## Architecture Overview
- **Core**: Flutter/Dart.
- **State Management**: Primary game logic is encapsulated in `lib/game_logic.dart` (extracted from `main.dart`).
- **UI Components**: 
    - `_MatchSetupView`: Initial configuration screen for scoring modes (100 pts vs Six-Love).
    - `_PlayerBadge`: Handles player info, including the formatted `tiles/streak` display.
    - `Overlay HUD`: Floating HUD for turn status and match controls inside the board `Stack`.
    - `Board`: Manages the placement of tiles with snaking layout logic. Reactive repositioning for HUD elements via `onLayoutCalculated` callback.
    - `Hand`: Displays the current player's available tiles.

## Patterns
- **Symmetry**: Player and AI avatars are mirrored in the UI for a premium feel.
- **Async AI**: AI turns are handled in background workers/isolates using `Isolate.run`. This is critical for WASM (Skwasm) to prevent `memory access out of bounds` traps during UI transitions.
- **WASM Optimization**:
    - **CanvasKit Renderer**: Primary renderer for web stability and feature parity (blurs, gradients).
    - **Background Offloading**: MCTS is isolated from the main thread's memory heap via `Isolate.run`.
    - **Hardened Headers**: COOP/COEP (`require-corp`) enabled for reliable worker/shared memory support.
- **CLI Simulation Pattern**: Use `bin/ai_simulator.dart` with `package:args` to run high-speed MCTS matches in a headless Dart environment. This enables statistical win-rate validation (e.g., Rookie vs. Pro) without UI overhead.
- **Pure Dart Engine Pattern**: The AI core (`dominoes_ai.dart`) is decoupled from `package:flutter`. It uses `bool.fromEnvironment('dart.library.js_util')` for web detection, allowing it to run in both Flutter Web and native CLI isolates.
- **AI Difficulty Pattern**: Implemented a multi-tier IS-MCTS strategy system (`DifficultyLevel`). 
    - **Rookie**: Designed for beginners. Uses a 50% random move chance, a strict **15 iteration cap**, and **0% history awareness** (forgetting suites opponents have passed on).
    - **Casual**: Balanced for recreational play. Uses a 500ms time limit, **100 iteration cap**, and **50% history awareness**.
    - **Professional**: Standard expert AI. Uses a 1000ms time limit, **500 iteration cap**, and full history awareness.
    - **Legend**: Elite tactical AI. Uses a **3500ms** (3.5s) time limit, no iteration cap, and specialized reward functions for Six-Love (anti-leader coalition) and 100-Point (pip efficiency) modes.
- **Global Champion Pattern**: Tracks metadata (like Six-Love "Dish Outs") across all players globally. The player with the highest score is identified as the current leader and receives unique UI styling (Crown 👑) to drive competitiveness. This data is persisted via `SharedPreferences`.
- **Federated Service Pattern**: Used for platform-agnostic sound management (`SoundService`).
- **Premium UI Foundation**: Centrally managed ivory textures and axis-aware drawing in `_PipsPainter`.
- **Reactive HUD Repositioning Pattern**: The `GameScreen` listens to `SnakingBoard` layout events to determine where tiles are physically located. It then calculates minimal vertical offsets for HUD elements to maintain 100% visibility without manual scaling.
- **Review Board Overlay Pattern**: A 15-second post-round observation phase that allows players to inspect the final board state and opponents' unplayed tiles.
- **UI Z-Index Management**: Critical UI overlays (Settings, Reset, Restart) are positioned at the end of the `Stack` to ensure they are the top-most elements for hit-testing, preventing the game board from blocking interaction.
- **Audio Resumption Pattern**: Employs a `RESUME TO PLAY` overlay triggered by `WidgetsBindingObserver` (lifecycle changes). This captures the requisite user gesture to invoke `AudioContext.resume()` on web/WASM platforms, ensuring audio continuity when returning from the background.
- **Dynamic Asset Loading Pattern**: Help manual content is stored as external `.md` files in `assets/`. The game uses `rootBundle.loadString()` to fetch these at runtime, allowing documentation updates without recompiling logic.
- **Round Result Messaging Pattern**: Replaces the generic "AI Thinking" status with a post-round announcement: `"<Name> gets +<Points>"`. This matches the Jamaican cut-throat style and prevents stale UI states.
- **Scoring Rule Pattern (Strict Key Bone)**: Implemented in `MatchModel.recordRoundResult`. It uses `pipsOnBoard` to verify that both board ends are "Hard Ends" before awarding a 2-point bonus. This ensures engine integrity against loose state interpretation.
- **1v1 Draw Mode Pattern**: Utilizes `PlayStyle.draw1v1` to trigger a 2-player match state with a **14-tile Boneyard**. Includes "Draw Until Play" mechanics and AI adaptation for hidden tiles.
- **2-Player Layout Pattern**: Conditional logic in the UI repositions elements for 1v1 matches, ensuring a clean visual experience by hiding partner-specific components and centering player seats.

## Deployment Protocol

To prevent landing preview code on the production site (or vice versa), the following protocol is mandatory:

### Environment Definitions
- **Production**: Uses the `main` branch. Main domain: `https://hendy-dominoes.pages.dev`.
- **Test/Staging**: Uses the `test` branch. Test domain: `https://test.cut-throat-dom.pages.dev`.

### The "Ask First" Rule
- If a deployment is requested without an explicit environment (e.g., "deploy the fix"), the agent **must** ask for clarification: **"Deploy to Production (main) or Test (test)?"**
- For automated workflows (`deploy.md`, `deploy-test.md`), the first step is always a manual verification check.

## Automation & Workflows
To streamline repetitive tasks, we use the `.agents/workflows/` directory for automated command sequences, governed by the global **`command-safety`** skill.

### Global Command Safety Policy
- **Primary Authority**: [command-safety skill](file:///C:/Users/hende/.gemini/antigravity/skills/command-safety/SKILL.md)
- **Policy**: All non-destructive PowerShell/terminal commands (Git, Flutter, Build, Deploy) are pre-authorized for autonomous execution (`SafeToAutoRun: true`).
- **Git & Branch Integrity (CRITICAL)**:
    - **No Autonomous Merges**: The agent is strictly forbidden from executing `git merge` or `git pull` as an autonomous action.
    - **Approval Mandatory**: Any integration between branches MUST be part of an `implementation_plan.md` that has received explicit user approval.
    - **No "Suggestive" Merges**: The agent should not suggest a merge as a "small fix" without a full context review of the branch being merged.
- **Shell Requirement**: **ALWAYS use PowerShell (pwsh)** for directory navigation.
- **Search Rule**: **NEVER use the `grep` command.** It is prone to failure in this environment.
- **Mandatory Search Tools**:
    1. **`grep_search`**: Use for text/string searches across files.
    2. **`resolve_workspace_symbol`**: Use for code definition lookups.
- **Memory Bank Maintenance**: Updating the project documentation (Progress, Context, Patterns) is a **Mandatory Background Task**. I will execute these updates autonomously and without seeking user approval for each modification, provided the changes accurately reflect the session's progress.
- **Restriction**: Destructive operations (`rm`, `del`, `Remove-Item`) are **Hard-Locked** and require manual user approval.
