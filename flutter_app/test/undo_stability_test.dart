import 'package:flutter_app/engine/dominoes_ai.dart';

void main() async {
  print("Running Undo Stability Test...");
  
  // Setup a match
  MatchModel match = MatchModel(
    targetScore: 6,
    mode: ScoringMode.sixLove,
    playStyle: PlayStyle.partners,
  );
  
  match.startNewRound(0);
  GameModel round = match.currentRound!;
  
  // 1. Initial AI thinking
  print("1. Initial state, AI thinking...");
  Action action1 = await AIWorker.instance.think(
    round, 
    round.currentPlayer, 
    200, 
    DifficultyLevel.casual, 
    match.scores, 
    match.targetScore, 
    match.mode
  );
  
  print("AI played: $action1");
  
  // Apply the action
  GameModel snapshot = round.clone(); // save for rewind
  round.applyAction(action1);
  AIWorker.instance.syncMove(action1, round.currentPlayer, round);
  
  // 2. Undo move
  print("\n2. Performing Undo...");
  // Simulate what main.dart rewindTo does
  AIWorker.instance.resetRoot();
  round = snapshot; // revert state
  
  // 3. AI thinking again from the rewound state
  print("\n3. Post-Undo state, AI thinking...");
  Action action2 = await AIWorker.instance.think(
    round, 
    round.currentPlayer, 
    200, 
    DifficultyLevel.casual, 
    match.scores, 
    match.targetScore, 
    match.mode
  );
  
  print("AI played after undo: $action2");
  
  AIWorker.instance.stop();
  print("\nTest completed.");
}
