import 'dart:math';
import 'dart:isolate';
import 'package:flutter/foundation.dart' show kIsWeb;

enum DifficultyLevel { rookie, casual, professional, legend }

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
  ScoringMode scoringMode;
  List<int> matchScores;
  int matchTarget;

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
    this.scoringMode = ScoringMode.points100,
    List<int>? matchScores,
    this.matchTarget = 100,
  }) : board = board ?? [],
       matchScores = matchScores ?? [0, 0, 0, 0],
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
      scoringMode: scoringMode,
      matchScores: List<int>.from(matchScores),
      matchTarget: matchTarget,
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

class MCTSPlayer {
  final int playerId;
  final DifficultyLevel difficulty;
  final Random random = Random();

  MCTSPlayer(this.playerId, {this.difficulty = DifficultyLevel.professional});

  /// Determinization: Randomly assign unknown tiles to opponents respecting game history constraints
  GameModel determinize(GameModel state) {
    GameModel detState = state.clone();

    // Collect all unknown tiles (opponents' hands)
    List<DominoTile> unknownTiles = [];
    List<int> needed = List.filled(4, 0);
    List<Set<int>> voids = List.generate(4, (_) => <int>{});
    
    // --- DIFFICULTY-BASED MEMORY (HISTORY AWARENESS) ---
    // Rookie: 0% memory of passes
    // Casual: 50% memory of passes
    // Pro/Legend: 100% memory of passes
    double memoryRetention = 1.0;
    if (difficulty == DifficultyLevel.rookie) {
      memoryRetention = 0.0;
    } else if (difficulty == DifficultyLevel.casual) {
      memoryRetention = 0.5;
    }

    if (memoryRetention > 0) {
      for (int i = 0; i < 4; i++) {
        for (int suit in detState.passedSuits[i]) {
          if (random.nextDouble() < memoryRetention) {
            voids[i].add(suit);
          }
        }
      }
    }

    for (int i = 0; i < 4; i++) {
      if (i != playerId) {
        unknownTiles.addAll(detState.hands[i]);
        needed[i] = detState.hands[i].length;
        detState.hands[i] = []; // Clear for reassignment
      }
    }

    // --- LEGEND: Probabilistic Weighting ---
    // If not Legend, we just shuffle randomly.
    // If Legend, we track which tiles are more likely to be in which hands.
    if (difficulty == DifficultyLevel.legend) {
      // In this IS-MCTS, we don't have deep history here, 
      // but detState.passedSuits IS the history we have.
      // We already use passedSuits to filter absolutely impossible tiles.
      // For Legend, we could also track 'strategic skips' if we had a move history.
      // Since we don't have move history in GameModel yet, 
      // we'll focus on the absolute constraints (passedSuits) which are already handled in assignTilesRec.
      // Optimization: We will prioritize the search in assignTilesRec 
      // to find 'valid' determinizations faster.
    }

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

    int effectiveTimeLimit = timeLimitMs;
    int iterationLimit = 100000; // Default high limit

    // Rookie level adjustments: 50% chance of a completely random move
    if (difficulty == DifficultyLevel.rookie) {
      if (random.nextDouble() < 0.5) {
        Action randomAction =
            rootLegalActions[random.nextInt(rootLegalActions.length)];
        print(
          "AI [$playerId ROOKIE]: Choosing RANDOM MOVE $randomAction instead of MCTS.",
        );
        return randomAction;
      }
      // If not doing a random move, use very little time for MCTS
      effectiveTimeLimit = 50;
      iterationLimit = 15; // Extremely shallow for Rookies
    } else if (difficulty == DifficultyLevel.casual) {
      effectiveTimeLimit = 500;
      iterationLimit = 100;
    } else if (difficulty == DifficultyLevel.legend) {
      effectiveTimeLimit = 3500;
      iterationLimit = 100000; // No real limit
    } else {
      // Professional (default)
      effectiveTimeLimit = 1000;
      iterationLimit = 500;
    }

    MCTSNode rootNode = MCTSNode(player: (rootState.currentPlayer - 1 + 4) % 4);
    Stopwatch sw = Stopwatch()..start();
    int iterations = 0;
    int nodeCount = 0;

    // 1-4. Main MCTS loop: Selection, Expansion, Simulation, Backpropagation
    while (sw.elapsedMilliseconds < effectiveTimeLimit &&
        iterations < iterationLimit) {
      iterations++;
      
      // Early Exit Logic for Legend
      if (difficulty == DifficultyLevel.legend && iterations > 1000 && sw.elapsedMilliseconds > 1500) {
        // Simple check if one move is significantly better (2x visits)
        List<MCTSNode> children = rootNode.children.values.toList();
        if (children.length > 1) {
          children.sort((a, b) => b.visits.compareTo(a.visits));
          if (children[0].visits > children[1].visits * 2) {
            print("AI [$playerId LEGEND]: Early Exit! Convergence achieved after $iterations iterations.");
            break;
          }
        }
      }

      // 1. Determinization
      GameModel state = determinize(rootState);
      MCTSNode node = rootNode;

      // 2. Selection
      while (!state.isGameOver) {
        List<Action> legalActions = state.getLegalActions(state.currentPlayer);

        for (var a in legalActions) {
          node.availabilityCount[a] = (node.availabilityCount[a] ?? 0) + 1;
        }

        List<Action> untried = legalActions
            .where((a) => !node.children.containsKey(a))
            .toList();

        if (untried.isNotEmpty) {
          // 3. Expansion
          if (nodeCount > 1000000) break; // Memory Guard
          
          Action actionToTry = untried[random.nextInt(untried.length)];
          int movingPlayer = state.currentPlayer;
          state.applyAction(actionToTry);

          MCTSNode childNode = MCTSNode(
            action: actionToTry,
            parent: node,
            player: movingPlayer,
          );
          nodeCount++;
          node.children[actionToTry] = childNode;
          node = childNode;
          break;
        } else {
          // UCB decay logic for Legend
          double explorationParam = 1.414;
          if (difficulty == DifficultyLevel.legend) {
            double progress = sw.elapsedMilliseconds / effectiveTimeLimit;
            explorationParam = 1.414 - (0.714 * progress); // Decay from 1.414 to 0.7
          }
          
          MCTSNode? bestChild = node.getBestChild(legalActions, explorationParam);
          if (bestChild == null) break;

          state.applyAction(bestChild.action!);
          node = bestChild;
        }
      }

      // 4. Simulation
      // Use End-Game Solver if < 8 tiles remain
      int unknownTilesCount = 0;
      for (int i = 0; i < 4; i++) {
        if (i != playerId) unknownTilesCount += state.hands[i].length;
      }
      
      bool useEndGameHeuristic = (difficulty == DifficultyLevel.legend && unknownTilesCount < 8);
      bool useRandomSimulation = (difficulty == DifficultyLevel.rookie);
      
      while (!state.isGameOver) {
        List<Action> actions = state.getLegalActions(state.currentPlayer);
        
        Action chosenAction;
        if (useRandomSimulation) {
          // --- ROOKIE: PURE RANDOM SIMULATION ---
          chosenAction = actions[random.nextInt(actions.length)];
        } else if (useEndGameHeuristic) {
          // --- LEGEND END-GAME HEURISTIC ---
          // Prioritize dumping the highest score tiles to reduce hand value immediately
          List<PlayAction> playActions = actions.whereType<PlayAction>().toList();
          if (playActions.isNotEmpty) {
            playActions.sort((a, b) => b.tile.score.compareTo(a.tile.score));
            // In endgame, we are much more likely to play the best possible move
            chosenAction = (random.nextDouble() < 0.95) ? playActions.first : playActions[random.nextInt(playActions.length)];
          } else {
            chosenAction = actions[random.nextInt(actions.length)];
          }
        } else {
          // Standard simulation (Casual, Professional)
          List<PlayAction> playActions = actions.whereType<PlayAction>().toList();
          if (playActions.isNotEmpty) {
            playActions.sort((a, b) => b.tile.score.compareTo(a.tile.score));
            chosenAction = (random.nextDouble() < 0.8) ? playActions.first : playActions[random.nextInt(playActions.length)];
          } else {
            chosenAction = actions[random.nextInt(actions.length)];
          }
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
          result = 0.5;
        } else {
          // --- ROOKIE: SIMPLE WIN/LOSS REWARD ---
          if (difficulty == DifficultyLevel.rookie) {
            result = (winner == movingPlayer) ? 1.0 : 0.0;
          } else if (state.scoringMode == ScoringMode.points100) {
            // 100-Point Mode: Focus on round win and pip efficiency
            if (winner == movingPlayer) {
              // Reward winning the match: 1.0
              // Otherwise, reward based on pips gained (0.5 to 0.9)
              int totalOpPips = 0;
              for (int i = 0; i < 4; i++) {
                if (i != winner) {
                  totalOpPips +=
                      state.hands[i].fold(0, (sum, t) => sum + t.score);
                }
              }
              int remaining =
                  max(1, state.matchTarget - state.matchScores[movingPlayer]);
              if (totalOpPips >= remaining) {
                result = 1.0;
              } else {
                result = 0.5 + 0.4 * (totalOpPips / 100.0).clamp(0.0, 1.0);
              }
            } else {
              // Penalty for losing (0.0 to 0.4)
              int myPips =
                  state.hands[movingPlayer].fold(0, (sum, t) => sum + t.score);
              result = 0.4 * (1.0 - (myPips / 100.0)).clamp(0.0, 1.0);
            }
          } else {
            // Six-Love Mode: Focus on Wins and Anti-Leader Coalition
            if (winner == movingPlayer) {
              result = 1.0;
            } else {
              // Identify the leader
              int leaderIndex = -1;
              int maxScore = 0;
              for (int i = 0; i < 4; i++) {
                if (state.matchScores[i] > maxScore) {
                  maxScore = state.matchScores[i];
                  leaderIndex = i;
                }
              }

              if (leaderIndex != -1 && winner == leaderIndex) {
                // Letting the leader win (especially near the end) is bad
                if (state.matchScores[leaderIndex] >= 5) {
                  result = 0.0;
                } else {
                  result = 0.1;
                }
              } else {
                result = 0.3; // Neutral loss
              }
            }
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
      "AI Player $playerId | Difficulty: $difficulty | Iterations: $iterations | Best Action: $bestAction | Visits: $maxVisits",
    );
    return bestAction;
  }
}

/// Wrapper for Isolate computation to prevent UI freezing
Future<Action> getBestActionAsync(
  GameModel state,
  int playerId,
  int timeLimitMs,
  DifficultyLevel difficulty,
  List<int> matchScores,
  int matchTarget,
  ScoringMode scoringMode,
) async {
  // Inject match context into the state before starting search
  state.matchScores = matchScores;
  state.matchTarget = matchTarget;
  state.scoringMode = scoringMode;

  try {
    // Attempt to run in a background worker with a 15s timeout
    return await Isolate.run(() {
      try {
        MCTSPlayer ai = MCTSPlayer(playerId, difficulty: difficulty);
        return ai.getBestAction(state, timeLimitMs: timeLimitMs);
      } catch (e, stack) {
        // Log error and rethrow to be caught by the outer try-catch
        print('Error in Isolate: $e\n$stack');
        rethrow;
      }
    }).timeout(const Duration(seconds: 15));
  } catch (e, stack) {
    // Fallback to main thread if the worker hangs or fails
    print(
      'AI Execution failed or timed out: $e. Falling back to main thread.',
    );
    print('Stack trace: $stack');
    MCTSPlayer ai = MCTSPlayer(playerId, difficulty: difficulty);
    return ai.getBestAction(state, timeLimitMs: timeLimitMs);
  }
}

/// Modes for determining match winners and round scoring
enum ScoringMode {
  /// Traditional: Accumulate points from opponent hands until target (e.g. 100)
  points100,

  /// Jamaican "Six-Love": Win 6 rounds in a row. Opponent wins reset streaks to 0
  sixLove,
}

/// Model to govern multiple rounds of dominoes up to a target score
class MatchModel {
  List<int> scores = [0, 0, 0, 0]; // 0: Human, 1-3: AIs
  int roundNumber = 1;
  int nextStarter = 0; // 0 for human, 1-3 for AI
  final int targetScore;
  ScoringMode mode;
  GameModel? currentRound;

  MatchModel({this.targetScore = 100, this.mode = ScoringMode.points100});

  bool get isMatchOver {
    if (mode == ScoringMode.sixLove) {
      // Match only ends when winner reaches 6 AND at least one opponent remains with zero wins.
      int winner = matchWinner;
      if (winner == -1) return false;
      // Someone must be at zero for the match to end
      return scores.asMap().entries.any((e) => e.key != winner && e.value == 0);
    }
    return scores.any((s) => s >= targetScore);
  }

  /// Returns true if the match winner won with an "Elite Jailer" score of 6-0-0-0.
  bool get isEliteJailer {
    if (mode != ScoringMode.sixLove) return false;
    int winner = matchWinner;
    if (winner == -1) return false;
    // Check if the winner has exactly 6 points and everyone else has 0
    return scores[winner] == 6 &&
        scores.asMap().entries.every((e) => e.key == winner || e.value == 0);
  }

  int get matchWinner {
    final int target = mode == ScoringMode.sixLove ? 6 : targetScore;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] >= target) return i;
    }
    return -1;
  }

