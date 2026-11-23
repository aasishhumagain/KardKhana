import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'call_break/call_break_game.dart';
import 'call_break/call_break_page.dart';
import 'cards/playing_card.dart';
import 'marriage/marriage_game.dart';
import 'marriage/marriage_page.dart';
import 'offline/offline_table_widgets.dart';
import 'settings/game_feedback.dart';
import 'settings/settings_page.dart';
import 'teen_patti/teen_patti_game.dart';
import 'teen_patti/teen_patti_page.dart';

class KardKhanaApp extends StatelessWidget {
  const KardKhanaApp({required this.appearance, this.feedback, super.key});

  final ValueNotifier<ThemeMode> appearance;
  final GameFeedback? feedback;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appearance,
    builder: (context, mode, _) => MaterialApp(
      title: 'KardKhana',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      builder: (context, child) => feedback == null
          ? child!
          : GameFeedbackScope(feedback: feedback!, child: child!),
      home: _GameCatalog(appearance: appearance),
    ),
  );

  static final _lightTheme = _theme(Brightness.light);
  static final _darkTheme = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF651B7B),
          brightness: brightness,
        ).copyWith(
          surface: dark ? const Color(0xFF24162D) : const Color(0xFFF9F3EC),
          surfaceContainerLow: dark
              ? const Color(0xFF31213C)
              : const Color(0xFFFFFCF3),
          outlineVariant: dark
              ? const Color(0xFF5A4266)
              : const Color(0xFFDED0E3),
        );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
    );
    return ThemeData(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: buttonShape),
      ),
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontFamily: 'Roboto',
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

enum _Game {
  callBreak(
    'Call Break',
    'Bidding and trick-taking',
    'Bid on how many tricks you expect to win, then play each trick and '
        'see how your result compares with your bid.',
    minPlayers: CallBreakGame.playerCount,
    maximumPlayers: CallBreakGame.playerCount,
    colors: [Color(0xFF16392F), Color(0xFF305747)],
    coverCards: [38, 51, 50],
  ),
  teenPatti(
    'Teen Patti',
    'Three-card hands and virtual points',
    'Play with a three-card hand and virtual points. At a showdown, hands '
        'are compared to resolve the round.',
    minPlayers: TeenPattiGame.minPlayers,
    maximumPlayers: TeenPattiGame.maxPlayers,
    colors: [Color(0xFF302841), Color(0xFF5B4965)],
    coverCards: [12, 25, 38],
  ),
  marriage(
    'Marriage',
    'Draw, discard, and declare groups',
    'Draw and discard cards to build valid groups. Choose the cards in '
        'each group when you make a declaration.',
    minPlayers: MarriageGame.minPlayers,
    maximumPlayers: MarriageGame.maxPlayers,
    colors: [Color(0xFF522C32), Color(0xFF824741)],
    coverCards: [17, 18, 19],
  );

  const _Game(
    this.title,
    this.summary,
    this.description, {
    required this.minPlayers,
    required this.maximumPlayers,
    required this.colors,
    required this.coverCards,
  });

  final String title;
  final String summary;
  final String description;
  final int minPlayers;
  final int maximumPlayers;
  final List<Color> colors;
  final List<int> coverCards;

  String get tableSize => minPlayers == maximumPlayers
      ? '$maximumPlayers players'
      : '$minPlayers–$maximumPlayers players';

  String get playerLimitLabel => minPlayers == maximumPlayers
      ? 'Exactly $maximumPlayers players to start'
      : 'Up to $maximumPlayers players';
}

class _GameCatalog extends StatelessWidget {
  const _GameCatalog({required this.appearance});

