import 'dart:math';
import 'dart:isolate';

/// Represents a single Domino tile.
class DominoTile {
  final int end1;
  final int end2;

  const DominoTile(this.end1, this.end2);

  bool contains(int value) => end1 == value || end2 == value;
  int get score => end1 + end2;
  bool get isDouble => end1 == end2;

  @override
  String toString() => '[$end1|$end2]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DominoTile &&
          ((end1 == other.end1 && end2 == other.end2) ||
              (end1 == other.end2 && end2 == other.end1));

  @override
  int get hashCode {
    if (end1 < end2) {
      return Object.hash(end1, end2);
    } else {
      return Object.hash(end2, end1);
    }
  }
}

/// Represents an action a player can take.
abstract class Action {}

class PlayAction extends Action {
  final DominoTile tile;
  final String side; // 'left' or 'right'
  final bool isFirstMove;

  PlayAction(this.tile, this.side, {this.isFirstMove = false});

  @override
  String toString() =>
      isFirstMove ? 'Play $tile as first move' : 'Play $tile on $side';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayAction &&
          tile == other.tile &&
          side == other.side &&
          isFirstMove == other.isFirstMove;

  @override
  int get hashCode => tile.hashCode ^ side.hashCode ^ isFirstMove.hashCode;
}

class DrawAction extends Action {
  @override
  String toString() => 'Draw from boneyard';

  @override
  bool operator ==(Object other) => other is DrawAction;

  @override
  int get hashCode => 'Draw'.hashCode;
}

class PassAction extends Action {
  @override
  String toString() => 'Pass';
  @override
  bool operator ==(Object other) => other is PassAction;
  @override
  int get hashCode => 'Pass'.hashCode;
}

/// The state of the game.
class GameModel {
  List<List<DominoTile>> hands;
  List<Set<int>> passedSuits; // [0..3] for players 0-3
  int? leftEnd;
  int? rightEnd;
  int currentPlayer;
  int consecutivePasses;
  int rootIndex = 0;
  List<DominoTile> board; // Just for visualization
  bool isFirstHandOfMatch;

  GameModel({
    required this.hands,
    List<Set<int>>? passedSuits,
    this.leftEnd,
    this.rightEnd,
    this.currentPlayer = 0,
    this.consecutivePasses = 0,
    this.rootIndex = 0,
    List<DominoTile>? board,
    this.isFirstHandOfMatch = false,
  }) : board = board ?? [],
       passedSuits = passedSuits ?? [{}, {}, {}, {}];

  GameModel clone() {
    return GameModel(
      hands: hands.map((h) => List<DominoTile>.from(h)).toList(),
      passedSuits: passedSuits.map((s) => Set<int>.from(s)).toList(),
      leftEnd: leftEnd,
      rightEnd: rightEnd,
      currentPlayer: currentPlayer,
      consecutivePasses: consecutivePasses,
      rootIndex: rootIndex,
      board: List.from(board),
      isFirstHandOfMatch: isFirstHandOfMatch,
    );
  }

  bool get isGameOver {
    for (int i = 0; i < 4; i++) {
      if (hands[i].isEmpty) return true;
    }
    if (consecutivePasses >= 4) return true; // Blocked game
    return false;
  }

  int get winner {
    if (!isGameOver) return -1;
    for (int i = 0; i < 4; i++) {
      if (hands[i].isEmpty) return i;
    }

    // Blocked game: player with lowest score in hand wins
    List<int> scores = hands
        .map((h) => h.fold(0, (sum, tile) => sum + tile.score))
        .toList();
    int minScore = scores.reduce(min);

    // Check for ties
    if (scores.where((s) => s == minScore).length > 1) {
      return -1; // Draw
    }

    return scores.indexOf(minScore);
  }

  bool canPlayerPlay(int player) {
    if (board.isEmpty) return hands[player].isNotEmpty;
    // board.isEmpty is false, so leftEnd and rightEnd must be non-null.
    for (var tile in hands[player]) {
      if (tile.contains(leftEnd!) || tile.contains(rightEnd!)) return true;
    }
    return false;
  }

