import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  group('MatchModel Scoring Logic', () {
    test('points100 mode: Winner gets pips sum', () {
      final match = MatchModel(targetScore: 100, mode: ScoringMode.traditional);

      // Simulate a round result
      // P0 wins, P1-3 have some pips
      final hand0 = <DominoTile>[];
      final hand1 = [const DominoTile(1, 1)]; // 2 pips
      final hand2 = [const DominoTile(2, 2)]; // 4 pips
      final hand3 = [const DominoTile(3, 3)]; // 6 pips

      match.currentRound = GameModel(
        hands: [hand0, hand1, hand2, hand3],
        currentPlayer: 0,
      );

      match.recordRoundResult();

      expect(match.scores[0], 2 + 4 + 6); // 12 points
      expect(match.scores[1], 0);
      expect(match.isMatchOver, false);
    });

    test('sixLove mode: Winner gets 1 point, no reset if some are at 0', () {
      final match = MatchModel(targetScore: 100, mode: ScoringMode.sixLove);

      // Setup: P0 and P1 have points, P2 and P3 are at 0
      match.scores = [3, 1, 0, 0];

      // P2 wins this round
      match.currentRound = GameModel(
        hands: [
          [const DominoTile(1, 1)],
          [const DominoTile(2, 2)],
          [],
          [const DominoTile(4, 4)],
        ],
        currentPlayer: 2,
      );

      match.recordRoundResult();

      expect(match.scores[2], 1); // P2 gets their first point
      expect(match.scores[0], 3); // P0 keeps their 3
      expect(match.scores[1], 1); // P1 keeps their 1
      expect(match.scores[3], 0); // P3 still at 0
    });

    test('sixLove mode: Game Bruk - all players have won at least 1 round', () {
      final match = MatchModel(targetScore: 100, mode: ScoringMode.sixLove);

      // Setup: P0, P1, P2 have points, P3 is at 0
      match.scores = [3, 2, 1, 0];

      // P3 wins this round (everyone has now won at least once)
      match.currentRound = GameModel(
        hands: [
          [const DominoTile(1, 1)],
          [const DominoTile(2, 2)],
          [const DominoTile(3, 3)],
          [],
        ],
        currentPlayer: 3,
      );

      match.recordRoundResult();

      // All scores should be reset to 0
      expect(match.scores[0], 0);
      expect(match.scores[1], 0);
      expect(match.scores[2], 0);
      expect(match.scores[3], 0);
    });

    test('sixLove mode: Target score is 6', () {
      final match = MatchModel(mode: ScoringMode.sixLove);
      match.scores = [5, 1, 0, 0];
      expect(match.isMatchOver, false);

      // P0 wins again
      match.currentRound = GameModel(
        hands: [
          [],
          [const DominoTile(1, 1)],
          [const DominoTile(2, 2)],
          [const DominoTile(3, 3)],
        ],
        currentPlayer: 0,
      );
      match.recordRoundResult();

      expect(match.scores[0], 6);
      expect(match.isMatchOver, true);
      expect(match.matchWinner, 0);
    });

    test('Persistence: JSON handles mode', () {
      final match = MatchModel(mode: ScoringMode.sixLove);
      match.scores = [2, 0, 0, 0];

      final json = match.toJson();
      expect(json['mode'], 'sixLove');

      final match2 = MatchModel.fromJson(json);
      expect(match2.mode, ScoringMode.sixLove);
      expect(match2.scores[0], 2);
    });

    test('Key Bone: Requires BOTH suits to be hard ends (strict rules)', () {
      final match = MatchModel(targetScore: 100, mode: ScoringMode.sixLove);
      
      // We need BOTH suits of the winning tile to be exhausted.
      // Suit 3 and Suit 6.
      // Suit 3 tiles: 3-0, 3-1, 3-2, 3-3, 3-4, 3-5, [3-6 remains]
      // Suit 6 tiles: 6-0, 6-1, 6-2, 6-4, 6-5, 6-6, [3-6 remains]
      List<DominoTile> board = [
        const DominoTile(3, 0), const DominoTile(3, 1), const DominoTile(3, 2),
        const DominoTile(3, 3), const DominoTile(3, 4), const DominoTile(3, 5),
        const DominoTile(6, 0), const DominoTile(6, 1), const DominoTile(6, 2),
        const DominoTile(6, 4), const DominoTile(6, 5), const DominoTile(6, 6),
      ];
      
      final game = GameModel(
        hands: [[const DominoTile(3, 6)], [const DominoTile(0, 0)], [const DominoTile(1, 1)], [const DominoTile(2, 2)]],
        board: List.from(board),
        currentPlayer: 0,
        leftEnd: 3,
        rightEnd: 6, 
      );
      
      // P0 plays [3|6] to win.
      // This tile matches BOTH ends (3 and 6) and exhausts BOTH suits.
      game.applyAction(PlayAction(const DominoTile(3, 6), 'left'));
      
      match.currentRound = game;
      final result = match.recordRoundResult();
      
      expect(result['isKeyBone'], true, reason: 'Winning with a tile that matches dual hard ends is a Key Bone');
      expect(result['points'], 2);
    });

    test('Key Bone: Single suit exhaustion is NOT enough (strict rules)', () {
      final match = MatchModel(targetScore: 100, mode: ScoringMode.sixLove);
      
      // Only suit 3 is exhausted. Suit 6 is not.
      List<DominoTile> board = [
        const DominoTile(3, 0), const DominoTile(3, 1), const DominoTile(3, 2),
        const DominoTile(3, 3), const DominoTile(3, 4), const DominoTile(3, 5),
      ];
      
      final game = GameModel(
        hands: [[const DominoTile(3, 6)], [const DominoTile(1, 1)], [const DominoTile(2, 2)], [const DominoTile(4, 4)]],
        board: List.from(board),
        currentPlayer: 0,
        leftEnd: 3,
        rightEnd: 0,
      );
      
      game.applyAction(PlayAction(const DominoTile(3, 6), 'left'));
      
      match.currentRound = game;
      final result = match.recordRoundResult();
      
      expect(result['isKeyBone'], false, reason: 'Single suit exhaustion (3) with other end (0) open is not a Key Bone');
      expect(result['points'], 1);
    });

    test('Key Bone: Double winning tile DOES NOT trigger key point', () {
      final match = MatchModel(targetScore: 100, mode: ScoringMode.sixLove);
      
      // Suit 3: [3,0],[3,1],[3,2],[3,3],[3,4],[3,5],[3,6]
      List<DominoTile> board = [
        const DominoTile(3, 0), const DominoTile(3, 1), const DominoTile(3, 2),
        const DominoTile(3, 4), const DominoTile(3, 5), const DominoTile(3, 6),
      ];
      
      final game = GameModel(
        hands: [[const DominoTile(3, 3)], [const DominoTile(0, 0)], [const DominoTile(1, 1)], [const DominoTile(2, 2)]],
        board: List.from(board),
        currentPlayer: 0,
        leftEnd: 3,
        rightEnd: 0,
      );
      
      // P0 plays [3|3] to win
      game.applyAction(PlayAction(const DominoTile(3, 3), 'left'));
      
      match.currentRound = game;
      final result = match.recordRoundResult();
      
      expect(result['isKeyBone'], false, reason: 'Doubles are excluded from Key Bones');
      expect(result['points'], 1); // Only 1 base point
    });

     test('Key Bone: Win on Left side must not use Right side for Key check', () {
      final match = MatchModel(targetScore: 100, mode: ScoringMode.sixLove);
      
      // Right end tile is [5|4]. Suit 5 count on board: [5,0],[5,1],[5,2],[5,3],[5,5],[5,6] plus [5,4] -> 7 tiles.
      // So Suit 5 is exhausted on the RIGHT end.
      List<DominoTile> board = [
        const DominoTile(1, 2), // Left end is 1
        const DominoTile(0, 5), const DominoTile(1, 5), const DominoTile(2, 5), 
        const DominoTile(3, 5), const DominoTile(5, 5), const DominoTile(6, 5),
        const DominoTile(5, 4) // Right end is 4
      ];
      
      final game = GameModel(
        hands: [[const DominoTile(1, 4)], [const DominoTile(0, 0)], [const DominoTile(1, 1)], [const DominoTile(2, 2)]],
        board: List.from(board),
        currentPlayer: 0,
        leftEnd: 1,
        rightEnd: 4,
      );
      
      // P0 plays [1|4] on LEFT. 
      // THE NEW STATE: Suit 1 or 4 is NOT exhausted (many tiles left). 
      // If we correctly check lastPlayedTile, no point.
      
      game.applyAction(PlayAction(const DominoTile(1, 4), 'left'));
      
      match.currentRound = game;
      final result = match.recordRoundResult();
      
      expect(result['isKeyBone'], false, reason: 'Winner played [1|4] which is not a key, even if board.last [5|4] was a key suit');
      expect(result['points'], 1);
    });

    test('Screenshot Reproduction - Key Bone SHOULD be awarded', () {
      final match = MatchModel(mode: ScoringMode.sixLove, playStyle: PlayStyle.partners);
      
      // The winning tile from the screenshot
      final winningTile = const DominoTile(1, 6);
      
      final game = GameModel(
        hands: [[winningTile], [const DominoTile(0, 0)], [const DominoTile(1, 1)], [const DominoTile(2, 2)]],
        currentPlayer: 0, // Winning player
        playStyle: PlayStyle.partners,
        scoringMode: ScoringMode.sixLove,
      );
      
      // Exhaust Suit 1 (need 8 pips total)
      game.board.add(const DominoTile(1, 1)); // 2 pips
      game.board.add(const DominoTile(1, 2)); // 1
      game.board.add(const DominoTile(1, 3)); // 1
      game.board.add(const DominoTile(1, 4)); // 1
      game.board.add(const DominoTile(1, 5)); // 1
      game.board.add(const DominoTile(1, 0)); // 1
      // Total Suit 1 = 2 + 1 + 1 + 1 + 1 + 1 = 7 pips.
      
      // Exhaust Suit 6 (need 8 pips total)
      game.board.add(const DominoTile(6, 6)); // 2 pips
      game.board.add(const DominoTile(6, 2)); // 1
      game.board.add(const DominoTile(6, 3)); // 1
      game.board.add(const DominoTile(6, 4)); // 1
      game.board.add(const DominoTile(6, 5)); // 1
      game.board.add(const DominoTile(6, 0)); // 1
      // Total Suit 6 = 2 + 1 + 1 + 1 + 1 + 1 = 7 pips.

      // Set ends before the final play
      game.leftEnd = 1;
      game.rightEnd = 6;
      
      // Now play the winning tile to reach 8 pips on both ends
      game.applyAction(PlayAction(winningTile, 'left'));
      
      match.currentRound = game;
      final result = match.recordRoundResult();
      
      expect(result['isKeyBone'], isTrue, reason: 'Both ends (1 and 6) reached 8 pips with the winning play.');
      expect(result['points'], 2, reason: 'Key Bone award should be 2 points.');
    });
  });
}
