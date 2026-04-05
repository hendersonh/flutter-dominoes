import 'dart:isolate';
import 'package:args/args.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

/// Data class to hold the result of a single match simulation
class MatchResult {
  final int winnerTeam;
  final int rounds;
  final int gameBruks;
  final int carryOvers;

  MatchResult({
    required this.winnerTeam,
    required this.rounds,
    required this.gameBruks,
    required this.carryOvers,
  });
}

/// Worker function to run a single match simulation in an Isolate
Future<MatchResult> _runSingleMatch(int matchIndex) async {
  MatchModel match = MatchModel(
    targetScore: 6,
    mode: ScoringMode.sixLove,
    playStyle: PlayStyle.partners,
  );

  int totalRounds = 0;
  int gameBruks = 0;
  int carryOvers = 0;
  int roundStarter = -1;
  bool isFirstHand = true;

  while (!match.isMatchOver) {
    match.startNewRound(roundStarter, isFirstHand: isFirstHand);
    GameModel round = match.currentRound!;
    totalRounds++;

    while (!round.isGameOver) {
      // Professional AI with 5ms limit for high-speed simulation
      MCTSPlayer ai = MCTSPlayer(round.currentPlayer, difficulty: DifficultyLevel.professional);
      Action action = ai.getBestAction(round, timeLimitMs: 5);
      round.applyAction(action);
    }

    // Capture state to detect Game Bruk
    List<int> preScores = List.from(match.scores);
    int prePending = match.pendingBonus;

    final res = match.recordRoundResult();
    int roundWinner = res['winner']!;

    if (roundWinner != -1) {
      int winnerTeam = roundWinner % 2;
      int loserTeam = 1 - winnerTeam;

      int loserPrePoints = preScores[loserTeam] + preScores[loserTeam + 2];
      int loserPostPoints = match.scores[loserTeam] + match.scores[loserTeam + 2];
      
      if (loserPrePoints > 0 && loserPostPoints == 0) gameBruks++;
      if (prePending > 0) carryOvers++;
    }

    roundStarter = (roundWinner != -1) ? roundWinner : (round.currentPlayer + 1) % 4;
    isFirstHand = false;
  }

  int finalWinnerTeam = (match.matchWinner % 2 == 0) ? 0 : 1;
  return MatchResult(
    winnerTeam: finalWinnerTeam,
    rounds: totalRounds,
    gameBruks: gameBruks,
    carryOvers: carryOvers,
  );
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('games', abbr: 'g', defaultsTo: '100', help: 'Number of matches to play')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final results = parser.parse(args);

  if (results['help']) {
    print('Six-Love Scoring Simulator (Parallel Core Version)');
    print(parser.usage);
    return;
  }

  final int numGames = int.parse(results['games']);

  print('=============================================');
  print('   HendyChallenge Parallel Rule Validator     ');
  print('=============================================');
  print('Mode: SIX-LOVE (2v2 Partners)');
  print('Status: DISPATCHING 20 LOGICAL CORES');
  print('Total Matches: $numGames');
  print('---------------------------------------------');

  final stopwatch = Stopwatch()..start();

  // Create a list of simulation tasks
  List<Future<MatchResult>> tasks = [];
  for (int i = 0; i < numGames; i++) {
    tasks.add(Isolate.run(() => _runSingleMatch(i)));
  }

  // Wait for all matches to complete
  List<MatchResult> allResults = await Future.wait(tasks);

  stopwatch.stop();

  // Aggregate stats
  int totalRounds = 0;
  int totalGameBruks = 0;
  int totalCarryOvers = 0;
  List<int> teamWins = [0, 0];

  for (var res in allResults) {
    totalRounds += res.rounds;
    totalGameBruks += res.gameBruks;
    totalCarryOvers += res.carryOvers;
    teamWins[res.winnerTeam]++;
  }

  print('---------------------------------------------');
  print('SIMULATION COMPLETE in ${stopwatch.elapsed.inSeconds}s (Parallel)');
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
