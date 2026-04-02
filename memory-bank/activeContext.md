# Active Context

> [!CAUTION] 
> **COMMAND SAFETY GUARDRAIL**
> - **NEVER** use the `grep` shell command. It is prone to failure on this Windows/PowerShell system.
> - **ALWAYS** use the **`grep_search`** tool for text-based searches.
> - **ALWAYS** use **`resolve_workspace_symbol`** for finding Dart/Flutter code definitions.
> - This is a mandatory project-wide constraint.


- [x] **Match Flow Optimization**: Refined the post-match game flow to eliminate the mandatory return to "Match Setup" after every match. Players can now choose **"PLAY AGAIN"** to immediately start a new match with the same rules or **"CHANGE RULES"** to adjust settings.
- [x] **GameController Refactoring**: Updated `resetMatch` and `restartGame` with a `goToSetup` flag to optionally skip the configuration modal while preserving `targetScore` and `mode`.
- [x] **Post-Match UI**: Updated the Game Over modal with specialized buttons for quick restarts and rule changes, improving the rhythm of long-playing sessions.
- [x] **Production Rollout**: Built and deployed version `1774880431206` to Cloudflare Pages (`cut-throat-dom`).
- [x] **Repository Cleanup**: Cleaned up the root directory by permanently removing the unused Google AI Studio Vite/React template (`src`, `index.html`, `vite.config.ts`, `package.json`, etc.) and the early prototype `dominoes_ai.dart` script. Rewrote root `README.md` to properly describe the Flutter WASM project.
- [x] **Agentic Guardrails**: Removed redundant MB update steps from the `/git` workflow due to the active global user rule that now mandates pre-commit Memory Bank synchronization.
- [x] **User Guide Revision**: Expanded `guide.html` to clearly define the `#/#` HUD metrics (Hand vs Score), rank-to-difficulty correlation (A/B/C/D), and provided a clear example for interpreting lifetime performance stats (e.g., `A*3 B*2`).
- [x] **Testing Environment**: Established a dedicated secondary deployment instance on Cloudflare Pages using the `--branch test` flag. Created a new `/deploy-test` workflow to facilitate rapid, non-disruptive experimentation with UI and logic changes.
- [x] **Git Repository Promotion**: Successfully promoted the `.git` directory from `flutter_app/` to the project root. Consolidated `.gitignore` to track all project documentation, MB assets, and agent workflows in a single repository.
- [x] **Test Deployment**: Repaired structural errors in `lib/main.dart` and resolved analysis blockers. Successfully built and deployed version `17751631477198` to the Cloudflare testing environment (`test.cut-throat-dom.pages.dev`).


- [x] **Zero Score Protocol (ZSP)**: Implemented collaborative AI starvation tactics for Jamaican Six-Love mode.
  - [x] **The Squeeze**: Added MCTS selection penalties for moves that open known victim voids.
  - [x] **Maintaining the Gap**: Integrated rollout biases to focus simulations on starvation outcomes.
  - [x] **Backpropagation Hierarchy**: Refined MCTS rewards to prioritize victim-starvation over individual wins during ZSP activation.
  - [x] **Deterministic Locking**: Added suite-counting logic to `GameModel` for hard-lock detection.
  - [x] **Verification**: Successfully validated coalition behavior in 5-1-1-0 simulation-based unit tests.
  - [x] **High-Precision Verification**: Confirmed protocol stability at **200,000 iterations** for Legend difficulty.
  - [x] **Test Deployment**: Built and pushed versioned ZSP implementation to `test.cut-throat-dom.pages.dev`.
  - [x] **Integration**: Successfully merged `feature/ai-zero-score-protocol` into `feature/4-player-block`.

- [x] **Partners Feature**: Successfully implemented the 2v2 partner-based mode.
  - [x] **Research**: Analyzed IS-MCTS and scoring logic for team compatibility.
  - [x] **Planning**: Created and verified the `implementation_plan.md` for 2v2 integration.
  - [x] **Implementation**: Integrated team-based HUD, "Bruk" liquidation logic, and partner-aware MCTS rewards.
  - [x] **Verification**: Validated 2v2 gameplay and Six-Love rules in end-to-end simulations.
  - [x] **Maintenance**: UI cleanup (removed "Team #" from board HUD), finalized game mode terminology, and added "PlayStyle" label to HUD header.
- [x] **Mobile UI & Terminology Optimization**: Finalized the interface for small devices (Pixel 7).
  - [x] **Terminology**: Replaced all "CUT-THROAT" references with "SOLO" in the HUD and Match Setup.
  - [x] **AI Language**: Updated difficulty descriptions to be player-friendly (removed "MCTS", added "Tactical Search").
  - [x] **Match Setup Layout**: Reduced margins (12px -> 8px) and padding (16px -> 10px) in `_MatchSetupView` to prevent text-cutoff.
  - [x] **UI Refinement**: Reduced `SegmentedButton` padding and refined `_ModeDescription` labels ("Target Rules").
  - [x] **Verification**: Manually verified layout fit for 380px-412px viewports.

> [!IMPORTANT]
> **Automated Workflow Policy**: Git operations, building/deploying to Cloudflare, and **Memory Bank maintenance** are pre-authorized. I will execute these tasks autonomously and without seeking user approval, following the established safety guardrails.
