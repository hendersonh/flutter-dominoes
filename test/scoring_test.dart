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
  });
}
