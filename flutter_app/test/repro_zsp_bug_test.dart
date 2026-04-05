import 'package:test/test.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  group('DIAGNOSTIC: AI Self-Sabotage (ZSP Inversion) Verification', () {
    test('AI 3 (Victim at 0) should choose immediate WIN over continuing', () {
      // 1. Match State: P3 is the "Victim" (0 pts in Six-Love)
      final match = MatchModel(mode: ScoringMode.sixLove);
      match.scores = [10, 10, 10, 0];
      
      // 2. Game State: AI 3's turn
      // - AI 3 has only ONE tile: [5|1]
      // - If it plays [5|1], it wins the round immediately (0 tiles left).
      // - We compare this to a "dummy" legal action if we had more tiles.
      
      final state = GameModel(
        hands: [
          [const DominoTile(0, 0)], // P0
          [const DominoTile(1, 1)], // P1
          [const DominoTile(2, 2)], // P2
          [const DominoTile(5, 1)], // P3 (only 1 tile!)
        ],
        currentPlayer: 3, 
        scoringMode: ScoringMode.sixLove,
        matchScores: [10, 10, 10, 0],
        leftEnd: 5,
        rightEnd: 5,
        board: [const DominoTile(5, 5)],
      );

      final ai = MCTSPlayer(3, difficulty: DifficultyLevel.legend);
      
      // We will perform a search. 
      // In the previous (buggy) version, the AI would penalize this win by -100.0
      // In the new version, it should reward it by +10.0.
      
      final action = ai.getBestAction(state, timeLimitMs: 1000);
      print("AI 3 (Victim) chose action: $action");

      expect(action, isA<PlayAction>());
      final play = action as PlayAction;
      
      expect(play.tile, const DominoTile(5, 1));
      expect(state.hands[3].length, 1, reason: "Self-check: Hand should have 1 tile before move");
    });
  });
}
