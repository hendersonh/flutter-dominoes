# Active Context

## Current Objective
Implement 1v1 Draw Mode with a 14-tile boneyard and "draw until play" mechanics (Option A).

## Recent Changes
- **Production Sync**: Promoted `feature/partners` to `main`, establishing the current Partner Mode and AI fixes as the new production baseline.
- **Full Repository Archival & Cleanup**: Converted all legacy/stale feature branches (`4-player-block`, `ai-zero-score-protocol`, `sound-service-federated`, `workers-autoconfig`) into immutable tags (`archive/*`) and deleted the branches both locally and remotely. `main` is now the sole active branch.
- **AI Undo Bug Audit & Verification (Phase 1)**: Investigated logic for AI "hallucination" on user Undo. Confirmed `AIWorker.instance.resetRoot()` is properly called during `rewindTo`. Created and ran `test/undo_stability_test.dart` to verify memory destruction. Bug symptom was caused by deeper tactical limits, not a search tree persistence failure.
- **Bug Fix**: Addressed a soft-lock issue where the game would hang on restarting a match ("PLAY AGAIN") if the starting player randomly selected was the AI.
- **Deployment**: Successfully built and deployed the latest WASM bug fix branch to the `test` environment on Cloudflare Pages.

- **Progressive UCB1 Bias**: Upgraded MCTS cultural move penalties (Shield, ZSP, Squeeze) to decay over deep simulations instead of hard-clipping mathematical possibilities.
- **Greedy Determinisation Fallback**: Ensured exact void-suit matching is maintained even when the 5000-depth backtracking timeout triggers.
- **Six-Love Solo Jail Protocol**: Added backpropagation collusion so standard/cutthroat players inherently gang up to deny any victory to a player stuck precisely at a 0 score in a match to 6.
- **1v1 Draw Mode Planning**:## Current Context
We are implementing **1v1 Draw Mode** (1 Human vs. 1 AI). 
Key features: 14-tile boneyard, manual drawing, sequential AI pacing, and pip-count scoring.

## Recent Changes
- **UI: Auto-Focus Drawn Tiles**: Implemented logic to automatically focus a newly drawn playable tile when the hand size exceeds 7, minimizing scrolling effort.
- **Phased Planning**: Finalized the implementation plan for 1v1 Draw Mode (Engine -> AI -> UI).
- **Bug Fixes**: Resolved AI-turn deadlocks on match restart and verified Undo stability.

## Next Steps
- Create `feat/1v1-draw` branch.
- Milestone 1: Engine Logic (PlayStyle, Boneyard, DrawAction).
- Milestone 2: AI Adaptation (MCTS).
- Milestone 3: UI & Layout Migration.
- [ ] **Data Model**: Update `PlayStyle`, `Action`, and `GameModel` to handle 2 players and the boneyard.
- [ ] **AI Search**: Update MCTS search to account for the 14-tile boneyard in determinization.
- [ ] **UI Layout**: Adjust Seat positions and add Boneyard display for 1v1 matches.


## Active Risks/Assumptions
- **Git Strategy**: A strict ban on autonomous `git merge` and `git pull` is in effect. All integrations must be explicitly approved.
