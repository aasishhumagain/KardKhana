import 'package:material_ui/material_ui.dart';

import '../cards/playing_card.dart';
import '../lan/lan_room_setup_page.dart';
import '../ui/game_table_screen.dart';
import '../ui/table_actions.dart';
import '../ui/table_widgets.dart';
import 'call_break_game.dart';
import 'call_break_room.dart';
import 'call_break_session.dart';
import 'offline_call_break.dart';

void openOfflineCallBreak(BuildContext context) {
  final session = OfflineCallBreak(animateDeals: true);
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => _CallBreakTable(session: session)),
  );
}

class CallBreakSetupPage extends StatelessWidget {
  const CallBreakSetupPage({required this.host, super.key});

  final bool host;

  @override
  Widget build(BuildContext context) => LanRoomSetupPage<CallBreakRoom>(
    host: host,
    minPlayers: CallBreakGame.playerCount,
    maxPlayers: CallBreakGame.playerCount,
    createRoom: (name, _) => CallBreakRoom.host(name),
    joinRoom: CallBreakRoom.join,
    buildTable: (room, addresses) =>
        _CallBreakTable(session: room, addresses: addresses),
  );
}

class _CallBreakTable extends StatefulWidget {
  const _CallBreakTable({required this.session, this.addresses = const []});

  final CallBreakSession session;
  final List<String> addresses;

  @override
  State<_CallBreakTable> createState() => _CallBreakTableState();
}

class _CallBreakTableState extends State<_CallBreakTable> {
  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final room = session is CallBreakRoom ? session : null;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final view = session.view;
        final phase = view['phase'] as String;
        final players = (view['players'] as List).cast<Map<String, dynamic>>();
        final seat = view['seat'] as int;
        final connected = room?.connected ?? true;
        final canAdvance = (room?.isHost ?? true) && connected;

