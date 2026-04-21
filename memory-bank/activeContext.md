# Active Context

## Current Objective
Investigate and resolve the underlying cause of AI degradation following an Undo action in Professional difficulty.

## Recent Changes
- **Production Sync**: Promoted `feature/partners` to `main`, establishing the current Partner Mode and AI fixes as the new production baseline.
- **AI Undo Bug Audit & Verification (Phase 1)**: Investigated logic for AI "hallucination" on user Undo. Confirmed `AIWorker.instance.resetRoot()` is properly called during `rewindTo`. Created and ran `test/undo_stability_test.dart` to verify memory destruction. Bug symptom was caused by deeper tactical limits, not a search tree persistence failure.

- **Progressive UCB1 Bias**: Upgraded MCTS cultural move penalties (Shield, ZSP, Squeeze) to decay over deep simulations instead of hard-clipping mathematical possibilities.
- **Greedy Determinisation Fallback**: Ensured exact void-suit matching is maintained even when the 5000-depth backtracking timeout triggers.
- **Six-Love Solo Jail Protocol**: Added backpropagation collusion so standard/cutthroat players inherently gang up to deny any victory to a player stuck precisely at a 0 score in a match to 6.

## Next Steps
- [x] **Audit Tactical Upgrades (Phase 2)**: Audited `dominoes_ai.dart` and confirmed all Phase 2 heuristics (Solo Jail Protocol, Progressive UCB1 Bias, Partner Reward Pooling, etc.) are already fully implemented in the codebase.
- [ ] **Audit Simulation Depth**: Investigate the AI's core tactical loop, time limits, and iteration caps in `dominoes_ai.dart` for Professional mode to understand why gameplay degrades despite correct cache clearance.

## Active Risks/Assumptions
- **Git Strategy**: A strict ban on autonomous `git merge` and `git pull` is in effect. All integrations must be explicitly approved.
