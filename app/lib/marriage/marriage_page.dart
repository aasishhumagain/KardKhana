import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../cards/standard_cards.dart';
import '../offline/offline_table_widgets.dart';
import 'marriage_game.dart';

class MarriagePage extends StatefulWidget {
  const MarriagePage({required this.playerCount, super.key});

  final int playerCount;

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
    _game = MarriageGame(widget.playerCount);
  }

  @override
  void dispose() {
    _cpu?.cancel();
    super.dispose();
  }

  void _scheduleCpu() {
    _cpu?.cancel();
    if (_game.complete || _game.turn == 0) return;
    _cpu = Timer(const Duration(milliseconds: 450), () {
      setState(_game.playCpuTurn);
      _scheduleCpu();
    });
  }

  void _apply(bool accepted, {String? error}) {
    setState(() {
      _message = accepted ? null : error;
      if (accepted) _selected.clear();
    });
    if (accepted) _scheduleCpu();
  }

  void _toggleCard(int card) {
    setState(() {
      _message = null;
      if (_selected.remove(card)) return;
      if (_selected.length == 3) {
        _message = 'Deselect a card before choosing another.';
      } else {
        _selected.add(card);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yourTurn = !_game.complete && _game.turn == 0;
    final picked = _selected.length == 1 ? _selected.single : null;
    final maal = _game.maalFor(0);
    final discard = _game.topDiscard;
    final winner = _game.winner;
    final status = _game.complete
        ? winner == null
              ? 'Stock exhausted · Draw'
              : winner == 0
              ? 'You win the hand'
              : '${offlineSeatName(winner)} wins the hand'
        : yourTurn
        ? _game.hasDrawn
              ? 'Lay a group or discard one card'
              : 'Lay a group or draw a card'
        : '${offlineSeatName(_game.turn)} is playing';

    return Scaffold(
      appBar: AppBar(title: const Text('Marriage · Offline')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hand ${_game.round} · $status',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OfflineSeats(
              activeSeat: _game.complete ? null : _game.turn,
              status: [
                for (var seat = 0; seat < widget.playerCount; seat++)
                  _game.complete
                      ? '${_game.roundPointsFor(seat)} this hand · ${_game.pointsFor(seat)} total'
                      : '${_game.groupCount(seat)}/7 groups · ${_game.noteFor(seat)}',
              ],
            ),
            const SizedBox(height: 8),
            if (_game.complete)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () => _apply(_game.nextRound()),
                  child: const Text('Next hand'),
                ),
              )
            else ...[
              Text(
                maal == null
                    ? 'Lay three pure runs or tunnellas to reveal the maal.'
                    : 'Maal · ${cardLabel(maal)}   Wild cards may complete runs and trials.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: yourTurn && !_game.hasDrawn
                        ? () => _apply(_game.draw(0, fromDiscard: false))
                        : null,
                    child: Text('Draw stock · ${_game.stockCount}'),
                  ),
                  OutlinedButton(
                    onPressed: yourTurn && !_game.hasDrawn && discard != null
                        ? () => _apply(_game.draw(0, fromDiscard: true))
                        : null,
                    child: Text(
                      discard == null
                          ? 'Discard pile empty'
                          : 'Take ${marriageCardLabel(discard)}',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: yourTurn && _selected.length == 3
                        ? () => _apply(
                            _game.layGroup(0, _selected.toList()),
                            error: maal == null
                                ? 'That group needs three consecutive cards of one suit or three identical cards.'
                                : 'Those cards do not form a legal run, tunnella, or trial.',
                          )
                        : null,
                    child: const Text('Lay group'),
                  ),
                  OutlinedButton(
                    onPressed: picked != null && _game.canDiscard(0, picked)
                        ? () => _apply(_game.discard(0, picked))
                        : null,
                    child: const Text('Discard selected'),
                  ),
                ],
              ),
              if (_message case final message?)
                Text(message, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final card in _game.handFor(0))
                    OfflineCard(
                      maal != null && isMarriageWild(card, maal)
                          ? '${marriageCardLabel(card)} · Wild'
                          : marriageCardLabel(card),
                      red:
                          !isPrintedJoker(card) &&
                          (cardSuit(marriageFace(card)) == CardSuit.hearts ||
                              cardSuit(marriageFace(card)) ==
                                  CardSuit.diamonds),
                      selected: _selected.contains(card),
                      onPressed: yourTurn ? () => _toggleCard(card) : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
