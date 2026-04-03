import 'package:args/args.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('games', abbr: 'g', defaultsTo: '100', help: 'Number of matches to play')
    ..addOption('difficulty', abbr: 'd', allowed: ['rookie', 'casual', 'professional', 'legend'], defaultsTo: 'rookie', help: 'Difficulty of the Test Player (Player 0)')
    ..addOption('mode', abbr: 'm', allowed: ['100', 'six-love'], defaultsTo: '100', help: 'Scoring mode')
    ..addFlag('partners', abbr: 'p', negatable: false, help: '2v2 Partner Mode (Team 1: P0/P2, Team 2: P1/P3)')
    ..addFlag('debug', abbr: 'v', negatable: false, help: 'Show turn-by-turn logs');

  final results = parser.parse(args);
  final int numGames = int.parse(results['games']);
  final DifficultyLevel testDiff = DifficultyLevel.values.firstWhere((e) => e.name == results['difficulty']);
  final ScoringMode scoringMode = results['mode'] == '100' ? ScoringMode.traditional : ScoringMode.sixLove;
  final bool isPartners = results['partners'];
  final bool debug = results['debug'];

  print('=========================================');
  print('   HendyChallenge AI Simulator v1.1      ');
  print('=========================================');
  print('Test Player (P0): $testDiff');
  print('Opponents (P1-3): ${DifficultyLevel.professional}');
  print('Style: ${isPartners ? "PARTNERS (2v2)" : "CUT-THROAT"}');
  print('Mode: $scoringMode');
  print('Total Matches: $numGames');
  print('-----------------------------------------');

  List<int> matchWins = [0, 0, 0, 0];
  Stopwatch totalSw = Stopwatch()..start();

  for (int i = 0; i < numGames; i++) {
    MatchModel match = MatchModel(
      targetScore: 100, 
      mode: scoringMode,
      playStyle: isPartners ? PlayStyle.partners : PlayStyle.cutThroat,
    );
    
    int roundStarter = -1; // Random for first round or 6-6 logic
    bool isFirstHand = true;

    while (!match.isMatchOver) {
      match.startNewRound(roundStarter, isFirstHand: isFirstHand);
      GameModel round = match.currentRound!;
      
      if (debug) print('\n--- Round ${match.roundNumber} START ---');

      while (!round.isGameOver) {
        int cp = round.currentPlayer;
        DifficultyLevel activeDiff = (cp == 0) ? testDiff : DifficultyLevel.professional;
        
        // Use shorter time limits for speed in simulation
        int timeLimit = (activeDiff == DifficultyLevel.rookie) ? 20 : 100;
        if (activeDiff == DifficultyLevel.legend) timeLimit = 500;

        MCTSPlayer ai = MCTSPlayer(cp, difficulty: activeDiff);
        Action action = ai.getBestAction(round, timeLimitMs: timeLimit);
        
        if (debug) {
          print('Player $cp ($activeDiff) plays $action');
        }
        
        round.applyAction(action);
      }

      final result = match.recordRoundResult();
      int roundWinner = result['winner']!;
      if (debug) print('Round Over! Winner: P$roundWinner. Match Scores: ${match.scores}');
      
      roundStarter = (roundWinner != -1) ? roundWinner : (round.currentPlayer + 1) % 4;
      isFirstHand = false;
    }

    int matchWinner = match.matchWinner;
    if (matchWinner != -1) {
      matchWins[matchWinner]++;
    }
    
    if ((i + 1) % 10 == 0 || i == numGames - 1) {
      double progress = ((i + 1) / numGames) * 100;
      String currentWinsStr = isPartners 
          ? "Team 1: ${matchWins[0]}, Team 2: ${matchWins[1]}"
          : "P0: ${matchWins[0]}, P1: ${matchWins[1]}, P2: ${matchWins[2]}, P3: ${matchWins[3]}";
      print('Progress: ${progress.toStringAsFixed(1)}% | $currentWinsStr');
    }
  }

  totalSw.stop();
  print('-----------------------------------------');
  print('SIMULATION COMPLETE in ${totalSw.elapsed.inSeconds}s');
  print('Final Match Win Counts:');
  if (isPartners) {
    print('TEAM 1 (P0+P2): ${matchWins[0]} wins (${(matchWins[0]/numGames*100).toStringAsFixed(1)}%)');
    print('TEAM 2 (P1+P3): ${matchWins[1]} wins (${(matchWins[1]/numGames*100).toStringAsFixed(1)}%)');
  } else {
    for (int i = 0; i < 4; i++) {
      double winRate = (matchWins[i] / numGames) * 100;
      String label = (i == 0) ? 'P$i [TEST - $testDiff]' : 'P$i [PRO]';
      print('$label: ${matchWins[i]} wins (${winRate.toStringAsFixed(1)}%)');
    }
  }
  print('=========================================');
}
