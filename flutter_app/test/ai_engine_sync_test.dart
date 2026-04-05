import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  group('AI MCTS Synchronization (Phase 1)', () {
    test('MCTSNode.prune correctly shifts root to child', () {
      final root = MCTSNode(action: null, player: 0);
      final playAction = PlayAction(const DominoTile(6, 6), 'L', isFirstMove: true);
      
      // Simulate child node creation
      final child = MCTSNode(action: playAction, player: 1, parent: root);
      child.visits = 100;
      child.wins = 50.0;
      root.children[playAction] = child;
      
      // Prune the tree (what syncMove effectively triggers)
      final newRoot = root.prune(playAction, 1);
      
      expect(newRoot.action, equals(playAction));
      expect(newRoot.visits, equals(100));
      expect(newRoot.wins, equals(50.0));
      expect(newRoot.parent, isNull, reason: 'Pruned node should be detached from parent');
    });

    test('MCTSNode.prune handles unknown actions by resetting', () {
      final root = MCTSNode(action: null, player: 0);
      final unknownAction = PassAction();
      
      final newRoot = root.prune(unknownAction, 1);
      
      expect(newRoot.visits, equals(0), reason: 'Should be a fresh node if action was not in tree');
      expect(newRoot.player, equals(1));
    });
  });
}
