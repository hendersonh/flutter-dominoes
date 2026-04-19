import 'dart:math';
import 'dart:isolate';
import 'dart:async';

// Use a pure Dart way to detect web, removing the dependency on package:flutter
const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

enum DifficultyLevel { rookie, casual, professional, legend }

enum PlayStyle { cutThroat, partners }

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
  PlayStyle playStyle;
  List<int> matchScores;
  int matchTarget;

  // Track the last action for round-end scoring (Key Bone etc.)
  DominoTile? lastPlayedTile;
  bool wasLastActionPlay = false;

  // Inference markers for Partner Mode
  List<Map<int, double>> playSpeeds; // [player][suit] -> seconds

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
    this.scoringMode = ScoringMode.traditional,
    this.playStyle = PlayStyle.cutThroat,
    List<int>? matchScores,
    this.matchTarget = 100,
    List<Map<int, double>>? playSpeeds,
  }) : board = board ?? [],
       matchScores = matchScores ?? [0, 0, 0, 0],
       passedSuits = passedSuits ?? [{}, {}, {}, {}],
       playSpeeds = playSpeeds ?? [{}, {}, {}, {}];

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
        playStyle: playStyle,
        matchScores: List<int>.from(matchScores),
        matchTarget: matchTarget,
        playSpeeds: playSpeeds.map((m) => Map<int, double>.from(m)).toList(),
      )
      ..lastPlayedTile = lastPlayedTile
      ..wasLastActionPlay = wasLastActionPlay;
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

    // Check if anyone played their last tile
    for (int i = 0; i < 4; i++) {
      if (hands[i].isEmpty) return i;
    }

    // Blocked game: compare pip counts
    List<int> pipCounts = hands
        .map((h) => h.fold(0, (sum, t) => sum + t.score))
        .toList();

    if (playStyle == PlayStyle.partners) {
      // TEAM TOTALS: Team 1 (0+2) vs Team 2 (1+3)
      int team1Pips = pipCounts[0] + pipCounts[2];
      int team2Pips = pipCounts[1] + pipCounts[3];

      if (team1Pips < team2Pips) {
        // Individual winner on Team 1 is the one with fewer pips
        return pipCounts[0] <= pipCounts[2] ? 0 : 2;
      } else if (team2Pips < team1Pips) {
        // Individual winner on Team 2 is the one with fewer pips
        return pipCounts[1] <= pipCounts[3] ? 1 : 3;
      } else {
        // EXACT TIE in team totals = Draw (Tie)
        return -1;
      }
    } else {
      // Cut-throat: find individual with lowest pip count
      int minPips = pipCounts.reduce(min);

      // Check for ties (Draw)
      List<int> minPlayers = [];
      for (int i = 0; i < 4; i++) {
        if (pipCounts[i] == minPips) minPlayers.add(i);
      }

      if (minPlayers.length > 1) {
        return -1; // Cut-throat tie = Draw
      }

      return pipCounts.indexOf(minPips);
    }
  }

  /// Returns true if the board ends are both "Hard" (no more tiles of that suit available).
  bool get isBoardHard {
    if (leftEnd == null || rightEnd == null) return false;
    final counts = pipsOnBoard;
    return counts[leftEnd!] == 8 && counts[rightEnd!] == 8;
  }

  /// Check if the winning move was a Key Bone (+2 points).
  /// A Key Bone is a non-double that wins on two Hard Ends.
  bool isKeyBone(PlayAction action) {
    if (action.tile.isDouble) return false;
    // We check if the board IS ALREADY hard or BECOMES hard after this play.
    final counts = pipsOnBoard;
    // Note: suiteCounts includes the tile just played if board already updated.
    // If called BEFORE applyAction, we check if they are at 7.
    return counts[leftEnd!] == 8 && counts[rightEnd!] == 8;
  }

  /// Identifies the "Victim" player in Six-Love mode (exactly one player at 0 wins).
  /// Returns -1 if no singular victim exists or not in Six-Love mode.
  int get victimId {
    if (scoringMode != ScoringMode.sixLove) return -1;
    int zeroCount = 0;
    int victim = -1;
    for (int i = 0; i < matchScores.length; i++) {
      if (matchScores[i] == 0) {
        zeroCount++;
        victim = i;
      }
    }
    return zeroCount == 1 ? victim : -1;
  }

  bool canPlayerPlay(int player) {
    if (board.isEmpty) return hands[player].isNotEmpty;
    // board.isEmpty is false, so leftEnd and rightEnd must be non-null.
    for (var tile in hands[player]) {
      if (tile.contains(leftEnd!) || tile.contains(rightEnd!)) return true;
    }
    return false;
  }

  /// Returns the number of pips (ends) presented for each suit (0-6) on the board.
  /// Each non-double tile contributes 1 pip to each of its two suits.
  /// Each double tile contributes 2 pips to its suit.
  /// Total pips for any suit in a standard 28-tile set is 8.
  Map<int, int> get pipsOnBoard {
    Map<int, int> counts = {for (int i = 0; i <= 6; i++) i: 0};
    for (var tile in board) {
      counts[tile.end1] = counts[tile.end1]! + 1;
      counts[tile.end2] = counts[tile.end2]! + 1;
    }
    return counts;
  }

  /// Returns the count of tiles containing each suit (0-6).
  /// Max count for any suit is 7.
  Map<int, int> get tileCountsOnBoard {
    Map<int, int> counts = {for (int i = 0; i <= 6; i++) i: 0};
    for (var tile in board) {
      counts[tile.end1] = (counts[tile.end1] ?? 0) + 1;
      if (!tile.isDouble) {
        counts[tile.end2] = (counts[tile.end2] ?? 0) + 1;
      }
    }
    return counts;
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
      lastPlayedTile = action.tile;
      wasLastActionPlay = true;
      consecutivePasses = 0;
      currentPlayer = (currentPlayer + 1) % 4;
    } else if (action is PassAction) {
      // If they passed, they don't have the left or right ends
      if (leftEnd != null) passedSuits[currentPlayer].add(leftEnd!);
      if (rightEnd != null) passedSuits[currentPlayer].add(rightEnd!);

      wasLastActionPlay = false;
      consecutivePasses++;
      currentPlayer = (currentPlayer + 1) % 4;
    }
  }
}


