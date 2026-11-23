import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../cards/playing_card.dart';
import '../lan/lan_room.dart';
import '../lan/lan_room_setup_page.dart';
import '../offline/offline_table_widgets.dart';
import '../offline/offline_turn_pacing.dart';
import '../ui/game_table_screen.dart';
import '../ui/table_actions.dart';
import '../ui/table_widgets.dart';
import 'teen_patti_game.dart';
import 'teen_patti_room.dart';

class TeenPattiSetupPage extends StatelessWidget {
  const TeenPattiSetupPage({required this.host, super.key});

  final bool host;

  @override
  Widget build(BuildContext context) =>
      LanRoomSetupPage<LanRoom<TeenPattiGame>>(
        host: host,
        minPlayers: TeenPattiGame.minPlayers,
        maxPlayers: TeenPattiGame.maxPlayers,
        createRoom: hostTeenPattiRoom,
        joinRoom: joinTeenPattiRoom,
        buildTable: (room, addresses) => TeenPattiPage.lan(room, addresses),
      );
}

class TeenPattiPage extends StatefulWidget {
  const TeenPattiPage({required int this.playerCount, super.key})
    : room = null,
      addresses = const [];

  const TeenPattiPage.lan(
    LanRoom<TeenPattiGame> this.room,
    this.addresses, {
    super.key,
  }) : playerCount = null;

  final int? playerCount;
  final LanRoom<TeenPattiGame>? room;
  final List<String> addresses;

  @override
  State<TeenPattiPage> createState() => _TeenPattiPageState();
}

class _TeenPattiPageState extends State<TeenPattiPage> {
  late TeenPattiGame _game;
  Timer? _cpu;

  @override
  void initState() {
    super.initState();
    if (widget.playerCount case final count?) _game = TeenPattiGame(count);
  }

  @override
  void dispose() {
    _cpu?.cancel();
    widget.room?.dispose();
    super.dispose();
  }

  void _scheduleCpu() {
    _cpu?.cancel();
    if (_game.complete || _game.turn == 0) return;
    _cpu = Timer(offlineCpuTurnDelay, () {
      setState(_game.playCpuTurn);
      _scheduleCpu();
    });
  }

  void _act(TeenPattiAction action) {
    if (widget.room case final room?) {
      room.send(action.name);
      return;
    }
    if (!_game.act(0, action)) return;
    setState(() {});
    _scheduleCpu();
  }

  void _next({required bool reset}) {
    if (widget.room case final room?) {
      room.send(reset ? 'rematch' : 'next');
      return;
    }
    setState(() {
      if (reset) {
        _game = TeenPattiGame(_game.playerCount);
      } else {
        _game.nextRound();
      }
    });
    _scheduleCpu();
  }

