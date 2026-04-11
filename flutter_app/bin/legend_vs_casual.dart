import 'dart:isolate';
import 'package:args/args.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

/// Data class for simulation results
class SimResult {
  final int winnerTeam;
  SimResult(this.winnerTeam);
}

/// Worker function for a single match simulation
Future<SimResult> _runSingleMatch(int index) async {
  // Team 1 (P0, P2): Legend
  // Team 2 (P1, P3): Casual
  final Map<int, DifficultyLevel> playerDiffs = {
    0: DifficultyLevel.legend,
    1: DifficultyLevel.casual,
    2: DifficultyLevel.legend,
    3: DifficultyLevel.casual,
  };

  MatchModel match = MatchModel(
    targetScore: 100, 
    mode: ScoringMode.traditional,
    playStyle: PlayStyle.partners,
  );
  
  int roundStarter = -1;
  bool isFirstHand = true;

  while (!match.isMatchOver) {
    match.startNewRound(roundStarter, isFirstHand: isFirstHand);
    GameModel round = match.currentRound!;
    
    while (!round.isGameOver) {
      int cp = round.currentPlayer;
      DifficultyLevel activeDiff = playerDiffs[cp]!;
      
      // Increased limit for Legend to showcase its better depth
      int timeLimit = activeDiff == DifficultyLevel.legend ? 150 : 20;

      MCTSPlayer ai = MCTSPlayer(cp, difficulty: activeDiff);
      Action action = ai.getBestAction(round, timeLimitMs: timeLimit);
      round.applyAction(action);
    }

    final result = match.recordRoundResult();
    int roundWinner = result['winner']!;
    roundStarter = (roundWinner != -1) ? roundWinner : (round.currentPlayer + 1) % 4;
    isFirstHand = false;
  }

  // Team 0 wins if P0 or P2 is the match winner
  int winnerTeam = (match.matchWinner % 2 == 0) ? 0 : 1;
  return SimResult(winnerTeam);
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('games', abbr: 'g', defaultsTo: '100', help: 'Number of matches to play')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final results = parser.parse(args);

  if (results['help']) {
    print('Legend vs Casual AI Simulator');
    print(parser.usage);
    return;
  }

  final int numGames = int.parse(results['games']);
  
  print('=========================================');
  print('   AI MCTS Simulation: Legend vs Casual  ');
  print('=========================================');
  print('Team 1 (P0, P2): LEGEND (150ms)');
  print('Team 2 (P1, P3): CASUAL (20ms)');
  print('Status: DISPATCHING 20 LOGICAL CORES');
  print('Total Matches: $numGames');
  print('-----------------------------------------');

  Stopwatch totalSw = Stopwatch()..start();

  List<Future<SimResult>> tasks = [];
  for (int i = 0; i < numGames; i++) {
    tasks.add(Isolate.run(() => _runSingleMatch(i)));
  }

  List<SimResult> allResults = await Future.wait(tasks);

  totalSw.stop();

  List<int> teamWins = [0, 0];
  for (var res in allResults) {
    teamWins[res.winnerTeam]++;
  }

  print('\n-----------------------------------------');
  print('SIMULATION COMPLETE in ${totalSw.elapsed.inSeconds}s!');
  print('Results across $numGames Matches:');
  
  double team1Rate = (teamWins[0] / numGames) * 100;
  double team2Rate = (teamWins[1] / numGames) * 100;
  
  print('Team 1 [LEGEND]: ${teamWins[0]} wins (${team1Rate.toStringAsFixed(1)}%)');
  print('Team 2 [CASUAL]: ${teamWins[1]} wins (${team2Rate.toStringAsFixed(1)}%)');
  print('=========================================');
}
