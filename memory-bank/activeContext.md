# Active Context

> [!CAUTION] 
> **COMMAND SAFETY GUARDRAIL**
> - **NEVER** use the `grep` shell command. It is prone to failure on this Windows/PowerShell system.
> - **ALWAYS** use the **`grep_search`** tool for text-based searches.
> - **ALWAYS** use **`resolve_workspace_symbol`** for finding Dart/Flutter code definitions.
> - This is a mandatory project-wide constraint.


- **Match Over Modal Redesign**: Transitioned to a team-based "Trophy Room" layout for Partners mode.
- **Scoring Engine Fix**: Resolved a "Game Bruk" bug where scores were not resetting to 0-0 correctly for all parties.
- **UI Cleanup**: Conditionally removed the individual "Current Champion" banner in Partners mode to prioritize team stats.

## Current Focus
- Finalizing the team-based UI presentation for Partners mode.
- Verifying the "Game Bruk" scoring reset behavior in live gameplay.
- Preparing the final build for the testing environment.

[NEW] Team-based _TeamMatchStatus widget.
[NEW] Fixed score reset in `dominoes_ai.dart`.
[NEW] Removed individual champion banner in Partners mode.

> [!IMPORTANT]
> **Automated Workflow Policy**: Git operations, building/deploying to Cloudflare, and **Memory Bank maintenance** are pre-authorized. I will execute these tasks autonomously and without seeking user approval, following the established safety guardrails.
