import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/cards/playing_card.dart';
import 'package:kardkhana/kardkhana_app.dart';
import 'package:kardkhana/ui/card_flights.dart';
import 'package:kardkhana/ui/table_actions.dart';
import 'package:kardkhana/ui/table_scene.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('landscape catalog opens each game with its player limit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final appearance = ValueNotifier(ThemeMode.light);
    addTearDown(appearance.dispose);
    await tester.pumpWidget(KardKhanaApp(appearance: appearance));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == 'KardKhana',
      ),
      findsOneWidget,
    );

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

    double tileTop(Finder title) => tester
        .getTopLeft(find.ancestor(of: title, matching: find.byType(Card)))
        .dy;
    final firstCardY = tileTop(find.text(games.keys.first));
    for (final title in games.keys) {
      final card = find.text(title).hitTestable();
      expect(card, findsOneWidget);
      expect(tileTop(card), firstCardY);
    }

    for (final game in games.entries) {
      expect(find.text('Choose a game'), findsOneWidget);
      await tester.tap(find.text(game.key));
      await tester.pumpAndSettle();
      expect(find.text('Choose a game'), findsNothing);
      expect(find.text(game.key), findsOneWidget);
      expect(find.text(game.value.summary), findsOneWidget);

      if (game.key == 'Marriage') {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Host room'));
        await tester.pumpAndSettle();
        for (var count = 2; count <= 5; count++) {
          expect(
            find.widgetWithText(ChoiceChip, '$count players'),
            findsOneWidget,
          );
        }
        expect(find.widgetWithText(ChoiceChip, '6 players'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Join room'));
        await tester.pumpAndSettle();
        expect(find.text('Nickname'), findsOneWidget);
        expect(find.text('Host IP address'), findsOneWidget);
        expect(find.text('Room code'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

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
        if (game.key == 'Teen Patti') {
          await tester.tap(find.text('Look').hitTestable());
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
        final fourthCpu = find.text('CPU 4');
        expect(fourthCpu.hitTestable(), findsOneWidget);
        expect(find.text('CPU 5'), findsNothing);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final playerLimit = find.text(game.value.limit);
      await tester.scrollUntilVisible(playerLimit, 80);
      expect(playerLimit, findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(find.text('Choose a game'), findsOneWidget);
  });

  testWidgets('Marriage shows a live game log and a shortcut Home', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 296);
    tester.view.padding = const FakeViewPadding(top: 24, right: 36);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    final appearance = ValueNotifier(ThemeMode.light);
    addTearDown(appearance.dispose);
    await tester.pumpWidget(KardKhanaApp(appearance: appearance));
    await tester.pumpAndSettle();

    Future<void> tap(Finder target) async {
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap(find.text('Marriage'));
    await tap(find.text('Play offline'));
    await tap(find.text('2 players'));
    await tap(find.text('Start game'));
    final home = find.byTooltip('Home');
    final log = find.byTooltip('Log');
    expect(tester.getCenter(home).dx, lessThan(tester.getCenter(log).dx));
    expect(tester.getCenter(log).dx, lessThan(100));

    await tap(log);
    expect(find.text('Game log'), findsOneWidget);
    expect(
      find.text('Moves will appear here as the game is played.'),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Marriage · Offline'), findsOneWidget);

    await tap(find.textContaining('Draw stock'));
    expect(find.textContaining('Draw stock').hitTestable(), findsNothing);
    final actions = find.byType(TableActionBar).hitTestable();
    final actionsTop = tester.getTopLeft(actions).dy;
    final cards = find.descendant(
      of: find.byType(HandSpread),
      matching: find.byType(PlayingCard),
    );
    final card = cards.hitTestable().first;
    final face = find.descendant(of: card, matching: find.byType(InkWell));
    final cardTop = tester.getTopLeft(face).dy;
    expect(
      tester.getSize(card).height,
      greaterThan(tester.getSize(card).width),
    );
    await tap(card);
    expect(tester.widget<PlayingCard>(card).selected, isTrue);
    expect(tester.getTopLeft(face).dy, lessThan(cardTop));
    final spread = find.byType(HandSpread).hitTestable();
    final spreadTop = tester.getTopLeft(spread).dy;
    await tester.drag(spread, const Offset(0, -64));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(spread).dy, lessThan(spreadTop));
    expect(tester.getTopLeft(actions).dy, actionsTop);
    await tester.tap(find.text('Discard selected').hitTestable());
    await tester.pump();
    final thrownCard = find
        .descendant(
          of: find.byType(CardFlights),
          matching: find.byType(PlayingCard),
        )
        .last;
    final launch = tester.getCenter(thrownCard);
    await tester.pump(const Duration(milliseconds: 100));
    final inFlight = tester.getCenter(thrownCard);
    expect(inFlight.dy, lessThan(launch.dy));
    await tester.pump(const Duration(milliseconds: 300));
    final landed = tester.getCenter(thrownCard);
    expect(landed, isNot(inFlight));
    await tester.pump();
    expect(tester.getCenter(thrownCard), landed);
    await tester.tap(log);
    await tester.pump();
    final draw = find.text('Drew a card from stock').hitTestable();
    final discard = find.textContaining('Discarded ').hitTestable();
    expect(draw, findsOneWidget);
    expect(discard, findsOneWidget);
    expect(tester.getTopLeft(discard).dy, lessThan(tester.getTopLeft(draw).dy));

    expect(find.text('CPU 1').hitTestable(), findsNothing);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('CPU 1').hitTestable(), findsWidgets);
    await tap(home);
    expect(find.text('Choose a game'), findsOneWidget);
  });

  testWidgets('compact landscape keeps the game tiles reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 320);
    tester.view.padding = const FakeViewPadding(top: 24, right: 36);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    final appearance = ValueNotifier(ThemeMode.dark);
    addTearDown(appearance.dispose);
    await tester.pumpWidget(KardKhanaApp(appearance: appearance));
    await tester.pumpAndSettle();

    for (final name in ['Call Break', 'Teen Patti', 'Marriage']) {
      expect(find.text(name).hitTestable(), findsOneWidget);
    }
    expect(find.byTooltip('Settings').hitTestable(), findsOneWidget);

    for (final target in [
      find.text('Marriage'),
      find.text('Play offline'),
      find.text('5 players'),
      find.text('Start game'),
      find.textContaining('Draw stock'),
    ]) {
      await tester.tap(target.hitTestable());
      await tester.pumpAndSettle();
    }
    expect(
      find
          .descendant(
            of: find.byType(HandSpread),
            matching: find.byType(PlayingCard),
          )
          .hitTestable(),
      findsNWidgets(22),
    );
    expect(find.text('CPU 4').hitTestable(), findsOneWidget);
    expect(find.text('Discard selected').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings changes appearance across app screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final appearance = ValueNotifier(ThemeMode.light);
    addTearDown(appearance.dispose);
    await tester.pumpWidget(KardKhanaApp(appearance: appearance));
    await tester.pumpAndSettle();

    Brightness brightness(String label) =>
        Theme.of(tester.element(find.text(label))).brightness;

    final settings = find.byTooltip('Settings');
    expect(tester.getCenter(settings).dx, greaterThan(720));
    expect(brightness('Choose a game'), Brightness.light);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(appearance.value, ThemeMode.dark);
    expect(brightness('Appearance'), Brightness.dark);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(brightness('Choose a game'), Brightness.dark);
    await tester.tap(find.text('Call Break'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play offline'));
    await tester.pumpAndSettle();
    expect(brightness('Call Break · Offline'), Brightness.dark);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(settings);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(appearance.value, ThemeMode.light);
    expect(brightness('Appearance'), Brightness.light);
  });
}