  /// Calculates social points for the "Running Champion" standings.
  /// Returns a map of player index to point adjustments, and a flag for Elite Jailer.
  Map<String, dynamic> calculateSocialPoints() {
    List<int> adjustments = [0, 0, 0, 0];
    int winner = matchWinner;
    if (winner == -1) {
      return {'adjustments': adjustments, 'isEliteJailer': false};
    }

    adjustments[winner] += 10;
    bool allOthersZero = true;
    for (int i = 0; i < 4; i++) {
      if (i == winner) continue;
      if (scores[i] == 0) {
        adjustments[i] -= 5;
      } else {
        adjustments[i] += 2;
        allOthersZero = false;
      }
    }
    return {'adjustments': adjustments, 'isEliteJailer': allOthersZero};
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
      if (mode == ScoringMode.sixLove) {
        // Six-Love: Winner gets 1 win point.
        scores[winner]++;
        // The Reset (Game Bruk): If all players now have > 0 wins,
        // AND no one has hit 6 yet, reset all to zero.
        if (scores.every((s) => s > 0) && scores.every((s) => s < 6)) {
          for (int i = 0; i < scores.length; i++) {
            scores[i] = 0;
          }
        }
      } else {
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
      'mode': mode.name,
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
    match.mode = ScoringMode.values.firstWhere(
      (m) => m.name == (json['mode'] ?? 'points100'),
      orElse: () => ScoringMode.points100,
    );
    return match;
  }
}

// End of file
