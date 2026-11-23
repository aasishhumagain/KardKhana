import 'dart:math';

import '../cards/standard_cards.dart';
import '../table_log.dart';

enum TeenPattiHand {
  highCard('High card'),
  pair('Pair'),
  color('Color'),
  sequence('Sequence'),
  pureSequence('Pure sequence'),
  trail('Trail');

  const TeenPattiHand(this.label);
  final String label;
}

enum TeenPattiAction { look, call, raise, pack, show }

({TeenPattiHand kind, int strength}) rankTeenPattiHand(List<int> hand) {
  final ranks = hand.map(cardRank).toList()..sort((a, b) => b.compareTo(a));
  final [high, middle, low] = ranks;
  final flush = hand.every((card) => cardSuit(card) == cardSuit(hand.first));
  // A-K-Q leads A-2-3 in this variant. K-Q-J follows both.
  final run = switch ((high, middle, low)) {
    (14, 13, 12) => 15,
    (14, 3, 2) => 14,
    _ when high - middle == 1 && middle - low == 1 => high,
    _ => 0,
  };
  final pairRank = high == middle || middle == low ? middle : 0;
  final kind = switch (ranks) {
    _ when high == low => TeenPattiHand.trail,
    _ when run > 0 && flush => TeenPattiHand.pureSequence,
    _ when run > 0 => TeenPattiHand.sequence,
    _ when flush => TeenPattiHand.color,
    _ when pairRank > 0 => TeenPattiHand.pair,
    _ => TeenPattiHand.highCard,
  };
  final kicker = high == pairRank ? low : high;
  final tieBreak = switch (kind) {
    TeenPattiHand.trail => high,
    TeenPattiHand.sequence || TeenPattiHand.pureSequence => run,
    TeenPattiHand.pair => pairRank * 16 + kicker,
    _ => high * 256 + middle * 16 + low,
  };
  return (kind: kind, strength: kind.index * 4096 + tieBreak);
}

class TeenPattiGame {
  TeenPattiGame(this.playerCount, {Random? random})
    : _random = random ?? Random.secure(),
      _points = List.filled(playerCount, startingPoints) {
    if (playerCount < minPlayers || playerCount > maxPlayers) {
      throw RangeError.range(
        playerCount,
        minPlayers,
        maxPlayers,
        'playerCount',
      );
    }
    _deal();
  }

  static const minPlayers = 3;
  static const maxPlayers = 5;
  static const startingPoints = 30;
  static const stakeCap = 8;
  static const boot = 1;
  static const _seenCostMultiplier = 2;

  final int playerCount;
  final Random _random;
  final _log = TableLog();
  final List<int> _points;
  late List<List<int>> _hands;
  late List<bool> _active;
  late List<bool> _seen;
  late List<String> _notes;
  int _first = 0;
  int _turn = 0;
  int _stake = 1;
  int _pot = 0;
  int _turns = 0;
  int _round = 0;
  List<int> _winners = [];
  bool _showdown = false;

  int get turn => _turn;
  int get round => _round;
  int get pot => _pot;
  int get stake => _stake;
  bool get complete => _winners.isNotEmpty;
  bool get canDeal =>
      complete && _points.where((points) => points >= boot).length >= 2;
  bool get showdown => _showdown;
  List<int> get winners => List.unmodifiable(_winners);
  List<List<Object>> get logView => _log.toView();

  int pointsFor(int seat) => _points[seat];
  String noteFor(int seat) => _notes[seat];
  int callCost(int seat) => _cost(seat, _stake);
  int raiseCost(int seat) => _cost(seat, min(_stake * 2, stakeCap));

  List<int> visibleHand(int seat, {int? viewer = 0}) =>
      (seat == viewer && _seen[seat]) || (_showdown && _active[seat])
      ? List.unmodifiable(_hands[seat])
      : const [];

  Set<TeenPattiAction> actionsFor(int seat) {
    if (complete || _turn != seat) return const {};
    return {
      if (!_seen[seat]) TeenPattiAction.look,
      if (_points[seat] >= callCost(seat)) TeenPattiAction.call,
      if (_stake < stakeCap && _points[seat] >= raiseCost(seat))
        TeenPattiAction.raise,
      TeenPattiAction.pack,
      if (_active.where((active) => active).length == 2 &&
          _points[seat] >= callCost(seat))
        TeenPattiAction.show,
    };
  }

