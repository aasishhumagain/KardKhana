import 'dart:async';
import 'dart:math';

import 'call_break_game.dart';
import 'call_break_session.dart';

class OfflineCallBreak extends CallBreakSession {
  OfflineCallBreak({
    Random? random,
    this._cpuDelay = const Duration(milliseconds: 350),
  }) : _random = random ?? Random.secure() {
    _dealMatch();
    _scheduleCpuTurn();
  }

  static const _humanSeat = 0;
  static final _seats = List.generate(
    CallBreakGame.playerCount,
    (seat) => (name: seat == _humanSeat ? 'Player' : 'CPU $seat', ready: true),
  );

  final Random _random;
  final Duration _cpuDelay;
  late CallBreakGame _game;
  Timer? _cpuTimer;

  @override
  Map<String, dynamic> get view => {
    ...callBreakTableView(_game, _seats),
    ...callBreakSeatView(_game, _humanSeat),
  };

  @override
  void send(String action, [Map<String, Object?> fields = const {}]) {
    final bid = fields['bid'];
    final card = fields['card'];
    final accepted = switch (action) {
      'bid' when bid is int => _game.bid(_humanSeat, bid),
      'play' when card is int => _game.play(_humanSeat, card),
      'next' => _game.nextRound(),
      'rematch' when _game.phase == CallBreakPhase.matchEnd => _dealMatch(),
      _ => false,
    };
    if (accepted) _tableChanged();
  }

  bool _dealMatch() {
    _game = CallBreakGame(random: _random);
    return true;
  }

  void _tableChanged() {
    _scheduleCpuTurn();
    notifyListeners();
  }

  void _scheduleCpuTurn() {
    _cpuTimer?.cancel();
    final seat = _game.turn;
    final phase = _game.phase;
    if (seat == _humanSeat ||
        (phase != CallBreakPhase.bidding && phase != CallBreakPhase.playing)) {
      return;
    }

    _cpuTimer = Timer(_cpuDelay, () {
      if (phase == CallBreakPhase.bidding) {
        _game.bid(seat, _estimateBid(_game.handFor(seat)));
      } else {
        final legal = _game.legalCardsFor(seat);
        final card = _chooseCard(legal, leading: _game.trick.isEmpty);
        _game.play(seat, card);
      }
      _tableChanged();
    });
  }

  @override
  void dispose() {
    _cpuTimer?.cancel();
    super.dispose();
  }
}

int _estimateBid(List<int> hand) {
  var expectedTricks = 0.0;
  for (final card in hand) {
    final rank = cardRank(card);
    if (cardSuit(card) == CardSuit.spades) {
      expectedTricks += rank >= 11 ? 0.9 : 0.35;
    } else if (rank == 14) {
      expectedTricks += 0.8;
    } else if (rank == 13) {
      expectedTricks += 0.25;
    }
  }
  return max(1, min(CallBreakGame.cardsPerHand, expectedTricks.round()));
}

int _chooseCard(List<int> legal, {required bool leading}) {
  // Cash a non-trump ace when leading. Otherwise spend the weakest legal card.
  if (leading) {
    for (final card in legal) {
      if (cardSuit(card) != CardSuit.spades && cardRank(card) == 14) {
        return card;
      }
    }
  }
  return legal.reduce((a, b) => _cardCost(a) <= _cardCost(b) ? a : b);
}

int _cardCost(int card) =>
    cardRank(card) + (cardSuit(card) == CardSuit.spades ? 13 : 0);
