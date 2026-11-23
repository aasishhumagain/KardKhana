import 'package:material_ui/material_ui.dart';

import 'game_feedback.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.appearance, super.key});

  final ValueNotifier<ThemeMode> appearance;

  @override
  Widget build(BuildContext context) {
    final feedback = GameFeedbackScope.maybeOf(context);
    final sections = [
      _SettingsGroup(
        title: 'Appearance',
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: appearance,
          builder: (context, mode, _) => RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (selection) {
              if (selection != null) appearance.value = selection;
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Light'),
                  secondary: Icon(Icons.light_mode_outlined, size: 19),
                  dense: true,
                ),
                Divider(height: 1, indent: 12, endIndent: 12),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Dark'),
                  secondary: Icon(Icons.dark_mode_outlined, size: 19),
                  dense: true,
                ),
              ],
            ),
          ),
        ),
      ),
      if (feedback != null)
        _SettingsGroup(
          title: 'Game feedback',
          child: ListenableBuilder(
            listenable: feedback,
            builder: (context, _) => Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined, size: 19),
                  title: const Text('Card sounds'),
                  value: feedback.soundEnabled,
                  onChanged: (value) => feedback.soundEnabled = value,
                  dense: true,
                ),
                const Divider(height: 1, indent: 12, endIndent: 12),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, size: 19),
                  title: const Text('Vibration'),
                  subtitle: const Text('Light tap when you make a move'),
                  value: feedback.vibrationEnabled,
                  onChanged: (value) => feedback.vibrationEnabled = value,
                  dense: true,
                ),
              ],
            ),
          ),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 790),
            child: LayoutBuilder(
              builder: (context, limits) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (limits.maxWidth >= 490 && sections.length == 2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10,
                      children: [
                        for (final section in sections)
                          Expanded(child: section),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: sections,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const Divider(height: 1),
        child,
      ],
    ),
  );
}
