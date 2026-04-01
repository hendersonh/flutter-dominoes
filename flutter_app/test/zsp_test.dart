import 'package:test/test.dart';
import '../lib/engine/dominoes_ai.dart';

void main() {
  group('Zero Score Protocol Verification', () {
    test('AI 1 (Leader) should prioritize starving Human Victim (P0) at 0 wins', () {
      // 1. Setup Match State: P0=0, P1=5, P2=1, P3=1
      final match = MatchModel(mode: ScoringMode.sixLove);
      match.scores = [0, 5, 1, 1];
      
      // 2. Setup Game State: Human (P0) is VOID in suite 4.
      // Board currently ends in [3|4].
      final p0Hand = [const DominoTile(0, 0), const DominoTile(1, 1)];
      final p1Hand = [const DominoTile(4, 5), const DominoTile(3, 2)];
      
      final state = GameModel(
        hands: [p0Hand, p1Hand, [const DominoTile(2, 2)], [const DominoTile(5, 5)]],
        currentPlayer: 1, // AI 1's turn
        scoringMode: ScoringMode.sixLove,
        matchScores: [0, 5, 1, 1],
        leftEnd: 3,
        rightEnd: 4,
        board: [const DominoTile(3, 4)],
        passedSuits: [
          {4}, // P0 is void in 4
          {}, {}, {}
        ],
      );

      final ai = MCTSPlayer(1, difficulty: DifficultyLevel.legend);
      
      // AI 1 has two moves: 
      // A: Play (4, 5) -> Board ends in (3, 5). P0 can play (P0 has 0, 1).
      // B: Play (3, 2) -> Board ends in (2, 4). P0 is still void in 4! (Maintaining the Gap)

      // In a normal game, AI might pick (4, 5) or (3, 2) based on pip count.
      // Under ZSP, it should STRONGLY prefer (3, 2) because it maintains the 4-void.

      final action = ai.getBestAction(state, timeLimitMs: 3000);
      print("AI Resulting Action: $action");

      expect(action, isA<PlayAction>());
      final play = action as PlayAction;
      expect(play.tile, const DominoTile(3, 2), reason: "AI should choose to maintain the suite-4 void for the victim.");
    });

    test('Victim AI (P3 at 0 wins) should NOT use ZSP on itself', () {
      final state = GameModel(
        hands: [[], [], [], [const DominoTile(4, 4)]],
        currentPlayer: 3, // AI 3 is the Victim
        scoringMode: ScoringMode.sixLove,
        matchScores: [1, 1, 1, 0], // AI 3 is at 0
        leftEnd: 4,
        rightEnd: 4,
        board: [const DominoTile(4, 0)],
      );

      final ai = MCTSPlayer(3, difficulty: DifficultyLevel.legend);
      final action = ai.getBestAction(state, timeLimitMs: 500);
      
      // AI 3 should just try to win (it only has one move anyway here, but it shouldn't apply ZSP penalties to its own win).
      expect(action, isA<PlayAction>());
    });
  });
}
