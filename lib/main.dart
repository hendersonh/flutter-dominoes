import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine/dominoes_ai.dart';

const List<String> playerNames = ['Hendy', 'Ed', 'Paul', 'Tim'];

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameController(),
      child: const DominoesApp(),
    ),
  );
}

class DominoesApp extends StatelessWidget {
  const DominoesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HendyChallenge Dominoes',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2BEE4B),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: GoogleFonts.splineSansTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2BEE4B),
          secondary: Color(0xFF2BEE4B),
          surface: Color(0xFF0F172A),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

class GameController extends ChangeNotifier {
  late MatchModel _match;
  bool _isAiThinking = false;
  String? _statusMessage;
  String? _topOverlayMessage;
  String? _bottomOverlayMessage;
  int? _knockingPlayerIndex;
  bool _showNextRoundButton = false;
  bool _isFinishingRound = false;

  DominoTile? _selectedTile;

  int _lifetimeMatchWins = 0;
  int _lifetimeMatchLosses = 0;
  bool _matchStatsSaved = false;

  GameController() {
    _initMatch();
  }

  MatchModel get match => _match;
  GameModel? get game => _match.currentRound;
  bool get isAiThinking => _isAiThinking;
  String? get statusMessage => _statusMessage;
  String? get topOverlayMessage => _topOverlayMessage;
  String? get bottomOverlayMessage => _bottomOverlayMessage;
  int? get knockingPlayerIndex => _knockingPlayerIndex;
  bool get showNextRoundButton => _showNextRoundButton;
  bool get isInitialized => _match.currentRound != null;
  DominoTile? get selectedTile => _selectedTile;
  int get lifetimeMatchWins => _lifetimeMatchWins;
  int get lifetimeMatchLosses => _lifetimeMatchLosses;

  static const String _kMatchKey = 'dominoes_match_data';

