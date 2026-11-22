import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/main.dart' as app;
import 'package:material_ui/material_ui.dart';

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

      final offline = find.widgetWithText(FilledButton, 'Play offline');
      expect(offline.hitTestable(), findsOneWidget);
      await tester.tap(offline);
      await tester.pumpAndSettle();
      expect(find.text('${game.key} · Offline'), findsOneWidget);
      if (game.key == 'Call Break') {
        for (var cpu = 1; cpu <= 3; cpu++) {
          expect(find.text('CPU $cpu'), findsOneWidget);
        }
      } else {
        await tester.tap(find.widgetWithText(ChoiceChip, '5 players'));
        await tester.tap(find.widgetWithText(FilledButton, 'Start game'));
        await tester.pumpAndSettle();
        expect(find.text('CPU 4'), findsOneWidget);
        expect(find.text('CPU 5'), findsNothing);
        if (game.key == 'Teen Patti') {
          await tester.tap(find.widgetWithText(OutlinedButton, 'Look'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Your hand ·'), findsOneWidget);
        } else {
          await tester.tap(find.textContaining('Draw stock'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Lay a group or discard one card'),
            findsOneWidget,
          );
        }
      }
      await tester.pageBack();
      await tester.pumpAndSettle();

      final playerLimit = find.text(game.value.limit);
      await tester.scrollUntilVisible(playerLimit, 80);
      expect(playerLimit, findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(find.text('Choose a game'), findsOneWidget);
  });
}
