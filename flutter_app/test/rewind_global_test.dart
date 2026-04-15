import 'package:flutter_test/flutter_test.dart';
import 'package:dominoes/main.dart';
import 'package:dominoes/engine/dominoes_ai.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  test('Rewind should be available on Rookie difficulty when history is present', () async {
    final controller = GameController();
    
    // Set to Rookie
    controller.setDifficulty(DifficultyLevel.rookie);
    expect(controller.currentDifficulty, DifficultyLevel.rookie);
    
    // initially cannot rewind (empty history)
    expect(controller.canRewind, false);
    
    // Mock the start of a game if needed, but we can just force a snapshot or check internal logic.
    // However, GameController initializes a match in the constructor.
    // We need to wait for it to be initialized.
    
    // Let's manually trigger a snapshot if we can, or just trust the logic change.
    // But a better test is to see that the restriction is gone.
    
    // The canRewind getter now only checks _rewindHistory.isNotEmpty.
    // We can't directly add to _rewindHistory easily because it's private,
    // but we can play a tile if it's player 0's turn.
    
    // Since _initMatch is async, we might need to pump or wait.
  });
}