  bool act(int seat, TeenPattiAction action) {
    if (!actionsFor(seat).contains(action)) return false;
    if (action == TeenPattiAction.look) {
      _seen[seat] = true;
      _notes[seat] = 'Seen';
      _log.add(_round, seat, TableMove.decision, 'Looked at their cards');
      return true;
    }
    switch (action) {
      case TeenPattiAction.pack:
        _active[seat] = false;
        _notes[seat] = 'Packed';
        _log.add(_round, seat, TableMove.decision, 'Packed');
      case TeenPattiAction.raise:
        _stake = min(_stake * 2, stakeCap);
        _pay(seat, 'Raise');
      case TeenPattiAction.call:
        _pay(seat, 'Chaal');
      case TeenPattiAction.show:
        _pay(seat, 'Show');
        _finish(show: true);
        return true;
      case TeenPattiAction.look:
        throw StateError('Look is handled before the turn advances.');
    }
    _turns++;
    final remaining = _active.where((active) => active).length;
    if (remaining == 1 || _turns == playerCount * 2) {
      _finish(show: remaining > 1);
    } else {
      _turn = _nextActive(seat);
    }
    return true;
  }

  void playCpuTurn() {
    final seat = _turn;
    if (seat == 0 || complete) return;
    if (!_seen[seat] &&
        (_turns >= playerCount || _stake > 1) &&
        _points[seat] >= _stake * _seenCostMultiplier) {
      act(seat, TeenPattiAction.look);
    }
    final actions = actionsFor(seat);
    final rank = _seen[seat] ? rankTeenPattiHand(_hands[seat]).kind : null;
    final strong = rank != null && rank.index >= TeenPattiHand.sequence.index;
    final action = switch (actions) {
      _ when !actions.contains(TeenPattiAction.call) => TeenPattiAction.pack,
      _ when rank == TeenPattiHand.highCard && callCost(seat) >= 4 =>
        TeenPattiAction.pack,
      _ when strong && actions.contains(TeenPattiAction.show) =>
        TeenPattiAction.show,
      _ when strong && actions.contains(TeenPattiAction.raise) =>
        TeenPattiAction.raise,
      _ => TeenPattiAction.call,
    };
    act(seat, action);
  }

  bool nextRound() {
    if (!canDeal) return false;
    _first = (_first + 1) % playerCount;
    _deal();
    return true;
  }

  int _cost(int seat, int stake) =>
      _seen[seat] ? _seenCostMultiplier * stake : stake;

  void _pay(int seat, String label) {
    final paid = callCost(seat);
    _points[seat] -= paid;
    _pot += paid;
    _notes[seat] = '$label $paid';
    _log.add(_round, seat, TableMove.decision, '$label · $paid points');
  }

  void _deal() {
    final deck = List.generate(standardDeckSize, (card) => card)
      ..shuffle(_random);
    _active = _points.map((points) => points >= boot).toList();
    _hands = List.generate(
      playerCount,
      (seat) => _active[seat] ? List.generate(3, (_) => deck.removeLast()) : [],
    );
    _seen = List.filled(playerCount, false);
    _notes = _active
        .map((active) => active ? 'Blind' : 'Out of points')
        .toList();
    _stake = 1;
    _pot = 0;
    _turns = 0;
    _winners = [];
    _showdown = false;
    _round++;
    for (var seat = 0; seat < playerCount; seat++) {
      if (_active[seat]) {
        _points[seat] -= boot;
        _pot += boot;
      }
    }
    _turn = _nextActive((_first - 1) % playerCount);
  }

  int _nextActive(int seat) {
    do {
      seat = (seat + 1) % playerCount;
    } while (!_active[seat]);
    return seat;
  }

  void _finish({required bool show}) {
    _showdown = show;
    final active = [
      for (var offset = 0; offset < playerCount; offset++)
        if (_active[(_first + offset) % playerCount])
          (_first + offset) % playerCount,
    ];
    if (!show) {
      _winners = active;
    } else {
      final strengths = active
          .map((seat) => rankTeenPattiHand(_hands[seat]).strength)
          .toList();
      final best = strengths.reduce(max);
      _winners = [
        for (var index = 0; index < active.length; index++)
          if (strengths[index] == best) active[index],
      ];
    }
    final share = _pot ~/ _winners.length;
    final remainder = _pot % _winners.length;
    for (var index = 0; index < _winners.length; index++) {
      _points[_winners[index]] += share + (index < remainder ? 1 : 0);
      _log.add(
        _round,
        _winners[index],
        TableMove.result,
        _winners.length == 1 ? 'Won the hand' : 'Shared the pot',
      );
    }
  }
}