  List<Action> getLegalActions(int player) {
    List<Action> actions = [];

    if (leftEnd == null && rightEnd == null) {
      // First move of the game
      if (isFirstHandOfMatch) {
        DominoTile doubleSix = const DominoTile(6, 6);
        if (hands[player].contains(doubleSix)) {
          actions.add(PlayAction(doubleSix, 'left', isFirstMove: true));
        } else {
          // Fallback if rules are broken, should not happen if MatchModel sets startingPlayer correctly
          for (var tile in hands[player]) {
            actions.add(PlayAction(tile, 'left', isFirstMove: true));
          }
        }
      } else {
        for (var tile in hands[player]) {
          actions.add(PlayAction(tile, 'left', isFirstMove: true));
        }
      }
      return actions;
    }

    bool canPlay = false;
    for (var tile in hands[player]) {
      if (tile.contains(leftEnd!)) {
        actions.add(PlayAction(tile, 'left'));
        canPlay = true;
      }
      // Don't add duplicate actions if playing a double or if leftEnd == rightEnd
      if (tile.contains(rightEnd!) &&
          (leftEnd != rightEnd || !tile.contains(leftEnd!))) {
        actions.add(PlayAction(tile, 'right'));
        canPlay = true;
      }
    }

    if (!canPlay) {
      actions.add(PassAction());
    }

    return actions;
  }

  void applyAction(Action action) {
    if (action is PlayAction) {
      // Find the tile instance in hand to remove it properly
      final tileInHand = hands[currentPlayer].firstWhere(
        (t) => t == action.tile,
      );
      hands[currentPlayer].remove(tileInHand);

      if (action.isFirstMove || board.isEmpty) {
        leftEnd = action.tile.end1;
        rightEnd = action.tile.end2;
        board.add(action.tile);
        rootIndex = 0;
      } else if (action.side == 'left') {
        if (leftEnd == null) return; // Should not happen
        if (action.tile.end2 == leftEnd) {
          leftEnd = action.tile.end1;
          board.insert(0, action.tile);
          rootIndex++;
        } else if (action.tile.end1 == leftEnd) {
          leftEnd = action.tile.end2;
          board.insert(0, DominoTile(action.tile.end2, action.tile.end1));
          rootIndex++;
        }
      } else {
        if (rightEnd == null) return; // Should not happen
        if (action.tile.end1 == rightEnd) {
          rightEnd = action.tile.end2;
          board.add(action.tile);
        } else if (action.tile.end2 == rightEnd) {
          rightEnd = action.tile.end1;
          board.add(DominoTile(action.tile.end2, action.tile.end1));
        }
      }
      consecutivePasses = 0;
      currentPlayer = (currentPlayer + 1) % 4;
    } else if (action is PassAction) {
      // If they passed, they don't have the left or right ends
      if (leftEnd != null) passedSuits[currentPlayer].add(leftEnd!);
      if (rightEnd != null) passedSuits[currentPlayer].add(rightEnd!);

      consecutivePasses++;
      currentPlayer = (currentPlayer + 1) % 4;
    }
  }
}

/// Information Set MCTS Node
class MCTSNode {
  final Action? action;
  final MCTSNode? parent;
  final int player; // Player who made the move resulting in this node

  int visits = 0;
  double wins = 0.0;

  // Maps an action to a child node
  Map<Action, MCTSNode> children = {};

  // Track how often an action was legal (Info Set UCB1 denominator)
  Map<Action, int> availabilityCount = {};

  MCTSNode({this.action, this.parent, required this.player});

  void update(double result) {
    visits++;
    wins += result;
  }

  /// Selects the best child using the UCB1 formula modified for Information Sets.
  /// Only considers children that correspond to legal actions in the current determinized state.
  MCTSNode? getBestChild(List<Action> legalActions, double explorationParam) {
    MCTSNode? bestChild;
    double bestValue = -double.infinity;

    for (var action in legalActions) {
      var child = children[action];
      if (child != null) {
        int ni = child.visits;
        // In original UCB1, Ni is the total parent visits.
        // In IS-MCTS, Ni must be the availability count to prevent rare action explosion.
        int Ni = availabilityCount[action] ?? 1;

        double ucb1 = (child.wins / ni) + explorationParam * sqrt(log(Ni) / ni);
        if (ucb1 > bestValue) {
          bestValue = ucb1;
          bestChild = child;
        }
      }
    }
    return bestChild;
  }
}

/// MCTS Player implementation
class MCTSPlayer {
  final int playerId;
  final int maxIterations;
  final Random random = Random();

  MCTSPlayer(this.playerId, {this.maxIterations = 10000});

