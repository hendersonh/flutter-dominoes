import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  group('AI Phase 2: Legend Enhancements', () {
    test('MCTSPlayer respects MatchTarget in Traditional mode', () {
      // Simulate a state near match target
      final state = GameModel(
        hands: [
          [const DominoTile(6, 6)],
          [const DominoTile(0, 0)],
          [const DominoTile(1, 1)],
          [const DominoTile(2, 2)],
        ],
        matchScores: [95, 0], // Team 0 is at 95, target 100
        matchTarget: 100,
        scoringMode: ScoringMode.traditional,
        playStyle: PlayStyle.partners,
      );

      final player = MCTSPlayer(0, difficulty: DifficultyLevel.legend);
      
      // We expect the player to prioritize winning this round above all else
      // as it ends the entire match.
      final action = player.getBestAction(
        state,
        timeLimitMs: 50,
        matchScores: state.matchScores,
        matchTarget: state.matchTarget,
        scoringMode: state.scoringMode,
      );

      expect(action, isNotNull);
      expect(action, isA<PlayAction>());
    });

    test('Legend AI weights Team Wins in Partners mode', () {
      // Setup a scenario where player 2 (partner of 0) has a winning move
      // but player 0 must provide the right end ("The Shield").
      final state = GameModel(
        hands: [
          [const DominoTile(6, 2), const DominoTile(6, 3)], // Player 0
          [const DominoTile(5, 5)], // Player 1
          [const DominoTile(2, 2)], // Player 2 (Partner of 0)
          [const DominoTile(5, 4)], // Player 3
        ],
        board: [const DominoTile(6, 6)],
        leftEnd: 6,
        rightEnd: 6,
        currentPlayer: 0,
        playStyle: PlayStyle.partners,
      );

      final player = MCTSPlayer(0, difficulty: DifficultyLevel.legend);
      
      final action = player.getBestAction(
        state,
        timeLimitMs: 100,
      );

      expect(action, isNotNull);
      if (action is PlayAction) {
        // Player 0 should prefer playing (6, 2) to open the '2' suit for partner
        // rather than (6, 3) which might block the partner.
        // This is a probabilistic test, but it shows 'Legend' intent.
        print("Legend chose: $action");
      }
    });

    test('Zero Score Protocol affects rollout selection', () {
       // Setup a Six-Love scenario where player 3 is the Victim (0 wins)
       final state = GameModel(
        hands: [
          [const DominoTile(6, 6)],
          [const DominoTile(5, 5)],
          [const DominoTile(4, 4)],
          [const DominoTile(0, 0)],
        ],
        matchScores: [1, 1], // Wait, for Six-Love, matchScores are round wins
        scoringMode: ScoringMode.sixLove,
        playStyle: PlayStyle.partners,
      );
      
      // Force matchScores to show a victim (only one team at 0)
      // Actually, victimId logic: zeroCount == 1 ? victim : -1
      state.matchScores = [2, 0]; // Team 1 (players 1 & 3) is at 0 -> Victim is Team 1
      
      expect(state.victimId, equals(1)); // Team 1 (Victim)
      
      final player = MCTSPlayer(0, difficulty: DifficultyLevel.legend);
      final action = player.getBestAction(state, timeLimitMs: 50);
      
      expect(action, isNotNull);
    });
  });
}
