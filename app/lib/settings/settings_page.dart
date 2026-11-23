import 'package:material_ui/material_ui.dart';

import 'game_feedback.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.appearance, super.key});

  final ValueNotifier<ThemeMode> appearance;

  @override
  Widget build(BuildContext context) {
    final feedback = GameFeedbackScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: appearance,
                  builder: (context, mode, _) => RadioGroup<ThemeMode>(
                    groupValue: mode,
                    onChanged: (selection) {
                      if (selection != null) appearance.value = selection;
                    },
                    child: const Card.outlined(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.light,
                            title: Text('Light'),
                            secondary: Icon(Icons.light_mode_outlined),
                          ),
                          Divider(height: 1, indent: 16, endIndent: 16),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.dark,
                            title: Text('Dark'),
                            secondary: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (feedback != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Game feedback',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: feedback,
                    builder: (context, _) => Card.outlined(
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.volume_up_outlined),
                            title: const Text('Card sounds'),
                            value: feedback.soundEnabled,
                            onChanged: (value) => feedback.soundEnabled = value,
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          SwitchListTile(
                            secondary: const Icon(Icons.vibration),
                            title: const Text('Vibration'),
                            subtitle: const Text(
                              'Light tap when you make a move',
                            ),
                            value: feedback.vibrationEnabled,
                            onChanged: (value) =>
                                feedback.vibrationEnabled = value,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
