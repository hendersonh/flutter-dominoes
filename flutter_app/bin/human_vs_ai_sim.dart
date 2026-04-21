import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_app/engine/dominoes_ai.dart';

// Top-level function for the Isolate entry point
Future<Map<String, dynamic>> runSimulationBatch(int numGames) async {
  int humanWins = 0;
  int aiWins = 0;
  int totalHumanScore = 0;
  int totalAiScore = 0;

  final Map<int, DifficultyLevel> playerDiffs = {
    0: DifficultyLevel.legend, // Simulating a high-level human
    1: DifficultyLevel.professional, // The AI opponent
  };

  await runZoned(() async {
    for (int i = 0; i < numGames; i++) {
        MatchModel match = MatchModel(
          targetScore: 100, 
          mode: ScoringMode.traditional,
          playStyle: PlayStyle.draw1v1,
        );
        
        int roundStarter = -1; // Random for first round or 6-6 logic
        bool isFirstHand = true;

        while (!match.isMatchOver) {
          match.startNewRound(roundStarter, isFirstHand: isFirstHand);
          GameModel round = match.currentRound!;
          
          while (!round.isGameOver) {
            int cp = round.currentPlayer;
            DifficultyLevel activeDiff = playerDiffs[cp]!;
            
            // Limit time for faster simulation.
            int timeLimit = 50;
            if (activeDiff == DifficultyLevel.legend) timeLimit = 150;

            MCTSPlayer ai = MCTSPlayer(cp, difficulty: activeDiff);
            Action action = ai.getBestAction(round, timeLimitMs: timeLimit);
            
            round.applyAction(action);
          }

          final result = match.recordRoundResult();
          int roundWinner = result['winner']!;
          roundStarter = (roundWinner != -1) ? roundWinner : (round.currentPlayer + 1) % 2;
          isFirstHand = false;
        }

        int matchWinner = match.matchWinner;
        if (matchWinner == 0) {
          humanWins++;
        } else if (matchWinner == 1) {
          aiWins++;
        }
        
        totalHumanScore += match.scores[0];
        totalAiScore += match.scores[1];
    }
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      // Suppress all child prints
    }
  ));

  return {
    'humanWins': humanWins,
    'aiWins': aiWins,
    'totalHumanScore': totalHumanScore,
    'totalAiScore': totalAiScore,
  };
}

void main() async {
  int totalGames = 10;
  int cores = Platform.numberOfProcessors;
  if (cores > 10) cores = 10; // Cap at 10 cores
  
  // Create workload batches
  int gamesPerCore = totalGames ~/ cores;
  int remainder = totalGames % cores;
  
  List<int> batches = List.generate(cores, (i) => gamesPerCore + (i < remainder ? 1 : 0));
  batches.removeWhere((cnt) => cnt == 0); // Cleanup empty loads

  print('=========================================');
  print('   1v1 Draw: Human (Legend) vs AI (Pro) ');
  print('=========================================');
  print('Total Matches: $totalGames');
  print('Running on ${batches.length} CPU cores concurrently...');
  print('Wait a few moments, calculations in progress...');
  print('-----------------------------------------');

  Stopwatch totalSw = Stopwatch()..start();

  List<Future<Map<String, dynamic>>> pendingSimulations = [];
  
  for (int i = 0; i < batches.length; i++) {
    int batchSize = batches[i];
    pendingSimulations.add(Isolate.run(() => runSimulationBatch(batchSize)).then((res) {
      print('Core ${i+1} finished its $batchSize match(es).');
      return res;
    }));
  }

  // Wait for all isolates to finish
  List<Map<String, dynamic>> allResults = await Future.wait(pendingSimulations);

  // Aggregate results
  int finalHumanWins = 0;
  int finalAiWins = 0;
  int finalHumanScore = 0;
  int finalAiScore = 0;
  
  for (var result in allResults) {
    finalHumanWins += result['humanWins'] as int;
    finalAiWins += result['aiWins'] as int;
    finalHumanScore += result['totalHumanScore'] as int;
    finalAiScore += result['totalAiScore'] as int;
  }

  totalSw.stop();
  print('-----------------------------------------');
  print('SIMULATION COMPLETE in ${totalSw.elapsed.inSeconds}s!');
  print('Final Match Win Counts (Target: 100 pts):');
  print('Human (Legend): $finalHumanWins (${((finalHumanWins / totalGames) * 100).toStringAsFixed(1)}%)');
  print('AI (Pro):       $finalAiWins (${((finalAiWins / totalGames) * 100).toStringAsFixed(1)}%)');
  print('-----------------------------------------');
  print('Average Score per Match:');
  print('Human (Legend): ${(finalHumanScore / totalGames).toStringAsFixed(1)}');
  print('AI (Pro):       ${(finalAiScore / totalGames).toStringAsFixed(1)}');
  print('=========================================');
}
