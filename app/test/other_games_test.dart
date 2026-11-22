import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/cards/standard_cards.dart';
import 'package:kardkhana/marriage/marriage_game.dart';
import 'package:kardkhana/teen_patti/teen_patti_game.dart';

void main() {
  test('Teen Patti ranks trail, sequences, color, pair and high card', () {
    int value(List<int> cards) => rankTeenPattiHand(cards).strength;

    expect(value([12, 25, 38]), greaterThan(value([12, 11, 10])));
    expect(value([12, 11, 10]), greaterThan(value([12, 0, 1])));
    expect(value([12, 0, 1]), greaterThan(value([11, 10, 9])));
    expect(value([11, 10, 9]), greaterThan(value([11, 23, 35])));
    expect(value([11, 23, 35]), greaterThan(value([3, 7, 10])));
    expect(value([3, 7, 10]), greaterThan(value([12, 25, 1])));
    expect(value([12, 25, 1]), greaterThan(value([12, 23, 28])));
    expect(value([12, 25, 3]), greaterThan(value([12, 25, 1])));
    expect(value([12, 25, 3]), value([38, 51, 16]));
  });

  test('Teen Patti plays a capped virtual-points hand with four CPUs', () {
    expect(() => TeenPattiGame(6), throwsRangeError);
    final game = TeenPattiGame(5, random: Random(31));
    expect(game.pot, 5);
    expect(game.visibleHand(0), isEmpty);
    expect(game.actionsFor(1), isEmpty);
    expect(game.act(0, TeenPattiAction.show), false);
    expect(game.act(0, TeenPattiAction.look), true);
    expect(game.visibleHand(0), hasLength(3));
    expect(game.visibleHand(1), isEmpty);
    expect(game.callCost(0), 2);
    expect(game.act(0, TeenPattiAction.raise), true);
    expect(game.stake, 2);

    for (var step = 0; step < 10 && !game.complete; step++) {
      if (game.turn == 0) {
        final actions = game.actionsFor(0);
        expect(
          game.act(
            0,
            actions.contains(TeenPattiAction.call)
                ? TeenPattiAction.call
                : TeenPattiAction.pack,
          ),
          true,
        );
      } else {
        game.playCpuTurn();
      }
    }
    expect(game.complete, true);
    expect(game.winners, isNotEmpty);
    expect(
      Iterable<int>.generate(5)
          .fold(0, (total, seat) => total + game.pointsFor(seat)),
      5 * TeenPattiGame.startingPoints,
    );
    expect(game.nextRound(), true);
    expect(game.round, 2);
  });

  test('Marriage distinguishes pure runs, tunnellas, trials and wildcards', () {
    expect(isMarriageGroup([0, 1, 2]), true);
    expect(isMarriageGroup([12, 0, 1]), true);
    expect(isMarriageGroup([0, standardDeckSize, standardDeckSize * 2]), true);
    expect(isMarriageGroup([0, 0, 0]), false);
    expect(isMarriageGroup([0, 13, 26]), false);
    expect(isMarriageGroup([0, 13, 26], maal: 51), true);
    expect(isMarriageGroup([0, 2, 156]), false);
    expect(isMarriageGroup([0, 2, 156], maal: 51), true);
    expect(isMarriageGroup([0, 52, 156], maal: 51), false);
  });

  test(
    'Marriage unlocks the maal with three groups and scores a declaration',
    () {
      expect(() => MarriageGame(6), throwsRangeError);
      final hand = [
        ...List.generate(12, (index) => index),
        ...List.generate(9, (index) => index + 13),
      ];
      final game = MarriageGame(5, random: _DealHand(hand));
      expect(game.handFor(0), unorderedEquals(hand));
      expect(game.maalFor(0), isNull);
      expect(game.draw(1, fromDiscard: false), false);
      expect(game.layGroup(0, [0, 0, 1]), false);
      for (var index = 0; index < hand.length; index += 3) {
        expect(game.layGroup(0, hand.sublist(index, index + 3)), true);
        expect(game.hasSeenMaal(0), index >= 6);
      }
      expect(game.maalFor(0), isNotNull);
      expect(game.maalFor(1), isNull);
      expect(game.winner, 0);
      expect(game.roundPointsFor(0), 40);
      expect(game.roundPointsFor(1), -10);
    },
  );

  test('Marriage enforces draw then discard and advances CPU turns', () {
    final game = MarriageGame(2, random: Random(53));
    expect(game.handFor(0), hasLength(21));
    final card = game.handFor(0).first;
    expect(game.discard(0, card), false);
    expect(game.draw(0, fromDiscard: false), true);
    expect(game.draw(0, fromDiscard: false), false);
    expect(game.handFor(0), hasLength(22));
    expect(game.discard(0, card), true);
    expect(game.handFor(0), hasLength(21));
    expect(game.turn, 1);
    game.playCpuTurn();
    expect(game.complete || game.turn == 0, true);

    for (var turn = 0; turn < 300 && !game.complete; turn++) {
      if (game.turn == 0) {
        expect(game.draw(0, fromDiscard: false), true);
        expect(game.discard(0, game.handFor(0).first), true);
      } else {
        game.playCpuTurn();
      }
    }
    expect(game.complete, true);
    expect(game.pointsFor(0) + game.pointsFor(1), 0);
    expect(game.nextRound(), true);
    expect(game.round, 2);
  });
}

// List.shuffle swaps from its last index toward its first. Supply the swaps
// for one fixture deck so the player receives seven known groups.
class _DealHand implements Random {
  _DealHand(List<int> hand)
    : _target = [
        for (var card = 0; card < 159; card++)
          if (!hand.contains(card)) card,
        ...hand,
      ];

  final List<int> _target;
  final _current = List.generate(159, (card) => card);
  final _random = Random(7);
  bool _fixture = true;

  @override
  int nextInt(int max) {
    if (!_fixture) return _random.nextInt(max);
    final last = max - 1;
    final swap = _current.indexOf(_target[last]);
    final card = _current[swap];
    _current[swap] = _current[last];
    _current[last] = card;
    if (max <= 2) _fixture = false;
    return swap;
  }

  @override
  bool nextBool() => _random.nextBool();

  @override
  double nextDouble() => _random.nextDouble();
}
