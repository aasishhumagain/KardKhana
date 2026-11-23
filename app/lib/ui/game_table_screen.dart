import 'package:material_ui/material_ui.dart';

import '../table_log.dart';
import 'table_widgets.dart';

class GameTableScreen extends StatefulWidget {
  const GameTableScreen({
    required this.title,
    required this.view,
    required this.table,
    this.actions,
    this.roundLabel = 'Hand',
    super.key,
  });

  final String title;
  final Map<String, dynamic> view;
  final Widget table;
  final Widget? actions;
  final String roundLabel;

  @override
  State<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends State<GameTableScreen> {
  final _playerNames = <int, String>{};
  bool _showLog = false;

  @override
  void initState() {
    super.initState();
    _rememberPlayers();
  }

  @override
  void didUpdateWidget(covariant GameTableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberPlayers();
  }

  void _rememberPlayers() {
    final players = widget.view['players'] as List;
    for (var seat = 0; seat < players.length; seat++) {
      final player = players[seat] as Map<String, dynamic>;
      if (player['name'] case final String name) _playerNames[seat] = name;
    }
  }

  String _playerName(int seat) => seat == widget.view['seat']
      ? 'You'
      : _playerNames[seat] ?? 'Player ${seat + 1}';

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_showLog,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _showLog) setState(() => _showLog = false);
    },
    child: Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Home',
                icon: const Icon(Icons.home_outlined),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              IconButton(
                tooltip: _showLog ? 'Back to game' : 'Log',
                isSelected: _showLog,
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long_rounded),
                onPressed: () => setState(() => _showLog = !_showLog),
              ),
            ],
          ),
        ),
        titleSpacing: 4,
        title: Text(_showLog ? 'Game log' : widget.title),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _showLog ? 1 : 0,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: widget.table),
                ?widget.actions,
              ],
            ),
            if (_showLog)
              _GameLog(
                entries: TableLog.readView(widget.view['log']),
                playerName: _playerName,
                roundLabel: widget.roundLabel,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    ),
  );
}

class _GameLog extends StatelessWidget {
  const _GameLog({
    required this.entries,
    required this.playerName,
    required this.roundLabel,
  });

  final List<TableLogEntry> entries;
  final String Function(int) playerName;
  final String roundLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: tablePadding,
          child: Text('Moves will appear here as the game is played.'),
        ),
      );
    }
    return ListView.separated(
      padding: tablePadding,
      primary: false,
      itemCount: entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        return Card.outlined(
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 17,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(switch (entry.move) {
                TableMove.draw => Icons.download_rounded,
                TableMove.discard => Icons.upload_rounded,
                TableMove.play => Icons.style_outlined,
                TableMove.decision => Icons.more_horiz,
                TableMove.result => Icons.emoji_events_outlined,
              }, size: 18),
            ),
            title: Text(playerName(entry.seat)),
            subtitle: Text(entry.message),
            trailing: Text('$roundLabel ${entry.round}'),
          ),
        );
      },
    );
  }
}
