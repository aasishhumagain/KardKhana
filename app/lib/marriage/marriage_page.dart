import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../cards/playing_card.dart';
import '../cards/standard_cards.dart';
import '../lan/lan_room.dart';
import '../lan/lan_room_setup_page.dart';
import '../offline/offline_table_widgets.dart';
import '../offline/offline_turn_pacing.dart';
import '../ui/game_table_screen.dart';
import '../ui/table_actions.dart';
import '../ui/table_widgets.dart';
import 'marriage_game.dart';
import 'marriage_room.dart';

class MarriageSetupPage extends StatelessWidget {
  const MarriageSetupPage({required this.host, super.key});

  final bool host;

  @override
  Widget build(BuildContext context) => LanRoomSetupPage<LanRoom<MarriageGame>>(
    host: host,
    minPlayers: MarriageGame.minPlayers,
    maxPlayers: MarriageGame.maxPlayers,
    createRoom: hostMarriageRoom,
    joinRoom: joinMarriageRoom,
    buildTable: (room, addresses) => MarriagePage.lan(room, addresses),
  );
}

class MarriagePage extends StatefulWidget {
  const MarriagePage({required int this.playerCount, super.key})
    : room = null,
      addresses = const [];

  const MarriagePage.lan(
    LanRoom<MarriageGame> this.room,
    this.addresses, {
    super.key,
  }) : playerCount = null;

  final int? playerCount;
  final LanRoom<MarriageGame>? room;
  final List<String> addresses;

  @override
  State<MarriagePage> createState() => _MarriagePageState();
}

class _MarriagePageState extends State<MarriagePage> {
  late final MarriageGame _game;
  final _selected = <int>{};
  Timer? _cpu;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.playerCount case final count?) _game = MarriageGame(count);
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

  void _submit(
    String action,
    Map<String, Object?> fields,
    bool Function() offlineAction,
  ) {
    final room = widget.room;
    if (room != null) {
      room.send(action, fields);
    } else if (!offlineAction()) {
      return;
    }
    setState(() {
      _message = null;
      _selected.clear();
    });
    if (room == null) _scheduleCpu();
  }

  void _draw({required bool fromDiscard}) => _submit('draw', {
    'fromDiscard': fromDiscard,
  }, () => _game.draw(0, fromDiscard: fromDiscard));

  void _layGroup(int? maal) {
    final cards = _selected.toList();
    if (!isMarriageGroup(cards, maal: maal)) {
      setState(() {
        _message = maal == null
            ? 'That group needs three consecutive cards of one suit or three identical cards.'
            : 'Those cards do not form a legal run, tunnella, or trial.';
      });
      return;
    }
    _submit('lay', {'cards': cards}, () => _game.layGroup(0, cards));
  }

  void _toggleCard(int card) {
    setState(() {
      _message = null;
      if (_selected.remove(card)) return;
      if (_selected.length == marriageGroupSize) {
        _message = 'Deselect a card before choosing another.';
      } else {
        _selected.add(card);
      }
    });
  }

  Map<String, dynamic> _offlineView() => {
    ...marriageTableView(_game, [
      for (var seat = 0; seat < _game.playerCount; seat++)
        (name: offlineSeatName(seat), ready: true),
    ]),
    ...marriageSeatView(_game, 0),
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
      title: room == null ? 'Marriage · Offline' : 'Marriage',
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
            ..._match(context, view, complete: phase == 'roundEnd'),
        ],
      ),
    );
  }

  Widget _turnActions(Map<String, dynamic> view) {
    final yourTurn = view['turn'] == view['seat'];
    final afterDraw = yourTurn && view['hasDrawn'] == true;
    final stock = view['stockCount'] as int;
    final discard = view['topDiscard'] as int?;
    final maal = view['maal'] as int?;
    final picked = _selected.length == 1 ? _selected.single : null;
    final discardable = view['discardable'] as List;

    return TableActionBar(
      actions: [
        if (afterDraw)
          TableAction(
            label: 'Discard selected',
            icon: Icons.upload_rounded,
            tone: TableActionTone.primary,
            onPressed: picked != null && discardable.contains(picked)
                ? () => _submit('discard', {
                    'card': picked,
                  }, () => _game.discard(0, picked))
                : null,
          )
        else ...[
          TableAction(
            label: 'Draw stock · $stock',
            icon: Icons.layers_outlined,
            tone: TableActionTone.primary,
            onPressed: yourTurn && stock > 0
                ? () => _draw(fromDiscard: false)
                : null,
          ),
          TableAction(
            label: discard == null
                ? 'Discard pile empty'
                : 'Take ${marriageCardLabel(discard)}',
            icon: Icons.download_rounded,
            onPressed: yourTurn && discard != null
                ? () => _draw(fromDiscard: true)
                : null,
          ),
        ],
        TableAction(
          label: 'Lay group',
          icon: Icons.grid_view_rounded,
          onPressed: yourTurn && _selected.length == marriageGroupSize
              ? () => _layGroup(maal)
              : null,
        ),
      ],
    );
  }

  List<Widget> _match(
    BuildContext context,
    Map<String, dynamic> view, {
    required bool complete,
  }) {
    final theme = Theme.of(context);
    final players = (view['players'] as List).cast<Map<String, dynamic>>();
    final seat = view['seat'] as int;
    final turn = view['turn'] as int;
    final names = [
      for (var index = 0; index < players.length; index++)
        index == seat ? 'You' : players[index]['name'] as String,
    ];
    final yourTurn = !complete && turn == seat;
    final hasDrawn = view['hasDrawn'] as bool;
    final maal = view['maal'] as int?;
    final winner = view['winner'] as int?;
    final hand = (view['hand'] as List).cast<int>();
    final status = complete
        ? winner == null
              ? 'Stock exhausted · Draw'
              : winner == seat
              ? 'You win the hand'
              : '${names[winner]} wins the hand'
        : yourTurn
        ? hasDrawn
              ? 'Lay a group or discard one card'
              : 'Lay a group or draw a card'
        : '${names[turn]} is playing';

    return [
      TableStatus(
        progress: 'Hand ${view['round']}',
        status: status,
        yourTurn: yourTurn,
        complete: complete,
      ),
      const SizedBox(height: 8),
      if (!complete) ...[
        if (_message case final message?) ...[
          Text(message, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 4),
        ],
        CardTray(
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final card in hand)
                PlayingCard(
                  isPrintedJoker(card) ? null : marriageFace(card),
                  key: ValueKey(card),
                  wild: maal != null && isMarriageWild(card, maal),
                  selected: _selected.contains(card),
                  onPressed: yourTurn ? () => _toggleCard(card) : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          maal == null
              ? 'Lay three pure runs or tunnellas to reveal the maal.'
              : 'Maal · ${cardLabel(maal)}   Wild cards may complete runs and trials.',
        ),
        const SizedBox(height: 8),
      ],
      TableSeats(
        activeSeat: complete ? null : turn,
        names: names,
        status: [
          for (final player in players)
            complete
                ? '${player['roundPoints']} this hand · ${player['points']} total'
                : '${player['groups']}/${MarriageGame.groupsToWin} groups · ${player['note']}',
        ],
      ),
      const SizedBox(height: 8),
      if (complete && (widget.room?.isHost ?? true))
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => _submit('next', const {}, () => _game.nextRound()),
            child: const Text('Next hand'),
          ),
        ),
    ];
  }
}
