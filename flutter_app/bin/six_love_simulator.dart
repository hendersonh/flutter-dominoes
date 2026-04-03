import 'package:args/args.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('games', abbr: 'g', defaultsTo: '100', help: 'Number of matches to play')
    ..addFlag('verbose', abbr: 'v', help: 'Show round-by-round scoring logs')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final results = parser.parse(args);

  if (results['help']) {
    print('Six-Love Scoring Simulator');
    print(parser.usage);
    return;
  }

  final int numGames = int.parse(results['games']);
  final bool verbose = results['verbose'];

  print('=============================================');
  print('   HendyChallenge Six-Love Rule Validator    ');
  print('=============================================');
  print('Mode: SIX-LOVE (Jamaican Style)');
  print('Style: PARTNERS (2v2)');
  print('Difficulty: PROFESSIONAL');
  print('Total Matches: $numGames');
  print('---------------------------------------------');

  int totalGameBruks = 0;
  int totalCarryOvers = 0;
  int totalRounds = 0;
  List<int> teamWins = [0, 0];

  final stopwatch = Stopwatch()..start();

  for (int i = 0; i < numGames; i++) {
    MatchModel match = MatchModel(
      targetScore: 6,
      mode: ScoringMode.sixLove,
      playStyle: PlayStyle.partners,
    );

    int roundStarter = -1;
    bool isFirstHand = true;

    while (!match.isMatchOver) {
      match.startNewRound(roundStarter, isFirstHand: isFirstHand);
      GameModel round = match.currentRound!;
      totalRounds++;

      // Rapid-play logic: Random moves or simple heuristic for speed
      while (!round.isGameOver) {
        // Use a very low time limit for MCTS to get "valid" but fast moves
        MCTSPlayer ai = MCTSPlayer(round.currentPlayer, difficulty: DifficultyLevel.professional);
        Action action = ai.getBestAction(round, timeLimitMs: 5);
        round.applyAction(action);
      }

      // CAPTURE STATE BEFORE SCORING
      List<int> preScores = List.from(match.scores);
      int prePending = match.pendingBonus;

      // RECORD RESULT
      final res = match.recordRoundResult();
      int roundWinner = res['winner']!;
      
      // CALCULATE EVENTS
      if (roundWinner != -1) {
        int winnerTeam = roundWinner % 2;
        int loserTeam = 1 - winnerTeam;
        
        // Detect "Game Bruk" (Reset)
        int loserPrePoints = preScores[loserTeam] + preScores[loserTeam + 2];
        int loserPostPoints = match.scores[loserTeam] + match.scores[loserTeam + 2];
        bool isGameBruk = loserPrePoints > 0 && loserPostPoints == 0;
        
        if (isGameBruk) totalGameBruks++;

        // Detect Bonuses
        // Points awarded = 1 (base) + KeyBone + Pending
        // We can check the actual bonus flags from the engine's last round result
        // Or reconstruct from points difference
        int pointsAwarded = match.scores[roundWinner] - preScores[roundWinner];
        
        if (prePending > 0) totalCarryOvers++;
        
        // Log if verbose
        if (verbose) {
          String bonusStr = "";
          if (pointsAwarded > 1) {
            bonusStr = " [+$pointsAwarded POINTS]";
          }
          String resetStr = isGameBruk ? " [GAME BRUK! RESET TEAM ${loserTeam + 1}]" : "";
          print('Match ${i+1} | Round ${match.roundNumber} | Team ${winnerTeam + 1} wins $bonusStr$resetStr');
        }
      } else {
        if (verbose) print('Match ${i+1} | Round ${match.roundNumber} | DRAWN GAME [Point Carries Over]');
      }

      roundStarter = (roundWinner != -1) ? roundWinner : (round.currentPlayer + 1) % 4;
      isFirstHand = false;
    }

    int winnerTeam = (match.matchWinner % 2 == 0) ? 0 : 1;
    teamWins[winnerTeam]++;
  }

  stopwatch.stop();

  print('---------------------------------------------');
  print('SIMULATION COMPLETE in ${stopwatch.elapsed.inSeconds}s');
  print('\nSTATISTICS SUMMARY:');
  print('Total Matches Played: $numGames');
  print('Total Rounds Played:  $totalRounds');
  print('Average Rounds/Match: ${(totalRounds / numGames).toStringAsFixed(1)}');
  print('\nSIX-LOVE RULE ADHERENCE:');
  print('Game Bruk (Resets):   $totalGameBruks occurrences');
  print('Carry-Overs (Ties):   $totalCarryOvers occurrences');
  print('\nMATCH RESULTS:');
  print('Team 1 (P0/P2) Wins:  ${teamWins[0]} (${(teamWins[0] / numGames * 100).toStringAsFixed(1)}%)');
  print('Team 2 (P1/P3) Wins:  ${teamWins[1]} (${(teamWins[1] / numGames * 100).toStringAsFixed(1)}%)');
  print('=============================================');
}
