// test/layout_overflow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:provider/provider.dart';

// Mock GameController or use the real one if possible
// For a simple layout test, let's just test the hub if it was a standalone widget, 
// but since it's embedded in GameScreen, we'll pump the GameScreen with mock data.

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StatHub does not overflow on narrow screen', (WidgetTester tester) async {
    // Set a narrow screen size
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameController(),
        child: const MaterialApp(
          home: GameScreen(),
        ),
      ),
    );

    // Initial pump to let _initMatch run (it's called in constructor)
    await tester.pump();
    // Wait for async init if necessary, but GameScreen handles null game

    // We expect the Row with status and AI to fit 320px
    // The previous implementation overflowed by 0.0657 pixels at some point.
    
    // Check if we find the expected widgets in the new positions
    expect(find.text('HENDY'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsWidgets); // Both AI and Human (in badge)
    
    // Verify that the bottom center badge is present
    expect(find.text('YOU'), findsOneWidget);
    
    // Check for overflow - Flutter tests will fail automatically if there is an overflow 
    // during pumpWidget/pump when debugCheckHasNoOverflow is enabled (default in many tests)
    // or we can manually check constraints.
  });
}
