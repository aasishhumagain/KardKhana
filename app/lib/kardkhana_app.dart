import 'package:material_ui/material_ui.dart';

class KardKhanaApp extends StatelessWidget {
  const KardKhanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KardKhana',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF215D4B)),
        scaffoldBackgroundColor: const Color(0xFFF9F7F1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF174638),
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const _GameCatalog(),
    );
  }
}

enum _Game {
  callBreak(
    'Call Break',
    'Bidding and trick-taking',
    'Bid on how many tricks you expect to win, then play each trick and '
        'see how your result compares with your bid.',
    Icons.flag_outlined,
    maximumPlayers: 4,
    requiresFullTable: true,
  ),
  teenPatti(
    'Teen Patti',
    'Three-card hands and virtual points',
    'Play with a three-card hand and virtual points. At a showdown, hands '
        'are compared to resolve the round.',
    Icons.layers_outlined,
    maximumPlayers: 5,
  ),
  marriage(
    'Marriage',
    'Draw, discard, and declare groups',
    'Draw and discard cards to build valid groups. Choose the cards in '
        'each group when you make a declaration.',
    Icons.style_outlined,
    maximumPlayers: 5,
  );

  const _Game(
    this.title,
    this.summary,
    this.description,
    this.icon, {
    required this.maximumPlayers,
    this.requiresFullTable = false,
  });

  final String title;
  final String summary;
  final String description;
  final IconData icon;
  final int maximumPlayers;
  final bool requiresFullTable;

  String get playerLimitLabel => requiresFullTable
      ? 'Exactly $maximumPlayers players to start'
      : 'Up to $maximumPlayers players';
}

class _GameCatalog extends StatelessWidget {
  const _GameCatalog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('KardKhana')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  for (final game in _Game.values) _GameCard(game: game),
                ];

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Choose a game',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (constraints.maxWidth >= 640)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 12,
                          children: [
                            for (final card in cards) Expanded(child: card),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: cards,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final _Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => _GameDetails(game: game)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(game.icon, color: colors.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 12),
              Text(game.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(game.summary, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                game.playerLimitLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameDetails extends StatelessWidget {
  const _GameDetails({required this.game});

  final _Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(game.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(game.summary, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(game.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                Card.outlined(
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: Text(game.playerLimitLabel),
                    subtitle: const Text('Private rooms are in development.'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
