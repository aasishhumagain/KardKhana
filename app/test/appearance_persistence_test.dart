import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/main.dart' as app;
import 'package:kardkhana/settings/game_feedback.dart';
import 'package:kardkhana/ui/game_table_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('app startup restores appearance and feedback settings', (
    tester,
  ) async {
    final platform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = platform);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Brightness catalogBrightness() =>
        Theme.of(tester.element(find.text('Choose a game'))).brightness;

    await app.main();
    await tester.pumpAndSettle();
    expect(catalogBrightness(), Brightness.light);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    Finder setting(String label) => find.widgetWithText(SwitchListTile, label);
    bool enabled(String label) =>
        tester.widget<SwitchListTile>(setting(label)).value;
    Future<void> showFeedback() async {
      await tester.scrollUntilVisible(setting('Vibration'), 70);
      await tester.pumpAndSettle();
    }

    await showFeedback();
    expect(enabled('Card sounds'), true);
    expect(enabled('Vibration'), true);
    await tester.tap(setting('Card sounds').hitTestable());
    await tester.pumpAndSettle();
    expect(enabled('Vibration'), true);
    await tester.tap(setting('Vibration').hitTestable());
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await app.main();
    await tester.pumpAndSettle();
    expect(catalogBrightness(), Brightness.dark);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await showFeedback();
    expect(enabled('Card sounds'), false);
    expect(enabled('Vibration'), false);
  });

  testWidgets('dealing and accepted card moves trigger the selected feedback', (
    tester,
  ) async {
    final platform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = platform);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final feedback = await GameFeedback.load(SharedPreferencesAsync());
    addTearDown(feedback.dispose);
    final messenger = tester.binding.defaultBinaryMessenger;
    const soundChannel = MethodChannel('kardkhana/card_sounds');
    final sounds = <String>[];
    final vibrations = <Object?>[];
    messenger.setMockMethodCallHandler(soundChannel, (call) async {
      sounds.add(call.arguments as String);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        vibrations.add(call.arguments);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(soundChannel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final log = <List<Object>>[];
    Widget table() => MaterialApp(
      home: GameFeedbackScope(
        feedback: feedback,
        child: GameTableScreen(
          title: 'Marriage',
          view: {
            'phase': 'playing',
            'round': 1,
            'seat': 0,
            'players': [
              {'name': 'You'},
              {'name': 'CPU 1'},
            ],
            'log': List.of(log),
          },
          table: const Center(child: Text('Hand ready')),
        ),
      ),
    );

    await tester.pumpWidget(table());
    expect(find.text('Shuffling cards').hitTestable(), findsOneWidget);
    expect(find.text('Hand ready').hitTestable(), findsNothing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 760));
    expect(find.text('Dealing cards').hitTestable(), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Hand ready').hitTestable(), findsOneWidget);
    expect(sounds, ['shuffle', 'deal', 'deal']);

    log.addAll([
      [1, 1, 'draw', 'Drew a card from stock'],
      [1, 1, 'discard', 'Discarded a card'],
    ]);
    await tester.pumpWidget(table());
    await tester.pump(const Duration(milliseconds: 150));
    expect(sounds.skip(3), ['pickUp', 'drop']);
    expect(vibrations, isEmpty);

    log.add([1, 0, 'discard', 'Discarded a card']);
    await tester.pumpWidget(table());
    expect(sounds.last, 'drop');
    expect(vibrations, ['HapticFeedbackType.selectionClick']);
    await tester.pumpWidget(table());
    expect(sounds, hasLength(6));
    feedback.soundEnabled = false;
    feedback.vibrationEnabled = false;
    log.add([1, 0, 'draw', 'Drew a card from stock']);
    await tester.pumpWidget(table());
    expect(sounds, hasLength(6));
    expect(vibrations, hasLength(1));
  });
}
