import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../cards/playing_card.dart';
import '../cards/standard_cards.dart';
import '../lan/lan_room.dart';
import '../lan/lan_room_setup_page.dart';
import '../offline/offline_table_widgets.dart';
import '../offline/offline_turn_pacing.dart';
import '../ui/game_table_screen.dart';
import '../ui/card_flights.dart';
import '../ui/table_actions.dart';
import '../ui/table_scene.dart';
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
    if (room == null && action != 'next') _scheduleCpu();
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

  void _layDublee() {
    final cards = _selected.toList();
    if (!isMarriageDublee(cards.first, cards.last)) {
      setState(
        () => _message = 'A Dublee needs two cards of the same rank and suit.',
      );
      return;
    }
    _submit('layDublee', {'cards': cards}, () {
      final accepted = _game.layDublee(0, cards.first, cards.last);
      if (!accepted) {
        setState(
          () =>
              _message = 'Finish with the card you took from the discard pile.',
        );
      }
      return accepted;
    });
  }

  void _toggleCard(int card, int limit) {
    setState(() {
      _message = null;
      if (_selected.remove(card)) return;
      if (_selected.length == limit) {
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
    final connected = room?.connected ?? true;
    return GameTableScreen(
      title: room == null ? 'Marriage · Offline' : 'Marriage',
      view: view,
      onDealFinished: room == null ? _scheduleCpu : null,
      actions: phase == 'playing' && connected
          ? _turnActions(view)
          : phase == 'roundEnd' && connected && (room?.isHost ?? true)
          ? TableActionBar(
              actions: [
                TableAction(
                  label: 'Next hand',
                  icon: Icons.refresh_rounded,
                  tone: TableActionTone.primary,
                  onPressed: () =>
                      _submit('next', const {}, () => _game.nextRound()),
                ),
              ],
            )
          : null,
      table: (phase == 'playing' || phase == 'roundEnd') && connected
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
                  LanRoomLobby(room: room, addresses: widget.addresses),
              ],
            ),
    );
  }

  Widget _turnActions(Map<String, dynamic> view) {
    final yourTurn = view['turn'] == view['seat'];
    final afterDraw = yourTurn && view['hasDrawn'] == true;
    final maal = view['maal'] as int?;
    final player = (view['players'] as List)[view['seat'] as int] as Map;
    final dublees = player['dublees'] as int? ?? 0;
    final groups = player['groups'] as int;
    final available = view['availableDublees'] as int?;
    final picked = _selected.length == 1 ? _selected.single : null;
    final discardable = view['discardable'] as List;

    return TableActionBar(
      scrollHorizontally: true,
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
          ),
        if (dublees == 0) ...[
          TableAction(
            label: 'Lay group',
            icon: Icons.grid_view_rounded,
            onPressed: yourTurn && _selected.length == marriageGroupSize
                ? () => _layGroup(maal)
                : null,
          ),
          if (groups == 0 && available != null)
            TableAction(
              label: available >= MarriageGame.dubleesToReveal
                  ? 'Show 7 Dublees'
                  : 'Dublees $available/${MarriageGame.dubleesToReveal}',
              icon: Icons.copy_outlined,
              onPressed: yourTurn && available >= MarriageGame.dubleesToReveal
                  ? () => _submit(
                      'showDublees',
                      const {},
                      () => _game.showDublees(0),
                    )
                  : null,
            ),
        ] else if (dublees == MarriageGame.dubleesToReveal)
          TableAction(
            label: 'Lay eighth Dublee',
            icon: Icons.copy_outlined,
            onPressed: afterDraw && _selected.length == dubleeSize
                ? _layDublee
                : null,
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
      for (var index = 0; index < players.length; index++)
        index == seat ? 'You' : players[index]['name'] as String,
    ];
    final yourTurn = !complete && turn == seat;
    final hasDrawn = view['hasDrawn'] as bool;
    final dublees = players[seat]['dublees'] as int? ?? 0;
    final maal = view['maal'] as int?;
    final progress = 'Hand ${view['round']}';
    final winner = view['winner'] as int?;
    final hand = (view['hand'] as List).cast<int>();
    final status = complete
        ? winner == null
              ? 'Stock exhausted · Draw'
              : winner == seat
              ? 'You finish the hand'
              : '${names[winner]} finishes the hand'
        : yourTurn
        ? dublees == MarriageGame.dubleesToWin
              ? 'Discard one card to finish'
              : dublees > 0
              ? hasDrawn
                    ? 'Lay your eighth Dublee or discard'
                    : 'Draw to make your eighth Dublee'
              : hasDrawn
              ? 'Lay a group or discard one card'
              : 'Lay a group or draw a card'
        : '${names[turn]} is playing';

    final stock = view['stockCount'] as int;
    final discard = view['topDiscard'] as int?;
    final round = view['round'] as int;
    final discards =
        (view['discardPile'] as List?)?.cast<List<dynamic>>() ??
        [
          if (discard != null) [discard, null, discard],
        ];
    final canDraw = yourTurn && !hasDrawn;
    final canTake =
        canDraw && (view['canTakeDiscard'] as bool? ?? discard != null);
    return TableScene(
      seats: [
        for (var i = 0; i < players.length; i++)
          (
            name: names[i],
            detail: complete
                ? '${players[i]['roundPoints']} this hand · ${players[i]['points']} total · ${players[i]['maalPoints'] ?? 0} maal'
                : [
                    if ((players[i]['dublees'] as int? ?? 0) > 0)
                      '${players[i]['dublees']}/${MarriageGame.dubleesToWin} Dublees'
                    else
                      '${players[i]['groups']}/${MarriageGame.groupsToWin} groups',
                    if (i == seat && maal != null) 'Maal ${cardLabel(maal)}',
                  ].join(' · '),
          ),
      ],
      localSeat: seat,
      activeSeat: complete ? null : turn,
      progress: progress,
      status: status,
      notice: notice ?? _message,
      round: round,
      landingZone: LandingZone.discard,
      cards: [
        for (final [int card, int? thrower, int serial] in discards)
          (
            serial: serial,
            seat: thrower,
            face: PlayingCard(
              isPrintedJoker(card) ? null : marriageFace(card),
              compact: true,
            ),
          ),
      ],
      center: Row(
        children: [
          Expanded(
            child: Center(
              child: _Pile(
                label: canDraw && stock > 0
                    ? 'Draw stock · $stock'
                    : 'Stock · $stock',
                card: stock > 0 ? const PlayingCard.faceDown() : null,
                stacked: true,
                onTap: canDraw && stock > 0
                    ? () => _draw(fromDiscard: false)
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _Pile(
                label: canTake && discard != null
                    ? 'Take ${marriageCardLabel(discard)}'
                    : 'Discard pile',
                card: null,
                occupied: discard != null,
                onTap: canTake ? () => _draw(fromDiscard: true) : null,
              ),
            ),
          ),
        ],
      ),
      hand: complete
          ? const SizedBox(height: 69)
          : HandSpread(
              cards: [
                for (final card in hand)
                  PlayingCard(
                    isPrintedJoker(card) ? null : marriageFace(card),
                    key: ValueKey(card),
                    compact: true,
                    wild: maal != null && isMarriageWild(card, maal),
                    selected: _selected.contains(card),
                    onPressed: yourTurn
                        ? () => _toggleCard(
                            card,
                            dublees == MarriageGame.dubleesToReveal
                                ? dubleeSize
                                : marriageGroupSize,
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}

class _Pile extends StatelessWidget {
  const _Pile({
    required this.label,
    required this.card,
    required this.onTap,
    this.stacked = false,
    this.occupied = false,
  });

  final String label;
  final Widget? card;
  final VoidCallback? onTap;
  final bool stacked;
  final bool occupied;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Flexible(
              child: SizedBox(
                height: 40,
                width: 34,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (stacked && card != null)
                      Transform.translate(
                        offset: const Offset(-2, 2),
                        child: const FittedBox(child: PlayingCard.faceDown()),
                      ),
                    if (card case final face?)
                      FittedBox(child: face)
                    else if (!occupied)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0x889FBEAB)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onTap == null
                    ? const Color(0xFFD3E7D8)
                    : const Color(0xFFFFDA96),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
