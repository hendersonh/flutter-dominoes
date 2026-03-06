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
  List<DominoTile> boneyard;
  List<Set<int>>
  passedSuits; // [0] for p0, [1] for p1 - suits they passed/drew on
  int? leftEnd;
  int? rightEnd;
  int currentPlayer;
  int consecutivePasses;
  int rootIndex = 0;
  List<DominoTile> board; // Just for visualization

  GameModel({
    required this.hands,
    required this.boneyard,
    List<Set<int>>? passedSuits,
    this.leftEnd,
    this.rightEnd,
    this.currentPlayer = 0,
    this.consecutivePasses = 0,
    this.rootIndex = 0,
    List<DominoTile>? board,
  }) : board = board ?? [],
       passedSuits = passedSuits ?? [{}, {}];

  GameModel clone() {
    return GameModel(
      hands: [List.from(hands[0]), List.from(hands[1])],
      boneyard: List.from(boneyard),
      passedSuits: passedSuits.map((s) => Set<int>.from(s)).toList(),
      leftEnd: leftEnd,
      rightEnd: rightEnd,
      currentPlayer: currentPlayer,
      consecutivePasses: consecutivePasses,
      rootIndex: rootIndex,
      board: List.from(board),
    );
  }

  bool get isGameOver {
    if (hands[0].isEmpty || hands[1].isEmpty) return true;
    if (consecutivePasses >= 2) return true; // Blocked game
    return false;
  }

  int get winner {
    if (!isGameOver) return -1;
    if (hands[0].isEmpty) return 0;
    if (hands[1].isEmpty) return 1;

    // Blocked game: player with lowest score in hand wins
    int score0 = hands[0].fold(0, (sum, tile) => sum + tile.score);
    int score1 = hands[1].fold(0, (sum, tile) => sum + tile.score);

    if (score0 < score1) return 0;
    if (score1 < score0) return 1;
    return -1; // Draw
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
      for (var tile in hands[player]) {
        actions.add(PlayAction(tile, 'left', isFirstMove: true));
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
      if (boneyard.isNotEmpty) {
        actions.add(DrawAction());
      } else {
        actions.add(PassAction());
      }
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
      currentPlayer = 1 - currentPlayer;
    } else if (action is DrawAction) {
      // If they had to draw, they don't have the left or right ends
      if (leftEnd != null) passedSuits[currentPlayer].add(leftEnd!);
      if (rightEnd != null) passedSuits[currentPlayer].add(rightEnd!);

      if (boneyard.isNotEmpty) {
        // Since we drew an unknown tile, it could be ANY suit.
        // Therefore, we must clear our historical voids to be logically safe.
        passedSuits[currentPlayer].clear();

        DominoTile drawnTile = boneyard.removeLast();
        hands[currentPlayer].add(drawnTile);
      }

      // Re-apply the void for the CURRENT ends, because if we cannot play
      // the newly drawn tile, it definitely doesn't match the current ends.
      if (leftEnd != null) passedSuits[currentPlayer].add(leftEnd!);
      if (rightEnd != null) passedSuits[currentPlayer].add(rightEnd!);
      // Current player remains the same to play or draw again
    } else if (action is PassAction) {
      // If they passed, they don't have the left or right ends
      if (leftEnd != null) passedSuits[currentPlayer].add(leftEnd!);
      if (rightEnd != null) passedSuits[currentPlayer].add(rightEnd!);

      consecutivePasses++;
      currentPlayer = 1 - currentPlayer;
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

  /// Determinization: Randomly assign unknown tiles to opponent and boneyard respecting game history constraints
  GameModel determinize(GameModel state) {
    GameModel detState = state.clone();
    int opponentId = 1 - playerId;

    // Collect all unknown tiles (opponent hand + boneyard)
    List<DominoTile> unknownTiles = [];
    unknownTiles.addAll(detState.hands[opponentId]);
    unknownTiles.addAll(detState.boneyard);

    // Shuffle unknown tiles
    unknownTiles.shuffle(random);

    // Constraints: Opponent cannot have tiles with suits they previously passed on
    Set<int> opponentVoids = detState.passedSuits[opponentId];

    for (int attempts = 0; attempts < 20; attempts++) {
      unknownTiles.shuffle(random);

      List<DominoTile> validOpponentHand = [];
      List<DominoTile> remainingForBoneyard = [];

      int opponentHandSize = detState.hands[opponentId].length;

      for (var tile in unknownTiles) {
        if (validOpponentHand.length < opponentHandSize) {
          bool canOpponentHave = true;
          for (int voidSuit in opponentVoids) {
            if (tile.contains(voidSuit)) {
              canOpponentHave = false;
              break;
            }
          }

          if (canOpponentHave) {
            validOpponentHand.add(tile);
          } else {
            remainingForBoneyard.add(tile);
          }
        } else {
          remainingForBoneyard.add(tile);
        }
      }

      if (validOpponentHand.length == opponentHandSize) {
        detState.hands[opponentId] = validOpponentHand;
        detState.boneyard = remainingForBoneyard;
        return detState;
      }
    }

    // Fallback exactly as before if mathematically forced to relax constraints
    List<DominoTile> validOpponentHand = [];
    List<DominoTile> remainingForBoneyard = [];
    int opponentHandSize = detState.hands[opponentId].length;

    for (var tile in unknownTiles) {
      if (validOpponentHand.length < opponentHandSize) {
        bool canOpponentHave = true;
        for (int voidSuit in opponentVoids) {
          if (tile.contains(voidSuit)) {
            canOpponentHave = false;
            break;
          }
        }

        if (canOpponentHave) {
          validOpponentHand.add(tile);
        } else {
          remainingForBoneyard.add(tile);
        }
      } else {
        remainingForBoneyard.add(tile);
      }
    }

    if (validOpponentHand.length < opponentHandSize) {
      int needed = opponentHandSize - validOpponentHand.length;
      validOpponentHand.addAll(remainingForBoneyard.take(needed));
      remainingForBoneyard.removeRange(0, needed);
    }

    detState.hands[opponentId] = validOpponentHand;
    detState.boneyard = remainingForBoneyard;

    return detState;
  }

  Action getBestAction(GameModel rootState, {int timeLimitMs = 1500}) {
    List<Action> rootLegalActions = rootState.getLegalActions(playerId);
    if (rootLegalActions.length == 1) return rootLegalActions[0];

    MCTSNode rootNode = MCTSNode(player: 1 - playerId);
    Stopwatch sw = Stopwatch()..start();

    while (sw.elapsedMilliseconds < timeLimitMs) {
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
      double result = 0.0;
      if (winner == -1) {
        result = 0.5; // Natural Draw
      } else {
        // Evaluate win/loss magnitude based on pip differential
        int myScore = state.hands[playerId].fold(0, (sum, t) => sum + t.score);
        int opScore = state.hands[1 - playerId].fold(
          0,
          (sum, t) => sum + t.score,
        );
        int scoreDiff = (opScore - myScore).abs();

        if (winner == playerId) {
          // Win: Guarantee > 0.5 (base 0.6 + up to 0.4 for margin)
          result = 0.6 + 0.4 * (scoreDiff / 100.0).clamp(0.0, 1.0);
        } else {
          // Loss: Guarantee < 0.5 (base 0.4 - up to 0.4 for margin)
          result = 0.4 - 0.4 * (scoreDiff / 100.0).clamp(0.0, 1.0);
        }
      }

      while (node.parent != null) {
        // node.player is the player who made the move to reach this node
        node.update(node.player == playerId ? result : 1.0 - result);
        node = node.parent!;
      }
      rootNode.update(result);
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
  int humanScore = 0;
  int aiScore = 0;
  int roundNumber = 1;
  int nextStarter = 0; // 0 for human, 1 for AI
  final int targetScore;
  GameModel? currentRound;

  MatchModel({this.targetScore = 150});

  bool get isMatchOver => humanScore >= targetScore || aiScore >= targetScore;

  int get matchWinner {
    if (humanScore >= targetScore && humanScore > aiScore) return 0;
    if (aiScore >= targetScore && aiScore > humanScore) return 1;
    return -1;
  }

  void startNewRound(int startingPlayer) {
    List<DominoTile> allTiles = [];
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        allTiles.add(DominoTile(i, j));
      }
    }
    allTiles.shuffle();

    List<DominoTile> humanHand = allTiles.sublist(0, 7);
    List<DominoTile> aiHand = allTiles.sublist(7, 14);
    List<DominoTile> boneyard = allTiles.sublist(14);

    currentRound = GameModel(
      hands: [humanHand, aiHand],
      boneyard: boneyard,
      currentPlayer: startingPlayer,
    );
  }

  /// Records the result of the current round and advances to the next.
  /// Returns the winner of the round, or -1 for a tie.
  int recordRoundResult() {
    if (currentRound == null) return -1;
    int winner = currentRound!.winner;

    int p0Remaining = currentRound!.hands[0].fold(0, (sum, t) => sum + t.score);
    int p1Remaining = currentRound!.hands[1].fold(0, (sum, t) => sum + t.score);

    if (winner == 0) {
      humanScore += (p1Remaining - p0Remaining).abs();
    } else if (winner == 1) {
      aiScore += (p0Remaining - p1Remaining).abs();
    }
    // If draw (winner == -1), no score is awarded.

    roundNumber++;
    // Set next starter based on previous round winner
    if (winner == 0) {
      nextStarter = 0;
    } else if (winner == 1) {
      nextStarter = 1;
    }
    return winner;
  }

  Map<String, dynamic> toJson() {
    return {
      'humanScore': humanScore,
      'aiScore': aiScore,
      'roundNumber': roundNumber,
      'targetScore': targetScore,
      'nextStarter': nextStarter,
    };
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final match = MatchModel(targetScore: json['targetScore'] ?? 150);
    match.humanScore = json['humanScore'] ?? 0;
    match.aiScore = json['aiScore'] ?? 0;
    match.roundNumber = json['roundNumber'] ?? 1;
    match.nextStarter = json['nextStarter'] ?? 0;
    return match;
  }
}

/// Main function to simulate a Human vs AI Match
void main() async {
  print("=== Draw Dominoes: Human vs AI Match (IS-MCTS) ===");
  print("Target Score: 150 points");

  MatchModel match = MatchModel(targetScore: 150);
  int nextStarter = 0; // Human starts first round

  while (!match.isMatchOver) {
    print("\n==================================================");
    print("MATCH SCORE - Human: ${match.humanScore} | AI: ${match.aiScore}");
    print("--- ROUND ${match.roundNumber} ---");

    match.startNewRound(nextStarter);
    GameModel game = match.currentRound!;

    while (!game.isGameOver) {
      print("\n--------------------------------------------------");
      print("Board: ${game.board.isEmpty ? 'Empty' : game.board.join(' ')}");
      print("Ends: [${game.leftEnd ?? '?'} | ${game.rightEnd ?? '?'}]");
      print("Boneyard: ${game.boneyard.length} tiles");
      print("AI Hand: ${game.hands[1].length} tiles");

      if (game.currentPlayer == 0) {
        // Human Turn
        print(
          "Your Hand: ${game.hands[0].asMap().entries.map((e) => '${e.key}: ${e.value}').join(', ')}",
        );
        List<Action> legalActions = game.getLegalActions(0);

        print("Legal Actions:");
        for (int i = 0; i < legalActions.length; i++) {
          print("$i: ${legalActions[i]}");
        }

        // Auto-play for CLI simulation (Always picks first legal move)
        // In a real CLI, we would use stdin.readLineSync()
        Action chosenAction = legalActions[0];
        print("Human chooses: $chosenAction");
        game.applyAction(chosenAction);
      } else {
        // AI Turn
        print("\nAI is thinking...");
        Stopwatch stopwatch = Stopwatch()..start();

        // 3 seconds for CLI simulation so games don't take forever,
        // 10s is overkill for a continuous test loop
        Action aiAction = await getBestActionAsync(game, 1, 3000);

        stopwatch.stop();
        print(
          "AI chooses: $aiAction (took ${stopwatch.elapsedMilliseconds}ms)",
        );
        game.applyAction(aiAction);
      }
    }

    print("\n--- Round ${match.roundNumber} Over ---");
    print("Final Board: ${game.board.join(' ')}");
    print(
      "Human Hand Remaining: ${game.hands[0]} (Pips: ${game.hands[0].fold(0, (sum, t) => sum + t.score)})",
    );
    print(
      "AI Hand Remaining: ${game.hands[1]} (Pips: ${game.hands[1].fold(0, (sum, t) => sum + t.score)})",
    );

    int roundWinner = match.recordRoundResult();

    if (roundWinner == 0) {
      print(">> Human wins the round!");
      nextStarter = 0; // Winner starts next round
    } else if (roundWinner == 1) {
      print(">> AI wins the round!");
      nextStarter = 1;
    } else {
      print(">> Round is a draw!");
      // Starter remains the same
    }
  }

  print("\n==================================================");
  print("=== MATCH OVER ===");
  print("FINAL SCORE - Human: ${match.humanScore} | AI: ${match.aiScore}");

  if (match.matchWinner == 0) {
    print("🏆 HUMAN WINS THE MATCH! 🏆");
  } else if (match.matchWinner == 1) {
    print("🤖 AI WINS THE MATCH! 🤖");
  } else {
    print("It's a tie!");
  }
}