  /// Determinization: Randomly assign unknown tiles to opponents respecting game history constraints
  GameModel determinize(GameModel state) {
    GameModel detState = state.clone();

    // Collect all unknown tiles (opponents' hands)
    List<DominoTile> unknownTiles = [];
    List<int> needed = List.filled(4, 0);
    List<Set<int>> voids = detState.passedSuits;

    for (int i = 0; i < 4; i++) {
      if (i != playerId) {
        unknownTiles.addAll(detState.hands[i]);
        needed[i] = detState.hands[i].length;
        detState.hands[i] = []; // Clear for reassignment
      }
    }

    // Shuffle pool to ensure random valid distribution on each MCTS iteration
    unknownTiles.shuffle(random);

    // Process opponents using the Fail-First principle (Minimum Remaining Values heuristic).
    // Sort by the number of voids (descending) so heavily constrained players get tiles first.
    List<int> opponents = [0, 1, 2, 3]
      ..remove(playerId)
      ..shuffle(random); // Shuffle first to randomly break ties
    opponents.sort((a, b) => voids[b].length.compareTo(voids[a].length));

    int iterations = 0;

    bool assignTilesRec(int oppIndexIndex) {
      iterations++;
      if (iterations > 5000) {
        return false;
      } // Safety cutoff for pathological constraint graphs

      if (oppIndexIndex >= opponents.length) return true;
      int pIndex = opponents[oppIndexIndex];

      if (needed[pIndex] == 0) return assignTilesRec(oppIndexIndex + 1);

      for (int i = 0; i < unknownTiles.length; i++) {
        DominoTile t = unknownTiles[i];
        if (!voids[pIndex].contains(t.end1) &&
            !voids[pIndex].contains(t.end2)) {
          unknownTiles.removeAt(i);
          detState.hands[pIndex].add(t);
          needed[pIndex]--;

          if (assignTilesRec(oppIndexIndex)) {
            return true;
          }

          // Backtrack
          needed[pIndex]++;
          detState.hands[pIndex].removeLast();
          unknownTiles.insert(i, t);
        }
      }
      return false;
    }

    bool success = assignTilesRec(0);

    if (!success) {
      // Fallback: If absolutely impossible to satisfy constraints, distribute randomly
      for (int i = 0; i < 4; i++) {
        if (i != playerId) detState.hands[i] = [];
      }
      unknownTiles.shuffle(random);
      int tileIndex = 0;
      for (int i = 0; i < 4; i++) {
        if (i == playerId) continue;
        int assignCount = state.hands[i].length;
        detState.hands[i] = unknownTiles.sublist(
          tileIndex,
          tileIndex + assignCount,
        );
        tileIndex += assignCount;
      }
    }

    return detState;
  }

  Action getBestAction(GameModel rootState, {int timeLimitMs = 1500}) {
    List<Action> rootLegalActions = rootState.getLegalActions(playerId);
    if (rootLegalActions.length == 1) return rootLegalActions[0];

    MCTSNode rootNode = MCTSNode(player: (rootState.currentPlayer - 1 + 4) % 4);
    Stopwatch sw = Stopwatch()..start();
    int iterations = 0;

    while (sw.elapsedMilliseconds < timeLimitMs) {
      iterations++;
      // 1. Determinization
      GameModel state = determinize(rootState);
      MCTSNode node = rootNode;

      // 2. Selection
      // Traverse down the tree as long as all legal actions in the current state are fully expanded
      while (!state.isGameOver) {
        List<Action> legalActions = state.getLegalActions(state.currentPlayer);

        // Record availability BEFORE choosing to accurately track IS-MCTS availability denominator!
        for (var a in legalActions) {
          node.availabilityCount[a] = (node.availabilityCount[a] ?? 0) + 1;
        }

        // Find untried actions for the current determinized state
        List<Action> untried = legalActions
            .where((a) => !node.children.containsKey(a))
            .toList();

        if (untried.isNotEmpty) {
          // 3. Expansion
          Action actionToTry = untried[random.nextInt(untried.length)];
          int movingPlayer = state.currentPlayer;
          state.applyAction(actionToTry);

          MCTSNode childNode = MCTSNode(
            action: actionToTry,
            parent: node,
            player: movingPlayer, // The player who just moved
          );
          node.children[actionToTry] = childNode;
          node = childNode;
          break; // Move to simulation phase
        } else {
          // All legal actions have been expanded, select the best one using UCB1
          MCTSNode? bestChild = node.getBestChild(legalActions, 1.414);
          if (bestChild == null) break; // Should not happen if untried is empty

          state.applyAction(bestChild.action!);
          node = bestChild;
        }
      }

      // 4. Simulation
      while (!state.isGameOver) {
        List<Action> actions = state.getLegalActions(state.currentPlayer);

        // HEURISTIC: Heavy-Tile preference during simulation
        List<PlayAction> playActions = actions.whereType<PlayAction>().toList();
        Action chosenAction;

        if (playActions.isNotEmpty) {
          playActions.sort((a, b) => b.tile.score.compareTo(a.tile.score));
          // 80% of the time, greedily dump the highest tile to mimic basic strategy
          if (random.nextDouble() < 0.8) {
            chosenAction = playActions.first;
          } else {
            chosenAction = playActions[random.nextInt(playActions.length)];
          }
        } else {
          chosenAction = actions[random.nextInt(actions.length)];
        }

        state.applyAction(chosenAction);
      }

      // 5. Backpropagation
      int winner = state.winner;

      MCTSNode? currentNode = node;
      while (currentNode != null) {
        double result = 0.0;
        int movingPlayer = currentNode.player;

        if (winner == -1) {
          result = 0.5; // Natural Draw
        } else {
          // Evaluate win/loss magnitude based on pip differential
          int myPips = state.hands[movingPlayer].fold(
            0,
            (sum, t) => sum + t.score,
          );

          if (winner == movingPlayer) {
            // Win: Reward based on total pips trapped (actual game rules)
            int sumOpPips = 0;
            for (int i = 0; i < 4; i++) {
              if (i != movingPlayer) {
                sumOpPips += state.hands[i].fold(0, (sum, t) => sum + t.score);
              }
            }
            // Max theoretical sum is around 63 * 3 = 189, though closer to 100 in practice.
            // Normalize sumOpPips against a reasonable cap, say 100 points.
            result = 0.6 + 0.4 * (sumOpPips / 100.0).clamp(0.0, 1.0);
          } else {
            // Loss: Heavily penalize having a large number of pips left in hand.
            // A score near 0.0 means terrible loss (many pips left).
            // A score near 0.4 means a "good" loss (very few pips left).
            result = 0.4 - 0.4 * (myPips / 100.0).clamp(0.0, 1.0);
          }
        }

        currentNode.update(result);
        currentNode = currentNode.parent;
      }
    }

    // Return the action with the most visits
    Action bestAction = rootLegalActions[0];
    int maxVisits = -1;

    for (var action in rootLegalActions) {
      var child = rootNode.children[action];
      if (child != null && child.visits > maxVisits) {
        maxVisits = child.visits;
        bestAction = action;
      }
    }

    print(
      "AI Player $playerId Iterations: $iterations | Best Action: $bestAction | Visits: $maxVisits",
    );
    return bestAction;
  }
}

