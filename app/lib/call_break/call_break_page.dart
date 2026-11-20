import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'call_break_game.dart';
import 'call_break_room.dart';
import 'call_break_session.dart';
import 'offline_call_break.dart';

void openOfflineCallBreak(BuildContext context) {
  final session = OfflineCallBreak();
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => _CallBreakTable(session: session)),
  );
}

class CallBreakSetupPage extends StatefulWidget {
  const CallBreakSetupPage({required this.host, super.key});

  final bool host;

  @override
  State<CallBreakSetupPage> createState() => _CallBreakSetupPageState();
}

class _CallBreakSetupPageState extends State<CallBreakSetupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _enterRoom() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    CallBreakRoom? room;
    try {
      final name = _name.text.trim();
      room = widget.host
          ? await CallBreakRoom.host(name)
          : await CallBreakRoom.join(
              _address.text.trim(),
              name,
              _code.text.trim(),
            );
      final addresses = widget.host ? await _localAddresses() : <String>[];
      if (!mounted) {
        room.dispose();
        return;
      }
      final enteredRoom = room;
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              _CallBreakTable(session: enteredRoom, addresses: addresses),
        ),
      );
    } catch (error) {
      room?.dispose();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is CallBreakRoomException
            ? error.message
            : widget.host
            ? 'Could not host. Close any existing room and try again.'
            : 'Could not connect. Check the host IP and join the same network.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.host ? 'Host room' : 'Join room';
    return Scaffold(
      appBar: AppBar(title: Text(action)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 20,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nickname'),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Enter a nickname.' : null,
                  ),
                  if (!widget.host) ...[
                    TextFormField(
                      controller: _address,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Host IP address',
                      ),
                      validator: (value) =>
                          InternetAddress.tryParse(value!.trim())?.type ==
                              InternetAddressType.IPv4
                          ? null
                          : 'Enter an IPv4 address.',
                    ),
                    TextFormField(
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: 'Room code'),
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value!.trim())
                          ? null
                          : 'Enter the six-digit room code.',
                    ),
                  ],
                  if (_error case final error?)
                    _Message(text: error, isError: true),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _enterRoom,
                    child: Text(_busy ? 'Connecting…' : action),
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

Future<List<String>> _localAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final wifi = interfaces.where(
      (interface) => RegExp(r'^(wlan|wifi|ap)').hasMatch(interface.name),
    );
    return [
      for (final interface in wifi.isEmpty ? interfaces : wifi)
        for (final address in interface.addresses) address.address,
    ];
  } on SocketException {
    return [];
  }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(room == null ? 'Call Break · Offline' : 'Call Break'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final view = session.view;
            final phase = view['phase'] as String;
            final players = (view['players'] as List)
                .cast<Map<String, dynamic>>();
            final seat = view['seat'] as int;

            return ListView(
              padding: const EdgeInsets.all(16),
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
            );
          },
        ),
      ),
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
      _Message(
        text: 'Round $round / ${CallBreakGame.roundsPerMatch}   •   $status',
      ),
      _Seats(
        players: players,
        localSeat: seat,
        activeSeat: bidding || playing ? turn : null,
        showScores: roundEnd || matchEnd,
      ),
      const SizedBox(height: 8),
      if (!bidding)
        _Message(
          text: trick.isNotEmpty
              ? 'Current trick   ${_describeTrick(trick, players)}'
              : lastWinner != null
              ? '${players[lastWinner]['name']} took the last trick   '
                    '${_describeTrick(lastTrick, players)}'
              : 'Spades are trump.',
        ),
      if (hand.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            spacing: 6,
            children: [
              for (final card in hand)
                _PlayingCard(
                  card: card,
                  onPlay: legal.contains(card)
                      ? () => session.send('play', {'card': card})
                      : null,
                ),
            ],
          ),
        ),
      if (bidding && seat == turn)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var bid = 1; bid <= CallBreakGame.cardsPerHand; bid++)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(42, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => session.send('bid', {'bid': bid}),
                child: Text('$bid'),
              ),
          ],
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      spacing: 8,
      children: [
        for (var seat = 0; seat < players.length; seat++)
          Expanded(
            child: Card.outlined(
              color: seat == activeSeat ? colors.primaryContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seat == localSeat
                          ? '${players[seat]['name']} (you)'
                          : players[seat]['name'] as String? ?? 'Open seat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      showScores
                          ? 'Round ${_points(players[seat]['roundScore'] as int)}'
                                '   Total ${_points(players[seat]['score'] as int)}'
                          : players[seat]['bid'] != null
                          ? 'Bid ${players[seat]['bid']}   Won ${players[seat]['tricks']}'
                          : activeSeat != null
                          ? 'Waiting to bid'
                          : players[seat]['name'] == null
                          ? 'Waiting to join'
                          : players[seat]['ready'] == true
                          ? 'Ready'
                          : 'Not ready',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayingCard extends StatelessWidget {
  const _PlayingCard({required this.card, this.onPlay});

  final int card;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final suit = cardSuit(card);
    final red = suit == CardSuit.diamonds || suit == CardSuit.hearts;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(46, 52),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: Colors.white,
        foregroundColor: red ? const Color(0xFF9C233B) : Colors.black87,
        disabledBackgroundColor: Colors.white,
        disabledForegroundColor: red ? const Color(0xFF9C233B) : Colors.black87,
        side: BorderSide(
          width: onPlay == null ? 1 : 2,
          color: onPlay == null
              ? const Color(0xFFC9CCC5)
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      onPressed: onPlay,
      child: Text(cardLabel(card)),
    );
  }
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
