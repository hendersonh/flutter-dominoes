import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_app/engine/dominoes_ai.dart';

// Top-level function for the Isolate entry point
Future<List<int>> runSimulationBatch(int numGames) async {
  List<int> matchWins = [0, 0, 0, 0];

  final Map<int, DifficultyLevel> playerDiffs = {
    0: DifficultyLevel.legend,
    1: DifficultyLevel.professional,
    2: DifficultyLevel.casual,
    3: DifficultyLevel.rookie,
  };

  await runZoned(() async {
    for (int i = 0; i < numGames; i++) {
        MatchModel match = MatchModel(
          targetScore: 100, 
          mode: ScoringMode.traditional,
          playStyle: PlayStyle.cutThroat,
        );
        
        int roundStarter = -1; // Random for first round or 6-6 logic
        bool isFirstHand = true;

        while (!match.isMatchOver) {
          match.startNewRound(roundStarter, isFirstHand: isFirstHand);
          GameModel round = match.currentRound!;
          
          while (!round.isGameOver) {
            int cp = round.currentPlayer;
            DifficultyLevel activeDiff = playerDiffs[cp]!;
            
            // Standard constraints
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

        int matchWinner = match.matchWinner;
        if (matchWinner != -1) {
          matchWins[matchWinner]++;
        }
    }
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      // Suppress all child prints
    }
  ));

  return matchWins;
}

void main() async {
  int totalGames = 200;
  int cores = Platform.numberOfProcessors;
  
  // Create workload batches
  int gamesPerCore = totalGames ~/ cores;
  int remainder = totalGames % cores;
  
  List<int> batches = List.generate(cores, (i) => gamesPerCore + (i < remainder ? 1 : 0));
  batches.removeWhere((cnt) => cnt == 0); // Cleanup empty loads

  print('=========================================');
  print('   AI MCTS Gauntlet Simulator (Parallel) ');
  print('=========================================');
  print('Total Matches: $totalGames');
  print('Running on $cores CPU cores concurrently...');
  print('Wait a few moments, calculations in progress...');
  print('-----------------------------------------');

  Stopwatch totalSw = Stopwatch()..start();

  List<Future<List<int>>> pendingSimulations = [];
  
  for (int batchSize in batches) {
    pendingSimulations.add(Isolate.run(() => runSimulationBatch(batchSize)));
  }

  // Wait for all isolates to finish
  List<List<int>> allResults = await Future.wait(pendingSimulations);

  // Aggregate results
  List<int> finalWins = [0, 0, 0, 0];
  for (List<int> result in allResults) {
    for (int i = 0; i < 4; i++) {
      finalWins[i] += result[i];
    }
  }

  totalSw.stop();
  print('-----------------------------------------');
  print('SIMULATION COMPLETE in ${totalSw.elapsed.inSeconds}s!');
  print('Final Match Win Counts:');
  for (int i = 0; i < 4; i++) {
    double winRate = (finalWins[i] / totalGames) * 100;
    String name = '';
    if (i == 0) name = 'LEGEND';
    if (i == 1) name = 'PROFESSIONAL';
    if (i == 2) name = 'CASUAL';
    if (i == 3) name = 'ROOKIE';
    print('P$i [$name]: ${finalWins[i]} wins (${winRate.toStringAsFixed(1)}%)');
  }
  print('=========================================');
}