        return GameTableScreen(
          title: room == null ? 'Call Break · Offline' : 'Call Break',
          view: view,
          roundLabel: 'Round',
          onDealFinished: session is OfflineCallBreak
              ? session.completeDeal
              : null,
          actions: phase == 'bidding' && seat == view['turn'] && connected
              ? TableActionBar(
                  scrollHorizontally: true,
                  actions: [
                    for (var bid = 1; bid <= CallBreakGame.cardsPerHand; bid++)
                      TableAction(
                        label: '$bid',
                        onPressed: () => session.send('bid', {'bid': bid}),
                      ),
                  ],
                )
              : canAdvance && (phase == 'roundEnd' || phase == 'matchEnd')
              ? TableActionBar(
                  actions: [
                    TableAction(
                      label: phase == 'roundEnd'
                          ? 'Deal next round'
                          : 'Rematch',
                      icon: Icons.refresh_rounded,
                      tone: TableActionTone.primary,
                      onPressed: () => session.send(
                        phase == 'roundEnd' ? 'next' : 'rematch',
                      ),
                    ),
                  ],
                )
              : null,
          table: ListView(
            padding: tablePadding,
            children: [
              if (room?.notice case final notice?)
                _Message(text: notice, isError: true),
              if (room != null && (!room.connected || phase == 'ended'))
                _Message(
                  text:
                      view['ended'] as String? ??
                      'Return to the catalog to join a new room.',
                )
              else if (room != null && phase == 'lobby')
                LanRoomLobby(room: room, addresses: widget.addresses)
              else
                ..._buildMatch(session, view, players, seat, phase),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMatch(
    CallBreakSession session,
    Map<String, dynamic> view,
    List<Map<String, dynamic>> players,
    int seat,
    String phase,
  ) {
    final round = view['round'] as int;
    final turn = view['turn'] as int;
    final bidding = phase == 'bidding';
    final playing = phase == 'playing';
    final roundEnd = phase == 'roundEnd';
    final matchEnd = phase == 'matchEnd';
    final scores = players.map((player) => player['score'] as int).toList();
    final bestScore = scores.reduce((a, b) => a > b ? a : b);
    final winners = [
      for (var index = 0; index < players.length; index++)
        if (scores[index] == bestScore) players[index]['name'] as String,
    ];
    final hand = (view['hand'] as List).cast<int>();
    final legal = (view['legal'] as List).cast<int>();
    final trick = (view['trick'] as List).cast<List<dynamic>>();
    final lastTrick = (view['lastTrick'] as List).cast<List<dynamic>>();
    final lastWinner = view['lastWinner'] as int?;
    final names = [
      for (var index = 0; index < players.length; index++)
        index == seat ? 'You' : players[index]['name'] as String,
    ];
    final status = switch (phase) {
      'bidding' when turn == seat => 'Your bid',
      'bidding' => '${players[turn]['name']} is bidding',
      'playing' when turn == seat => 'Your turn to play',
      'playing' => '${players[turn]['name']} is playing',
      'roundEnd' => 'Round complete',
      _ =>
        winners.length == 1
            ? '${winners.single} wins'
            : 'Tie between ${winners.join(', ')}',
    };

    return [
      TableStatus(
        progress: 'Round $round / ${CallBreakGame.roundsPerMatch}',
        status: status,
        yourTurn: (bidding || playing) && seat == turn,
        complete: roundEnd || matchEnd,
      ),
      const SizedBox(height: 5),
      _Seats(
        players: players,
        localSeat: seat,
        activeSeat: bidding || playing ? turn : null,
        showScores: roundEnd || matchEnd,
      ),
      if (!bidding) ...[
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            if (playing)
              Expanded(
                child: _Trick(
                  title: 'Current trick',
                  detail: '♠ Trump',
                  plays: trick,
                  names: names,
                ),
              ),
            if (lastWinner != null)
              Expanded(
                child: _Trick(
                  title: 'Last trick',
                  detail: '${names[lastWinner]} won',
                  plays: lastTrick,
                  names: names,
                ),
              ),
          ],
        ),
      ],
      if (hand.isNotEmpty) ...[
        const SizedBox(height: 6),
        CardTray(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              return Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: compact ? 3 : 5,
                    children: [
                      for (final card in hand)
                        PlayingCard(
                          card,
                          key: ValueKey(card),
                          compact: compact,
                          dimmed:
                              playing && seat == turn && !legal.contains(card),
                          onPressed: legal.contains(card)
                              ? () => session.send('play', {'card': card})
                              : null,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ];
  }
}

class _Trick extends StatelessWidget {
  const _Trick({
    required this.title,
    required this.detail,
    required this.plays,
    required this.names,
  });

  final String title;
  final String detail;
  final List<List<dynamic>> plays;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CardTray(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 4,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (plays.isEmpty)
            SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  'Waiting for the lead',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 3,
              children: [
                for (final play in plays)
                  Flexible(
                    child: SizedBox(
                      width: 46,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: [
                          SizedBox(
                            height: 38,
                            child: FittedBox(
                              child: PlayingCard(play[1] as int),
                            ),
                          ),
                          Text(
                            names[play[0] as int],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _points(int tenths) => (tenths / 10).toStringAsFixed(1);

class _Seats extends StatelessWidget {
  const _Seats({
    required this.players,
    required this.localSeat,
    this.activeSeat,
    this.showScores = false,
  });

  final List<Map<String, dynamic>> players;
  final int localSeat;
  final int? activeSeat;
  final bool showScores;

  @override
  Widget build(BuildContext context) => TableSeats(
    activeSeat: activeSeat,
    statusLines: showScores ? 2 : 1,
    names: [
      for (var seat = 0; seat < players.length; seat++)
        seat == localSeat
            ? 'You'
            : players[seat]['name'] as String? ?? 'Open seat',
    ],
    status: [
      for (final player in players)
        if (showScores)
          'Round ${_points(player['roundScore'] as int)} · Total ${_points(player['score'] as int)}'
        else if (player['bid'] != null)
          'Bid ${player['bid']} · Won ${player['tricks']}'
        else if (activeSeat != null)
          'Waiting to bid'
        else if (player['name'] == null)
          'Waiting to join'
        else
          player['ready'] == true ? 'Ready' : 'Not ready',
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isError ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}
