# Active Context

## Current Objective
Optimize the MCTS AI engine by correcting fundamental algorithmic flaws in perspective-taking and reward scaling.

## Recent Changes
- **MCTS Perspective Fix**: Corrected the `getBestChild` logic to use the acting player's perspective, stopping the AI from accidentally protecting opponents' void suits.
- **Reward Normalization**: Scaled ISMCTS backpropagation rewards from extreme values (-100.0) to a normalized [0, 1] range to preserve UCB1 exploration integrity.
- **Verification Suite**: Added `mcts_perspective_test.dart` and verified against `repro_zsp_bug_test.dart`.

## Next Steps
- [ ] **Heuristic Calibration**: Tune the magic-number weights (Shield/Squeeze) in `getBestChild` to ensure they don't overpower the Monte Carlo rollout evidence.
- [ ] **Autonomous A/B Testing**: Run a 1000-match simulation to quantify the win-rate improvement of the corrected engine.

## Active Risks/Assumptions
- **Exploration Parameters**: Normalizing rewards might require a slight adjustment to the `explorationParam` (currently 1.414) if the search becomes too wide.
- **Git Strategy**: A strict ban on autonomous `git merge` and `git pull` is in effect. All integrations must be explicitly approved.
- **Assumption**: The `[0, 1]` reward range is sufficient for both Traditional and Six-Love scoring modes.
