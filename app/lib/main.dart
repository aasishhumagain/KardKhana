import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kardkhana_app.dart';
import 'settings/game_feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = SharedPreferencesAsync();
  final appearance = ValueNotifier(ThemeMode.light);
  const themeKey = 'theme_mode';
  try {
    if (await preferences.getString(themeKey) == ThemeMode.dark.name) {
      appearance.value = ThemeMode.dark;
    }
  } catch (error) {
    debugPrint('Could not read the saved appearance: $error');
  }

  // Keep rapid theme changes in order when writing to storage.
  var pendingSave = Future<void>.value();
  appearance.addListener(() {
    final selection = appearance.value.name;
    pendingSave = pendingSave.then((_) async {
      try {
        await preferences.setString(themeKey, selection);
      } catch (error) {
        debugPrint('Could not save the appearance: $error');
      }
    });
  });

  final feedback = await GameFeedback.load(preferences);
  runApp(KardKhanaApp(appearance: appearance, feedback: feedback));
}
