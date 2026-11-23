import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../cards/playing_card.dart';
import '../lan/lan_room.dart';
import '../lan/lan_room_setup_page.dart';
import '../offline/offline_table_widgets.dart';
import '../offline/offline_turn_pacing.dart';
import '../ui/game_table_screen.dart';
import '../ui/table_actions.dart';
import '../ui/table_scene.dart';
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
      onDealFinished: room == null ? _scheduleCpu : null,
      actions: (room?.connected ?? true) ? _tableActions(view, phase) : null,
      table: phase == 'playing' && (room?.connected ?? true)
          ? _match(view, notice: room?.notice)
          : ListView(
              padding: tablePadding,
              children: [
                if (room?.notice case final notice?)
                  Text(
                    notice,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (room != null && (!room.connected || phase == 'ended'))
                  Text(
                    view['ended'] as String? ??
                        'Return to the catalog to join a new room.',
                  )
                else if (room != null && phase == 'lobby')
                  LanRoomLobby(room: room, addresses: widget.addresses)
                else
                  _match(view),
              ],
            ),
    );
  }

  Widget? _tableActions(Map<String, dynamic> view, String phase) {
    if (phase == 'roundEnd' && (widget.room?.isHost ?? true)) {
      final local = (view['players'] as List)[view['seat'] as int] as Map;
      final reset =
          view['canDeal'] == false ||
          (widget.room == null && local['points'] == 0);
      return TableActionBar(
        actions: [
          TableAction(
            label: reset ? 'Reset points' : 'Next hand',
            icon: Icons.refresh_rounded,
            tone: TableActionTone.primary,
            onPressed: () => _next(reset: reset),
          ),
        ],
      );
    }
    if (phase != 'playing') return null;
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

  Widget _match(Map<String, dynamic> view, {String? notice}) {
    final complete = view['phase'] == 'roundEnd';
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

    final progress = 'Hand ${view['round']}';
    if (complete) {
      return Column(
        spacing: 8,
        children: [
          TableStatus(
            progress: '$progress · Pot $pot',
            status: banner,
            yourTurn: false,
            complete: true,
          ),
          TableSeats(
            names: names,
            status: [
              for (final player in players)
                '${player['points']} points · ${player['note']}',
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (ownHand.isNotEmpty)
                _shownHand('Your hand', ownHand, compact: true),
              for (var i = 0; i < players.length; i++)
                if (i != seat && (players[i]['reveal'] as List).isNotEmpty)
                  _shownHand(
                    names[i],
                    (players[i]['reveal'] as List).cast<int>(),
                    compact: true,
                  ),
            ],
          ),
        ],
      );
    }

    return TableScene(
      seats: [
        for (var i = 0; i < players.length; i++)
          (
            name: names[i],
            detail: '${players[i]['points']} pts · ${players[i]['note']}',
          ),
      ],
      localSeat: seat,
      activeSeat: turn,
      status: banner,
      progress: progress,
      notice: notice,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              const Icon(
                Icons.toll_rounded,
                color: Color(0xFFF3CC7F),
                size: 22,
              ),
              Text(
                'Pot $pot',
                style: const TextStyle(
                  color: Color(0xFFFFE0A5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (ownHand.isNotEmpty)
            Text(
              'Your hand · ${rankTeenPattiHand(ownHand).kind.label}',
              textAlign: TextAlign.center,
            )
          else if (players[seat]['note'] != 'Out of points')
            const Text(
              'Tap Look to see your cards',
              textAlign: TextAlign.center,
            ),
        ],
      ),
      hand: HandSpread(
        large: true,
        cards: [
          if (ownHand.isNotEmpty)
            for (final card in ownHand)
              PlayingCard(card, key: ValueKey(card), portrait: true)
          else if (players[seat]['note'] != 'Out of points')
            for (var index = 0; index < 3; index++)
              PlayingCard.faceDown(key: ValueKey(index)),
        ],
      ),
    );
  }
}

Widget _shownHand(String title, List<int> hand, {bool compact = false}) =>
    CardTray(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              for (final card in hand)
                PlayingCard(card, portrait: !compact, compact: compact),
            ],
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 130 : 220),
            child: Text(
              '$title · ${rankTeenPattiHand(hand).kind.label}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
