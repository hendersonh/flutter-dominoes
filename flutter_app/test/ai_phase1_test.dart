import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  group('Phase 1: Tree Pruning & State Caching Tests', () {
    test('MCTSNode.prune correctly preserves visited subtrees', () {
      final node = MCTSNode(player: 0);
      final tile = const DominoTile(6, 6);
      final action = PlayAction(tile, 'left', isFirstMove: true);
      
      // Simulate some visits
      node.visits = 100;
      node.wins = 50.0;
      
      final child = MCTSNode(player: 1, parent: node);
      child.visits = 20;
      child.wins = 10.0;
      node.children[action] = child;
      
      // Prune to that action
      final newRoot = node.prune(action, 1);
      
      expect(identical(newRoot, child), isTrue, reason: 'Pruned node should be the identical child instance');
      expect(newRoot.parent, isNull);
      expect(newRoot.visits, equals(20));
      expect(newRoot.wins, equals(10.0));
    });

    test('MCTSNode.prune returns fresh node if action not found', () {
      final node = MCTSNode(player: 0);
      final action = PassAction();
      
      final newRoot = node.prune(action, 1);
      
      expect(newRoot, isNot(equals(node)));
      expect(newRoot.visits, equals(0));
      expect(newRoot.player, equals(1));
    });

    test('MCTSPlayer uses existingRoot to persist search knowledge', () {
      final hands = [
        [const DominoTile(6, 6), const DominoTile(6, 5)],
        [const DominoTile(1, 1)],
        [const DominoTile(2, 2)],
        [const DominoTile(3, 3)],
      ];
      final state = GameModel(hands: hands, currentPlayer: 0);
      
      final player = MCTSPlayer(0, difficulty: DifficultyLevel.professional);
      
      // 1. Initial think
      final action1 = player.getBestAction(state, timeLimitMs: 200);
      final root1 = player.lastRoot!;
      expect(root1.visits, greaterThanOrEqualTo(50));
      final child1 = root1.children[action1]!;
      final childVisits = child1.visits;
      
      // 2. Simulate the move happening and state-syncing
      // In a real app, AIWorker would do this. Here we do it manually.
      final nextState = state.clone();
      // (Mock applying the action)
      nextState.leftEnd = 6;
      nextState.rightEnd = 6;
      nextState.hands[0].remove( (action1 as PlayAction).tile );
      nextState.currentPlayer = 1;
      
      // Prune root1 to action1
      final root2 = root1.prune(action1, 1);
      expect(root2.visits, equals(childVisits));
      
      // 3. Next think (e.g. after opponent moved)
      // For simplicity, let's say opponent passed
      final opponentAction = PassAction();
      /* final rootAfterOpponent = */ root2.prune(opponentAction, 2);
      
      // If opponent passed, and we didn't have a node for it, rootAfterOpponent visits will be 0
      // But if we did, it should be > 0.
      
      // The key test: calling getBestAction with root2 should start with visits > 0
      /* final action2 = */ player.getBestAction(nextState, timeLimitMs: 100, existingRoot: root2);
      expect(player.lastRoot!.visits, greaterThanOrEqualTo(childVisits + 10));
    });
  });
}
