import 'dart:isolate';
import 'package:args/args.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

/// Data class for gauntlet results
class GauntletResult {
  final int matchWinner;
  GauntletResult(this.matchWinner);
}

/// Worker function for a single gauntlet match
Future<GauntletResult> _runSingleGauntletMatch(int index) async {
  final Map<int, DifficultyLevel> playerDiffs = {
    0: DifficultyLevel.legend,
    1: DifficultyLevel.professional,
    2: DifficultyLevel.casual,
    3: DifficultyLevel.rookie,
  };

  MatchModel match = MatchModel(
    targetScore: 100, 
    mode: ScoringMode.traditional,
    playStyle: PlayStyle.cutThroat,
  );
  
  int roundStarter = -1;
  bool isFirstHand = true;

  while (!match.isMatchOver) {
    match.startNewRound(roundStarter, isFirstHand: isFirstHand);
    GameModel round = match.currentRound!;
    
    while (!round.isGameOver) {
      int cp = round.currentPlayer;
      DifficultyLevel activeDiff = playerDiffs[cp]!;
      
      int timeLimit = 50;
      if (activeDiff == DifficultyLevel.rookie) timeLimit = 5;
      if (activeDiff == DifficultyLevel.casual) timeLimit = 20;
      if (activeDiff == DifficultyLevel.professional) timeLimit = 50;
      if (activeDiff == DifficultyLevel.legend) timeLimit = 150;

      MCTSPlayer ai = MCTSPlayer(cp, difficulty: activeDiff);
      Action action = ai.getBestAction(round, timeLimitMs: timeLimit);
      round.applyAction(action);
    }

    final result = match.recordRoundResult();
    int roundWinner = result['winner']!;
    roundStarter = (roundWinner != -1) ? roundWinner : (round.currentPlayer + 1) % 4;
    isFirstHand = false;
  }

  return GauntletResult(match.matchWinner);
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('games', abbr: 'g', defaultsTo: '100', help: 'Number of matches to play')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final results = parser.parse(args);

  if (results['help']) {
    print('AI MCTS Gauntlet Simulator (Parallel Core Version)');
    print(parser.usage);
    return;
  }

  final int numGames = int.parse(results['games']);
  
  print('=========================================');
  print('   AI MCTS Parallel Gauntlet Simulator   ');
  print('=========================================');
  print('P0: LEGEND (150ms)');
  print('P1: PROFESSIONAL (50ms)');
  print('P2: CASUAL (20ms)');
  print('P3: ROOKIE (5ms)');
  print('Status: DISPATCHING 20 LOGICAL CORES');
  print('Total Matches: $numGames');
  print('-----------------------------------------');

  Stopwatch totalSw = Stopwatch()..start();

  // Dispatch work to Isolates
  List<Future<GauntletResult>> tasks = [];
  for (int i = 0; i < numGames; i++) {
    tasks.add(Isolate.run(() => _runSingleGauntletMatch(i)));
  }

  // Wait for all results
  List<GauntletResult> allResults = await Future.wait(tasks);

  totalSw.stop();

  // Aggregate wins
  List<int> matchWins = [0, 0, 0, 0];
  for (var res in allResults) {
    if (res.matchWinner != -1) {
      matchWins[res.matchWinner]++;
    }
  }

  print('\n-----------------------------------------');
  print('SIMULATION COMPLETE in ${totalSw.elapsed.inSeconds}s (Parallel)!');
  print('Final Match Win Counts across $numGames Matches:');
  for (int i = 0; i < 4; i++) {
    double winRate = (matchWins[i] / numGames) * 100;
    String diff = i == 0 ? "LEGEND" : (i == 1 ? "PROFESSIONAL" : (i == 2 ? "CASUAL" : "ROOKIE"));
    print('P$i [$diff]: ${matchWins[i]} wins (${winRate.toStringAsFixed(1)}%)');
  }
  print('=========================================');
}
