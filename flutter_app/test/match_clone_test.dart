import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  group('MatchModel Clone Tests', () {
    test('clone() creates an identical but independent deep copy', () {
      final original = MatchModel(
        targetScore: 150,
        mode: ScoringMode.sixLove,
        playStyle: PlayStyle.partners,
      );
      
      original.scores[0] = 5;
      original.roundNumber = 3;
      original.pendingBonus = 10;
      original.gameBrukOccurred = true;

      final clone = original.clone();

      // Verify identical values
      expect(clone.targetScore, 150);
      expect(clone.mode, ScoringMode.sixLove);
      expect(clone.playStyle, PlayStyle.partners);
      expect(clone.scores[0], 5);
      expect(clone.roundNumber, 3);
      expect(clone.pendingBonus, 10);
      expect(clone.gameBrukOccurred, true);

      // Verify independence (Mutating clone doesn't affect original)
      clone.scores[0] = 10;
      clone.roundNumber = 5;
      
      expect(original.scores[0], 5);
      expect(original.roundNumber, 3);
    });

    test('state restoration test', () {
      final original = MatchModel(targetScore: 100);
      original.scores[0] = 50;
      
      final snapshot = original.clone();
      
      // Mutate original
      original.scores[0] = 75;
      original.roundNumber = 2;
      
      // "Restore" from snapshot
      final restored = snapshot.clone();
      expect(restored.scores[0], 50);
      expect(restored.roundNumber, 1);
    });

    test('clone() handles currentRound deep copy', () {
      final original = MatchModel();
      original.currentRound = GameModel(
        hands: [[], [], [], []],
        currentPlayer: 1,
      );

      final clone = original.clone();
      
      expect(clone.currentRound, isNotNull);
      expect(clone.currentRound, isNot(same(original.currentRound)));
      expect(clone.currentRound!.currentPlayer, 1);
      expect(clone.currentRound!.hands.length, 4);
    });
  });
}
