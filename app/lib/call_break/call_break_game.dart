import 'dart:math';

import '../cards/standard_cards.dart';
import '../table_log.dart';

export '../cards/standard_cards.dart'
    show CardSuit, cardLabel, cardRank, cardSuit;

enum CallBreakPhase { bidding, playing, roundEnd, matchEnd }

class PlayedCard {
  const PlayedCard(this.seat, this.card);

  final int seat;
  final int card;
}

class CallBreakGame {
  CallBreakGame({Random? random}) : _random = random ?? Random.secure() {
    _firstSeat = _random.nextInt(playerCount);
    _deal();
  }

  static const playerCount = 4;
  static const roundsPerMatch = 5;
  static const cardsPerHand = 13;

  final Random _random;
  final _scores = List.filled(playerCount, 0);
  final _roundScores = List.filled(playerCount, 0);
  final _trick = <PlayedCard>[];
  final _log = TableLog();

  late List<List<int>> _hands;
  late List<int?> _bids;
  late List<int> _tricksWon;
  late int _firstSeat;
  late int _turn;
  late CallBreakPhase _phase;
  List<PlayedCard> _lastTrick = [];
  int? _lastWinner;
  int _round = 0;

  CallBreakPhase get phase => _phase;
  int get round => _round;
  int get turn => _turn;
  int? get lastWinner => _lastWinner;
  List<int?> get bids => List.unmodifiable(_bids);
  List<int> get tricksWon => List.unmodifiable(_tricksWon);
  List<int> get scores => List.unmodifiable(_scores);
  List<int> get roundScores => List.unmodifiable(_roundScores);
  List<PlayedCard> get trick => List.unmodifiable(_trick);
  List<PlayedCard> get lastTrick => List.unmodifiable(_lastTrick);
  List<List<Object>> get logView => _log.toView();

  List<int> handFor(int seat) => List.unmodifiable(_hands[seat]);

  List<int> legalCardsFor(int seat) {
    if (_phase != CallBreakPhase.playing || seat != _turn) return const [];
    return legalPlays(_hands[seat], _trick);
  }

  bool bid(int seat, int value) {
    if (_phase != CallBreakPhase.bidding ||
        seat != _turn ||
        value < 1 ||
        value > cardsPerHand) {
      return false;
    }
    _bids[seat] = value;
    _log.add(_round, seat, TableMove.decision, 'Bid $value');
    _turn = (seat + 1) % playerCount;
    if (_turn == _firstSeat) _phase = CallBreakPhase.playing;
    return true;
  }

  bool play(int seat, int card) {
    if (!legalCardsFor(seat).contains(card)) return false;

    _hands[seat].remove(card);
    _trick.add(PlayedCard(seat, card));
    _log.add(_round, seat, TableMove.play, 'Played ${cardLabel(card)}');
    if (_trick.length < playerCount) {
      _turn = (seat + 1) % playerCount;
      return true;
    }

    final winner = _winningPlay(_trick).seat;
    _tricksWon[winner]++;
    _log.add(_round, winner, TableMove.result, 'Won the trick');
    _lastTrick = List.of(_trick);
    _lastWinner = winner;
    _trick.clear();
    _turn = winner;

    if (_hands.every((hand) => hand.isEmpty)) {
      for (var seat = 0; seat < playerCount; seat++) {
        final earned = scoreFor(_bids[seat]!, _tricksWon[seat]);
        _roundScores[seat] = earned;
        _scores[seat] += earned;
      }
      _phase = _round == roundsPerMatch
          ? CallBreakPhase.matchEnd
          : CallBreakPhase.roundEnd;
    }
    return true;
  }

  bool nextRound() {
    if (_phase != CallBreakPhase.roundEnd) return false;
    _firstSeat = (_firstSeat + 1) % playerCount;
    _deal();
    return true;
  }

  void _deal() {
    final deck = List.generate(playerCount * cardsPerHand, (index) => index)
      ..shuffle(_random);
    _hands = List.generate(
      playerCount,
      (seat) =>
          deck.sublist(seat * cardsPerHand, (seat + 1) * cardsPerHand)..sort(),
    );
    _bids = List.filled(playerCount, null);
    _tricksWon = List.filled(playerCount, 0);
    _roundScores.fillRange(0, playerCount, 0);
    _lastTrick = [];
    _lastWinner = null;
    _turn = _firstSeat;
    _round++;
    _phase = CallBreakPhase.bidding;
  }

  // Scores are stored in tenths to keep round totals exact.
  static int scoreFor(int bid, int tricks) =>
      tricks < bid ? -10 * bid : 10 * bid + tricks - bid;

  static List<int> legalPlays(List<int> hand, List<PlayedCard> trick) {
    if (trick.isEmpty) return List.of(hand);

    final lead = cardSuit(trick.first.card);
    final follow = hand.where((card) => cardSuit(card) == lead).toList();
    final trumps = hand.where((card) => cardSuit(card) == CardSuit.spades);
    final eligible = follow.isNotEmpty
        ? follow
        : trumps.isNotEmpty
        ? trumps
        : hand;
    final winningCard = _winningPlay(trick).card;
    final higher = eligible.where((card) => _beats(card, winningCard)).toList();
    return higher.isEmpty ? eligible.toList() : higher;
  }

  static PlayedCard _winningPlay(List<PlayedCard> trick) {
    return trick.reduce(
      (winner, play) => _beats(play.card, winner.card) ? play : winner,
    );
  }

  static bool _beats(int card, int currentWinner) {
    final suit = cardSuit(card);
    final winningSuit = cardSuit(currentWinner);
    return suit == winningSuit
        ? cardRank(card) > cardRank(currentWinner)
        : suit == CardSuit.spades;
  }
}
