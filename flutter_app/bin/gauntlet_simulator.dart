import 'dart:async';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() async {
  final int numGames = 1;
  
  final Map<int, DifficultyLevel> playerDiffs = {
    0: DifficultyLevel.legend,
    1: DifficultyLevel.professional,
    2: DifficultyLevel.casual,
    3: DifficultyLevel.rookie,
  };

  print('=========================================');
  print('   AI MCTS Gauntlet Simulator            ');
  print('=========================================');
  for (int i = 0; i < 4; i++) {
    print('Player $i: ${playerDiffs[i]?.name.toUpperCase()}');
  }
  print('Total Matches: $numGames');
  print('-----------------------------------------');

  List<int> matchWins = [0, 0, 0, 0];
  Stopwatch totalSw = Stopwatch()..start();

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
    
    double progress = ((i + 1) / numGames) * 100;
    print('\nProgress: ${progress.toStringAsFixed(1)}% | Legend: ${matchWins[0]}, Pro: ${matchWins[1]}, Casual: ${matchWins[2]}, Rookie: ${matchWins[3]}');
  }

  totalSw.stop();
  print('\n-----------------------------------------');
  print('SIMULATION COMPLETE in ${totalSw.elapsed.inSeconds}s!');
  print('Final Match Win Counts:');
  for (int i = 0; i < 4; i++) {
    double winRate = (matchWins[i] / numGames) * 100;
    print('P$i [${playerDiffs[i]?.name.toUpperCase()}]: ${matchWins[i]} wins (${winRate.toStringAsFixed(1)}%)');
  }
  print('=========================================');
}
