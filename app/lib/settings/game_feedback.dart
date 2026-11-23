import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CardSound { shuffle, deal, pickUp, drop }

class GameFeedback extends ChangeNotifier {
  GameFeedback._(this._preferences);

  static const _soundKey = 'card_sounds';
  static const _vibrationKey = 'card_vibration';
  static const _channel = MethodChannel('kardkhana/card_sounds');

  final SharedPreferencesAsync _preferences;
  Future<void> _pendingSave = Future.value();
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  static Future<GameFeedback> load(SharedPreferencesAsync preferences) async {
    final feedback = GameFeedback._(preferences);
    try {
      feedback._soundEnabled = await preferences.getBool(_soundKey) ?? true;
      feedback._vibrationEnabled =
          await preferences.getBool(_vibrationKey) ?? true;
    } catch (error) {
      debugPrint('Could not read the saved game feedback settings: $error');
    }
    return feedback;
  }

  bool get soundEnabled => _soundEnabled;
  set soundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    _save(_soundKey, value);
  }

  bool get vibrationEnabled => _vibrationEnabled;
  set vibrationEnabled(bool value) {
    if (_vibrationEnabled == value) return;
    _vibrationEnabled = value;
    _save(_vibrationKey, value);
  }

  void _save(String key, bool value) {
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _preferences.setBool(key, value);
      } catch (error) {
        debugPrint('Could not save a game feedback setting: $error');
      }
    });
    notifyListeners();
  }

  Future<void> play(CardSound sound) async {
    if (!_soundEnabled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('play', sound.name);
    } on MissingPluginException {
      // The Android sound player is absent in widget tests.
    } on PlatformException catch (error) {
      debugPrint('Could not play a card sound: $error');
    }
  }

  void tap() {
    if (_vibrationEnabled) unawaited(HapticFeedback.selectionClick());
  }
}

class GameFeedbackScope extends InheritedWidget {
  const GameFeedbackScope({
    required this.feedback,
    required super.child,
    super.key,
  });

  final GameFeedback feedback;

  static GameFeedback? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameFeedbackScope>()?.feedback;

  @override
  bool updateShouldNotify(GameFeedbackScope oldWidget) =>
      feedback != oldWidget.feedback;
}
