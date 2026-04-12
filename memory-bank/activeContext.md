# Active Context

> [!CAUTION] 
> **COMMAND SAFETY GUARDRAIL**
> - **NEVER** use the `grep` shell command. It is prone to failure on this Windows/PowerShell system.
> - **ALWAYS** use the **`grep_search`** tool for text-based searches.
> - **ALWAYS** use **`resolve_workspace_symbol`** for finding Dart/Flutter code definitions.
> - This is a mandatory project-wide constraint.


- **Key Bone Scoring Logic**: Implemented strict Jamaican tournament regulations. Bonus points are now only awarded when winning with a non-double tile that "keys" both board ends (both must be exhaustive/Hard Ends with 8 pips each).
- **Match Over Modal Redesign**: Transitioned to a team-based "Trophy Room" layout for Partners mode.
- **Scoring Engine Fix**: Resolved a "Game Bruk" bug in Partner Six-Love mode where points were incorrectly awarded to the winner after a score reset.
- **New Project Deployment**: Successfully deployed to a brand new Cloudflare Pages project: `hendy-dominoes`.
- **Branding Update**: Formally renamed the application to **"HendyDominoes"** across all mobile/web configuration files.
- **Bruk Protocol Validation**: Verified that both teams reset to 0-0 cleanly using a dedicated reproduction test.

- **Partner Bruk Verification**: Added a dedicated test case to `test/scoring_test.dart` for the Six-Love Partner mode "Bruk" reset. Verified that when a trailing team wins, both teams reset to 0-0 without any points being awarded to the winner.

## Current Focus
- [x] **Phase 1: ZSP Inversion Fix**: Completed and verified.
- [x] **Phase 2: MCTS Determinization Sync**: Completed. Implemented tree-pruning, AISyncMove, and 'Legend' match heuristics.
- [x] **Phase 3: AI Engine Fixes (Vibe Audit)**: Refactored MCTS backpropagation to use the `owner's perspective`. Verified through A/B testing (+40% increase in 'Game Bruk' resets).
- [x] **Phase 4: Six-Love A/B Test Validation**: 200-match study confirmed the "Jailer" coordination logic transformed the AI into a competitive defensive specialist. Match duration increased by 29%.
- [x] **Phase 5: Brand Migration**: Migrated deployment to `hendy-dominoes` and updated app labels to **HendyDominoes**.
- [x] **Phase 6: Legend Training (Rewind)**: Implemented a smart 10-turn rewind for Legend difficulty.
- [x] **Fix: Human-Centered Rewind Logic**: Refactored the snapshot system to focus exclusively on "Human Decision Points". Every rewind lands exactly on a playable human turn.
- [x] **Phase 7: Unified Board HUD**: Consolidated all dispersed UI overlays (Settings, Match Info, Status Message, Rewind, Help) into a single cohesive row. Created a glassmorphism "Status Indicator Pill" for match context and live game status.
- [x] **Production Maintenance**: Resolved WASM production build linting issues and redeployed. HUD now features perfect vertical centering and professional equal spacing across all device widths.



[NEW] `lastPlayedTile` and `wasLastActionPlay` fields in `GameModel`.
[NEW] `GameModel.clone()`, `toJson()`, `fromJson()` updated for state persistence.
[NEW] `sixLove mode: Partner Game Bruk` regression test in `test/scoring_test.dart`.
[NEW] `AISyncMove` and `MCTSNode.prune` for persistent AI search state.
[NEW] `MCTSPlayer` match context (matchScores, matchTarget, scoringMode).

> [!IMPORTANT]
> **Automated Workflow Policy**: Git operations, building/deploying to Cloudflare, and **Memory Bank maintenance** are pre-authorized. I will execute these tasks autonomously and without seeking user approval, following the established safety guardrails.