  final ValueNotifier<ThemeMode> appearance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 530;
                  final cards = [
                    for (final game in _Game.values)
                      _GameCard(game: game, fillHeight: sideBySide),
                  ];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    children: [
                      _CatalogHeader(
                        onSettings: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                SettingsPage(appearance: appearance),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (sideBySide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 10,
                            children: [
                              for (final card in cards) Expanded(child: card),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 8,
                          children: cards,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 12,
      children: [
        Image.asset(
          'assets/branding/kardkhana_logo.png',
          width: 79,
          height: 50,
          fit: BoxFit.contain,
          semanticLabel: 'KardKhana',
        ),
        Expanded(
          child: Text(
            'Choose a game',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.55,
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined, size: 21),
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.fillHeight});

  final _Game game;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final caption = Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 4,
            children: [
              Expanded(
                child: Text(
                  game.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: colors.primary,
              ),
            ],
          ),
          Text(
            game.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (fillHeight) const Spacer(),
          _PlayerCount(label: game.tableSize),
        ],
      ),
    );
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => _GameDetails(game: game)),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GameArtwork(game: game),
            fillHeight ? Expanded(child: caption) : caption,
          ],
        ),
      ),
    );
  }
}

class _GameArtwork extends StatelessWidget {
  const _GameArtwork({required this.game});

  final _Game game;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: game.colors,
          ),
        ),
        child: SizedBox(
          height: 90,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -43,
                right: -16,
                child: Container(
                  width: 155,
                  height: 155,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x33FFF0CC)),
                  ),
                ),
              ),
              Positioned(
                left: -28,
                bottom: -103,
                child: Container(
                  width: 182,
                  height: 182,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x38FFF0CC)),
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 112,
                  height: 86,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 5,
                        top: 15,
                        child: Transform.rotate(
                          angle: -0.29,
                          child: PlayingCard(
                            game.coverCards[0],
                            portrait: true,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 5,
                        top: 15,
                        child: Transform.rotate(
                          angle: 0.29,
                          child: PlayingCard(
                            game.coverCards[2],
                            portrait: true,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 35,
                        top: 7,
                        child: PlayingCard(game.coverCards[1], portrait: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PlayerCount extends StatelessWidget {
  const _PlayerCount({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 6,
      children: [
        Icon(Icons.people_outline, size: 15, color: theme.colorScheme.primary),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _GameDetails extends StatelessWidget {
  const _GameDetails({required this.game});

  final _Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _GameArtwork(game: game),
        ),
        Text(
          game.summary,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(game.description, style: theme.textTheme.bodyMedium),
        _PlayerCount(label: game.playerLimitLabel),
      ],
    );
    final play = Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            FilledButton(
              onPressed: () => _openOffline(context),
              child: const _ActionLabel(
                icon: Icons.play_arrow_rounded,
                label: 'Play offline',
              ),
            ),
            Text(
              'Play against CPU opponents',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 1),
            Text('Wi-Fi or hotspot', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: () => _openSetup(context, host: true),
                  child: const _ActionLabel(
                    icon: Icons.add_rounded,
                    label: 'Host room',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openSetup(context, host: false),
                  child: const _ActionLabel(
                    icon: Icons.login_rounded,
                    label: 'Join room',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(game.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (constraints.maxWidth >= 520)
                    Row(
                      spacing: 10,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: overview),
                        Expanded(flex: 5, child: play),
                      ],
                    )
                  else ...[
                    overview,
                    const SizedBox(height: 16),
                    play,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openOffline(BuildContext context) {
    switch (game) {
      case _Game.callBreak:
        openOfflineCallBreak(context);
      case _Game.teenPatti:
        _openOfflineSetup(
          context,
          buildGame: (count) => TeenPattiPage(playerCount: count),
        );
      case _Game.marriage:
        _openOfflineSetup(
          context,
          buildGame: (count) => MarriagePage(playerCount: count),
        );
    }
  }

  void _openOfflineSetup(
    BuildContext context, {
    required Widget Function(int) buildGame,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OfflineGameSetup(
          title: game.title,
          minPlayers: game.minPlayers,
          maxPlayers: game.maximumPlayers,
          buildGame: buildGame,
        ),
      ),
    );
  }

  void _openSetup(BuildContext context, {required bool host}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => switch (game) {
          _Game.callBreak => CallBreakSetupPage(host: host),
          _Game.teenPatti => TeenPattiSetupPage(host: host),
          _Game.marriage => MarriageSetupPage(host: host),
        },
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Icon(icon, size: 17),
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ],
  );
}
