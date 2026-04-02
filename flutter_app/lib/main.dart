import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine/sound_service.dart';
import 'engine/audio_engine.dart';
import 'engine/dominoes_ai.dart' hide kIsWeb;
import 'engine/update_service.dart';

const List<String> playerNames = ['Hendy', 'Ed', 'Paul', 'Tim'];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the sound service
  final soundService = SoundService();
  await soundService.initialize();

  final updateService = UpdateService();
  unawaited(updateService.initialize());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameController()),
        ChangeNotifierProvider.value(value: updateService),
      ],
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

  bool _showReviewBoard = false;

  DominoTile? _selectedTile;

  List<int> _lifetimeMatchWins = [0, 0, 0, 0];
  List<int> _lifetimeMatchLosses = [0, 0, 0, 0];
  // Index 0: Human, 1-3: AIs. Tracks total matches won by 6-0.
  List<int> _lifetimeDishCounts = [0, 0, 0, 0];
  // Running Champion points based on Jail system
  List<int> _lifetimeSocialPoints = [0, 0, 0, 0];
  // Wins recorded at each DifficultyLevel: [rookie, casual, professional, legend]
  List<int> _lifetimeWinsByDifficulty = [0, 0, 0, 0];
  DifficultyLevel _currentDifficulty = DifficultyLevel.professional;
  List<int>? _lastMatchSocialAdjustments;
  bool _isEliteJailerMatch = false;
  bool _matchStatsSaved = false;
  bool _isSetupComplete = false;
  bool _needsResume = false;

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
  bool get showReviewBoard => _showReviewBoard;
  bool get isInitialized => _match.currentRound != null;
  DominoTile? get selectedTile => _selectedTile;
  List<int> get lifetimeMatchWins => _lifetimeMatchWins;
  List<int> get lifetimeMatchLosses => _lifetimeMatchLosses;
  List<int> get lifetimeDishCounts => _lifetimeDishCounts;
  List<int> get lifetimeSocialPoints => _lifetimeSocialPoints;
  List<int> get lifetimeWinsByDifficulty => _lifetimeWinsByDifficulty;
  List<int>? get lastMatchSocialAdjustments => _lastMatchSocialAdjustments;
  bool get isEliteJailerMatch => _isEliteJailerMatch;
  bool get needsResume => _needsResume;

  int get sixLoveChampionIndex {
    int maxDishes = _lifetimeDishCounts.reduce(math.max);
    if (maxDishes == 0) return -1;
    return _lifetimeDishCounts.indexOf(maxDishes);
  }

  int get lifetimeLeaderIndex {
    final indices = [0, 1, 2, 3];
    indices.sort((a, b) {
      if (_lifetimeMatchWins[b] != _lifetimeMatchWins[a]) {
        return _lifetimeMatchWins[b].compareTo(_lifetimeMatchWins[a]);
      }
      return _lifetimeMatchLosses[a].compareTo(_lifetimeMatchLosses[b]);
    });
    return indices.first;
  }

  bool get isMatchStarted =>
      _match.scores.any((s) => s > 0) ||
      (_match.currentRound?.board.isNotEmpty ?? false);
  bool get isSetupVisible => !_isSetupComplete;
  ScoringMode get scoringMode => _match.mode;

  static const String _kMatchKey = 'dominoes_match_data';

  Future<void> _loadLifetimeStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final winsJson = prefs.getString('lifetime_match_wins_list');
      if (winsJson != null) {
        _lifetimeMatchWins = List<int>.from(jsonDecode(winsJson));
      } else {
        _lifetimeMatchWins[0] = prefs.getInt('lifetime_match_wins') ?? 0;
      }
      final lossesJson = prefs.getString('lifetime_match_losses_list');
      if (lossesJson != null) {
        _lifetimeMatchLosses = List<int>.from(jsonDecode(lossesJson));
      } else {
        _lifetimeMatchLosses[0] = prefs.getInt('lifetime_match_losses') ?? 0;
      }

      final dishCountsJson = prefs.getString('lifetime_dish_counts');
      if (dishCountsJson != null) {
        _lifetimeDishCounts = List<int>.from(jsonDecode(dishCountsJson));
      }

      final socialPointsJson = prefs.getString('lifetime_social_points');
      if (socialPointsJson != null) {
        _lifetimeSocialPoints = List<int>.from(jsonDecode(socialPointsJson));
      }

      final winsByDiffJson = prefs.getString('lifetime_wins_by_difficulty');
      if (winsByDiffJson != null) {
        _lifetimeWinsByDifficulty = List<int>.from(jsonDecode(winsByDiffJson));
      }

      final difficultyIndex = prefs.getInt('current_difficulty_index');
      if (difficultyIndex != null) {
        _currentDifficulty = DifficultyLevel.values[difficultyIndex];
      }
    } catch (e) {
      debugPrint("Error loading lifetime stats: $e");
    }
  }

  Future<void> _saveLifetimeStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'lifetime_match_wins_list',
        jsonEncode(_lifetimeMatchWins),
      );
      await prefs.setString(
        'lifetime_match_losses_list',
        jsonEncode(_lifetimeMatchLosses),
      );
      await prefs.setString(
        'lifetime_dish_counts',
        jsonEncode(_lifetimeDishCounts),
      );
      await prefs.setString(
        'lifetime_social_points',
        jsonEncode(_lifetimeSocialPoints),
      );
      await prefs.setString(
        'lifetime_wins_by_difficulty',
        jsonEncode(_lifetimeWinsByDifficulty),
      );
      await prefs.setInt('current_difficulty_index', _currentDifficulty.index);
    } catch (e) {}
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
    // Only set _isSetupComplete if it hasn't been explicitly set by resetMatch
    if (!isMatchStarted) {
      // If we're starting fresh, it depends on whether we're in setup
    } else {
      _isSetupComplete = true;
    }
    notifyListeners();

    // If it's AI's turn to start the restored match
    if (_match.currentRound!.currentPlayer != 0) {
      _runAiTurn();
    }
  }

  void _updateStatusMessage() {
    if (_match.isMatchOver) {
      if (_match.playStyle == PlayStyle.partners) {
        int winnerTeam = _match.matchWinner % 2;
        _statusMessage = "MATCH OVER: TEAM ${winnerTeam + 1} Wins!";
      } else {
        _statusMessage = "MATCH OVER: ${playerNames[_match.matchWinner]} Wins!";
      }
      return;
    }

    if (_match.currentRound == null || _match.currentRound!.isGameOver) {
      _statusMessage = ""; // Clear turn status
      if (_match.currentRound != null) {
        int winner = _match.currentRound!.winner;
        if (_match.playStyle == PlayStyle.partners) {
          int winnerTeam = winner % 2;
          _bottomOverlayMessage = "TEAM ${winnerTeam + 1} Wins Round!";
        } else {
          if (winner == 0) {
            _bottomOverlayMessage = "${playerNames[0]} Wins Round!";
          } else if (winner != -1) {
            _bottomOverlayMessage = "${playerNames[winner]} Wins Round!";
          } else {
            _bottomOverlayMessage = "Round Drawn!";
          }
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

  Future<void> resetMatch({bool goToSetup = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMatchKey);
    
    // Preserve current settings
    final currentTarget = _match.targetScore;
    final currentMode = _match.mode;
    
    _matchStatsSaved = false;
    _isSetupComplete = !goToSetup;
    
    await _initMatch();
    
    // Ensure settings are preserved in the new match
    _match.targetScore = currentTarget;
    _match.mode = currentMode;
    if (_match.currentRound != null) {
      _match.currentRound!.scoringMode = currentMode;
      _match.currentRound!.matchTarget = currentMode == ScoringMode.sixLove ? 6 : currentTarget;
    }
    
    _isSetupComplete = !goToSetup;
    notifyListeners();
  }

  void setNeedsResume(bool val) {
    if (_needsResume == val) return;
    _needsResume = val;
    notifyListeners();
  }

  Future<void> resumeGame() async {
    print("GameController.resumeGame() called.");
    await SoundService().resume();
    _needsResume = false;
    notifyListeners();
  }

  void startMatch() {
    _isSetupComplete = true;
    notifyListeners();

    // Trigger AI turn if it's their turn to start, now that setup is complete
    if (game != null && !game!.isGameOver && game!.currentPlayer != 0) {
      _runAiTurn();
    }
  }

  void _startNextRound() {
    _showReviewBoard = false;
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

  void setScoringMode(ScoringMode mode) {
    if (isMatchStarted) return;
    _match.mode = mode;
    if (_match.currentRound != null) {
      _match.currentRound!.scoringMode = mode;
      _match.currentRound!.matchTarget = mode == ScoringMode.sixLove
          ? 6
          : _match.targetScore;
    }
    _saveMatch();
    _updateStatusMessage();
    notifyListeners();
  }

  void setTargetScore(int target) {
    if (isMatchStarted) return;
    _match.targetScore = target;
    if (_match.currentRound != null) {
      _match.currentRound!.matchTarget = target;
    }
    _saveMatch();
    notifyListeners();
  }

  void setPlayStyle(PlayStyle style) {
    if (isMatchStarted) return;
    _match.playStyle = style;
    if (_match.currentRound != null) {
      _match.currentRound!.playStyle = style;
    }
    _saveMatch();
    notifyListeners();
  }

  DifficultyLevel get currentDifficulty => _currentDifficulty;

  void setDifficulty(DifficultyLevel level) {
    if (_currentDifficulty == level) return;
    _currentDifficulty = level;
    _saveLifetimeStats();
    _updateStatusMessage();
    notifyListeners();
    print("AI Difficulty set to: ${level.name}");
  }

  void selectTile(DominoTile tile) {
    if (game == null ||
        game!.isGameOver ||
        game!.currentPlayer != 0 ||
        _isAiThinking) {
      return;
    }

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

  void skipReview() {
    if (_showReviewBoard) {
      _showReviewBoard = false;
      if (_match.isMatchOver) {
        _showNextRoundButton = true;
      } else {
        restartGame();
      }
      notifyListeners();
    }
  }

  void playTile(DominoTile tile, String side) {
    if (game == null ||
        game!.isGameOver ||
        game!.currentPlayer != 0 ||
        _isAiThinking) {
      return;
    }

    final action = PlayAction(tile, side, isFirstMove: game!.board.isEmpty);
    if (game != null) {
      game!.applyAction(action);
      SoundService().playSfx('assets/sounds/tile_place.wav');
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
        _isAiThinking) {
      return;
    }

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
      _bottomOverlayMessage = "Calculating Scores...";
      _statusMessage = "Calculating Scores...";
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 1000), () {
        int roundWinner = _match.recordRoundResult();
        _saveMatch(); // Persist scores!

        if (_match.isMatchOver) {
          if (!_matchStatsSaved) {
            _matchStatsSaved = true;
            int winner = _match.matchWinner;
            if (_match.playStyle == PlayStyle.partners) {
              int winnerTeam = winner % 2;
              for (int i = 0; i < 4; i++) {
                if (i % 2 == winnerTeam) {
                  _lifetimeMatchWins[i]++;
                } else {
                  _lifetimeMatchLosses[i]++;
                }
              }
            } else {
              for (int i = 0; i < 4; i++) {
                if (i == winner) {
                  _lifetimeMatchWins[i]++;
                } else {
                  _lifetimeMatchLosses[i]++;
                }
              }
            }

            // Track Six-Love Social Points and Elite Jailer status
            if (_match.mode == ScoringMode.sixLove) {
              final socialResult = _match.calculateSocialPoints();
              final adjustments = socialResult['adjustments'] as List<int>;
              _lastMatchSocialAdjustments = adjustments;
              _isEliteJailerMatch = socialResult['isEliteJailer'] as bool;

              for (int i = 0; i < 4; i++) {
                _lifetimeSocialPoints[i] += adjustments[i];
              }

              if (winner != -1) {
                if (_match.playStyle == PlayStyle.partners) {
                  int winnerTeam = winner % 2;
                  _lifetimeDishCounts[winnerTeam]++; 
                  _lifetimeDishCounts[winnerTeam + 2]++;
                } else {
                  _lifetimeDishCounts[winner]++;
                }
              }
            } else {
              _lastMatchSocialAdjustments = null;
              _isEliteJailerMatch = false;
            }

            // Track Win Quality (Strength of Schedule) for the human player
            if (winner == 0) {
              _lifetimeWinsByDifficulty[_currentDifficulty.index]++;
            }

            _saveLifetimeStats();
          }
        }

        if (_match.isMatchOver) {
          if (_match.playStyle == PlayStyle.partners) {
            int winnerTeam = _match.matchWinner % 2;
            _bottomOverlayMessage = "MATCH OVER: TEAM ${winnerTeam + 1} Wins!";
          } else if (_match.matchWinner == 0) {
            _bottomOverlayMessage = "MATCH OVER: ${playerNames[0]} Wins!";
          } else if (_match.matchWinner != -1) {
            _bottomOverlayMessage =
                "MATCH OVER: ${playerNames[_match.matchWinner]} Wins!";
          } else {
            _bottomOverlayMessage = "MATCH OVER: Tie!";
          }
          _statusMessage = _bottomOverlayMessage;
        } else {
          // Calculate and set winner message for Review Board
          if (roundWinner != -1) {
            int points = 0;
            if (_match.mode == ScoringMode.sixLove) {
              points = 1;
              // Additional points for Key Bone/Derby calculated by engine and applied during MatchModel.recordRoundResult
            } else {
              for (int i = 0; i < 4; i++) {
                if (i % 2 != roundWinner % 2) {
                  points += game!.hands[i].fold(0, (sum, t) => sum + t.score);
                }
              }
            }
            if (_match.playStyle == PlayStyle.partners) {
              int winnerTeam = roundWinner % 2;
              _statusMessage = "TEAM ${winnerTeam + 1} gets +$points";
            } else {
              _statusMessage = "${playerNames[roundWinner]} gets +$points";
            }
            _bottomOverlayMessage = _statusMessage;
          } else {
            _statusMessage = "Round Drawn!";
            _bottomOverlayMessage = _statusMessage;
          }
        }

        _showNextRoundButton = false;
        _isFinishingRound = false;

        // Start Review Phase
        _showReviewBoard = true;
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
      SoundService().playSfx('assets/sounds/tile_knock.wav');
      HapticFeedback.lightImpact();
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (game != null && !game!.isGameOver && game!.currentPlayer == 0) {
          passTurn();
        }
      });
    }
  }

  Duration _getAiThinkingDuration(int numOptions) {
    if (numOptions == 0) return const Duration(milliseconds: 100);
    if (numOptions == 1) return const Duration(milliseconds: 1000);

    // Randomized thinking time for strategic moves (avg 3.1s)
    final ms = 2500 + math.Random().nextInt(1200);
    return Duration(milliseconds: ms);
  }

  Future<void> _runAiTurn() async {
    if (game == null || game!.isGameOver || !_isSetupComplete) {
      _isAiThinking = false;
      return;
    }

    int cp = game!.currentPlayer;
    final legalActions = game!.getLegalActions(cp);
    final numPlayOptions = legalActions.whereType<PlayAction>().length;
    final bool isKnock = numPlayOptions == 0;

    // Determine specific delays for this turn
    final int preDelayMs = isKnock ? 200 : 300;
    final int postMoveDelayMs = isKnock
        ? 300
        : (numPlayOptions == 1 ? 700 : 600);
    final int knockDelayMs = 400;

    _isAiThinking = true;
    _statusMessage = "${playerNames[cp]} Thinking...";
    notifyListeners();

    // Natural delay before starting to "think"
    await Future.delayed(Duration(milliseconds: preDelayMs));

    final thinkingDuration = _getAiThinkingDuration(numPlayOptions);
    final stopwatch = Stopwatch()..start();

    // AI calculation
    final aiAction = await getBestActionAsync(
      game!,
      cp,
      1000,
      _currentDifficulty,
      _match.scores,
      _match.targetScore,
      _match.mode,
    );
    final elapsed = stopwatch.elapsedMilliseconds;

    // Wait for the remainder of the randomized thinking time
    final remainingDelay = thinkingDuration.inMilliseconds - elapsed;
    if (remainingDelay > 0) {
      await Future.delayed(Duration(milliseconds: remainingDelay));
    }

    print("AI Player $cp Action: $aiAction");
    if (aiAction is PassAction) {
      // Contextual Knock for AI
      _knockingPlayerIndex = cp;
      SoundService().playSfx('assets/sounds/tile_knock.wav');
      notifyListeners();
      await Future.delayed(Duration(milliseconds: knockDelayMs));
    }

    if (game != null) {
      if (aiAction is PlayAction) {
        game!.applyAction(aiAction);
        SoundService().playSfx('assets/sounds/tile_place.wav');
      } else {
        game!.applyAction(aiAction);
      }
      notifyListeners(); // Immediate update to show the tile
      print("Player $cp played ${aiAction.toString()}");
    }

    // Brief pause to allow the user to see the move before turn indicator shifts
    await Future.delayed(Duration(milliseconds: postMoveDelayMs));

    _isAiThinking = false;
    _checkGameState();
    notifyListeners();

    // Loop directly back to run AI turn if the next player is ALSO an AI
    if (game != null && !game!.isGameOver && game!.currentPlayer != 0) {
      // Call async microtask to safely chain AI turns
      Future.microtask(() => _runAiTurn());
    }
  }

  Future<void> restartGame({bool goToSetup = false}) async {
    if (_match.isMatchOver) {
      await resetMatch(goToSetup: goToSetup);
    } else if (game != null && game!.isGameOver) {
      // Clear overlays and wait for Skwasm to settle
      _topOverlayMessage = null;
      _bottomOverlayMessage = null;
      _showNextRoundButton = false;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 100));
      _startNextRound();
    } else {
      // User tapped reset mid-round
      _topOverlayMessage = null;
      _bottomOverlayMessage = null;
      await resetMatch(goToSetup: goToSetup);
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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  int _lastHandSize = 0;
  double _edYOffset = 0;
  double _timYOffset = 0;
  Size? _lastBoardSize;
  List<Rect>? _lastTileRects;
  Size _containerSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // We'll use a post-frame callback or listener to detect hand changes
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kIsWeb) {
        // When returning to the tab, we often need a new gesture to resume audio
        context.read<GameController>().setNeedsResume(true);
      }
    }
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

  void _handleBoardLayoutCalculated(Size boardSize, List<Rect> tileRects) {
    _lastBoardSize = boardSize;
    _lastTileRects = tileRects;
    _updateHudOffsets();
  }

  void _updateHudOffsets() {
    if (_lastBoardSize == null ||
        _lastTileRects == null ||
        _containerSize == Size.zero ||
        !mounted) {
      return;
    }

    final boardOffset = Offset(
      (_containerSize.width - _lastBoardSize!.width) / 2,
      (_containerSize.height - _lastBoardSize!.height) / 2,
    );

    final globalTiles = _lastTileRects!
        .map((r) => r.shift(boardOffset))
        .toList();

    // HUD size estimates: 72x80
    setState(() {
      _edYOffset = _findMinimalOffset(
        hudRect: Rect.fromLTWH(16, _containerSize.height / 2 - 40, 72, 80),
        tiles: globalTiles,
        containerHeight: _containerSize.height,
      );

      _timYOffset = _findMinimalOffset(
        hudRect: Rect.fromLTWH(
          _containerSize.width - 16 - 72,
          _containerSize.height / 2 - 40,
          72,
          80,
        ),
        tiles: globalTiles,
        containerHeight: _containerSize.height,
      );
    });
  }

  double _findMinimalOffset({
    required Rect hudRect,
    required List<Rect> tiles,
    required double containerHeight,
  }) {
    // Outward search: 0, 5, -5, 10, -10...
    for (double dy = 0; dy < containerHeight / 2; dy += 5) {
      if (_isClear(hudRect.shift(Offset(0, dy)), tiles, containerHeight)) {
        return dy;
      }
      if (dy == 0) continue;
      if (_isClear(hudRect.shift(Offset(0, -dy)), tiles, containerHeight)) {
        return -dy;
      }
    }
    return 0;
  }

  bool _isClear(Rect hud, List<Rect> tiles, double containerHeight) {
    // Keep away from screen edges and existing top/bottom HUDs (approx 80px high)
    if (hud.top < 80 || hud.bottom > containerHeight - 80) return false;

    for (final tile in tiles) {
      if (hud.overlaps(tile.inflate(8))) return false; // 8px buffer
    }
    return true;
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: controller.isSetupVisible
            ? _MatchSetupView(
                key: const ValueKey('match_setup'),
                controller: controller,
              )
            : GestureDetector(
                key: const ValueKey('game_board'),
                onTap: () {
                  // Master Unlock for Web Audio on first tap
                  if (kIsWeb) {
                    AudioEngine.unlockAudio();
                  }
                  controller.clearSelection();
                },
                child: Stack(
                  children: [
                    SafeArea(
                      child: Column(
                    children: [
                      // Game Board (Now taking full height)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B5B32),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              _containerSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  // (Match Controls moved to end of Stack for Z-index)
                                  // (Update Banner moved to end of Stack for Z-index)

                                  // (Status Overlay removed - now per-player dots)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: _EdgeScore(
                                      name: 'Hendy',
                                      tiles: game.hands[0].length,
                                      score: controller.match.playStyle == PlayStyle.partners
                                          ? controller.match.scores[0] + controller.match.scores[2]
                                          : controller.match.scores[0],
                                      isActive: game.currentPlayer == 0,
                                      isKnocking:
                                          controller.knockingPlayerIndex == 0,
                                      teamName: controller.match.playStyle == PlayStyle.partners ? 'TEAM 1' : null,
                                    ),
                                  ),
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    left: 16,
                                    top:
                                        _containerSize.height / 2 -
                                        40 +
                                        _edYOffset,
                                    child: _EdgeScore(
                                      name: 'Ed',
                                      tiles: game.hands[1].length,
                                      score: controller.match.playStyle == PlayStyle.partners
                                          ? controller.match.scores[1] + controller.match.scores[3]
                                          : controller.match.scores[1],
                                      isActive: game.currentPlayer == 1,
                                      isKnocking:
                                          controller.knockingPlayerIndex == 1,
                                      isThinking: game.currentPlayer == 1,
                                      teamName: controller.match.playStyle == PlayStyle.partners ? 'TEAM 2' : null,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 50.0),
                                      child: _EdgeScore(
                                        name: 'Paul',
                                        tiles: game.hands[2].length,
                                        score: controller.match.playStyle == PlayStyle.partners
                                            ? controller.match.scores[0] + controller.match.scores[2]
                                            : controller.match.scores[2],
                                        isActive: game.currentPlayer == 2,
                                        isKnocking:
                                            controller.knockingPlayerIndex == 2,
                                        isThinking: game.currentPlayer == 2,
                                        teamName: controller.match.playStyle == PlayStyle.partners ? 'TEAM 1' : null,
                                      ),
                                    ),
                                  ),
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    right: 16,
                                    top:
                                        _containerSize.height / 2 -
                                        40 +
                                        _timYOffset,
                                    child: _EdgeScore(
                                      name: 'Tim',
                                      tiles: game.hands[3].length,
                                      score: controller.match.playStyle == PlayStyle.partners
                                          ? controller.match.scores[1] + controller.match.scores[3]
                                          : controller.match.scores[3],
                                      isActive: game.currentPlayer == 3,
                                      isKnocking:
                                          controller.knockingPlayerIndex == 3,
                                      isThinking: game.currentPlayer == 3,
                                      teamName: controller.match.playStyle == PlayStyle.partners ? 'TEAM 2' : null,
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
                                        : Stack(
                                            children: [
                                              // Curved Watermark
                                              Center(
                                                child: Opacity(
                                                  opacity: 0.1,
                                                  child: _CurvedText(
                                                    text: "HELP HENDY WIN",
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                      letterSpacing: 2,
                                                    ),
                                                    radius: 100,
                                                  ),
                                                ),
                                              ),
                                              InteractiveViewer(
                                                boundaryMargin:
                                                    const EdgeInsets.all(1000),
                                                minScale: 0.1,
                                                maxScale: 2.0,
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return SnakingBoard(
                                                      board: game.board,
                                                      rootIndex: game.rootIndex,
                                                      maxWidth:
                                                          constraints.maxWidth,
                                                      isSelectingSide:
                                                          controller
                                                              .selectedTile !=
                                                          null,
                                                      onSelectSide: controller
                                                          .confirmPlay,
                                                      onLayoutCalculated:
                                                          _handleBoardLayoutCalculated,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),

                                  // Status Overlay (Top Center)
                                  if (controller.topOverlayMessage != null)
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 16.0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF2BEE4B,
                                              ).withOpacity(0.5),
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
                                      controller.bottomOverlayMessage !=
                                          "..game over") ...[
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF2BEE4B,
                                              ).withOpacity(0.5),
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

                                  // Game Over Modal (Idea B)
                                  if (game.isGameOver &&
                                      controller.showNextRoundButton)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withOpacity(0.7),
                                        child: Center(
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 360,
                                            ),
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 24,
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E1E1E),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color:
                                                    controller.match.isMatchOver
                                                    ? (controller
                                                                  .match
                                                                  .matchWinner ==
                                                              0
                                                          ? const Color(
                                                              0xFF2BEE4B,
                                                            )
                                                          : Colors.red)
                                                    : const Color(
                                                        0xFF2BEE4B,
                                                      ).withOpacity(0.5),
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (controller.match.isMatchOver)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 12.0),
                                                      child: _buildMatchGradeBadge(controller.currentDifficulty),
                                                    ),
                                                  Text(
                                                    controller
                                                            .bottomOverlayMessage ??
                                                        'Game Over',
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          controller
                                                                  .match
                                                                  .isMatchOver &&
                                                              controller
                                                                      .match
                                                                      .matchWinner !=
                                                                  0
                                                          ? Colors.red
                                                          : const Color(
                                                              0xFF2BEE4B,
                                                            ),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  if (controller.scoringMode !=
                                                      ScoringMode.sixLove) ...[
                                                    const SizedBox(height: 16),
                                                    const Text(
                                                      'LIFETIME MATCH RECORD',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white54,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black26,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Column(
                                                        children: (() {
                                                          final indices =
                                                              List.generate(
                                                                4,
                                                                (i) => i,
                                                              );
                                                          indices.sort((a, b) {
                                                            int winComp = controller
                                                                .lifetimeMatchWins[
                                                                    b]
                                                                .compareTo(
                                                                    controller
                                                                        .lifetimeMatchWins[
                                                                    a]);
                                                            if (winComp != 0) {
                                                              return winComp;
                                                            }
                                                            return controller
                                                                .lifetimeMatchLosses[
                                                                    a]
                                                                .compareTo(
                                                                    controller
                                                                        .lifetimeMatchLosses[
                                                                    b]);
                                                          });

                                                          return indices
                                                              .asMap()
                                                              .entries
                                                              .map<Widget>((entry) {
                                                            final pos =
                                                                entry.key;
                                                            final pIdx =
                                                                entry.value;
                                                            return Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 16,
                                                                vertical: 8,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: pos < 3
                                                                    ? const Border(
                                                                        bottom:
                                                                            BorderSide(
                                                                          color: Colors
                                                                              .white10,
                                                                        ),
                                                                      )
                                                                    : null,
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Text(
                                                                        playerNames[pIdx],
                                                                        style: const TextStyle(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      if (pos == 0) ...[
                                                                        const SizedBox(width: 4),
                                                                        const Text('👑',
                                                                            style: TextStyle(
                                                                                fontSize:
                                                                                    14)),
                                                                      ],
                                                                    ],
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      Text(
                                                                        'W: ${controller.lifetimeMatchWins[pIdx]}',
                                                                        style:
                                                                            const TextStyle(
                                                                          color: Color(
                                                                            0xFF2BEE4B,
                                                                          ),
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                      Text(
                                                                        'L: ${controller.lifetimeMatchLosses[pIdx]}',
                                                                        style:
                                                                            const TextStyle(
                                                                          color: Colors
                                                                              .orange,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList();
                                                        })(),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    _buildVictoryQualityRow(controller.lifetimeWinsByDifficulty),
                                                  ] else ...[
                                                    const SizedBox(height: 12),
                                                    _ChampionStatus(
                                                      championIndex: controller
                                                          .sixLoveChampionIndex,
                                                      dishCounts: controller
                                                          .lifetimeDishCounts,
                                                      socialPoints: controller
                                                          .lifetimeSocialPoints,
                                                      playerNames: playerNames,
                                                    ),
                                                  ],
                                                  if (controller.scoringMode ==
                                                      ScoringMode.sixLove) ...[
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'RUNNING CHAMPION STANDINGS',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            const Color(
                                                              0xFF2BEE4B,
                                                            ).withValues(
                                                              alpha: 0.7,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black26,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Column(
                                                        children: (() {
                                                          final indices =
                                                              List.generate(
                                                                4,
                                                                (i) => i,
                                                              );
                                                          indices.sort(
                                                            (a, b) => controller
                                                                .lifetimeSocialPoints[b]
                                                                .compareTo(
                                                                  controller
                                                                      .lifetimeSocialPoints[a],
                                                                ),
                                                          );

                                                          return indices.asMap().entries.map<Widget>((
                                                            entry,
                                                          ) {
                                                            final pos = entry
                                                                .key; // 0-based rank
                                                            final index = entry
                                                                .value; // Original player index
                                                            final points =
                                                                controller
                                                                    .lifetimeSocialPoints[index];
                                                            final dishes =
                                                                controller
                                                                    .lifetimeDishCounts[index];
                                                            final isChamp =
                                                                controller
                                                                    .sixLoveChampionIndex ==
                                                                index;
                                                            final adjustment =
                                                                controller
                                                                    .lastMatchSocialAdjustments?[index];
                                                            final wasWinner =
                                                                controller
                                                                    .match
                                                                    .matchWinner ==
                                                                index;

                                                            return Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical: 6,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                border: pos < 3
                                                                    ? Border(
                                                                        bottom: BorderSide(
                                                                          color:
                                                                              Colors.white10,
                                                                        ),
                                                                      )
                                                                    : null,
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Text(
                                                                    isChamp
                                                                        ? '👑'
                                                                        : '${pos + 1}.',
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Row(
                                                                        children: [
                                                                          Text(
                                                                            playerNames[index],
                                                                            style: TextStyle(
                                                                              color: isChamp
                                                                                  ? const Color(
                                                                                      0xFF2BEE4B,
                                                                                    )
                                                                                  : Colors.white70,
                                                                              fontWeight: isChamp
                                                                                  ? FontWeight.bold
                                                                                  : FontWeight.normal,
                                                                            ),
                                                                          ),
                                                                          if (wasWinner &&
                                                                              controller.isEliteJailerMatch)
                                                                            const Padding(
                                                                              padding: EdgeInsets.only(
                                                                                left: 4.0,
                                                                              ),
                                                                              child: Text(
                                                                                '💎',
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      ),
                                                                      if (adjustment !=
                                                                          null)
                                                                        Text(
                                                                          adjustment >
                                                                                  0
                                                                              ? '+$adjustment points'
                                                                              : '$adjustment points',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                9,
                                                                            color:
                                                                                adjustment >
                                                                                    0
                                                                                ? const Color(
                                                                                    0xFF2BEE4B,
                                                                                  ).withOpacity(
                                                                                    0.7,
                                                                                  )
                                                                                : Colors.red.withOpacity(
                                                                                    0.7,
                                                                                  ),
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                  const Spacer(),
                                                                  Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .end,
                                                                    children: [
                                                                      Text(
                                                                        '$points pts',
                                                                        style: TextStyle(
                                                                          color:
                                                                              isChamp
                                                                              ? const Color(
                                                                                  0xFF2BEE4B,
                                                                                )
                                                                              : Colors.white,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        '$dishes Dishes',
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              9,
                                                                          color:
                                                                              Colors.white38,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList();
                                                        })(),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    _buildVictoryQualityRow(controller.lifetimeWinsByDifficulty),
                                                  ],
                                                  const SizedBox(height: 24),
                                                  if (controller.match.isMatchOver) ...[
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton.icon(
                                                        icon: const Icon(Icons.replay),
                                                        label: const Text('PLAY AGAIN'),
                                                        onPressed: () =>
                                                            controller.restartGame(
                                                          goToSetup: false,
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                            0xFF2BEE4B,
                                                          ),
                                                          foregroundColor:
                                                              Colors.black,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            vertical: 12,
                                                          ),
                                                          textStyle:
                                                              const TextStyle(
                                                            inherit: false,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: OutlinedButton.icon(
                                                        icon: const Icon(
                                                          Icons
                                                              .settings_backup_restore,
                                                        ),
                                                        label: const Text(
                                                          'CHANGE RULES',
                                                        ),
                                                        onPressed: () =>
                                                            controller.restartGame(
                                                          goToSetup: true,
                                                        ),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              const Color(
                                                            0xFF2BEE4B,
                                                          ),
                                                          side: const BorderSide(
                                                            color: Color(
                                                              0xFF2BEE4B,
                                                            ),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            vertical: 12,
                                                          ),
                                                          textStyle:
                                                              const TextStyle(
                                                            inherit: false,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ] else
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton.icon(
                                                        icon: const Icon(
                                                          Icons.play_arrow,
                                                        ),
                                                        label: const Text(
                                                          'PLAY NEXT ROUND',
                                                        ),
                                                        onPressed: controller
                                                            .restartGame,
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                            0xFF2BEE4B,
                                                          ),
                                                          foregroundColor:
                                                              Colors.black,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            vertical: 12,
                                                          ),
                                                          textStyle:
                                                              const TextStyle(
                                                            inherit: false,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
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

                                  // Match Settings Icon (Top Left)
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: IconButton(
                                      tooltip: 'Match Settings',
                                      icon: const Icon(
                                        Icons.settings,
                                        color: Color(0xFF2BEE4B),
                                        size: 24,
                                      ),
                                      onPressed: () => _showResetConfirmation(
                                        context,
                                        controller,
                                      ),
                                    ),
                                  ),

                                  // Match Info Overlay (Top Center)
                                  Positioned(
                                    top: 8,
                                    left: 0,
                                    right: 0,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Builder(
                                        builder: (context) {
                                          final double screenWidth = MediaQuery.of(context).size.width;
                                          final bool isNarrow = screenWidth < 600;
                                          
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withAlpha(100),
                                              borderRadius: BorderRadius.circular(
                                                20,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                  Text(
                                                    controller.match.playStyle ==
                                                            PlayStyle.partners
                                                        ? 'PARTNERS'
                                                        : 'SOLO',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 1,
                                                  height: 12,
                                                  color: Colors.white24,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  controller.scoringMode ==
                                                          ScoringMode.sixLove
                                                      ? 'SIX-LOVE'
                                                      : 'Trgt=${controller.match.targetScore}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 1,
                                                  height: 12,
                                                  color: Colors.white24,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isNarrow && controller.currentDifficulty == DifficultyLevel.professional
                                                      ? 'PRO'
                                                      : controller.currentDifficulty.name.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Color(0xFF2BEE4B),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      ),
                                    ),
                                  ),

                                  // Match Controls Overlay (Top Right - Highest Z-Index)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          padding: const EdgeInsets.all(
                                            12,
                                          ),
                                          tooltip: 'How to Play',
                                          icon: const Icon(
                                            Icons.help_outline,
                                            color: Colors.white70,
                                            size: 24,
                                          ),
                                          onPressed: () => _showHelpModal(
                                            context,
                                            controller,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Review Board Overlay
                                  if (controller.showReviewBoard &&
                                      !controller.showNextRoundButton)
                                    Positioned.fill(
                                      child: ReviewBoardOverlay(
                                        controller: controller,
                                      ),
                                    ),

                                  // Resume Overlay
                                  if (controller.needsResume)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () => controller.resumeGame(),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.85),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.volume_up,
                                                  color: Color(0xFF2BEE4B),
                                                  size: 64,
                                                ),
                                                const SizedBox(height: 24),
                                                Text(
                                                  'RESUME TO PLAY',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Tap anywhere to restore audio',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.6),
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                              );
                            },
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
                            children: [
                              const Text('Tap a tile in your hand to play'),
                            ],
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
                          final availableWidth = screenWidth - 32;
                          double tileScale = (availableWidth / 422).clamp(
                            0.5,
                            1.0,
                          );

                          return SizedBox(
                            height: 102 * tileScale + 18,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: (controller.knockingPlayerIndex == 0)
                                  ? ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                        sigmaX: 5,
                                        sigmaY: 5,
                                      ),
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        opacity: 0.3,
                                        child: _buildHandRow(
                                          game,
                                          controller,
                                          tileScale,
                                        ),
                                      ),
                                    )
                                  : AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      opacity:
                                          controller.knockingPlayerIndex == 0
                                          ? 0.3
                                          : 1.0,
                                      child: _buildHandRow(
                                        game,
                                        controller,
                                        tileScale,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
        ),
        const _UpdateBanner(),
      ],
    );
  }

  Widget _buildHandRow(
    GameModel game,
    GameController controller,
    double tileScale,
  ) {
    return Row(
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
            onTap:
                game.isGameOver ||
                    !isPlayable ||
                    controller.knockingPlayerIndex == 0
                ? null
                : () => controller.selectTile(tile),
            child: Opacity(
              opacity: game.isGameOver || game.currentPlayer != 0 || isPlayable
                  ? 1.0
                  : 0.4,
              child: Hero(
                tag: 'tile-$index',
                child: DominoTileWidget(
                  tile: tile,
                  isVertical: true,
                  isHighlight: isPlayable,
                  isSelected: controller.selectedTile == tile,
                  scale: tileScale,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  Widget _buildMatchGradeBadge(DifficultyLevel difficulty) {
    String grade;
    String label;
    Color color;

    switch (difficulty) {
      case DifficultyLevel.legend:
        grade = 'A';
        label = 'LEGENDARY';
        color = const Color(0xFF64FFDA);
        break;
      case DifficultyLevel.professional:
        grade = 'B';
        label = 'PROFESSIONAL';
        color = const Color(0xFF2BEE4B);
        break;
      case DifficultyLevel.casual:
        grade = 'C';
        label = 'CASUAL';
        color = Colors.orangeAccent;
        break;
      case DifficultyLevel.rookie:
        grade = 'D';
        label = 'NOVICE';
        color = Colors.white54;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              grade,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'MATCH INTENSITY: $label',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVictoryQualityRow(List<int> winsByDiff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VICTORY QUALITY',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQualityBadge('A', winsByDiff[3], const Color(0xFF64FFDA)),
            _buildQualityBadge('B', winsByDiff[2], const Color(0xFF2BEE4B)),
            _buildQualityBadge('C', winsByDiff[1], Colors.orangeAccent),
            _buildQualityBadge('D', winsByDiff[0], Colors.white54),
          ],
        ),
      ],
    );
  }

  Widget _buildQualityBadge(String grade, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '×$count',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
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
            gradient: const RadialGradient(
              center: Alignment(-0.2, -0.4),
              radius: 1.2,
              colors: [
                Color(0xFFFFFFFF), // Highlight
                Color(0xFFFDFBF7), // Mid
                Color(0xFFF3F0E8), // Shadow side
              ],
            ),
            border: isSelected
                ? Border.all(color: const Color(0xFF2BEE4B), width: 4 * scale)
                : isHighlight
                ? Border.all(
                    color: const Color(0xFF2BEE4B).withOpacity(0.5),
                    width: 2 * scale,
                  )
                : Border.all(
                    color: const Color(0xFF9CA3AF).withOpacity(0.4),
                    width: 1.5 * scale,
                  ),
            borderRadius: BorderRadius.circular(6 * scale),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF2BEE4B).withOpacity(0.6),
                  blurRadius: 15 * scale,
                  spreadRadius: 2 * scale,
                )
              else ...[
                // Main soft shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8 * scale,
                  offset: Offset(2 * scale, 4 * scale),
                ),
                // Sharp contact shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2 * scale,
                  offset: Offset(0, 1 * scale),
                  spreadRadius: -1 * scale,
                ),
              ],
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

    return SizedBox(
      width: 40 * scale,
      height: 40 * scale,
      child: CustomPaint(
        painter: _PipsPainter(
          count: count,
          color: baseColor,
          scale: scale,
          isVertical: isVertical,
        ),
      ),
    );
  }
}

class _PipsPainter extends CustomPainter {
  final int count;
  final Color color;
  final double scale;
  final bool isVertical;

  _PipsPainter({
    required this.count,
    required this.color,
    required this.scale,
    required this.isVertical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double dotSize = 8.0 * scale;
    final double w = size.width;
    final double h = size.height;
    final double pad = 8.0 * scale;

    void drawDot(double cx, double cy) {
      final center = Offset(cx, cy);
      // Subtle inner depth shadow for the pip
      canvas.drawCircle(
        center.translate(0.5 * scale, 0.5 * scale),
        dotSize / 2,
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1 * scale),
      );
      canvas.drawCircle(center, dotSize / 2, paint);
      // Slight highlight for "drilled" look
      canvas.drawCircle(
        center.translate(-0.5 * scale, -0.5 * scale),
        dotSize / 2.5,
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale,
      );
    }

    // 1: center
    if (count % 2 == 1) drawDot(w / 2, h / 2);

    // 2, 3: diagonals
    if (count == 2 || count == 3) {
      if (isVertical) {
        drawDot(pad, pad); // TL
        drawDot(w - pad, h - pad); // BR
      } else {
        drawDot(w - pad, pad); // TR
        drawDot(pad, h - pad); // BL
      }
    }

    // 4, 5: 4 corners
    if (count >= 4) {
      drawDot(pad, pad); // TL
      drawDot(w - pad, pad); // TR
      drawDot(pad, h - pad); // BL
      drawDot(w - pad, h - pad); // BR
    }

    // 6: 2 rows or 2 columns
    if (count == 6) {
      if (isVertical) {
        // 2 columns (Left / Right)
        drawDot(pad, h / 2);
        drawDot(w - pad, h / 2);
      } else {
        // 2 rows (Top / Bottom)
        drawDot(w / 2, pad);
        drawDot(w / 2, h - pad);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PipsPainter oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.color != color ||
      oldDelegate.isVertical != isVertical;
}

class SnakingBoard extends StatelessWidget {
  final List<DominoTile> board;
  final int rootIndex;
  final double maxWidth;
  final bool isSelectingSide;
  final Function(String)? onSelectSide;
  final Function(Size, List<Rect>)? onLayoutCalculated;

  const SnakingBoard({
    super.key,
    required this.board,
    required this.rootIndex,
    required this.maxWidth,
    this.isSelectingSide = false,
    this.onSelectSide,
    this.onLayoutCalculated,
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
            maxWidth / 2 - turnClearance) {
          turnNow = true;
        }
      } else {
        if (rightCursorX - (isDouble ? vWidth : hWidth) <
            -maxWidth / 2 + turnClearance) {
          turnNow = true;
        }
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
            -maxWidth / 2 + turnClearance) {
          turnNow = true;
        }
      } else {
        if (leftCursorX + (isDouble ? vWidth : hWidth) >
            maxWidth / 2 - turnClearance) {
          turnNow = true;
        }
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

    if (onLayoutCalculated != null) {
      final List<Rect> tileRects = positions.values.map((pos) {
        return Rect.fromLTWH(
          pos.offset.dx - minX,
          pos.offset.dy - minY,
          pos.isVertical ? vWidth : hWidth,
          pos.isVertical ? vHeight : hHeight,
        );
      }).toList();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLayoutCalculated!(Size(boardWidth, boardHeight), tileRects);
      });
    }

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
                      color: const Color(0xFF2BEE4B).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2BEE4B).withOpacity(0.6),
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
                      color: const Color(0xFF2BEE4B).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2BEE4B).withOpacity(0.6),
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
  final bool isThinking;
  final String? teamName;

  const _EdgeScore({
    required this.name,
    required this.tiles,
    required this.score,
    required this.isActive,
    required this.isKnocking,
    this.isThinking = false,
    this.teamName,
  });

  @override
  State<_EdgeScore> createState() => _EdgeScoreState();
}

class _EdgeScoreState extends State<_EdgeScore> with TickerProviderStateMixin {
  late AnimationController _knockingController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _knockingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _knockingController, curve: Curves.easeInOut),
        );

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_EdgeScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isKnocking && !oldWidget.isKnocking) {
      _knockingController.repeat(count: 2);
    } else if (!widget.isKnocking && oldWidget.isKnocking) {
      _knockingController.stop();
      _knockingController.reset();
    }

    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _knockingController.dispose();
    _pulseController.dispose();
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isActive)
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2BEE4B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2BEE4B),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.teamName != null)
                      Text(
                        widget.teamName!,
                        style: TextStyle(
                          fontSize: 10,
                          color: (widget.isActive || widget.isKnocking)
                              ? const Color(0xFF2BEE4B).withOpacity(0.8)
                              : widget.teamName == 'TEAM 2' 
                                  ? const Color(0xFFFFD700).withOpacity(0.7)
                                  : Colors.white70,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isActive || widget.isKnocking
                            ? const Color(0xFF2BEE4B)
                            : widget.teamName == 'TEAM 2'
                                ? const Color(0xFFFFD700)
                                : Colors.white,
                        fontWeight: widget.isActive || widget.isKnocking
                            ? FontWeight.bold
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                if ((context.watch<GameController>().scoringMode == ScoringMode.sixLove &&
                        context.watch<GameController>().sixLoveChampionIndex ==
                            playerNames.indexOf(widget.name)) ||
                    (context.watch<GameController>().scoringMode == ScoringMode.traditional &&
                        context.watch<GameController>().lifetimeLeaderIndex ==
                            playerNames.indexOf(widget.name)))
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Tooltip(
                      message: context.watch<GameController>().scoringMode ==
                              ScoringMode.sixLove
                          ? 'Six-Love Champion'
                          : 'Lifetime Leader',
                      child: Text('👑', 
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.teamName == 'TEAM 2' ? const Color(0xFFFFD700) : null,
                        )
                      ),
                    ),
                  ),
                if (widget.isThinking) const _ThinkingDots(),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.tiles}/${widget.score}',
              style: TextStyle(
                fontSize: 14,
                color: widget.isActive || widget.isKnocking
                    ? const Color(0xFF2BEE4B)
                    : widget.teamName == 'TEAM 2'
                        ? const Color(0xFFFFD700).withOpacity(0.8)
                        : Colors.white.withOpacity(0.8),
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

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animations = List.generate(3, (i) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (context, child) {
              return Opacity(
                opacity: _animations[i].value,
                child: Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2BEE4B),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _ChampionStatus extends StatelessWidget {
  final int championIndex;
  final List<int> dishCounts;
  final List<int> socialPoints;
  final List<String> playerNames;

  const _ChampionStatus({
    required this.championIndex,
    required this.dishCounts,
    required this.socialPoints,
    required this.playerNames,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String name;
    String subtext;
    Color accentColor;
    String icon;

    if (championIndex != -1) {
      title = 'CURRENT CHAMPION';
      name = playerNames[championIndex].toUpperCase();
      subtext = 'Defend the title!';
      accentColor = const Color(0xFF2BEE4B);
      icon = '👑';
    } else {
      // Find top contender
      int maxDishes = -1;
      int topIndex = -1;
      for (int i = 0; i < dishCounts.length; i++) {
        if (dishCounts[i] > maxDishes) {
          maxDishes = dishCounts[i];
          topIndex = i;
        }
      }

      if (maxDishes > 0) {
        title = 'TOP CONTENDER';
        name = playerNames[topIndex].toUpperCase();
        subtext = '$maxDishes Dishes Given • ${socialPoints[topIndex]} Points';
        accentColor = Colors.orange;
        icon = '⚔️';
      } else {
        // Use social points if no dishes yet
        int maxPoints = -1000;
        int topSocialIndex = -1;
        for (int i = 0; i < socialPoints.length; i++) {
          if (socialPoints[i] > maxPoints) {
            maxPoints = socialPoints[i];
            topSocialIndex = i;
          }
        }

        if (maxPoints > 0) {
          title = 'RISING STAR';
          name = playerNames[topSocialIndex].toUpperCase();
          subtext = 'Leading with $maxPoints social points';
          accentColor = Colors.cyanAccent;
          icon = '⭐';
        } else {
          title = 'CHAMPIONSHIP VACANT';
          name = 'NO CHAMPION';
          subtext = 'Win 6-0 to claim the crown!';
          accentColor = Colors.white24;
          icon = '⚪';
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: accentColor.withOpacity(0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: championIndex != -1 ? accentColor : Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double radius;

  const _CurvedText({
    required this.text,
    required this.style,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CurvedTextPainter(text: text, textStyle: style, radius: radius),
    );
  }
}

class _CurvedTextPainter extends CustomPainter {
  final String text;
  final TextStyle textStyle;
  final double radius;

  _CurvedTextPainter({
    required this.text,
    required this.textStyle,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Calculate angles for each character
    double totalAngle = 0;
    final List<double> charAngles = [];
    for (int i = 0; i < text.length; i++) {
      textPainter.text = TextSpan(text: text[i], style: textStyle);
      textPainter.layout();
      double angle = textPainter.width / radius;
      charAngles.add(angle);
      totalAngle += angle;
    }

    double currentAngle = -totalAngle / 2;

    for (int i = 0; i < text.length; i++) {
      textPainter.text = TextSpan(text: text[i], style: textStyle);
      textPainter.layout();

      // Position character along the arc
      final charAngle = charAngles[i];
      final angle = currentAngle + charAngle / 2;

      final x = radius * math.sin(angle);
      final y = -radius * math.cos(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();

      currentAngle += charAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MatchSetupView extends StatefulWidget {
  final GameController controller;
  const _MatchSetupView({super.key, required this.controller});

  @override
  State<_MatchSetupView> createState() => _MatchSetupViewState();
}

class _MatchSetupViewState extends State<_MatchSetupView> {
  bool _isInteractable = false;

  @override
  void initState() {
    super.initState();
    // Safety delay to prevent "tap-through" from previous screen buttons
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isInteractable = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 600;
    final bool hideIcons = screenWidth < 600;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 384),
        margin: EdgeInsets.symmetric(
          horizontal: isNarrow ? 8 : 24,
          vertical: 16,
        ),
        padding: EdgeInsets.all(isNarrow ? 10 : 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2BEE4B).withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 32,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 8),
              const Text(
                'Match Setup',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the scoring rules for this match.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              SegmentedButton<ScoringMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ScoringMode.traditional,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isNarrow ? 'Target' : 'First to Target'),
                    ),
                    icon: hideIcons ? null : const Icon(Icons.score),
                  ),
                  ButtonSegment(
                    value: ScoringMode.sixLove,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isNarrow ? '6-Love' : 'Six-Love'),
                    ),
                    icon: hideIcons ? null : const Icon(Icons.auto_awesome),
                  ),
                ],
                selected: {widget.controller.scoringMode},
                onSelectionChanged: (Set<ScoringMode> selection) {
                  if (_isInteractable) {
                    widget.controller.setScoringMode(selection.first);
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF2BEE4B);
                    }
                    return null;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return Colors.white70;
                  }),
                  padding: WidgetStateProperty.all(
                    isNarrow ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  textStyle: WidgetStateProperty.all(
                    TextStyle(fontSize: isNarrow ? 12 : 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Play Style',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PlayStyle>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PlayStyle.cutThroat,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Solo'),
                    ),
                    icon: hideIcons ? null : const Icon(Icons.person),
                  ),
                  ButtonSegment(
                    value: PlayStyle.partners,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isNarrow ? 'Prtnr' : 'Partners'),
                    ),
                    icon: hideIcons ? null : const Icon(Icons.group),
                  ),
                ],
                selected: {widget.controller.match.playStyle},
                onSelectionChanged: (Set<PlayStyle> selection) {
                  if (_isInteractable) {
                    widget.controller.setPlayStyle(selection.first);
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF2BEE4B);
                    }
                    return null;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return Colors.white70;
                  }),
                ),
              ),
              if (widget.controller.scoringMode == ScoringMode.traditional) ...[
                const SizedBox(height: 16),
                const Text(
                  'Target Points',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 100,
                      label: const Text('100'),
                      icon: hideIcons ? null : const Icon(Icons.flash_on),
                    ),
                    ButtonSegment(
                      value: 150,
                      label: const Text('150'),
                      icon: hideIcons ? null : const Icon(Icons.bolt),
                    ),
                    ButtonSegment(
                      value: 200,
                      label: const Text('200'),
                      icon: hideIcons ? null : const Icon(Icons.auto_awesome),
                    ),
                  ],
                  selected: {widget.controller.match.targetScore},
                  onSelectionChanged: (Set<int> selection) {
                    if (_isInteractable) {
                      widget.controller.setTargetScore(selection.first);
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF2BEE4B);
                      }
                      return null;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.black;
                      }
                      return Colors.white70;
                    }),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'AI Difficulty',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DifficultyLevel>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: DifficultyLevel.rookie,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Rookie'),
                    ),
                  ),
                  ButtonSegment(
                    value: DifficultyLevel.casual,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Casual'),
                    ),
                  ),
                  ButtonSegment(
                    value: DifficultyLevel.professional,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Pro'),
                    ),
                  ),
                  ButtonSegment(
                    value: DifficultyLevel.legend,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isNarrow ? 'Lgd' : 'Legend'),
                    ),
                  ),
                ],
                selected: {widget.controller.currentDifficulty},
                onSelectionChanged: (selection) {
                  if (_isInteractable) {
                    widget.controller.setDifficulty(selection.first);
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF2BEE4B);
                    }
                    return null;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return Colors.white70;
                  }),
                  padding: WidgetStateProperty.all(
                    isNarrow ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  textStyle: WidgetStateProperty.all(
                    TextStyle(fontSize: isNarrow ? 12 : 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isNarrow) ...[
                _ModeDescription(
                  mode: widget.controller.scoringMode,
                  targetScore: widget.controller.match.targetScore,
                ),
                const SizedBox(height: 8),
                _DifficultyDescription(
                  level: widget.controller.currentDifficulty,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _ModeDescription(
                        mode: widget.controller.scoringMode,
                        targetScore: widget.controller.match.targetScore,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DifficultyDescription(
                        level: widget.controller.currentDifficulty,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isInteractable
                      ? widget.controller.startMatch
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isInteractable
                        ? const Color(0xFF2BEE4B)
                        : const Color(0xFF2BEE4B).withOpacity(0.5),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: const Text(
                    'START MATCH',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeDescription extends StatelessWidget {
  final ScoringMode mode;
  final int targetScore;
  const _ModeDescription({required this.mode, required this.targetScore});

  @override
  Widget build(BuildContext context) {
    final title = mode == ScoringMode.traditional
        ? 'Traditional Rules'
        : 'Six-Love';
    final desc = mode == ScoringMode.traditional
        ? 'Win by accumulating $targetScore points from opponent hands.'
        : 'First to 6 points wins. All scores reset (Game Bruk) if EVERY player wins at least 1 round.';

    return Container(
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2BEE4B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class ReviewBoardOverlay extends StatelessWidget {
  final GameController controller;

  const ReviewBoardOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.game == null) return const SizedBox();
    final game = controller.game!;

    return GestureDetector(
      onTap: controller.skipReview,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black, // Fully opaque to hide the original board
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Header (Centered)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ROUND SUMMARY',
                          style: TextStyle(
                            color: Color(0xFF2BEE4B),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Tap anywhere to continue...',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Main Content Area: North Player
                  _MiniHand(
                    name: playerNames[2],
                    tiles: game.hands[2],
                    position: 'North',
                    teamName: controller.match.playStyle == PlayStyle.partners ? 'TEAM 1' : null,
                  ),

                  // Middle Row: West Player | Board | East Player
                  Expanded(
                    child: Row(
                      children: [
                        _MiniHand(
                          name: playerNames[1],
                          tiles: game.hands[1],
                          position: 'West',
                          teamName: controller.match.playStyle == PlayStyle.partners ? 'TEAM 2' : null,
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Center(
                                child: IgnorePointer(
                                  child: SnakingBoard(
                                    board: game.board,
                                    rootIndex: game.rootIndex,
                                    maxWidth: constraints.maxWidth,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        _MiniHand(
                          name: playerNames[3],
                          tiles: game.hands[3],
                          position: 'East',
                          teamName: controller.match.playStyle == PlayStyle.partners ? 'TEAM 2' : null,
                        ),
                      ],
                    ),
                  ),

                  // Removed South player's hand as it is already visible at the bottom of the screen.

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      controller.statusMessage ?? '',
                      style: const TextStyle(
                        color: Color(0xFF2BEE4B),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Skip button at bottom right
            Positioned(
              bottom: 24,
              right: 24,
              child: TextButton.icon(
                onPressed: controller.skipReview,
                icon: const Icon(Icons.skip_next, color: Colors.white),
                label: const Text(
                  'SKIP',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniHand extends StatelessWidget {
  final String name;
  final List<DominoTile> tiles;
  final String position;
  final String? teamName;

  const _MiniHand({
    required this.name,
    required this.tiles,
    required this.position,
    this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox();
    final bool isVertical = position == 'East' || position == 'West';

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (teamName != null)
                    Text(
                      teamName!,
                      style: TextStyle(
                        color: teamName == 'TEAM 2' 
                            ? const Color(0xFFFFD700) 
                            : const Color(0xFF2BEE4B),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    name,
                    style: TextStyle(
                      color: teamName == 'TEAM 2' 
                          ? const Color(0xFFFFD700) 
                          : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if ((context.watch<GameController>().scoringMode ==
                          ScoringMode.sixLove &&
                      context.watch<GameController>().sixLoveChampionIndex ==
                          playerNames.indexOf(name)) ||
                  (context.watch<GameController>().scoringMode ==
                          ScoringMode.traditional &&
                      context.watch<GameController>().lifetimeLeaderIndex ==
                          playerNames.indexOf(name)))
                const Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Text('👑', style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            direction: isVertical ? Axis.vertical : Axis.horizontal,
            spacing: 4,
            children: tiles.map((tile) {
              return SizedBox(
                width: 55, // Increased from 45 for maximum visibility
                height: 110, // Increased from 90
                child: Transform.scale(
                  scale: 1.1, // Increased from 0.9 to 1.1 (larger than original widget size)
                  child: DominoTileWidget(tile: tile, isVertical: true),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

void _showHelpModal(BuildContext context, GameController controller) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const TabBar(
              indicatorColor: Color(0xFF00C853),
              labelColor: Color(0xFF00C853),
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'Rules', icon: Icon(Icons.menu_book)),
                Tab(text: 'Scoring', icon: Icon(Icons.leaderboard)),
                Tab(text: 'Controls', icon: Icon(Icons.touch_app)),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: Future.wait([
                  DefaultAssetBundle.of(
                    context,
                  ).loadString('assets/help_rules.md'),
                  DefaultAssetBundle.of(
                    context,
                  ).loadString('assets/help_scoring.md'),
                  DefaultAssetBundle.of(
                    context,
                  ).loadString('assets/help_controls.md'),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C853),
                      ),
                    );
                  }

                  List<String> parseContent(String raw) {
                    return raw
                        .split('\n')
                        .map((l) => l.trim())
                        .where((l) => l.startsWith('-'))
                        .map((l) => l.replaceFirst('-', '').trim())
                        .toList();
                  }

                  return TabBarView(
                    children: [
                      _HelpSection(
                        title: 'Game Rules',
                        content: parseContent(snapshot.data![0]),
                      ),
                      _HelpSection(
                        title: 'Scoring Modes',
                        content: parseContent(snapshot.data![1]),
                      ),
                      _HelpSection(
                        title: 'Controls',
                        content: parseContent(snapshot.data![2]),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'GOT IT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showResetConfirmation(BuildContext context, GameController controller) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          const Text(
            'Reset Match?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        'This will end the current match and return to setup. All current scores will be lost.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            controller.resetMatch();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withOpacity(0.8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'RESET MATCH',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

class _HelpSection extends StatelessWidget {
  final String title;
  final List<String> content;

  const _HelpSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF00C853),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...content.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6.0, right: 12),
                    child: Icon(Icons.circle, size: 6, color: Colors.white38),
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();
    if (!updateService.isUpdateAvailable) return const SizedBox.shrink();

    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2BEE4B), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: Color(0xFF2BEE4B)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Update Available!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'A new version is ready. Refresh to update.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => updateService.performUpdate(),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF2BEE4B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'REFRESH',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyDescription extends StatelessWidget {
  final DifficultyLevel level;
  const _DifficultyDescription({required this.level});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String desc;

    switch (level) {
      case DifficultyLevel.rookie:
        title = 'Rookie AI';
        desc = 'Learning the ropes. Focuses on playing high-value tiles.';
        break;
      case DifficultyLevel.casual:
        title = 'Casual AI';
        desc = 'Standard strategy with awareness of basic board states.';
        break;
      case DifficultyLevel.professional:
        title = 'Professional AI';
        desc = 'Skilled strategy with opportunistic plays and strong defense.';
        break;
      case DifficultyLevel.legend:
        title = 'Legend AI';
        desc = 'Uses advanced tactical search and tile tracking to dominate.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