/// Information Set MCTS Node
class MCTSNode {
  final Action? action;
  MCTSNode? parent;
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

  /// Prunes the tree, returning the child node for the given action and detaching it from the parent.
  /// If no child exists for the action, returns a fresh node.
  MCTSNode prune(Action action, int nextPlayer) {
    var child = children[action];
    if (child != null) {
      child.parent = null;
      return child;
    }
    // Fallback: entire tree is invalid for this move (rare if search was deep)
    return MCTSNode(action: action, player: nextPlayer);
  }

  /// Selects the best child using the UCB1 formula modified for Information Sets.
  /// Only considers children that correspond to legal actions in the current determinized state.
  MCTSNode? getBestChild(
    List<Action> legalActions,
    double explorationParam, {
    int victimId = -1,
    List<Set<int>>? passedSuits,
    List<Map<int, double>>? playSpeeds,
    int? currentLeft,
    int? currentRight,
    PlayStyle playStyle = PlayStyle.cutThroat,
    List<int>? teamScores,
  }) {
    MCTSNode? bestChild;
    double bestValue = -double.infinity;

    for (var action in legalActions) {
      var child = children[action];
      if (child != null) {
        int ni = child.visits;
        int Ni = availabilityCount[action] ?? 1;

        double ucb1 = (child.wins / ni) + explorationParam * sqrt(log(Ni) / ni);

        // --- PARTNER HEURISTICS ---
        if (playStyle == PlayStyle.partners &&
            action is PlayAction &&
            currentLeft != null &&
            currentRight != null &&
            passedSuits != null) {
          int actingPlayer = (player + 1) % 4;
          int partnerId = (actingPlayer + 2) % 4;

          int? nextLeft = currentLeft;
          int? nextRight = currentRight;
          if (action.side == 'left') {
            nextLeft = (action.tile.end1 == currentLeft)
                ? action.tile.end2
                : action.tile.end1;
          } else {
            nextRight = (action.tile.end1 == currentRight)
                ? action.tile.end2
                : action.tile.end1;
          }

          // 1. THE SHIELD: Don't open for partner's void
          final partnerVoids = passedSuits[partnerId];
          if (partnerVoids.contains(nextLeft) ||
              partnerVoids.contains(nextRight)) {
            // If we are leading in Six-Love, liquidation is catastrophic
            if (teamScores != null && teamScores[player % 2] > 0) {
              ucb1 -= 0.40; // THE SHIELD (Lead Protection)
            } else {
              ucb1 -= 0.15; // Standard Defensive Shield
            }
          }

          // 2. THE SQUEEZE: Open for opponent's void
          int opp1 = (actingPlayer + 1) % 4;
          int opp2 = (actingPlayer + 3) % 4;
          if (passedSuits[opp1].contains(nextLeft) ||
              passedSuits[opp1].contains(nextRight) ||
              passedSuits[opp2].contains(nextLeft) ||
              passedSuits[opp2].contains(nextRight)) {
            ucb1 += 0.10; // THE SQUEEZE
          }

          // 3. THE ASSIST / THE TELL: Partner Weakness or Strength
          if (playSpeeds != null) {
            final speeds = playSpeeds[partnerId];
            // Tell 1: Snap Play (< 1.5s). Means they had no choices (only one valid tile). Weak.
            if ((speeds[nextLeft] != null && speeds[nextLeft]! < 1.5) ||
                (speeds[nextRight] != null && speeds[nextRight]! < 1.5)) {
              ucb1 -= 0.05; // Avoid leading back to a 'snap play' end
            }
            // Tell 2: Hesitation (> 3.0s). Means they weighed multiple choices. Strong.
            else if ((speeds[nextLeft] != null && speeds[nextLeft]! > 3.0) ||
                     (speeds[nextRight] != null && speeds[nextRight]! > 3.0)) {
              ucb1 += 0.05; // THE ASSIST
            }
          }
        }

        // --- ZERO SCORE PROTOCOL (ZSP) ---
        if (victimId != -1 &&
            passedSuits != null &&
            action is PlayAction &&
            currentLeft != null &&
            currentRight != null) {
          int? nextLeft = currentLeft;
          int? nextRight = currentRight;
          if (action.side == 'left') {
            nextLeft = (action.tile.end1 == currentLeft)
                ? action.tile.end2
                : action.tile.end1;
          } else {
            nextRight = (action.tile.end1 == currentRight)
                ? action.tile.end2
                : action.tile.end1;
          }
          final voids = passedSuits[victimId];
          if (!voids.contains(nextLeft) && !voids.contains(nextRight)) {
            ucb1 -= 0.30; // ZSP Penalty
          }
        }

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


  MCTSNode? lastRoot;

  Action getBestAction(
    GameModel rootState, {
    int timeLimitMs = 1500,
    MCTSNode? existingRoot,
    List<int>? matchScores,
    int? matchTarget,
    ScoringMode? scoringMode,
  }) {
    lastRoot = existingRoot ?? MCTSNode(player: (playerId + 3) % 4);
    List<Action> rootLegalActions = rootState.getLegalActions(playerId);
    if (rootLegalActions.length == 1) return rootLegalActions[0];

    int effectiveTimeLimit = timeLimitMs;
    int iterationLimit = 200000; // Default high limit

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
      iterationLimit = 200000; // Increased for high-precision Legend
    } else {
      // Professional (default)
      effectiveTimeLimit = 1000;
      iterationLimit = 500;
    }

    MCTSNode rootNode = existingRoot ?? MCTSNode(player: (rootState.currentPlayer - 1 + 4) % 4);
    lastRoot = rootNode;

    Stopwatch sw = Stopwatch()..start();
    int iterations = 0;
    int nodeCount = 0;

    // 1-4. Main MCTS loop: Selection, Expansion, Simulation, Backpropagation
    while (sw.elapsedMilliseconds < effectiveTimeLimit &&
        iterations < iterationLimit) {
      iterations++;

      // Early Exit Logic for Legend
      if (difficulty == DifficultyLevel.legend &&
          iterations > 1000 &&
          sw.elapsedMilliseconds > 1500) {
        // Simple check if one move is significantly better (2x visits)
        List<MCTSNode> children = rootNode.children.values.toList();
        if (children.length > 1) {
          children.sort((a, b) => b.visits.compareTo(a.visits));
          if (children[0].visits > children[1].visits * 2) {
            print(
              "AI [$playerId LEGEND]: Early Exit! Convergence achieved after $iterations iterations.",
            );
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
            explorationParam =
                1.414 - (0.714 * progress); // Decay from 1.414 to 0.7
          }

          int victimId = rootState.victimId;
          bool isProtocolActive = (victimId != -1 && victimId != playerId);

          MCTSNode? bestChild = node.getBestChild(
            legalActions,
            explorationParam,
            victimId: isProtocolActive ? victimId : -1,
            passedSuits: state.passedSuits,
            playSpeeds: state.playSpeeds,
            currentLeft: state.leftEnd,
            currentRight: state.rightEnd,
            playStyle: rootState.playStyle,
            teamScores: rootState.playStyle == PlayStyle.partners
                ? rootState.matchScores
                : null,
          );
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

      bool useEndGameHeuristic =
          (difficulty == DifficultyLevel.legend && unknownTilesCount < 8);
      bool useRandomSimulation = (difficulty == DifficultyLevel.rookie);

      while (!state.isGameOver) {
        List<Action> actions = state.getLegalActions(state.currentPlayer);
        int victimId = rootState.victimId;
        bool isProtocolActive = (victimId != -1 && victimId != playerId);

        Action chosenAction;
        if (useRandomSimulation) {
          // --- ROOKIE: PURE RANDOM SIMULATION ---
          chosenAction = actions[random.nextInt(actions.length)];
        } else if (isProtocolActive) {
          // --- ZERO SCORE PROTOCOL: STARVATION ROLLOUT ---
          // Prioritize moves that "Maintain the Gap" (keep a victim void on the board)
          List<PlayAction> starvationMoves = actions
              .whereType<PlayAction>()
              .where((a) {
                // Predict the ends if we play this tile
                int? newLeft = state.leftEnd;
                int? newRight = state.rightEnd;
                if (a.side == 'left') {
                  newLeft = (a.tile.end1 == state.leftEnd)
                      ? a.tile.end2
                      : a.tile.end1;
                } else {
                  newRight = (a.tile.end1 == state.rightEnd)
                      ? a.tile.end2
                      : a.tile.end1;
                }

                // Is the victim void in at least one of the new ends?
                final voids = state.passedSuits[victimId];
                return (newLeft != null && voids.contains(newLeft)) ||
                    (newRight != null && voids.contains(newRight));
              })
              .toList();

          if (starvationMoves.isNotEmpty && random.nextDouble() < 0.9) {
            // Highly likely to choose a starvation move if available
            chosenAction =
                starvationMoves[random.nextInt(starvationMoves.length)];
          } else {
            // Standard pip-count heuristic as fallback
            List<PlayAction> playActions = actions
                .whereType<PlayAction>()
                .toList();
            if (playActions.isNotEmpty) {
              playActions.sort((a, b) => b.tile.score.compareTo(a.tile.score));
              chosenAction = (random.nextDouble() < 0.8)
                  ? playActions.first
                  : playActions[random.nextInt(playActions.length)];
            } else {
              chosenAction = actions[random.nextInt(actions.length)];
            }
          }
        } else if (useEndGameHeuristic) {
          // --- LEGEND END-GAME HEURISTIC ---
          // Prioritize dumping the highest score tiles to reduce hand value immediately
          List<PlayAction> playActions = actions
              .whereType<PlayAction>()
              .toList();
          if (playActions.isNotEmpty) {
            playActions.sort((a, b) => b.tile.score.compareTo(a.tile.score));
            // In endgame, we are much more likely to play the best possible move
            chosenAction = (random.nextDouble() < 0.95)
                ? playActions.first
                : playActions[random.nextInt(playActions.length)];
          } else {
            chosenAction = actions[random.nextInt(actions.length)];
          }
        } else {
          // Standard simulation (Casual, Professional)
          List<PlayAction> playActions = actions
              .whereType<PlayAction>()
              .toList();
          if (playActions.isNotEmpty) {
            playActions.sort((a, b) => b.tile.score.compareTo(a.tile.score));
            chosenAction = (random.nextDouble() < 0.8)
                ? playActions.first
                : playActions[random.nextInt(playActions.length)];
          } else {
            chosenAction = actions[random.nextInt(actions.length)];
          }
        }
        state.applyAction(chosenAction);
      }

      // 5. Backpropagation
      int winner = state.winner;
      int victimId = rootState.victimId;
      bool isPartnerMode = rootState.playStyle == PlayStyle.partners;

      // --- PRE-COMPUTED REWARD MAP (Brainstormed Perspective Shift) ---
      // This builds a fixed reward for every player BEFORE climbing the tree,
      // moving complex branching out of the performance-critical climb.
      final List<double> rewardMap = List.filled(4, 0.0);
      for (int p = 0; p < 4; p++) {
        if (winner == -1) {
          rewardMap[p] = 0.5; // Draw
        } else if (isPartnerMode) {
          // --- PARTNER REWARD POOLING ---
          if (winner % 2 == p % 2) {
            rewardMap[p] = 1.0;
            // Bonus for Key Bone (Hard Board at end of simulation)
            if (state.isBoardHard) rewardMap[p] += 0.5;
          } else {
            // Liquidator Penalty: If partner team leads and opponents win
            if (rootState.matchScores[p % 2] > 0) {
              rewardMap[p] = 0.0; // Normalized failure for liquidation
            } else {
              rewardMap[p] = 0.0;
            }
          }
        } else if (rootState.scoringMode == ScoringMode.sixLove &&
            victimId != -1) {
          // --- SIX-LOVE / ZSP REWARDS ---
          if (p == victimId) {
            // I am the victim. Survival (Bruk or Win) is my only goal.
            rewardMap[p] = (winner == p) ? 1.0 : 0.0; // Normalized victim reward
          } else {
            // I am a Jailer. COORDINATION matters more than personal glory.
            if (winner == victimId) {
              rewardMap[p] = 0.0; // FAILURE: Victim escaped! (Normalized)
            } else {
              // SUCCESS: Any jailer won, victim lost.
              // We use 1.0 for all jailers to simulate pure cooperation.
              rewardMap[p] = 1.0;
            }
          }
        } else if (rootState.scoringMode == ScoringMode.traditional) {
          // --- TRADITIONAL SCORE (Pip-based distance) ---
          if (winner == p) {
            rewardMap[p] = 1.0;
          } else {
            int myPips = state.hands[p].fold(0, (sum, t) => sum + t.score);
            rewardMap[p] = 0.4 *
                (1.0 - (myPips / 60.0))
                    .clamp(0.0, 1.0);
          }
        } else {
          // --- MATCH LEADERBOARD AWARENESS (Neutral Mode) ---
          if (winner == p) {
            rewardMap[p] = 1.0;
          } else {
            // Neutral loss logic: scale by how dangerous the leader is
            int leaderIdx = -1;
            int maxScore = 0;
            for (int i = 0; i < 4; i++) {
              if (rootState.matchScores[i] > maxScore) {
                maxScore = rootState.matchScores[i];
                leaderIdx = i;
              }
            }
            if (leaderIdx != -1 && winner == leaderIdx) {
              rewardMap[p] = (maxScore >= 5) ? 0.0 : 0.1;
            } else {
              rewardMap[p] = 0.3; // Neutral loss
            }
          }
        }
      }

      MCTSNode? currentNode = node;
      while (currentNode != null) {
        // PER-PLAYER PERSPECTIVE: Extract reward for the player who owned this decision
        double result = rewardMap[currentNode.player];
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
  try {
    // Use the global worker for persistent search and tree pruning
    return await AIWorker.instance.think(
      state,
      playerId,
      timeLimitMs,
      difficulty,
      matchScores,
      matchTarget,
      scoringMode,
    );
  } catch (e) {
    print('AI Worker failed: $e. Falling back to main thread.');
    MCTSPlayer ai = MCTSPlayer(playerId, difficulty: difficulty);
    return ai.getBestAction(
      state,
      timeLimitMs: timeLimitMs,
      matchScores: matchScores,
      matchTarget: matchTarget,
      scoringMode: scoringMode,
    );
  }
}

// --- AI WORKER PROTOCOL ---

abstract class AIWorkerMessage {}

class AIThinkMessage extends AIWorkerMessage {
  final GameModel state;
  final int playerId;
  final int timeLimitMs;
  final DifficultyLevel difficulty;
  final List<int> matchScores;
  final int matchTarget;
  final ScoringMode scoringMode;

  AIThinkMessage(
    this.state,
    this.playerId,
    this.timeLimitMs,
    this.difficulty,
    this.matchScores,
    this.matchTarget,
    this.scoringMode,
  );
}

class AIBeginThink extends AIWorkerMessage {
  final GameModel state;
  final Duration timeLimit;
  final int playerId;
  final DifficultyLevel difficulty;
  final PlayStyle playStyle;

  AIBeginThink({
    required this.state,
    required this.timeLimit,
    required this.playerId,
    required this.difficulty,
    this.playStyle = PlayStyle.cutThroat,
  });
}

class AISyncMove extends AIWorkerMessage {
  final Action action;
  final int nextPlayer;
  final GameModel state;

  AISyncMove({
    required this.action,
    required this.nextPlayer,
    required this.state,
  });
}

class AIRootReset extends AIWorkerMessage {}

class AIResponseMessage extends AIWorkerMessage {
  final Action action;
  AIResponseMessage(this.action);
}

class AIStopMessage extends AIWorkerMessage {}

/// A long-lived background worker for the AI.
/// It maintains a persistent MCTS search tree that is pruned as the game progresses.
class AIWorker {
  static final AIWorker instance = AIWorker._internal();
  AIWorker._internal();

  Isolate? _isolate;
  SendPort? _sendPort;
  Completer<Action>? _thinkCompleter;

  bool get isActive => _isolate != null;

  Future<void> _ensureStarted() async {
    if (isActive) return;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_workerEntryPoint, receivePort.sendPort);

    final events = receivePort.asBroadcastStream();
    _sendPort = await events.first as SendPort;

    events.listen((message) {
      if (message is AIResponseMessage) {
        _thinkCompleter?.complete(message.action);
        _thinkCompleter = null;
      }
    });
  }

  void beginThink(
    GameModel state,
    Duration timeLimit,
    int playerId,
    DifficultyLevel difficulty,
    PlayStyle playStyle,
  ) {
    _sendPort?.send(
      AIBeginThink(
        state: state,
        timeLimit: timeLimit,
        playerId: playerId,
        difficulty: difficulty,
        playStyle: playStyle,
      ),
    );
  }

  void syncMove(Action action, int nextPlayer, GameModel state) {
    _sendPort?.send(AISyncMove(action: action, nextPlayer: nextPlayer, state: state));
  }

  void resetRoot() {
    _sendPort?.send(AIRootReset());
  }

  /// Commands the worker to perform MCTS search and returns the best action.
  Future<Action> think(
    GameModel state,
    int playerId,
    int timeLimitMs,
    DifficultyLevel difficulty,
    List<int> matchScores,
    int matchTarget,
    ScoringMode scoringMode,
  ) async {
    await _ensureStarted();
    _thinkCompleter = Completer<Action>();
    _sendPort?.send(AIThinkMessage(
      state,
      playerId,
      timeLimitMs,
      difficulty,
      matchScores,
      matchTarget,
      scoringMode,
    ));
    return _thinkCompleter!.future;
  }

  void stop() {
    _isolate?.kill();
    _isolate = null;
    _sendPort = null;
  }

  static void _workerEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    Map<int, MCTSNode> playerRoots = {};

    receivePort.listen((message) {
      if (message is AIRootReset) {
        playerRoots.clear();
      } else if (message is AISyncMove) {
        playerRoots.forEach((id, root) {
          playerRoots[id] = root.prune(message.action, message.nextPlayer);
        });
      } else if (message is AIThinkMessage) {
        final state = message.state;
        final playerId = message.playerId;

        if (!playerRoots.containsKey(playerId)) {
          playerRoots[playerId] = MCTSNode(player: (playerId + 3) % 4);
        }

        final player = MCTSPlayer(playerId, difficulty: message.difficulty);
        final action = player.getBestAction(
          state,
          timeLimitMs: message.timeLimitMs,
          existingRoot: playerRoots[playerId],
          matchScores: message.matchScores,
          matchTarget: message.matchTarget,
          scoringMode: message.scoringMode,
        );

        mainSendPort.send(AIResponseMessage(action));
        // Update persistent root to the one used for search
        if (player.lastRoot != null) {
          playerRoots[playerId] = player.lastRoot!;
        }
      } else if (message is AIStopMessage) {
        Isolate.exit();
      }
    });
  }
}

/// Modes for determining match winners and round scoring
enum ScoringMode {
  /// Traditional: Accumulate points from opponent hands until target (e.g. 100, 150, 200)
  traditional,

  /// Jamaican "Six-Love": Win 6 rounds in a row. Opponent wins reset streaks to 0
  sixLove,
}

/// Model to govern multiple rounds of dominoes up to a target score
class MatchModel {
  List<int> scores = [0, 0, 0, 0]; // 0: Human, 1-3: AIs
  int roundNumber = 1;
  int nextStarter = 0; // 0 for human, 1-3 for AI
  int targetScore;
  ScoringMode mode;
  PlayStyle playStyle;
  int pendingBonus = 0; // Cumulative bonus for Draws
  bool gameBrukOccurred = false;
  GameModel? currentRound;

  MatchModel({
    this.targetScore = 100,
    this.mode = ScoringMode.traditional,
    this.playStyle = PlayStyle.cutThroat,
  });

  MatchModel clone() {
    return MatchModel(
      targetScore: targetScore,
      mode: mode,
      playStyle: playStyle,
    )
      ..scores = List<int>.from(scores)
      ..roundNumber = roundNumber
      ..nextStarter = nextStarter
      ..pendingBonus = pendingBonus
      ..gameBrukOccurred = gameBrukOccurred
      ..currentRound = currentRound?.clone();
  }

  bool get isMatchOver => matchWinner != -1;

  /// Returns true if the match winner won with an "Elite Jailer" score of 6-0-0-0 or team 6-0.
  bool get isEliteJailer {
    if (mode != ScoringMode.sixLove) return false;
    int winner = matchWinner;
    if (winner == -1) return false;

    if (playStyle == PlayStyle.partners) {
      int winnerTeam = winner % 2; // 0 or 1
      int opp1 = 1 - winnerTeam;
      int opp2 = 3 - winnerTeam;
      return (scores[winnerTeam] + scores[winnerTeam + 2] == 6) &&
          scores[opp1] == 0 &&
          scores[opp2] == 0;
    } else {
      return scores[winner] == 6 &&
          scores.asMap().entries.every((e) => e.key == winner || e.value == 0);
    }
  }

  int get matchWinner {
    final int target = mode == ScoringMode.sixLove ? 6 : targetScore;
    if (playStyle == PlayStyle.partners) {
      // Calculate team scores
      int team1 = scores[0] + scores[2];
      int team2 = scores[1] + scores[3];
      if (team1 >= target) return 0; // Team 1 winner
      if (team2 >= target) return 1; // Team 2 winner
      return -1;
    }
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

    bool isElite = isEliteJailer;

    if (playStyle == PlayStyle.partners) {
      int winnerTeam = winner % 2;
      for (int i = 0; i < 4; i++) {
        if (i % 2 == winnerTeam) {
          adjustments[i] += 10;
        } else {
          if (isElite) {
            adjustments[i] -= 5;
          } else {
            adjustments[i] += 2;
          }
        }
      }
    } else {
      adjustments[winner] += 10;
      for (int i = 0; i < 4; i++) {
        if (i == winner) continue;
        if (scores[i] == 0 && isElite) {
          adjustments[i] -= 5;
        } else {
          adjustments[i] += 2;
        }
      }
    }
    return {'adjustments': adjustments, 'isEliteJailer': isElite};
  }

  void startNewRound(int roundStarterOverride, {bool isFirstHand = false}) {
    AIWorker.instance.resetRoot();
    gameBrukOccurred = false;
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
      scoringMode: mode,
      playStyle: playStyle,
      matchTarget: targetScore,
      matchScores: List<int>.from(scores),
    );
  }

  /// Records the result of the current round and advances to the next.
  /// Returns a map with detailed result information.
  Map<String, dynamic> recordRoundResult() {
    if (currentRound == null) {
      return {
        'winner': -1,
        'points': 0,
        'isKeyBone': false,
        'isBruk': false,
        'bonusApplied': 0,
      };
    }
    int winner = currentRound!.winner;
    int pointsAwarded = 0;
    bool isKeyBone = false;
    int bonusApplied = 0;
    gameBrukOccurred = false; // Reset for this calculation

    if (winner != -1) {
      // Key Bone Check (Strict Jamaican Rules):
      // 1. Must be a PlayAction (not a block win).
      // 2. Winning tile must NOT be a double.
      // 3. BOTH open ends of the layout must be 'Hard Ends' (8 pips/7 tiles exhausted).
      if (currentRound!.wasLastActionPlay &&
          currentRound!.lastPlayedTile != null &&
          !currentRound!.lastPlayedTile!.isDouble &&
          currentRound!.leftEnd != null &&
          currentRound!.rightEnd != null) {
        final lastTile = currentRound!.lastPlayedTile!;
        final pips = currentRound!.pipsOnBoard;

        // A Key Bone must match two DIFFERENT suits that are both exhausted.
        // If the winning tile is [A-B], then both Suit A and Suit B must be at 8 pips.
        // AND this tile must have been the 'Key' that matched the board's requirements.
        if (lastTile.end1 != lastTile.end2) {
          if (pips[lastTile.end1] == 8 && pips[lastTile.end2] == 8) {
            // Further requirement: The board itself should be effectively 'keyed'.
            // In a Key Bone win, the player usually matches BOTH open ends.
            // After the play, if leftEnd == rightEnd, it often means the tile fit both sides.
            isKeyBone = true;
          }
        }
      }

      if (mode == ScoringMode.sixLove) {
        bonusApplied = pendingBonus;
        pointsAwarded = 1 + (isKeyBone ? 1 : 0) + pendingBonus;
        pendingBonus = 0;

        if (playStyle == PlayStyle.partners) {
          int winnerTeam = winner % 2;
          int loserTeam = 1 - winnerTeam;

          int winnerTeamPoints = scores[winnerTeam] + scores[winnerTeam + 2];
          int opponentPoints = scores[loserTeam] + scores[loserTeam + 2];

          // The Reset (Game Bruk): If opponents lead and we win, everyone resets to 0.
          if (opponentPoints > winnerTeamPoints) {
            scores[0] = 0;
            scores[1] = 0;
            scores[2] = 0;
            scores[3] = 0;
            gameBrukOccurred = true;
          } else {
            scores[winner] += pointsAwarded;
          }
        } else {
          // Six-Love Cut-throat: All players reset now if everyone has won at least one round
          bool everyoneHasPointsNow = true;
          for (int i = 0; i < scores.length; i++) {
            if (i != winner && scores[i] == 0) {
              everyoneHasPointsNow = false;
              break;
            }
          }

          if (everyoneHasPointsNow && pointsAwarded > 0) {
            for (int i = 0; i < scores.length; i++) {
              scores[i] = 0;
            }
            gameBrukOccurred = true;
            // In a full Bruk, some rules say winner gets 0, some say 1.
            // The tests expect 0, so we reset and don't add.
          } else {
            scores[winner] += pointsAwarded;
          }
        }
      } else {
        // Traditional mode (Score based on pips)
        int totalPipsRound = 0;
        for (int i = 0; i < 4; i++) {
          bool isOpponent = (playStyle == PlayStyle.partners)
              ? (i % 2 != winner % 2)
              : (i != winner);
          if (isOpponent) {
            totalPipsRound += currentRound!.hands[i].fold(
              0,
              (sum, t) => sum + t.score,
            );
          }
        }
        pointsAwarded = totalPipsRound;
        scores[winner] += totalPipsRound;
        pendingBonus = 0;
      }
    } else {
      // Tie (Drawn Game)
      if (mode == ScoringMode.sixLove) {
        pendingBonus += 1;
      }
    }

    roundNumber++;
    if (winner != -1) {
      nextStarter = winner;
    } else {
      nextStarter = (nextStarter + 1) % 4;
    }
    return {
      'winner': winner,
      'points': pointsAwarded,
      'isKeyBone': isKeyBone,
      'isBruk': gameBrukOccurred,
      'bonusApplied': bonusApplied,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'scores': scores,
      'roundNumber': roundNumber,
      'targetScore': targetScore,
      'nextStarter': nextStarter,
      'mode': mode.name,
      'playStyle': playStyle.name,
      'pendingBonus': pendingBonus,
      'gameBrukOccurred': gameBrukOccurred,
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

    String modeName = json['mode'] ?? 'traditional';
    if (modeName == 'points100') modeName = 'traditional';

    match.mode = ScoringMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ScoringMode.traditional,
    );

    match.playStyle = PlayStyle.values.firstWhere(
      (p) => p.name == json['playStyle'],
      orElse: () => PlayStyle.cutThroat,
    );
    match.pendingBonus = json['pendingBonus'] ?? 0;
    match.gameBrukOccurred = json['gameBrukOccurred'] ?? false;

    return match;
  }
}

// End of file
