# Active Context

## Current Objective
Monitor the behavior of the newly calibrated MCTS AI engine in testing. The primary AI flaws involving ZSP starvation, opponent void shielding, and UCB1 exploration collapse have been resolved.

## Recent Changes
- **MCTS Perspective Fix**: Corrected the `getBestChild` logic to use the acting player's perspective, stopping the AI from accidentally protecting opponents' void suits.
- **Reward Normalization**: Scaled ISMCTS backpropagation rewards from extreme values (-100.0) to a normalized [0, 1] range to preserve UCB1 exploration integrity.
- **Deployment**: Verified the test suite passed perfectly and deployed the updated AI to the `test` branch (version 1776613897273).

## Next Steps
- [ ] **Feedback & Review**: Await user feedback on the `Legend` difficulty's new gameplay behavior on the testing branch.
- [ ] **Deployment**: Target production branch once the new AI mechanics are proven stable.

## Active Risks/Assumptions
- **Git Strategy**: A strict ban on autonomous `git merge` and `git pull` is in effect. All integrations must be explicitly approved.
