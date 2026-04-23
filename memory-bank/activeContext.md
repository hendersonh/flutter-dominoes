# Active Context

## Current Objective
- Finalize the "Ghost Player" fix and Match Modal overhaul for 1v1 Draw Mode.
- [RECOVERY POINT] Last stable commit: `d39b6bcead562de36973e9dab23e2f975682bb8f` (Verified as of 2026-04-23)

## Recent Changes
- [x] **Feature: 1v1 Draw Mode**: Successfully implemented 2-player support with boneyard and draw mechanics.
- [x] **Safety Check**: Stored last stable commit `d39b6bcead562de36973e9dab23e2f975682bb8f` before ghost player fix and modal refactor.
- **UI: 1v1 Layout Optimization**: Verified responsive layout switches for 1v1 mode, ensuring seat positions and scores are correctly aligned for two players.
- **UI: Auto-Focus Drawn Tiles**: Implemented logic to automatically focus a newly drawn playable tile when the hand size exceeds 7, minimizing scrolling effort.
- **Production Sync**: Promoted `feature/partners` to `main`, establishing the current Partner Mode and AI fixes as the new production baseline.
- **Full Repository Archival & Cleanup**: Converted all legacy/stale feature branches (`4-player-block`, `ai-zero-score-protocol`, `sound-service-federated`, `workers-autoconfig`) into immutable tags (`archive/*`) and deleted the branches both locally and remotely. `main` is now the sole active branch.
- **AI Undo Bug Audit & Verification (Phase 1)**: Investigated logic for AI "hallucination" on user Undo. Confirmed `AIWorker.instance.resetRoot()` is properly called during `rewindTo`. Created and ran `test/undo_stability_test.dart` to verify memory destruction. Bug symptom was caused by deeper tactical limits, not a search tree persistence failure.
- **Bug Fix**: Addressed a soft-lock issue where the game would hang on restarting a match ("PLAY AGAIN") if the starting player randomly selected was the AI.
- **Deployment**: Successfully built and deployed the latest WASM bug fix branch to the `test` environment on Cloudflare Pages.

## Next Steps
- [ ] **Final QA**: Perform a complete manual playthrough of a 1v1 Draw match to verify edge cases (boneyard exhaustion, final tally).
- [ ] **Release**: Build and deploy the finalized version with 1v1 Draw Mode to the production environment.
- [ ] **Documentation**: Ensure all user guides and help files reflect the new 1v1 Draw mechanics.

## Active Risks/Assumptions
- **Git Strategy**: A strict ban on autonomous `git merge` and `git pull` is in effect. All integrations must be explicitly approved.
