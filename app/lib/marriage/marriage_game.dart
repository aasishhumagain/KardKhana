import 'dart:math';

import '../cards/standard_cards.dart';
import '../table_log.dart';

const _printedJokerStart = standardDeckSize * 3;
const marriageDeckSize = _printedJokerStart + 3;
const marriageGroupSize = 3;
final _runs = [
  [14, 2, 3],
  for (var low = 2; low <= 12; low++) [low, low + 1, low + 2],
];

int marriageFace(int card) => card % standardDeckSize;
bool isPrintedJoker(int card) => card >= _printedJokerStart;
String marriageCardLabel(int card) =>
    isPrintedJoker(card) ? 'Joker' : cardLabel(marriageFace(card));

bool isMarriageWild(int card, int maal) {
  if (isPrintedJoker(card)) return true;
  final face = marriageFace(card);
  final distance = (cardRank(face) - cardRank(maal)).abs();
  // Maal neighbors wrap around between ace and two.
  return distance == 0 ||
      (cardSuit(face) == cardSuit(maal) && (distance == 1 || distance == 12));
}

bool isMarriageGroup(List<int> cards, {int? maal}) {
  if (cards.length != marriageGroupSize ||
      cards.toSet().length != marriageGroupSize ||
      cards.any((card) => card < 0 || card >= marriageDeckSize)) {
    return false;
  }

  final hasPrinted = cards.any(isPrintedJoker);
  if (!hasPrinted) {
    final faces = cards.map(marriageFace).toList();
    if (faces.every((face) => face == faces.first) || _isRun(faces)) {
      return true;
    }
    if (maal != null && _isTrial(faces)) return true;
  }
  if (maal == null) return false;

  final natural = [
    for (final card in cards)
      if (!isMarriageWild(card, maal)) marriageFace(card),
  ];
  // A wildcard replaces a missing card in a run or trial. A tunnella
  // always requires three actual copies of the same face.
  return natural.isNotEmpty && (_isRun(natural) || _isTrial(natural));
}

bool _isRun(List<int> faces) {
  final suit = cardSuit(faces.first);
  if (faces.any((face) => cardSuit(face) != suit)) return false;
  final ranks = faces.map(cardRank).toSet();
  return ranks.length == faces.length &&
      _runs.any((run) => ranks.every(run.contains));
}

bool _isTrial(List<int> faces) =>
    faces.every((face) => cardRank(face) == cardRank(faces.first)) &&
    faces.map(cardSuit).toSet().length == faces.length;

