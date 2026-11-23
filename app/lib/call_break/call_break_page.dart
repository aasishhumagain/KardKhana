import 'package:material_ui/material_ui.dart';

import '../cards/playing_card.dart';
import '../lan/lan_room_setup_page.dart';
import '../ui/game_table_screen.dart';
import '../ui/table_actions.dart';
import '../ui/table_scene.dart';
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
          table: connected && phase != 'lobby' && phase != 'ended'
              ? _buildMatch(
                  session,
                  view,
                  players,
                  seat,
                  phase,
                  notice: room?.notice,
                )
              : ListView(
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
                      LanRoomLobby(room: room, addresses: widget.addresses),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMatch(
    CallBreakSession session,
    Map<String, dynamic> view,
    List<Map<String, dynamic>> players,
    int seat,
    String phase, {
    String? notice,
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

    final progress = 'Round $round / ${CallBreakGame.roundsPerMatch}';
    final completed = roundEnd || matchEnd;
    final showingLast = trick.isEmpty && lastTrick.isNotEmpty;
    final plays = showingLast ? lastTrick : trick;
    return TableScene(
      seats: [
        for (var i = 0; i < players.length; i++)
          (
            name: names[i],
            detail: completed
                ? 'Round ${_points(players[i]['roundScore'] as int)} · Total ${_points(players[i]['score'] as int)}'
                : players[i]['bid'] == null
                ? 'Waiting to bid'
                : 'Bid ${players[i]['bid']} · Won ${players[i]['tricks']}',
          ),
      ],
      localSeat: seat,
      activeSeat: completed ? null : turn,
      status: status,
      progress: progress,
      notice: notice,
      round: round,
      cards: [
        for (final [int thrower, int card] in plays)
          (
            serial: card,
            seat: thrower,
            face: Semantics(
              label: '${names[thrower]} played',
              child: PlayingCard(card, compact: true),
            ),
          ),
      ],
      center: bidding
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '♠',
                  style: TextStyle(
                    color: Color(0xFFFFDA96),
                    fontSize: 24,
                    height: 1,
                  ),
                ),
                Text('Spades are trump'),
              ],
            )
          : Align(
              alignment: plays.isEmpty ? Alignment.center : Alignment.topCenter,
              child: Text(
                showingLast && lastWinner != null
                    ? 'Last trick · ${names[lastWinner]} won'
                    : plays.isEmpty
                    ? 'Lead a card · ♠ Trump'
                    : 'Current trick · ♠ Trump',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD993),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      hand: hand.isEmpty
          ? const SizedBox(height: 69)
          : HandSpread(
              cards: [
                for (final card in hand)
                  PlayingCard(
                    card,
                    key: ValueKey(card),
                    compact: true,
                    dimmed: playing && seat == turn && !legal.contains(card),
                    onPressed: legal.contains(card)
                        ? () => session.send('play', {'card': card})
                        : null,
                  ),
              ],
            ),
    );
  }
}

String _points(int tenths) => (tenths / 10).toStringAsFixed(1);

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
