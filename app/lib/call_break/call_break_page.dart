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

        return GameTableScreen(
          title: room == null ? 'Call Break · Offline' : 'Call Break',
          view: view,
          roundLabel: 'Round',
          onDealFinished: session is OfflineCallBreak
              ? session.completeDeal
              : null,
          actions:
              phase == 'bidding' &&
                  seat == view['turn'] &&
                  (room?.connected ?? true)
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
                ..._buildLobby(room, players, seat)
              else
                ..._buildMatch(
                  session,
                  view,
                  players,
                  seat,
                  phase,
                  canAdvance: room?.isHost ?? true,
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildLobby(
    CallBreakRoom room,
    List<Map<String, dynamic>> players,
    int seat,
  ) {
    final ready = players[seat]['ready'] == true;
    final canStart = players.every((player) => player['ready'] == true);
    final occupied = players.where((player) => player['name'] != null).length;
    return [
      if (room.isHost)
        _Message(
          text:
              'Room code ${room.roomCode}   •   '
              'Host IP ${widget.addresses.isEmpty ? 'Use the host’s network settings' : widget.addresses.join(' or ')}',
        ),
      _Message(
        text:
            '$occupied / ${CallBreakGame.playerCount} seated. '
            'All four players must be ready.',
      ),
      _Seats(players: players, localSeat: seat),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => room.send('ready', {'ready': !ready}),
            child: Text(ready ? 'Not ready' : 'Ready'),
          ),
          if (room.isHost)
            FilledButton(
              onPressed: canStart ? () => room.send('start') : null,
              child: const Text('Start match'),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildMatch(
    CallBreakSession session,
    Map<String, dynamic> view,
    List<Map<String, dynamic>> players,
    int seat,
    String phase, {
    required bool canAdvance,
  }) {
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
    final trickSummary = [
      if (trick.isNotEmpty) 'Current trick   ${_describeTrick(trick, players)}',
      if (lastWinner != null)
        'Last trick · ${players[lastWinner]['name']} won   '
            '${_describeTrick(lastTrick, players)}',
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
      const SizedBox(height: 8),
      _Seats(
        players: players,
        localSeat: seat,
        activeSeat: bidding || playing ? turn : null,
        showScores: roundEnd || matchEnd,
      ),
      const SizedBox(height: 8),
      if (!bidding)
        _Message(
          text: trickSummary.isEmpty
              ? 'Spades are trump.'
              : trickSummary.join('\n'),
        ),
      if (hand.isNotEmpty)
        CardTray(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                for (final card in hand)
                  PlayingCard(
                    card,
                    key: ValueKey(card),
                    dimmed: playing && seat == turn && !legal.contains(card),
                    onPressed: legal.contains(card)
                        ? () => session.send('play', {'card': card})
                        : null,
                  ),
              ],
            ),
          ),
        ),
      if (canAdvance && (roundEnd || matchEnd))
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => session.send(roundEnd ? 'next' : 'rematch'),
            child: Text(roundEnd ? 'Deal next round' : 'Rematch'),
          ),
        ),
    ];
  }
}

String _describeTrick(
  List<List<dynamic>> trick,
  List<Map<String, dynamic>> players,
) => [
  for (final play in trick)
    '${players[play[0] as int]['name']} ${cardLabel(play[1] as int)}',
].join('   •   ');

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
    names: [
      for (var seat = 0; seat < players.length; seat++)
        seat == localSeat
            ? '${players[seat]['name']} (you)'
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
