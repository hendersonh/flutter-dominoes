# Active Context

> [!CAUTION] 
> **COMMAND SAFETY GUARDRAIL**
> - **NEVER** use the `grep` shell command. It is prone to failure on this Windows/PowerShell system.
> - **ALWAYS** use the **`grep_search`** tool for text-based searches.
> - **ALWAYS** use **`resolve_workspace_symbol`** for finding Dart/Flutter code definitions.
> - This is a mandatory project-wide constraint.


- **Key Bone Scoring Logic**: Implemented strict Jamaican tournament regulations. Bonus points are now only awarded when winning with a non-double tile that "keys" both board ends (both must be exhaustive/Hard Ends with 8 pips each).
- **Match Over Modal Redesign**: Transitioned to a team-based "Trophy Room" layout for Partners mode.
- **Scoring Engine Fix**: Resolved a "Game Bruk" bug where scores were not resetting to 0-0 correctly for all parties.

## Current Focus
- Verification of the **Strict Key Bone** scoring rules in `MatchModel.recordRoundResult`.
- Regression testing for Six-Love mode (including successful dual-ended exhaustion verification of the user's screenshot).
- Completed integration of the last played tile state in `GameModel`.

[NEW] `lastPlayedTile` and `wasLastActionPlay` fields in `GameModel`.
[NEW] `GameModel.clone()`, `toJson()`, `fromJson()` updated for state persistence.
[NEW] Comprehensive unit tests in `test/scoring_test.dart`.

> [!IMPORTANT]
> **Automated Workflow Policy**: Git operations, building/deploying to Cloudflare, and **Memory Bank maintenance** are pre-authorized. I will execute these tasks autonomously and without seeking user approval, following the established safety guardrails.
