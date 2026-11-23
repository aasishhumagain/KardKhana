import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../settings/game_feedback.dart';
import '../table_log.dart';
import 'deal_animation.dart';
import 'table_widgets.dart';

class GameTableScreen extends StatefulWidget {
  const GameTableScreen({
    required this.title,
    required this.view,
    required this.table,
    this.actions,
    this.onDealFinished,
    this.roundLabel = 'Hand',
    super.key,
  });

  final String title;
  final Map<String, dynamic> view;
  final Widget table;
  final Widget? actions;
  final VoidCallback? onDealFinished;
  final String roundLabel;

  @override
  State<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends State<GameTableScreen> {
  final _playerNames = <int, String>{};
  bool _showLog = false;
  late bool _dealing;
  int _dealNumber = 0;
  GameFeedback? _feedback;

  @override
  void initState() {
    super.initState();
    _rememberPlayers();
    _dealing = _playing(widget.view);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedback = GameFeedbackScope.maybeOf(context);
  }

  @override
  void didUpdateWidget(covariant GameTableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberPlayers();
    if (!_playing(widget.view)) {
      _dealing = false;
    } else if (!_playing(oldWidget.view) ||
        oldWidget.view['round'] != widget.view['round']) {
      _dealing = true;
      _dealNumber++;
      return;
    }
    if (!_dealing) _feedbackForMoves(oldWidget.view);
  }

  static bool _playing(Map<String, dynamic> view) =>
      view['phase'] == 'bidding' || view['phase'] == 'playing';

  void _finishDeal() {
    if (!_dealing) return;
    setState(() => _dealing = false);
    widget.onDealFinished?.call();
  }

  void _feedbackForMoves(Map<String, dynamic> previous) {
    final feedback = _feedback;
    if (feedback == null ||
        (!feedback.soundEnabled && !feedback.vibrationEnabled)) {
      return;
    }
    final before = TableLog.readView(previous['log']);
    final after = TableLog.readView(widget.view['log']);
    var overlap = math.min(before.length, after.length);
    // The capped log can discard its oldest moves while appending new ones.
    while (overlap > 0 && !_sameMoves(before, after, overlap)) {
      overlap--;
    }

    final sounds = <CardSound>[];
    var localAction = false;
    for (final entry in after.skip(overlap)) {
      if (entry.round != widget.view['round'] ||
          entry.move == TableMove.result) {
        continue;
      }
      localAction |= entry.seat == widget.view['seat'];
      final sound = switch (entry.move) {
        TableMove.draw => CardSound.pickUp,
        TableMove.discard || TableMove.play => CardSound.drop,
        TableMove.decision
            when entry.message == 'Looked at their cards' &&
                entry.seat == widget.view['seat'] =>
          CardSound.pickUp,
        _ => null,
      };
      if (sound != null) sounds.add(sound);
    }
    if (localAction) feedback.tap();
    if (sounds.isNotEmpty && feedback.soundEnabled) {
      unawaited(_playSounds(feedback, sounds, _dealNumber));
    }
  }

  bool _sameMoves(
    List<TableLogEntry> before,
    List<TableLogEntry> after,
    int count,
  ) {
    final first = before.length - count;
    for (var i = 0; i < count; i++) {
      if (before[first + i] != after[i]) return false;
    }
    return true;
  }

  Future<void> _playSounds(
    GameFeedback feedback,
    List<CardSound> sounds,
    int deal,
  ) async {
    for (var i = 0; i < sounds.length; i++) {
      if (i != 0) await Future<void>.delayed(const Duration(milliseconds: 130));
      if (!mounted || _dealNumber != deal) return;
      await feedback.play(sounds[i]);
    }
  }

  List<String> _dealSeats() {
    final players = (widget.view['players'] as List)
        .cast<Map<String, dynamic>>();
    final localSeat = widget.view['seat'] as int;
    return [
      for (var offset = 0; offset < players.length; offset++)
        if (players[(localSeat + offset) % players.length]['note'] !=
            'Out of points')
          _playerName((localSeat + offset) % players.length),
    ];
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
        title: Text(
          _showLog ? 'Game log' : widget.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: _dealing,
              child: ExcludeSemantics(
                excluding: _dealing,
                child: IndexedStack(
                  index: _showLog ? 1 : 0,
                  children: [
                    TableBoard(
                      active:
                          widget.view['phase'] != 'lobby' &&
                          widget.view['phase'] != 'ended',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: widget.table),
                          ?widget.actions,
                        ],
                      ),
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
            if (_dealing)
              DealAnimation(
                key: ValueKey(_dealNumber),
                seats: _dealSeats(),
                onComplete: _finishDeal,
              ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            spacing: 10,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(switch (entry.move) {
                  TableMove.draw => Icons.download_rounded,
                  TableMove.discard => Icons.upload_rounded,
                  TableMove.play => Icons.style_outlined,
                  TableMove.decision => Icons.more_horiz,
                  TableMove.result => Icons.emoji_events_outlined,
                }, size: 15),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 1,
                  children: [
                    Text(
                      playerName(entry.seat),
                      style: theme.textTheme.labelLarge,
                    ),
                    Text(
                      entry.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$roundLabel ${entry.round}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
