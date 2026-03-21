import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  group('MCTSPlayer Tests', () {
    test('getBestAction returns a valid action', () async {
      // Setup a simple game state
      List<DominoTile> humanHand = [DominoTile(0, 1), DominoTile(1, 1)];
      List<DominoTile> aiHand = [DominoTile(2, 2), DominoTile(2, 3)];
      List<DominoTile> boneyard = [DominoTile(4, 4)];
      
      GameModel game = GameModel(
        hands: [humanHand, aiHand],
        boneyard: boneyard,
        currentPlayer: 1, // AI turn
        leftEnd: 2,
        rightEnd: 2,
      );

      MCTSPlayer ai = MCTSPlayer(1);
      Action action = await ai.getBestAction(game, timeLimitMs: 100);
      
      expect(action, isNotNull);
      expect(action, isA<PlayAction>());
      final play = action as PlayAction;
      expect(play.tile.contains(2), isTrue);
    });

    test('getBestAction respects time limit', () async {
      List<DominoTile> humanHand = List.generate(7, (i) => DominoTile(i, i));
      List<DominoTile> aiHand = List.generate(7, (i) => DominoTile(i, (i + 1) % 7));
      List<DominoTile> boneyard = [];
      
      GameModel game = GameModel(
        hands: [humanHand, aiHand],
        boneyard: boneyard,
        currentPlayer: 1,
        leftEnd: 0,
        rightEnd: 0,
      );

      MCTSPlayer ai = MCTSPlayer(1);
      Stopwatch sw = Stopwatch()..start();
      await ai.getBestAction(game, timeLimitMs: 200);
      sw.stop();
      
      // Allow some overhead, but it should be close to 200ms
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(200));
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('getBestAction handles empty boneyard and no moves', () async {
       List<DominoTile> humanHand = [DominoTile(5, 5)];
       List<DominoTile> aiHand = [DominoTile(6, 6)];
       List<DominoTile> boneyard = [];
       
       GameModel game = GameModel(
         hands: [humanHand, aiHand],
         boneyard: boneyard,
         currentPlayer: 1,
         leftEnd: 1,
         rightEnd: 1,
       );

       MCTSPlayer ai = MCTSPlayer(1);
       Action action = await ai.getBestAction(game, timeLimitMs: 50);
       
       expect(action, isA<PassAction>());
    });
  });
}
