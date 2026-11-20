import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/main.dart' as app;

void main() {
  testWidgets('landscape catalog opens each game with its player limit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    app.main();
    await tester.pumpAndSettle();

    const games = {
      'Call Break': (
        summary: 'Bidding and trick-taking',
        limit: 'Exactly 4 players to start',
      ),
      'Teen Patti': (
        summary: 'Three-card hands and virtual points',
        limit: 'Up to 5 players',
      ),
      'Marriage': (
        summary: 'Draw, discard, and declare groups',
        limit: 'Up to 5 players',
      ),
    };

    final firstCardY = tester.getCenter(find.text(games.keys.first)).dy;
    for (final title in games.keys) {
      final card = find.text(title).hitTestable();
      expect(card, findsOneWidget);
      expect(tester.getCenter(card).dy, firstCardY);
    }

    for (final game in games.entries) {
      expect(find.text('Choose a game'), findsOneWidget);
      await tester.tap(find.text(game.key));
      await tester.pumpAndSettle();
      expect(find.text('Choose a game'), findsNothing);
      expect(find.text(game.key), findsOneWidget);
      expect(find.text(game.value.summary), findsOneWidget);
      expect(find.text(game.value.limit), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(find.text('Choose a game'), findsOneWidget);
  });
}