  Map<String, dynamic> _offlineView() => {
    ...teenPattiTableView(_game, [
      for (var seat = 0; seat < _game.playerCount; seat++)
        (name: offlineSeatName(seat), ready: true),
    ]),
    ...teenPattiSeatView(_game, 0),
  };

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    if (room == null) return _table(context, _offlineView());
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) => _table(context, room.view),
    );
  }

  Widget _table(BuildContext context, Map<String, dynamic> view) {
    final room = widget.room;
    final phase = view['phase'] as String;
    return GameTableScreen(
      title: room == null ? 'Teen Patti · Offline' : 'Teen Patti',
      view: view,
      actions: phase == 'playing' && (room?.connected ?? true)
          ? _turnActions(view)
          : null,
      table: ListView(
        padding: tablePadding,
        children: [
          if (room?.notice case final notice?)
            Text(
              notice,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (room != null && (!room.connected || phase == 'ended'))
            Text(
              view['ended'] as String? ??
                  'Return to the catalog to join a new room.',
            )
          else if (room != null && phase == 'lobby')
            LanRoomLobby(room: room, addresses: widget.addresses)
          else
            ..._match(view, phase == 'roundEnd'),
        ],
      ),
    );
  }

  Widget? _turnActions(Map<String, dynamic> view) {
    final available = view['actions'] as List;
    if (available.isEmpty) return null;

    return TableActionBar(
      actions: [
        for (final action in const [
          TeenPattiAction.look,
          TeenPattiAction.call,
          TeenPattiAction.raise,
          TeenPattiAction.show,
          TeenPattiAction.pack,
        ])
          if (available.contains(action.name))
            TableAction(
              onPressed: () => _act(action),
              label: switch (action) {
                TeenPattiAction.look => 'Look',
                TeenPattiAction.call => 'Chaal · ${view['callCost']}',
                TeenPattiAction.raise => 'Raise · ${view['raiseCost']}',
                TeenPattiAction.show => 'Show · ${view['callCost']}',
                TeenPattiAction.pack => 'Pack',
              },
              icon: switch (action) {
                TeenPattiAction.look => Icons.visibility_outlined,
                TeenPattiAction.call => Icons.play_arrow_rounded,
                TeenPattiAction.raise => Icons.trending_up_rounded,
                TeenPattiAction.show => Icons.style_outlined,
                TeenPattiAction.pack => Icons.exit_to_app_rounded,
              },
              tone: switch (action) {
                TeenPattiAction.call => TableActionTone.primary,
                TeenPattiAction.pack => TableActionTone.caution,
                _ => TableActionTone.secondary,
              },
            ),
      ],
    );
  }

  List<Widget> _match(Map<String, dynamic> view, bool complete) {
    final players = (view['players'] as List).cast<Map<String, dynamic>>();
    final seat = view['seat'] as int;
    final turn = view['turn'] as int;
    final names = [
      for (var i = 0; i < players.length; i++)
        i == seat ? 'You' : players[i]['name'] as String,
    ];
    final ownHand = (view['hand'] as List).cast<int>();
    final winners = (view['winners'] as List).cast<int>();
    final pot = view['pot'] as int;
    final reset =
        view['canDeal'] == false ||
        (widget.room == null && players[seat]['points'] == 0);
    final winnerVerb = winners.length == 1 && winners.single != seat
        ? 'wins'
        : winners.length == 1
        ? 'win'
        : 'share';
    final banner = complete
        ? '${winners.map((winner) => names[winner]).join(', ')} $winnerVerb $pot points'
        : turn == seat
        ? 'Your turn'
        : '${names[turn]} is playing';

    return [
      TableStatus(
        progress: 'Hand ${view['round']} · Pot $pot',
        status: banner,
        yourTurn: !complete && turn == seat,
        complete: complete,
      ),
      const SizedBox(height: 8),
      TableSeats(
        activeSeat: complete ? null : turn,
        names: names,
        status: [
          for (final player in players)
            '${player['points']} points · ${player['note']}',
        ],
      ),
      const SizedBox(height: 12),
      if (ownHand.isNotEmpty)
        _handRow('Your hand', ownHand)
      else if (!complete && players[seat]['note'] != 'Out of points')
        const Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CardTray(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  PlayingCard.faceDown(),
                  PlayingCard.faceDown(),
                  PlayingCard.faceDown(),
                ],
              ),
            ),
            Text('Your cards are face down. Look to play seen.'),
          ],
        ),
      if (complete) ...[
        for (var i = 0; i < players.length; i++)
          if (i != seat && (players[i]['reveal'] as List).isNotEmpty)
            _handRow(names[i], (players[i]['reveal'] as List).cast<int>()),
        if (widget.room?.isHost ?? true)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => _next(reset: reset),
              child: Text(reset ? 'Reset points' : 'Next hand'),
            ),
          ),
      ],
    ];
  }
}

Widget _handRow(String title, List<int> hand) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      CardTray(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            for (final card in hand) PlayingCard(card, portrait: true),
          ],
        ),
      ),
      Text('$title · ${rankTeenPattiHand(hand).kind.label}'),
    ],
  ),
);