  Future<void> _loadLifetimeStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lifetimeMatchWins = prefs.getInt('lifetime_match_wins') ?? 0;
      _lifetimeMatchLosses = prefs.getInt('lifetime_match_losses') ?? 0;
    } catch (e) {
      debugPrint("Error loading lifetime stats: $e");
    }
  }

  Future<void> _saveLifetimeStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lifetime_match_wins', _lifetimeMatchWins);
      await prefs.setInt('lifetime_match_losses', _lifetimeMatchLosses);
    } catch (e) {
      debugPrint("Error saving lifetime stats: $e");
    }
  }

  Future<void> _initMatch() async {
    _match = MatchModel(targetScore: 100);
    _topOverlayMessage = null;
    _bottomOverlayMessage = null;
    _selectedTile = null;
    _knockingPlayerIndex = null;
    _isFinishingRound = false;
    _showNextRoundButton = false;
    // Explicitly set a non-null placeholder if needed, but we handle it with isInitialized
    await _loadLifetimeStats();
    await _loadMatch();

    // If we loaded a match but no round is active, start one
    if (_match.currentRound == null) {
      _match.startNewRound(
        _match.nextStarter,
        isFirstHand: _match.roundNumber == 1,
      );
    }

    _updateStatusMessage();
    _sortPlayerHand();
    notifyListeners();

    // If it's AI's turn to start the restored match
    if (_match.currentRound!.currentPlayer != 0) {
      _runAiTurn();
    }
  }

  void _updateStatusMessage() {
    if (_match.isMatchOver) {
      if (_match.matchWinner == 0) {
        _statusMessage = "MATCH OVER: ${playerNames[0]} Wins!";
      } else {
        _statusMessage = "MATCH OVER: ${playerNames[_match.matchWinner]} Wins!";
      }
      return;
    }

    if (_match.currentRound == null || _match.currentRound!.isGameOver) {
      _statusMessage = ""; // Clear turn status
      if (_match.currentRound != null) {
        int winner = _match.currentRound!.winner;
        if (winner == 0) {
          _bottomOverlayMessage = "${playerNames[0]} Wins Round!";
        } else if (winner != -1) {
          _bottomOverlayMessage = "${playerNames[winner]} Wins Round!";
        } else {
          _bottomOverlayMessage = "Round Drawn!";
        }
      } else {
        _statusMessage = "Starting match...";
      }
      return;
    }

    _statusMessage = _match.currentRound!.currentPlayer == 0
        ? "${playerNames[0]}'s Turn"
        : "${playerNames[_match.currentRound!.currentPlayer]} Thinking...";
  }

  Future<void> _saveMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final matchJson = jsonEncode(_match.toJson());
      await prefs.setString(_kMatchKey, matchJson);
      print("Game Saved: $matchJson");
    } catch (e) {
      debugPrint("Error saving match: $e");
    }
  }

  Future<void> _loadMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final matchJson = prefs.getString(_kMatchKey);
      if (matchJson != null) {
        final Map<String, dynamic> data = jsonDecode(matchJson);
        _match = MatchModel.fromJson(data);
        print("Game Loaded: $matchJson");
      }
    } catch (e) {
      debugPrint("Error loading match: $e");
    }
  }

  Future<void> resetMatch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMatchKey);
    _matchStatsSaved = false;
    // Restart from scratch
    await _initMatch();
  }

  void _startNextRound() {
    _topOverlayMessage = null;
    _bottomOverlayMessage = null;
    _selectedTile = null;
    _knockingPlayerIndex = null;
    _isFinishingRound = false;
    _showNextRoundButton = false;
    _match.startNewRound(_match.nextStarter, isFirstHand: false);
    _updateStatusMessage();
    _sortPlayerHand();
    notifyListeners();

    if (_match.currentRound!.currentPlayer != 0) {
      _runAiTurn();
    }
  }

  void clearSelection() {
    if (_selectedTile != null) {
      _selectedTile = null;
      notifyListeners();
    }
  }

  void selectTile(DominoTile tile) {
    if (game == null ||
        game!.isGameOver ||
        game!.currentPlayer != 0 ||
        _isAiThinking)
      return;

    bool canPlayLeft = game!.board.isEmpty || tile.contains(game!.leftEnd!);
    bool canPlayRight = game!.board.isEmpty || tile.contains(game!.rightEnd!);

    if (!canPlayLeft && !canPlayRight) return; // Unplayable

    if (game!.board.isEmpty) {
      playTile(tile, 'left');
      return;
    }

    if (canPlayLeft && !canPlayRight) {
      playTile(tile, 'left');
      return;
    }

    if (canPlayRight && !canPlayLeft) {
      playTile(tile, 'right');
      return;
    }

    if (game!.leftEnd == game!.rightEnd) {
      playTile(tile, 'left');
      return;
    }

    // Playable on both sides, wait for user to select board end
    _selectedTile = tile;
    notifyListeners();
  }

  void confirmPlay(String side) {
    if (_selectedTile != null) {
      playTile(_selectedTile!, side);
      _selectedTile = null;
    }
  }

  void playTile(DominoTile tile, String side) {
    if (game == null ||
        game!.isGameOver ||
        game!.currentPlayer != 0 ||
        _isAiThinking)
      return;

    final action = PlayAction(tile, side, isFirstMove: game!.board.isEmpty);
    if (game != null) {
      game!.applyAction(action);
      print("Player played $tile on $side. Board: ${game!.board}");
      _sortPlayerHand();

      _checkGameState();
      notifyListeners();

      if (!game!.isGameOver && game!.currentPlayer != 0) {
        _runAiTurn();
      }
    }
  }

  void passTurn() {
    if (game == null ||
        game!.isGameOver ||
        game!.currentPlayer != 0 ||
        _isAiThinking)
      return;

    game!.applyAction(PassAction());
    _checkGameState();
    notifyListeners();

    if (!game!.isGameOver && game!.currentPlayer != 0) {
      _runAiTurn();
    }
  }

  void _checkGameState() {
    if (game != null && game!.isGameOver) {
      if (_isFinishingRound) return;
      _isFinishingRound = true;

      _showNextRoundButton = false;
      _knockingPlayerIndex = null;
      _bottomOverlayMessage = "..game over";
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 5000), () {
        int roundWinner = _match.recordRoundResult();
        _saveMatch(); // Persist scores!

        if (_match.isMatchOver) {
          if (!_matchStatsSaved) {
            _matchStatsSaved = true;
            if (_match.matchWinner == 0) {
              _lifetimeMatchWins++;
            } else {
              _lifetimeMatchLosses++;
            }
            _saveLifetimeStats();
          }
        }

        if (_match.isMatchOver) {
          if (_match.matchWinner == 0) {
            _bottomOverlayMessage = "MATCH OVER: ${playerNames[0]} Wins!";
          } else if (_match.matchWinner != -1) {
            _bottomOverlayMessage =
                "MATCH OVER: ${playerNames[_match.matchWinner]} Wins!";
          } else {
            _bottomOverlayMessage = "MATCH OVER: Tie!";
          }
        } else {
          if (roundWinner == 0) {
            _bottomOverlayMessage = "${playerNames[0]} Wins Round!";
          } else if (roundWinner != -1) {
            _bottomOverlayMessage = "${playerNames[roundWinner]} Wins Round!";
          } else {
            _bottomOverlayMessage = "Round Drawn!";
          }
        }

        _showNextRoundButton = true;
        _isFinishingRound = false;
        notifyListeners();
      });
    } else if (game != null) {
      if (game!.currentPlayer == 0) {
        _topOverlayMessage = null;
      }
      _bottomOverlayMessage = null;
      _knockingPlayerIndex =
          null; // Clear knock state on every valid state check
      _statusMessage = game!.currentPlayer == 0
          ? "${playerNames[0]}'s Turn"
          : "${playerNames[game!.currentPlayer]} Thinking...";
      if (game!.currentPlayer == 0) {
        _handlePlayerAutoTurn();
      }
    }
  }

  void _handlePlayerAutoTurn() {
    if (game != null && !game!.canPlayerPlay(0)) {
      // Contextual Knock for Human
      _knockingPlayerIndex = 0;
      HapticFeedback.lightImpact();
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (game != null && !game!.isGameOver && game!.currentPlayer == 0) {
          passTurn();
        }
      });
    }
  }

  Future<void> _runAiTurn() async {
    if (game == null || game!.isGameOver) {
      _isAiThinking = false;
      return;
    }
    _isAiThinking = true;
    int cp = game!.currentPlayer;
    _statusMessage = "${playerNames[cp]} Thinking...";
    notifyListeners();

    // Yield to the event loop so Flutter can render the human's/previous move
    await Future.delayed(const Duration(milliseconds: 500));

    // Fast calculation: AI needs less time physically, but we still add a minimum UI delay
    final stopwatch = Stopwatch()..start();
    final aiAction = await getBestActionAsync(game!, cp, 1000);
    final elapsed = stopwatch.elapsedMilliseconds;

    // Total artificial minimum delay per AI turn is 1.5s
    if (elapsed < 1500) {
      await Future.delayed(Duration(milliseconds: 1500 - elapsed));
    }

    print("AI Player $cp Action: $aiAction");
    if (aiAction is PassAction) {
      // Contextual Knock for AI
      _knockingPlayerIndex = cp;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    if (game != null) {
      game!.applyAction(aiAction);
      print("Player $cp played ${aiAction.toString()}");
    }

    _isAiThinking = false;
    _checkGameState();
    notifyListeners();

    // Loop directly back to run AI turn if the next player is ALSO an AI
    if (game != null && !game!.isGameOver && game!.currentPlayer != 0) {
      // Call async microtask to safely chain AI turns
      Future.microtask(() => _runAiTurn());
    }
  }

  void restartGame() {
    if (_match.isMatchOver) {
      resetMatch();
    } else if (game != null && game!.isGameOver) {
      _startNextRound();
    } else {
      // User tapped reset mid-round
      _topOverlayMessage = null;
      _bottomOverlayMessage = null;
      resetMatch();
    }
  }

  void _sortPlayerHand() {
    if (game == null) return;
    game!.hands[0].sort((a, b) {
      int maxA = math.max(a.end1, a.end2);
      int minA = math.min(a.end1, a.end2);
      int maxB = math.max(b.end1, b.end2);
      int minB = math.min(b.end1, b.end2);

      if (maxA != maxB) return maxB.compareTo(maxA);
      return minB.compareTo(minA);
    });
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastHandSize = 0;

  @override
  void initState() {
    super.initState();
    // We'll use a post-frame callback or listener to detect hand changes
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    if (!controller.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF64FFDA)),
        ),
      );
    }

    final game = controller.game!;

    // Detect if hand size increased
    if (game.hands[0].length > _lastHandSize) {
      _scrollToEnd();
    }
    _lastHandSize = game.hands[0].length;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('HendyChallenge Dominoes'),
        actions: [
          IconButton(
            tooltip: 'Restart Round',
            icon: const Icon(Icons.refresh),
            onPressed: controller.restartGame,
          ),
          IconButton(
            tooltip: 'Reset Match (Clear Scores)',
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Match?'),
                  content: const Text(
                    'This will clear all scores and start a fresh match from zero.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        controller.resetMatch();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'RESET',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: controller.clearSelection,
        child: SafeArea(
          child: Column(
            children: [
              // Score Bar (Matched to image)
              // Top Message
              if (controller.statusMessage != null &&
                  controller.statusMessage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    controller.statusMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2BEE4B),
                    ),
                  ),
                ),

              // Game Board
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B5B32),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _EdgeScore(
                          name: 'Hendy',
                          tiles: game.hands[0].length,
                          score: controller.match.scores[0],
                          isActive: game.currentPlayer == 0,
                          isKnocking: controller.knockingPlayerIndex == 0,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _EdgeScore(
                          name: 'Ed',
                          tiles: game.hands[1].length,
                          score: controller.match.scores[1],
                          isActive: game.currentPlayer == 1,
                          isKnocking: controller.knockingPlayerIndex == 1,
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: _EdgeScore(
                          name: 'Paul',
                          tiles: game.hands[2].length,
                          score: controller.match.scores[2],
                          isActive: game.currentPlayer == 2,
                          isKnocking: controller.knockingPlayerIndex == 2,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _EdgeScore(
                          name: 'Tim',
                          tiles: game.hands[3].length,
                          score: controller.match.scores[3],
                          isActive: game.currentPlayer == 3,
                          isKnocking: controller.knockingPlayerIndex == 3,
                        ),
                      ),

                      // Interactive Board Content
                      Center(
                        child: game.board.isEmpty
                            ? (game.currentPlayer == 0
                                  ? const Text(
                                      'Tap a tile to start',
                                      style: TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : Text(
                                      '${playerNames[game.currentPlayer]} is starting...',
                                    ))
                            : InteractiveViewer(
                                boundaryMargin: const EdgeInsets.all(1000),
                                minScale: 0.1,
                                maxScale: 2.0,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SnakingBoard(
                                      board: game.board,
                                      rootIndex: game.rootIndex,
                                      maxWidth: constraints.maxWidth,
                                      isSelectingSide:
                                          controller.selectedTile != null,
                                      onSelectSide: controller.confirmPlay,
                                    );
                                  },
                                ),
                              ),
                      ),

                      // Status Overlay (Top Center)
                      if (controller.topOverlayMessage != null)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2BEE4B,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                controller.topOverlayMessage!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2BEE4B),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Status Overlay (Bottom Center) - For Wins/Losses only now
                      if (controller.bottomOverlayMessage != null &&
                          !controller.showNextRoundButton &&
                          controller.bottomOverlayMessage != "..game over") ...[
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2BEE4B,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                controller.bottomOverlayMessage!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2BEE4B),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Premium Game Over Progress (Frosted Glass)
                      if (controller.bottomOverlayMessage == "..game over" &&
                          !controller.showNextRoundButton)
                        const Align(
                          alignment: Alignment.bottomCenter,
                          child: _GlassyProgress(
                            message: "ROUND COMPLETE",
                            duration: Duration(seconds: 5),
                          ),
                        ),

                      // Game Over Modal (Idea B)
                      if (game.isGameOver && controller.showNextRoundButton)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.7),
                            child: Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 24,
                                ),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: controller.match.isMatchOver
                                        ? (controller.match.matchWinner == 0
                                              ? const Color(0xFF2BEE4B)
                                              : Colors.red)
                                        : const Color(
                                            0xFF2BEE4B,
                                          ).withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        controller.bottomOverlayMessage ??
                                            'Game Over',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              controller.match.isMatchOver &&
                                                  controller
                                                          .match
                                                          .matchWinner !=
                                                      0
                                              ? Colors.red
                                              : const Color(0xFF2BEE4B),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'LIFETIME MATCH RECORD',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white54,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: _StatBox(
                                              label: 'WINS',
                                              value:
                                                  controller.lifetimeMatchWins,
                                              color: const Color(0xFF2BEE4B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _StatBox(
                                              label: 'LOSSES',
                                              value: controller
                                                  .lifetimeMatchLosses,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: Icon(
                                            controller.match.isMatchOver
                                                ? Icons.replay
                                                : Icons.play_arrow,
                                          ),
                                          label: Text(
                                            controller.match.isMatchOver
                                                ? 'START NEW MATCH'
                                                : 'PLAY NEXT ROUND',
                                          ),
                                          onPressed: controller.restartGame,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF2BEE4B,
                                            ),
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            textStyle: const TextStyle(
                                              inherit: false,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Control Area (Ends)
              if (game.board.isNotEmpty &&
                  controller.statusMessage == "Your Turn" &&
                  controller.selectedTile == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [const Text('Tap a tile in your hand to play')],
                  ),
                ),

              if (controller.selectedTile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Tap a ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const Text(
                        'glowing end',
                        style: TextStyle(
                          color: Color(0xFF2BEE4B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        ' on the board to play',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

              // Player Hand (Vertical Rack)
              Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final availableWidth =
                      screenWidth - 32; // 16 horizontal padding on each side
                  // 7 tiles + 6 gaps (12px each). A normal tile is 50px wide.
                  // We want to fit 7 tiles comfortably. Target max width = 7 * 50 + 6 * 12 = 422
                  double tileScale = (availableWidth / 422).clamp(0.5, 1.0);

                  return SizedBox(
                    height:
                        102 * tileScale +
                        18, // Reclaims board space while fitting scaled tiles + padding
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ImageFiltered(
                        imageFilter: controller.knockingPlayerIndex == 0
                            ? ImageFilter.blur(sigmaX: 5, sigmaY: 5)
                            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: controller.knockingPlayerIndex == 0
                              ? 0.3
                              : 1.0,
                          child: Row(
                            children: game.hands[0].asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final tile = entry.value;
                              final isPlayable =
                                  !game.isGameOver &&
                                  game.currentPlayer == 0 &&
                                  (game.board.isEmpty ||
                                      tile.contains(game.leftEnd!) ||
                                      tile.contains(game.rightEnd!));

                              return Padding(
                                padding: EdgeInsets.only(
                                  right: 12.0 * tileScale,
                                ),
                                child: GestureDetector(
                                  onTap:
                                      game.isGameOver ||
                                          !isPlayable ||
                                          controller.knockingPlayerIndex == 0
                                      ? null
                                      : () => controller.selectTile(tile),
                                  child: Opacity(
                                    opacity:
                                        game.isGameOver ||
                                            game.currentPlayer != 0 ||
                                            isPlayable
                                        ? 1.0
                                        : 0.4,
                                    child: Hero(
                                      tag: 'tile-$index',
                                      child: DominoTileWidget(
                                        tile: tile,
                                        isVertical: true,
                                        isHighlight: isPlayable,
                                        isSelected:
                                            controller.selectedTile == tile,
                                        scale: tileScale,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Bottom spacer
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class DominoTileWidget extends StatelessWidget {
  final DominoTile tile;
  final bool isVertical;
  final bool isHighlight;
  final bool isSelected;
  final bool isFlipped;
  final double scale;

  const DominoTileWidget({
    super.key,
    required this.tile,
    this.isVertical = false,
    this.isHighlight = false,
    this.isSelected = false,
    this.isFlipped = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: (isVertical ? 50 : 102) * scale,
          height: (isVertical ? 102 : 50) * scale,
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF7),
            border: isSelected
                ? Border.all(color: const Color(0xFF2BEE4B), width: 4 * scale)
                : isHighlight
                ? Border.all(
                    color: const Color(0xFF2BEE4B).withValues(alpha: 0.5),
                    width: 2 * scale,
                  )
                : Border.all(
                    color: const Color(0xFF9CA3AF),
                    width: 1.5 * scale,
                  ),
            borderRadius: BorderRadius.circular(4 * scale),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2BEE4B).withValues(alpha: 0.6),
                      blurRadius: 12 * scale,
                      spreadRadius: 2 * scale,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6 * scale,
                      offset: Offset(1 * scale, 3 * scale),
                    ),
                  ],
          ),
          child: Flex(
            direction: isVertical ? Axis.vertical : Axis.horizontal,
            children: [
              Expanded(
                child: Center(
                  child: _Pips(
                    isFlipped ? tile.end2 : tile.end1,
                    isVertical: isVertical,
                    scale: scale,
                  ),
                ),
              ),
              Container(
                width: isVertical ? double.infinity : 1.5 * scale,
                height: isVertical ? 1.5 * scale : double.infinity,
                color: const Color(0xFF9CA3AF),
              ),
              Expanded(
                child: Center(
                  child: _Pips(
                    isFlipped ? tile.end1 : tile.end2,
                    isVertical: isVertical,
                    scale: scale,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (tile.isDouble)
          Container(
            width: 10 * scale,
            height: 10 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                radius: 1.0,
                colors: [Color(0xFFFBBF24), Color(0xFFB45309)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1 * scale,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 3 * scale,
                  offset: Offset(0, 1 * scale),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Pips extends StatelessWidget {
  final int count;
  final bool isVertical;
  final double scale;
  const _Pips(this.count, {this.isVertical = false, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    Color baseColor;
    switch (count) {
      case 1:
        baseColor = const Color(0xFF3B82F6);
        break; // Blue
      case 2:
        baseColor = const Color(0xFF10B981);
        break; // Green
      case 3:
        baseColor = const Color(0xFFEF4444);
        break; // Red
      case 4:
        baseColor = const Color(0xFFF59E0B);
        break; // Amber
      case 5:
        baseColor = const Color(0xFF8B5CF6);
        break; // Purple
      case 6:
        baseColor = const Color(0xFF06B6D4);
        break; // Teal
      default:
        baseColor = const Color(0xFF374151); // Dark Gray for 0/Default
    }

    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          bool visible = false;
          switch (count) {
            case 1:
              visible = index == 4;
              break;
            case 2:
              visible = index == 0 || index == 8;
              break;
            case 3:
              visible = index == 0 || index == 4 || index == 8;
              break;
            case 4:
              visible = index == 0 || index == 2 || index == 6 || index == 8;
              break;
            case 5:
              visible =
                  index == 0 ||
                  index == 2 ||
                  index == 4 ||
                  index == 6 ||
                  index == 8;
              break;
            case 6:
              if (isVertical) {
                // 2 vertical lines of 3
                visible =
                    index == 0 ||
                    index == 3 ||
                    index == 6 ||
                    index == 2 ||
                    index == 5 ||
                    index == 8;
              } else {
                // 2 horizontal lines of 3
                visible =
                    index == 0 ||
                    index == 1 ||
                    index == 2 ||
                    index == 6 ||
                    index == 7 ||
                    index == 8;
              }
              break;
          }
          return visible
              ? Container(
                  margin: EdgeInsets.all(4 * scale),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.2),
                      radius: 0.8,
                      colors: [
                        baseColor.withValues(alpha: 0.8), // Lighter top-left
                        baseColor, // Actual color
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 1 * scale,
                        offset: Offset(0, 1 * scale),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 1 * scale,
                        offset: Offset(0, -1 * scale),
                      ),
                    ],
                  ),
                )
              : const SizedBox();
        },
      ),
    );
  }
}

class SnakingBoard extends StatelessWidget {
  final List<DominoTile> board;
  final int rootIndex;
  final double maxWidth;
  final bool isSelectingSide;
  final Function(String)? onSelectSide;

  const SnakingBoard({
    super.key,
    required this.board,
    required this.rootIndex,
    required this.maxWidth,
    this.isSelectingSide = false,
    this.onSelectSide,
  });

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) return const SizedBox();

    // Configuration
    double scale = (maxWidth / 570.0).clamp(0.4, 1.0);

    final double hWidth = 102.0 * scale;
    final double hHeight = 50.0 * scale;
    final double vWidth = 50.0 * scale;
    final double vHeight = 102.0 * scale;
    final double turnClearance = 30.0 * scale; // Margin from edges
    final double rowSpacing = 76.5 * scale; // Half hHeight + Half vHeight

    Map<int, _TilePos> positions = {};

    // 1. Root Positioning
    bool rootIsVertical = board[rootIndex].isDouble;

    positions[rootIndex] = _TilePos(
      offset: Offset(
        rootIsVertical ? -vWidth / 2 : -hWidth / 2,
        rootIsVertical ? -vHeight / 2 : -hHeight / 2,
      ),
      isVertical: rootIsVertical,
    );

    // 2. Grow Right (indices > rootIndex)
    double rightCursorX = rootIsVertical ? vWidth / 2 : hWidth / 2;
    double rightCursorY = 0;
    int rightDirection = 1; // 1 = L->R, -1 = R->L

    for (int i = rootIndex + 1; i < board.length; i++) {
      final tile = board[i];
      bool isDouble = tile.isDouble;
      bool turnNow = false;

      if (rightDirection == 1) {
        if (rightCursorX + (isDouble ? vWidth : hWidth) >
            maxWidth / 2 - turnClearance)
          turnNow = true;
      } else {
        if (rightCursorX - (isDouble ? vWidth : hWidth) <
            -maxWidth / 2 + turnClearance)
          turnNow = true;
      }

      if (turnNow) {
        bool prevWasDouble = board[i - 1].isDouble;
        double attachY =
            rightCursorY + (prevWasDouble ? vHeight / 2 : hHeight / 2);

        // TURN logic (Snaking Down)
        if (rightDirection == 1) {
          // Attach elbow's TOP edge to previous RIGHT half's BOTTOM edge
          positions[i] = _TilePos(
            offset: Offset(rightCursorX - vWidth, attachY),
            isVertical: true,
            isFlipped: false,
          );
          rightCursorY = attachY + rowSpacing; // Next row center Y
          rightCursorX =
              rightCursorX - vWidth; // Next row starts at left edge of elbow
          rightDirection = -1;
        } else {
          // Attach elbow's TOP edge to previous LEFT half's BOTTOM edge
          positions[i] = _TilePos(
            offset: Offset(rightCursorX, attachY),
            isVertical: true,
            isFlipped: false,
          );
          rightCursorY = attachY + rowSpacing; // Next row center Y
          rightCursorX =
              rightCursorX + vWidth; // Next row starts at right edge of elbow
          rightDirection = 1;
        }
      } else {
        // Normal growth
        double tileW = isDouble ? vWidth : hWidth;
        double tileH = isDouble ? vHeight : hHeight;

        if (rightDirection == 1) {
          positions[i] = _TilePos(
            offset: Offset(rightCursorX, rightCursorY - tileH / 2),
            isVertical: isDouble,
            isFlipped: false,
          );
          rightCursorX += tileW;
        } else {
          positions[i] = _TilePos(
            offset: Offset(rightCursorX - tileW, rightCursorY - tileH / 2),
            isVertical: isDouble,
            isFlipped: true,
          );
          rightCursorX -= tileW;
        }
      }
    }

    // 3. Grow Left (indices < rootIndex)
    double leftCursorX = rootIsVertical ? -vWidth / 2 : -hWidth / 2;
    double leftCursorY = 0;
    int leftDirection = -1; // -1 = R->L, 1 = L->R

    for (int i = rootIndex - 1; i >= 0; i--) {
      final tile = board[i];
      bool isDouble = tile.isDouble;
      bool turnNow = false;

      if (leftDirection == -1) {
        if (leftCursorX - (isDouble ? vWidth : hWidth) <
            -maxWidth / 2 + turnClearance)
          turnNow = true;
      } else {
        if (leftCursorX + (isDouble ? vWidth : hWidth) >
            maxWidth / 2 - turnClearance)
          turnNow = true;
      }

      if (turnNow) {
        bool prevWasDouble = board[i + 1].isDouble;
        double attachY =
            leftCursorY - (prevWasDouble ? vHeight / 2 : hHeight / 2);

        // TURN logic (Snaking Up)
        if (leftDirection == -1) {
          // Attach elbow's BOTTOM edge to previous LEFT half's TOP edge
          positions[i] = _TilePos(
            offset: Offset(leftCursorX, attachY - vHeight),
            isVertical: true,
            isFlipped: false,
          );
          leftCursorY = attachY - rowSpacing; // Next row center Y
          leftCursorX =
              leftCursorX + vWidth; // Next row starts at right edge of elbow
          leftDirection = 1;
        } else {
          // Attach elbow's BOTTOM edge to previous RIGHT half's TOP edge
          positions[i] = _TilePos(
            offset: Offset(leftCursorX - vWidth, attachY - vHeight),
            isVertical: true,
            isFlipped: false,
          );
          leftCursorY = attachY - rowSpacing; // Next row center Y
          leftCursorX =
              leftCursorX - vWidth; // Next row starts at left edge of elbow
          leftDirection = -1;
        }
      } else {
        // Normal growth
        double tileW = isDouble ? vWidth : hWidth;
        double tileH = isDouble ? vHeight : hHeight;

        if (leftDirection == -1) {
          positions[i] = _TilePos(
            offset: Offset(leftCursorX - tileW, leftCursorY - tileH / 2),
            isVertical: isDouble,
            isFlipped: false,
          );
          leftCursorX -= tileW;
        } else {
          positions[i] = _TilePos(
            offset: Offset(leftCursorX, leftCursorY - tileH / 2),
            isVertical: isDouble,
            isFlipped: true,
          );
          leftCursorX += tileW;
        }
      }
    }

    // Wrap sizing correctly
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (var pos in positions.values) {
      minX = math.min(minX, pos.offset.dx);
      maxX = math.max(maxX, pos.offset.dx + (pos.isVertical ? vWidth : hWidth));
      minY = math.min(minY, pos.offset.dy);
      maxY = math.max(
        maxY,
        pos.offset.dy + (pos.isVertical ? vHeight : hHeight),
      );
    }

    final double boardWidth = maxX - minX;
    final double boardHeight = maxY - minY;

    return Center(
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ...positions.entries.map((entry) {
              final pos = entry.value;
              return Positioned(
                left: pos.offset.dx - minX,
                top: pos.offset.dy - minY,
                child: DominoTileWidget(
                  tile: board[entry.key],
                  isVertical: pos.isVertical,
                  isFlipped: pos.isFlipped,
                  scale: scale,
                ),
              );
            }),
            if (isSelectingSide && board.length > 1) ...[
              Positioned(
                left: positions[0]!.offset.dx - minX - (20 * scale),
                top: positions[0]!.offset.dy - minY - (20 * scale),
                child: GestureDetector(
                  onTap: () => onSelectSide?.call('left'),
                  child: Container(
                    width:
                        (positions[0]!.isVertical ? vWidth : hWidth) +
                        (40 * scale),
                    height:
                        (positions[0]!.isVertical ? vHeight : hHeight) +
                        (40 * scale),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2BEE4B).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2BEE4B).withValues(alpha: 0.6),
                          blurRadius: 20 * scale,
                          spreadRadius: 5 * scale,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left:
                    positions[board.length - 1]!.offset.dx -
                    minX -
                    (20 * scale),
                top:
                    positions[board.length - 1]!.offset.dy -
                    minY -
                    (20 * scale),
                child: GestureDetector(
                  onTap: () => onSelectSide?.call('right'),
                  child: Container(
                    width:
                        (positions[board.length - 1]!.isVertical
                            ? vWidth
                            : hWidth) +
                        (40 * scale),
                    height:
                        (positions[board.length - 1]!.isVertical
                            ? vHeight
                            : hHeight) +
                        (40 * scale),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2BEE4B).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2BEE4B).withValues(alpha: 0.6),
                          blurRadius: 20 * scale,
                          spreadRadius: 5 * scale,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TilePos {
  final Offset offset;
  final bool isVertical;
  final bool isFlipped;
  _TilePos({
    required this.offset,
    required this.isVertical,
    this.isFlipped = false,
  });
}

class _EdgeScore extends StatefulWidget {
  final String name;
  final int tiles;
  final int score;
  final bool isActive;
  final bool isKnocking;

  const _EdgeScore({
    super.key,
    required this.name,
    required this.tiles,
    required this.score,
    required this.isActive,
    this.isKnocking = false,
  });

  @override
  State<_EdgeScore> createState() => _EdgeScoreState();
}

class _EdgeScoreState extends State<_EdgeScore>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_EdgeScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isKnocking && !oldWidget.isKnocking) {
      _controller.repeat(count: 2);
    } else if (!widget.isKnocking && oldWidget.isKnocking) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.name,
              style: TextStyle(
                fontSize: 14,
                color: widget.isActive || widget.isKnocking
                    ? const Color(0xFF2BEE4B)
                    : Colors.white,
                fontWeight: widget.isActive || widget.isKnocking
                    ? FontWeight.bold
                    : FontWeight.w400,
              ),
            ),
            Text(
              '${widget.tiles}/${widget.score}',
              style: TextStyle(
                fontSize: 14,
                color: widget.isActive || widget.isKnocking
                    ? const Color(0xFF2BEE4B)
                    : Colors.white.withValues(alpha: 0.8),
                fontWeight: widget.isActive || widget.isKnocking
                    ? FontWeight.bold
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBox({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassyProgress extends StatefulWidget {
  final String message;
  final Duration duration;

  const _GlassyProgress({
    super.key,
    required this.message,
    required this.duration,
  });

  @override
  State<_GlassyProgress> createState() => _GlassyProgressState();
}

class _GlassyProgressState extends State<_GlassyProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 32, right: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(2), // For the glowing border effect
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2BEE4B).withValues(alpha: 0.3),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF2BEE4B),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      height: 4,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2BEE4B),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
