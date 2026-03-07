import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine/dominoes_ai.dart';

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
        scaffoldBackgroundColor: const Color(0xFF111827),
        textTheme: GoogleFonts.beVietnamProTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2BEE4B),
          secondary: Color(0xFF2BEE4B),
          surface: Color(0xFF1E1E1E),
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
  bool _showNextRoundButton = false;

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
  bool get showNextRoundButton => _showNextRoundButton;
  bool get isInitialized => _match.currentRound != null;
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
    _match = MatchModel(targetScore: 150);
    // Explicitly set a non-null placeholder if needed, but we handle it with isInitialized
    await _loadLifetimeStats();
    await _loadMatch();

    // If we loaded a match but no round is active, start one
    if (_match.currentRound == null) {
      _match.startNewRound(_match.nextStarter);
    }

    _updateStatusMessage();
    notifyListeners();

    // If it's AI's turn to start the restored match
    if (_match.currentRound!.currentPlayer == 1) {
      _runAiTurn();
    }
  }

  void _updateStatusMessage() {
    if (_match.isMatchOver) {
      if (_match.matchWinner == 0) {
        _statusMessage = "MATCH OVER: You Win!";
      } else if (_match.matchWinner == 1) {
        _statusMessage = "MATCH OVER: Hendy Wins!";
      } else {
        _statusMessage = "MATCH OVER: Tie!";
      }
      return;
    }

    if (_match.currentRound == null || _match.currentRound!.isGameOver) {
      _statusMessage = ""; // Clear turn status
      if (_match.currentRound != null) {
        int winner = _match.currentRound!.winner;
        if (winner == 0) {
          _bottomOverlayMessage = "Round Won!";
        } else if (winner == 1) {
          _bottomOverlayMessage = "Round Lost!";
        } else {
          _bottomOverlayMessage = "Round Drawn!";
        }
      } else {
        _statusMessage = "Starting match...";
      }
      return;
    }

    _statusMessage = _match.currentRound!.currentPlayer == 0
        ? "Your Turn"
        : "Hendy Thinking...";
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
    _match.startNewRound(_match.nextStarter);
    _updateStatusMessage();
    notifyListeners();

    if (_match.currentRound!.currentPlayer == 1) {
      _runAiTurn();
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

      _checkGameState();
      notifyListeners();

      if (!game!.isGameOver && game!.currentPlayer == 1) {
        _runAiTurn();
      }
    }
  }

  void drawFromBoneyard() {
    if (game == null ||
        game!.isGameOver ||
        game!.currentPlayer != 0 ||
        _isAiThinking ||
        game!.boneyard.isEmpty)
      return;

    game!.applyAction(DrawAction());
    _checkGameState();
    notifyListeners();
  }

  void passTurn() {
    if (game == null ||
        game!.isGameOver ||
        game!.currentPlayer != 0 ||
        _isAiThinking ||
        game!.boneyard.isNotEmpty)
      return;

    game!.applyAction(PassAction());
    _checkGameState();
    notifyListeners();

    if (!game!.isGameOver && game!.currentPlayer == 1) {
      _runAiTurn();
    }
  }

  void _checkGameState() {
    if (game != null && game!.isGameOver) {
      int roundWinner = _match.recordRoundResult();
      _saveMatch(); // Persist scores!

      if (_match.isMatchOver) {
        if (!_matchStatsSaved) {
          _matchStatsSaved = true;
          if (_match.matchWinner == 0) {
            _lifetimeMatchWins++;
          } else if (_match.matchWinner == 1) {
            _lifetimeMatchLosses++;
          }
          _saveLifetimeStats();
        }
      }

      if (_match.isMatchOver) {
        if (_match.matchWinner == 0) {
          _bottomOverlayMessage = "MATCH OVER: You Win!";
        } else if (_match.matchWinner == 1) {
          _bottomOverlayMessage = "MATCH OVER: Hendy Wins!";
        } else {
          _bottomOverlayMessage = "MATCH OVER: Tie!";
        }
      } else {
        if (roundWinner == 0) {
          _bottomOverlayMessage = "Round Won!";
        } else if (roundWinner == 1) {
          _bottomOverlayMessage = "Round Lost!";
        } else {
          _bottomOverlayMessage = "Round Drawn!";
        }
      }

      _showNextRoundButton = false;
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 1000), () {
        _showNextRoundButton = true;
        notifyListeners();
      });
    } else if (game != null) {
      if (game!.currentPlayer == 0) {
        _topOverlayMessage = null; // Clear AI status when it's player's turn
      }
      _bottomOverlayMessage = null;
      _statusMessage = game!.currentPlayer == 0
          ? "Your Turn"
          : "Hendy Thinking...";
      if (game!.currentPlayer == 0) {
        _handlePlayerAutoTurn();
      }
    }
  }

  void _handlePlayerAutoTurn() {
    if (game != null && !game!.canPlayerPlay(0)) {
      if (game!.boneyard.isNotEmpty) {
        _bottomOverlayMessage = "No moves. Drawing...";
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (game != null && !game!.isGameOver && game!.currentPlayer == 0) {
            drawFromBoneyard();
          }
        });
      } else {
        _bottomOverlayMessage = "No moves. Passing...";
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (game != null && !game!.isGameOver && game!.currentPlayer == 0) {
            passTurn();
          }
        });
      }
    }
  }

  Future<void> _runAiTurn() async {
    if (game == null || game!.isGameOver) {
      _isAiThinking = false;
      return;
    }
    _isAiThinking = true;
    _statusMessage = "Hendy Thinking...";
    notifyListeners();

    // Yield to the event loop so Flutter can render the human's move
    // BEFORE the heavy synchronous AI computation starts and blocks the web thread.
    await Future.delayed(const Duration(milliseconds: 50));

    final stopwatch = Stopwatch()..start();

    // Give the AI exactly 2 seconds to think to ensure high quality moves without locking the game
    final aiAction = await getBestActionAsync(game!, 1, 2000);

    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1500) {
      await Future.delayed(Duration(milliseconds: 1500 - elapsed));
    }

    print("AI Action: $aiAction");
    if (aiAction is DrawAction) {
      _topOverlayMessage = "AI no moves... drawing tiles";
    } else if (aiAction is PassAction) {
      _topOverlayMessage = "AI no moves... passing turn";
    } else {
      _topOverlayMessage = null;
    }
    notifyListeners();

    if (game != null) {
      game!.applyAction(aiAction);
      print("Hendy played ${aiAction.toString()}");
    }

    _isAiThinking = false;
    _checkGameState();
    notifyListeners();

    // If AI just drew a tile, it might need to take another step immediately.
    // However, MCTS determinization already considers the draw action.
    // If the currentPlayer is still 1, it means the AI needs to move again.
    if (game != null && !game!.isGameOver && game!.currentPlayer == 1) {
      _runAiTurn();
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
      body: SafeArea(
        child: Column(
          children: [
            // Glassmorphism Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Human Stats
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundImage: AssetImage('assets/human.png'),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${controller.match.humanScore}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Status Center
                        Column(
                          children: [
                            Text(
                              'TARGET: ${controller.match.targetScore}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.statusMessage ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2BEE4B),
                              ),
                            ),
                          ],
                        ),

                        // AI Stats
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'HENDY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${controller.match.aiScore}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const CircleAvatar(
                              radius: 18,
                              backgroundImage: AssetImage('assets/hendy.png'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Auxiliary Stats
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 32, right: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HENDY TILES: ${game.hands[1].length}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'BONEYARD: ${game.boneyard.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Game Board
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [Color(0xFF2E6F40), Color(0xFF113820)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Center Text Decal
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Can you beat Hendy?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withOpacity(0.12),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Interactive Board Content
                    Center(
                      child: game.board.isEmpty
                          ? Text(
                              game.currentPlayer == 0
                                  ? 'Place your first tile to start'
                                  : 'Waiting for Hendy...',
                            )
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
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2BEE4B).withOpacity(0.5),
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

                    // Status Overlay (Bottom Center)
                    if (controller.bottomOverlayMessage != null &&
                        !controller.showNextRoundButton)
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
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2BEE4B).withOpacity(0.5),
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

                    // Game Over Modal (Idea B)
                    if (game.isGameOver && controller.showNextRoundButton)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.7),
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              padding: const EdgeInsets.all(32),
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
                                        ).withOpacity(0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    controller.bottomOverlayMessage ??
                                        'Game Over',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          controller.match.isMatchOver &&
                                              controller.match.matchWinner != 0
                                          ? Colors.red
                                          : const Color(0xFF2BEE4B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'LIFETIME MATCH RECORD',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _StatBox(
                                        label: 'WINS',
                                        value: controller.lifetimeMatchWins,
                                        color: const Color(0xFF2BEE4B),
                                      ),
                                      const SizedBox(width: 16),
                                      _StatBox(
                                        label: 'LOSSES',
                                        value: controller.lifetimeMatchLosses,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
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
                  ],
                ),
              ),
            ),

            // Control Area (Ends)
            if (game.board.isNotEmpty &&
                controller.statusMessage == "Your Turn")
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [const Text('Tap a tile in your hand to play')],
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
                    child: Row(
                      children: game.hands[0].asMap().entries.map((entry) {
                        final index = entry.key;
                        final tile = entry.value;
                        final isPlayable =
                            !game.isGameOver &&
                            game.currentPlayer == 0 &&
                            (game.board.isEmpty ||
                                tile.contains(game.leftEnd!) ||
                                tile.contains(game.rightEnd!));

                        return Padding(
                          padding: EdgeInsets.only(right: 12.0 * tileScale),
                          child: GestureDetector(
                            onTap: game.isGameOver || !isPlayable
                                ? null
                                : () => _showPlayOptions(
                                    context,
                                    controller,
                                    tile,
                                  ),
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
                                  scale: tileScale,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
    );
  }

  void _showPlayOptions(
    BuildContext context,
    GameController controller,
    DominoTile tile,
  ) {
    final game = controller.game!;

    // Check if playable
    bool canPlayLeft = game.board.isEmpty || tile.contains(game.leftEnd!);
    bool canPlayRight = game.board.isEmpty || tile.contains(game.rightEnd!);

    if (!canPlayLeft && !canPlayRight) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This tile cannot be played!')),
      );
      return;
    }

    if (game.board.isEmpty) {
      controller.playTile(tile, 'left');
      return;
    }

    if (canPlayLeft && !canPlayRight) {
      controller.playTile(tile, 'left');
      return;
    }

    if (canPlayRight && !canPlayLeft) {
      controller.playTile(tile, 'right');
      return;
    }

    // If both ends are the same number, playing on left or right is logically identical
    if (game.leftEnd == game.rightEnd) {
      controller.playTile(tile, 'left');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Play on which side?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (canPlayLeft)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.playTile(tile, 'left');
                        Navigator.pop(context);
                      },
                      child: const Text('LEFT END'),
                    ),
                  ),
                if (canPlayLeft && canPlayRight) const SizedBox(width: 16),
                if (canPlayRight)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.playTile(tile, 'right');
                        Navigator.pop(context);
                      },
                      child: const Text('RIGHT END'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DominoTileWidget extends StatelessWidget {
  final DominoTile tile;
  final bool isVertical;
  final bool isHighlight;
  final bool isFlipped;
  final double scale;

  const DominoTileWidget({
    super.key,
    required this.tile,
    this.isVertical = false,
    this.isHighlight = false,
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
            border: isHighlight
                ? Border.all(color: const Color(0xFF2BEE4B), width: 3 * scale)
                : Border.all(
                    color: const Color(0xFF9CA3AF),
                    width: 1.5 * scale,
                  ),
            borderRadius: BorderRadius.circular(4 * scale),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
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
                color: Colors.white.withOpacity(0.3),
                width: 1 * scale,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
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
                    gradient: const RadialGradient(
                      center: Alignment(-0.2, -0.2),
                      radius: 0.8,
                      colors: [Color(0xFF374151), Color(0xFF111827)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 1 * scale,
                        offset: Offset(0, 1 * scale),
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

  const SnakingBoard({
    super.key,
    required this.board,
    required this.rootIndex,
    required this.maxWidth,
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
          children: positions.entries.map((entry) {
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
          }).toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