const bool _kIsWeb = identical(0, 0.0);

/// Wrapper for Isolate computation to prevent UI freezing
Future<Action> getBestActionAsync(
  GameModel state,
  int playerId,
  int timeLimitMs,
) async {
  if (_kIsWeb) {
    MCTSPlayer ai = MCTSPlayer(playerId);
    return ai.getBestAction(state, timeLimitMs: timeLimitMs);
  } else {
    return await Isolate.run(() {
      MCTSPlayer ai = MCTSPlayer(playerId);
      return ai.getBestAction(state, timeLimitMs: timeLimitMs);
    });
  }
}

/// Model to govern multiple rounds of dominoes up to a target score
class MatchModel {
  List<int> scores = [0, 0, 0, 0]; // 0: Human, 1-3: AIs
  int roundNumber = 1;
  int nextStarter = 0; // 0 for human, 1-3 for AI
  final int targetScore;
  GameModel? currentRound;

  MatchModel({this.targetScore = 100});

  bool get isMatchOver => scores.any((s) => s >= targetScore);

  int get matchWinner {
    int maxScore = scores.reduce(max);
    if (maxScore >= targetScore) {
      return scores.indexOf(maxScore);
    }
    return -1;
  }

  void startNewRound(int roundStarterOverride, {bool isFirstHand = false}) {
    List<DominoTile> allTiles = [];
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        allTiles.add(DominoTile(i, j));
      }
    }
    allTiles.shuffle();

    List<List<DominoTile>> dealtHands = [
      allTiles.sublist(0, 7),
      allTiles.sublist(7, 14),
      allTiles.sublist(14, 21),
      allTiles.sublist(21, 28),
    ];

    int startingPlayer = roundStarterOverride;

    if (isFirstHand) {
      // strictly find 6-6
      DominoTile doubleSix = const DominoTile(6, 6);
      for (int i = 0; i < 4; i++) {
        if (dealtHands[i].contains(doubleSix)) {
          startingPlayer = i;
          break;
        }
      }
    }

    nextStarter = startingPlayer; // Store who actually started

    currentRound = GameModel(
      hands: dealtHands,
      currentPlayer: startingPlayer,
      isFirstHandOfMatch: isFirstHand,
    );
  }

  /// Records the result of the current round and advances to the next.
  /// Returns the winner of the round, or -1 for a tie.
  int recordRoundResult() {
    if (currentRound == null) return -1;
    int winner = currentRound!.winner;

    if (winner != -1) {
      // Winner gets sum of all OTHER players' pips
      int totalPipsRound = 0;
      for (int i = 0; i < 4; i++) {
        if (i != winner) {
          totalPipsRound += currentRound!.hands[i].fold(
            0,
            (sum, t) => sum + t.score,
          );
        }
      }
      scores[winner] += totalPipsRound;
    }

    roundNumber++;
    // Set next starter based on previous round winner
    if (winner != -1) {
      nextStarter = winner; // Winner starts next round
    } else {
      nextStarter = (nextStarter + 1) % 4; // Tie: rotate starter clockwise
    }
    return winner;
  }

  Map<String, dynamic> toJson() {
    return {
      'scores': scores,
      'roundNumber': roundNumber,
      'targetScore': targetScore,
      'nextStarter': nextStarter,
    };
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final match = MatchModel(targetScore: json['targetScore'] ?? 100);
    if (json['scores'] != null) {
      match.scores = List<int>.from(json['scores']);
    } else {
      // Migration from 2-player state
      match.scores[0] = json['humanScore'] ?? 0;
      match.scores[1] = json['aiScore'] ?? 0;
    }
    match.roundNumber = json['roundNumber'] ?? 1;
    match.nextStarter = json['nextStarter'] ?? 0;
    return match;
  }
}