class MarriageGame {
  MarriageGame(this.playerCount, {Random? random})
    : _random = random ?? Random.secure(),
      _points = List.filled(playerCount, 0) {
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

  static const minPlayers = 2;
  static const maxPlayers = 5;
  static const handSize = 21;
  static const groupsToReveal = 3;
  static const groupsToWin = handSize ~/ marriageGroupSize;

  final int playerCount;
  final Random _random;
  final _log = TableLog();
  final List<int> _points;
  late List<List<int>> _hands;
  late List<List<List<int>>> _groups;
  late List<int> _stock;
  late List<int> _discard;
  late List<String> _notes;
  late List<int> _roundPoints;
  late int _maal;
  int _first = 0;
  int _turn = 0;
  int _round = 0;
  int? _winner;
  int? _pickedDiscard;
  bool _complete = false;
  bool _hasDrawn = false;

  int get round => _round;
  int get turn => _turn;
  int? get winner => _winner;
  int? get topDiscard => _discard.isEmpty ? null : _discard.last;
  int get stockCount => _stock.length;
  bool get complete => _complete;
  bool get hasDrawn => _hasDrawn;
  List<List<Object>> get logView => _log.toView();

  int groupCount(int seat) => _groups[seat].length;
  bool hasSeenMaal(int seat) => groupCount(seat) >= groupsToReveal;
  int? maalFor(int seat) => hasSeenMaal(seat) ? _maal : null;
  int pointsFor(int seat) => _points[seat];
  int roundPointsFor(int seat) => _roundPoints[seat];
  String noteFor(int seat) => _notes[seat];
  List<int> handFor(int seat) => List.unmodifiable(_hands[seat]);

  bool draw(int seat, {required bool fromDiscard}) {
    if (_complete || seat != _turn || _hasDrawn) return false;
    final pile = fromDiscard ? _discard : _stock;
    if (pile.isEmpty) return false;
    final card = pile.removeLast();
    _hands[seat].add(card);
    _sortHand(_hands[seat]);
    _pickedDiscard = fromDiscard ? card : null;
    _hasDrawn = true;
    _notes[seat] = fromDiscard ? 'Picked up the discard' : 'Drew from stock';
    _log.add(
      _round,
      seat,
      TableMove.draw,
      fromDiscard
          ? 'Picked up ${marriageCardLabel(card)} from the discard pile'
          : 'Drew a card from stock',
    );
    return true;
  }

  bool layGroup(int seat, List<int> cards) {
    if (_complete ||
        seat != _turn ||
        !cards.every(_hands[seat].contains) ||
        !isMarriageGroup(cards, maal: maalFor(seat))) {
      return false;
    }
    for (final card in cards) {
      _hands[seat].remove(card);
    }
    _groups[seat].add(List.of(cards));
    _notes[seat] = 'Laid group ${groupCount(seat)}';
    _log.add(_round, seat, TableMove.decision, _notes[seat]);
    if (groupCount(seat) == groupsToWin && !_hasDrawn) _finish(seat);
    return true;
  }

  bool canDiscard(int seat, int card) =>
      !_complete &&
      seat == _turn &&
      _hasDrawn &&
      _hands[seat].contains(card) &&
      (card != _pickedDiscard || _hands[seat].length == 1);

  bool discard(int seat, int card) {
    if (!canDiscard(seat, card)) return false;
    _hands[seat].remove(card);
    _discard.add(card);
    _notes[seat] = 'Discarded ${marriageCardLabel(card)}';
    _log.add(_round, seat, TableMove.discard, _notes[seat]);
    if (groupCount(seat) == groupsToWin) {
      _finish(seat);
    } else if (_stock.isEmpty) {
      _complete = true;
    } else {
      _turn = (seat + 1) % playerCount;
      _hasDrawn = false;
      _pickedDiscard = null;
    }
    return true;
  }

  bool nextRound() {
    if (!_complete) return false;
    _first = (_first + 1) % playerCount;
    _deal();
    return true;
  }

  void playCpuTurn() {
    final seat = _turn;
    if (seat == 0 || _complete) return;
    _layCpuGroups(seat);
    if (_complete) return;
    final top = topDiscard;
    final wantsDiscard =
        top != null &&
        _findGroup([..._hands[seat], top], maalFor(seat), requiredCard: top) !=
            null;
    draw(seat, fromDiscard: wantsDiscard);
    _layCpuGroups(seat);
    if (_complete) return;
    final discardable = _hands[seat].where((card) => canDiscard(seat, card));
    final card = discardable.reduce(
      (a, b) => _keepValue(a, seat) <= _keepValue(b, seat) ? a : b,
    );
    discard(seat, card);
  }

  void _layCpuGroups(int seat) {
    while (!_complete) {
      final group = _findGroup(_hands[seat], maalFor(seat));
      if (group == null) return;
      layGroup(seat, group);
    }
  }

  int _keepValue(int card, int seat) {
    final maal = maalFor(seat);
    if (maal != null && isMarriageWild(card, maal)) return 100;
    if (isPrintedJoker(card)) return 1;
    final face = marriageFace(card);
    final rank = cardRank(face);
    return _hands[seat].fold(0, (value, other) {
      if (other == card || isPrintedJoker(other)) return value;
      final otherFace = marriageFace(other);
      if (face == otherFace) return value + 3;
      if (cardSuit(face) == cardSuit(otherFace) &&
          _runs.any(
            (run) => run.contains(rank) && run.contains(cardRank(otherFace)),
          )) {
        return value + 2;
      }
      return value + (maal != null && cardRank(otherFace) == rank ? 2 : 0);
    });
  }

  void _deal() {
    _stock = List.generate(marriageDeckSize, (card) => card)..shuffle(_random);
    _hands = List.generate(playerCount, (_) {
      final hand = List.generate(handSize, (_) => _stock.removeLast());
      _sortHand(hand);
      return hand;
    });
    _maal = marriageFace(
      _stock.removeAt(_stock.lastIndexWhere((card) => !isPrintedJoker(card))),
    );
    _discard = [_stock.removeLast()];
    _groups = List.generate(playerCount, (_) => []);
    _roundPoints = List.filled(playerCount, 0);
    _notes = List.filled(playerCount, 'Waiting');
    _turn = _first;
    _round++;
    _winner = null;
    _pickedDiscard = null;
    _hasDrawn = false;
    _complete = false;
  }

  void _finish(int seat) {
    _winner = seat;
    _complete = true;
    _log.add(_round, seat, TableMove.result, 'Won the hand');
    for (var other = 0; other < playerCount; other++) {
      if (other == seat) continue;
      final paid = hasSeenMaal(other) ? 3 : 10;
      _roundPoints[other] = -paid;
      _roundPoints[seat] += paid;
    }
    for (var player = 0; player < playerCount; player++) {
      _points[player] += _roundPoints[player];
    }
  }
}

void _sortHand(List<int> hand) {
  int order(int card) =>
      isPrintedJoker(card) ? standardDeckSize : marriageFace(card);
  hand.sort((a, b) => order(a).compareTo(order(b)));
}

List<int>? _findGroup(List<int> hand, int? maal, {int? requiredCard}) {
  List<int>? withWild;
  for (var a = 0; a < hand.length - 2; a++) {
    for (var b = a + 1; b < hand.length - 1; b++) {
      for (var c = b + 1; c < hand.length; c++) {
        final group = [hand[a], hand[b], hand[c]];
        if (requiredCard != null && !group.contains(requiredCard)) continue;
        if (!isMarriageGroup(group, maal: maal)) continue;
        if (maal == null || !group.any((card) => isMarriageWild(card, maal))) {
          return group;
        }
        withWild ??= group;
      }
    }
  }
  return withWild;
}
