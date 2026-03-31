// test/snaking_board_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart'; // adjust import path if needed
import 'package:flutter_app/engine/dominoes_ai.dart';

void main() {
  testWidgets('SnakingBoard positions tiles correctly', (
    WidgetTester tester,
  ) async {
    // Create a simple board with a mix of horizontals and a double (vertical)
    final board = [
      DominoTile(0, 0), // double -> vertical root
      DominoTile(0, 1),
      DominoTile(1, 2),
      DominoTile(2, 2), // double -> vertical elbow
      DominoTile(2, 3),
    ];
    const rootIndex = 0;
    const maxWidth = 400.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SnakingBoard(
            board: board,
            rootIndex: rootIndex,
            maxWidth: maxWidth,
          ),
        ),
      ),
    );

    // Verify that the number of DominoTileWidget matches board length
    expect(find.byType(DominoTileWidget), findsNWidgets(board.length));

    // Verify at least one tile is rendered vertically (the double root)
    final verticalTiles = tester
        .widgetList<DominoTileWidget>(find.byType(DominoTileWidget))
        .where((w) => w.isVertical)
        .toList();
    expect(verticalTiles.length, greaterThanOrEqualTo(1));
  });
}