/// Main function to simulate a Human vs 3 AI Match
void main() async {
  print("=== Block Dominoes: 4-Player Match (IS-MCTS) ===");
  print("Target Score: 100 points");

  MatchModel match = MatchModel(targetScore: 100);

  while (!match.isMatchOver) {
    print("\n==================================================");
    print(
      "MATCH SCORE - P0: ${match.scores[0]} | P1: ${match.scores[1]} | P2: ${match.scores[2]} | P3: ${match.scores[3]}",
    );
    print("--- ROUND ${match.roundNumber} ---");

    match.startNewRound(match.nextStarter, isFirstHand: match.roundNumber == 1);
    GameModel game = match.currentRound!;

    while (!game.isGameOver) {
      print("\n--------------------------------------------------");
      print("Board: ${game.board.isEmpty ? 'Empty' : game.board.join(' ')}");
      print("Ends: [${game.leftEnd ?? '?'} | ${game.rightEnd ?? '?'}]");
      print(
        "Hands: P0:${game.hands[0].length} P1:${game.hands[1].length} P2:${game.hands[2].length} P3:${game.hands[3].length}",
      );

      int cp = game.currentPlayer;
      if (cp == 0) {
        // Human Turn
        print(
          "Your Hand: ${game.hands[0].asMap().entries.map((e) => '${e.key}: ${e.value}').join(', ')}",
        );
        List<Action> legalActions = game.getLegalActions(0);

        print("Legal Actions:");
        for (int i = 0; i < legalActions.length; i++) {
          print("$i: ${legalActions[i]}");
        }

        // Auto-play for CLI simulation
        Action chosenAction = legalActions[0];
        print("P0 (Human) chooses: $chosenAction");
        game.applyAction(chosenAction);
      } else {
        // AI Turn
        print("\nP$cp (AI) is thinking...");
        Stopwatch stopwatch = Stopwatch()..start();

        Action aiAction = await getBestActionAsync(game, cp, 1000);

        stopwatch.stop();
        print(
          "P$cp chooses: $aiAction (took ${stopwatch.elapsedMilliseconds}ms)",
        );
        game.applyAction(aiAction);
      }
    }

    print("\n--- Round ${match.roundNumber} Over ---");
    print("Final Board: ${game.board.join(' ')}");
    for (int i = 0; i < 4; i++) {
      print(
        "P$i Hand Remaining: ${game.hands[i]} (Pips: ${game.hands[i].fold(0, (sum, t) => sum + t.score)})",
      );
    }

    int roundWinner = match.recordRoundResult();

    if (roundWinner != -1) {
      print(">> Player $roundWinner wins the round!");
    } else {
      print(">> Round is a draw!");
    }
  }

  print("\n==================================================");
  print("=== MATCH OVER ===");
  print(
    "FINAL SCORE - P0: ${match.scores[0]} | P1: ${match.scores[1]} | P2: ${match.scores[2]} | P3: ${match.scores[3]}",
  );

  int winner = match.matchWinner;
  if (winner != -1) {
    print("🏆 PLAYER $winner WINS THE MATCH! 🏆");
  } else {
    print("It's a tie!");
  }
}
