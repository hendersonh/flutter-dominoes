# Product Context: HendyDominoes

## The "Why"
This project is a high-quality, interactive Dominoes game built with Flutter. The goal is to provide a premium, smooth game experience that works seamlessly across Web (WASM) and Android.

## Core Features
- Interactive board with drag-and-drop mechanics.
- **AI Difficulty System**: 4 levels (Rookie, Casual, Professional, Legend) for all skill levels.
- AI opponent with search-based strategy (IS-MCTS).
- Match Setup Screen: Pre-game configuration for scoring modes.
- Real-time scoring and round management.
- Symmetrical UI layout for player and AI badges with reactive positioning.
- **Six-Love Championship**: Thematic stats tracking (Dishes, Crown) to drive long-term engagement.

## Game Rules
- **Variant**: Cut-Throat / Draw Dominoes.
- **Scoring Modes**:
    - **100 Points**: Standard accumulation match to 100 points.
    - **Six-Love**: Traditional Jamaican rules. First to 6 rounds wins.
    - **Key Bone**: A 2-point bonus awarded in Six-Love mode when the winning tile is a non-double that matches both open board ends, and both those ends are "Hard Ends" (all 7 other tiles of that suit played on the board).
    - **Game Bruk**: In Six-Love mode, scores only reset to 0-0 if *every* player has won at least one round.
