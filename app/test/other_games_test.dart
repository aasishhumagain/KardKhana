import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/cards/standard_cards.dart';
import 'package:kardkhana/lan/lan_room.dart';
import 'package:kardkhana/marriage/marriage_game.dart';
import 'package:kardkhana/marriage/marriage_room.dart';
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

  test('Teen Patti CPU stays blind when it can only afford the blind call', () {
    final game = TeenPattiGame(3, random: Random(0));
    for (final (seat, action) in const [
      (0, TeenPattiAction.raise),
      (1, TeenPattiAction.look),
      (1, TeenPattiAction.raise),
      (2, TeenPattiAction.call),
      (0, TeenPattiAction.call),
      (1, TeenPattiAction.call),
      (2, TeenPattiAction.pack),
    ]) {
      expect(game.act(seat, action), true);
    }
    expect(game.winners, [0]);
    expect(game.nextRound(), true);
    for (var raise = 0; raise < 3; raise++) {
      expect(game.act(game.turn, TeenPattiAction.raise), true);
    }

    expect(game.turn, 1);
    expect(game.callCost(1), 8);
    expect(game.pointsFor(1), 10);
    game.playCpuTurn();
    expect(game.noteFor(1), 'Chaal 8');
    expect(game.pointsFor(1), 2);
    expect(game.visibleHand(1, viewer: 1), isEmpty);
    expect(game.turn, 2);
  });

  test('Teen Patti seen player can only Show against another seen player', () {
    final game = TeenPattiGame(3, random: Random(6));
    expect(game.act(0, TeenPattiAction.look), true);
    expect(game.act(0, TeenPattiAction.call), true);
    expect(game.act(1, TeenPattiAction.call), true);
    expect(game.act(2, TeenPattiAction.pack), true);
    expect(game.actionsFor(0), isNot(contains(TeenPattiAction.show)));
    final pot = game.pot;
    expect(game.act(0, TeenPattiAction.show), false);
    expect(game.pot, pot);
    expect(game.act(0, TeenPattiAction.call), true);
    expect(game.actionsFor(1), contains(TeenPattiAction.show));
    expect(game.act(1, TeenPattiAction.show), true);
    expect(game.showdown, true);
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
    expect(isMarriageGroup([156, 157, 158], maal: 51), true);
  });

  test('Marriage counts ace and two as same-suit maal neighbors', () {
    const aceClubs = 12;
    const kingClubs = 11;
    const twoClubs = 0;
    const twoDiamonds = 13;
    expect(isMarriageWild(twoClubs, aceClubs), true);
    expect(isMarriageWild(aceClubs, twoClubs), true);
    expect(isMarriageWild(kingClubs, aceClubs), true);
    expect(isMarriageWild(twoDiamonds, aceClubs), false);
    expect(isMarriageGroup([30, 32, twoClubs], maal: aceClubs), true);
    expect(isMarriageGroup([kingClubs, aceClubs, twoClubs]), false);
  });

  test(
    'Marriage unlocks the maal with three groups and scores a declaration',
    () {
      expect(() => MarriageGame(6), throwsRangeError);
      final hand = _marriageWinningHand;
      final game = MarriageGame(5, random: _DealHand(hand));
      expect(game.handFor(0), unorderedEquals(hand));
      expect(game.maalFor(0), isNull);
      expect(game.showDublees(0), false);
      expect(game.draw(1, fromDiscard: false), false);
      expect(game.layGroup(0, [0, 0, 1]), false);
      for (var index = 0; index < hand.length; index += 3) {
        expect(game.layGroup(0, hand.sublist(index, index + 3)), true);
        expect(game.hasSeenMaal(0), index >= 6);
      }
      expect(game.maalFor(0), isNotNull);
      expect(game.maalFor(1), isNull);
      expect(game.winner, 0);
      expect(game.maalPointsFor(0), 2);
      expect(game.roundPointsFor(0), 48);
      expect(game.roundPointsFor(1), -12);
    },
  );

  test('Marriage Dublee uses exact pairs and commits to the eighth pair', () {
    expect(isMarriageDublee(0, 52), true);
    expect(isMarriageDublee(0, 0), false);
    expect(isMarriageDublee(0, 13), false);
    expect(isMarriageDublee(156, 157), false);
    final game = MarriageGame(
      2,
      random: _DealHand(_dubleeHand, stockTop: [74, 62]),
    );
    expect(game.availableDublees(0), 8);
    expect(game.showDublees(1), false);
    expect(game.showDublees(0), true);
    expect(game.showDublees(0), false);
    expect(game.dubleeCount(0), 7);
    expect(game.maalFor(0), 22);
    expect(game.maalFor(1), isNull);
    expect(game.handFor(0), hasLength(7));
    expect(game.layGroup(0, [21, 22, 23]), false);
    expect(game.layDublee(0, 20, 72), false);
    expect(game.canTakeDiscard(0), true);
    expect(game.draw(0, fromDiscard: true), true);
    expect(game.layDublee(0, 20, 72), false);
    expect(game.discard(0, 30), false);
    expect(game.layDublee(0, 10, 62), true);
    expect(game.complete, false);
    expect(game.discard(0, 30), true);
    expect(game.winner, 0);
    expect(game.maalPointsFor(0), 10);
    expect(game.roundPointsFor(0), 25);
    expect(game.roundPointsFor(1), -25);
    expect(game.logView.last.last, 'Won with eight Dublees');
    expect(game.nextRound(), true);
    expect(game.dubleeCount(0), 0);
    expect(game.maalFor(0), isNull);
    expect(game.pointsFor(0), 25);
  });

  test('Marriage CPU reveals Dublees and finishes by drawing stock', () {
    final game = MarriageGame(
      2,
      random: _DealHand(_dubleeHand, seat: 1, stockTop: [74, 51, 50, 62]),
    );
    expect(game.draw(0, fromDiscard: false), true);
    expect(game.discard(0, 50), true);
    game.playCpuTurn();
    expect(game.winner, 1);
    expect(game.dubleeCount(1), 8);
    expect(
      game.logView.where((entry) => entry[1] == 1).map((entry) => entry.last),
      contains('Drew a card from stock'),
    );
  });

  test(
    'Marriage sequence player cannot pick up a wild discard after seeing',
    () {
      final game = MarriageGame(
        2,
        random: _DealHand(_marriageWinningHand, stockTop: [74, 75]),
      );
      expect(game.canTakeDiscard(0), true);
      for (var group = 0; group < MarriageGame.groupsToReveal; group++) {
        final start = group * marriageGroupSize;
        expect(
          game.layGroup(
            0,
            _marriageWinningHand.sublist(start, start + marriageGroupSize),
          ),
          true,
        );
      }
      expect(game.maalFor(0), 22);
      expect(game.canTakeDiscard(0), false);
      expect(game.draw(0, fromDiscard: true), false);
      expect(game.topDiscard, 75);
      expect(game.draw(0, fromDiscard: false), true);
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

  test('five LAN players finish a Marriage hand with private maal', () async {
    await expectLater(
      hostMarriageRoom('Host', 6, port: 0),
      throwsA(isA<LanRoomException>()),
    );
    final host = await hostMarriageRoom(
      'Host',
      5,
      port: 0,
      random: _DealHand(_marriageWinningHand),
    );
    final rooms = [host];
    addTearDown(() {
      for (final room in rooms.reversed) {
        room.dispose();
      }
    });

    Future<LanRoom<MarriageGame>> join(String name) =>
        joinMarriageRoom('127.0.0.1', name, host.roomCode!, port: host.port!);
    for (var seat = 1; seat < 5; seat++) {
      rooms.add(await join('Guest $seat'));
    }
    await expectLater(join('Extra guest'), throwsA(isA<LanRoomException>()));
    for (final room in rooms.take(4)) {
      room.send('ready', {'ready': true});
    }
    await _waitForMarriage(
      host,
      () => _marriagePlayers(host).where((p) => p['ready'] == true).length == 4,
    );
    host.send('start');
    await _waitForMarriage(host, () => host.notice != null);
    expect(host.view['phase'], 'lobby');
    rooms.last.send('ready', {'ready': true});
    await _waitForMarriage(
      host,
      () => _marriagePlayers(host).every((p) => p['ready'] == true),
    );

    Future<void> act(
      int seat,
      String action, [
      Map<String, Object?> fields = const {},
    ]) async {
      final before = host.view['revision'];
      final room = rooms[seat];
      await _waitForMarriage(room, () => room.view['revision'] == before);
      room.send(action, fields);
      await _waitForMarriage(host, () => host.view['revision'] != before);
      final after = host.view['revision'];
      for (final room in rooms) {
        await _waitForMarriage(room, () => room.view['revision'] == after);
      }
    }

    await act(0, 'start');
    expect(host.view['hand'], unorderedEquals(_marriageWinningHand));
    expect(
      rooms.expand((room) => (room.view['hand'] as List).cast<int>()).toSet(),
      hasLength(5 * MarriageGame.handSize),
    );
    for (final room in rooms) {
      expect(room.view['hand'], hasLength(MarriageGame.handSize));
      expect(room.view['maal'], isNull);
      expect(
        _marriagePlayers(room).any(
          (player) => player.containsKey('hand') || player.containsKey('maal'),
        ),
        false,
      );
    }

    rooms[1].send('draw', {'fromDiscard': false});
    await _waitForMarriage(rooms[1], () => rooms[1].notice != null);
    host.send('lay', {
      'cards': [0, 0, 1],
    });
    await _waitForMarriage(host, () => host.notice != null);
    expect(_marriagePlayers(host).first['groups'], 0);
    expect(host.view['log'], isEmpty);

    Future<void> lay(int group) => act(0, 'lay', {
      'cards': _marriageWinningHand.sublist(
        group * marriageGroupSize,
        (group + 1) * marriageGroupSize,
      ),
    });
    for (var group = 0; group < MarriageGame.groupsToReveal; group++) {
      await lay(group);
      expect(
        host.view['maal'] != null,
        group + 1 == MarriageGame.groupsToReveal,
      );
      expect(
        rooms.skip(1).map((room) => room.view['maal']),
        everyElement(isNull),
      );
    }

    Future<int> drawStock(int seat) async {
      final hand = (rooms[seat].view['hand'] as List).toSet();
      final stock = host.view['stockCount'] as int;
      await act(seat, 'draw', {'fromDiscard': false});
      expect(host.view['stockCount'], stock - 1);
      return (rooms[seat].view['hand'] as List).toSet().difference(hand).single
          as int;
    }

    final drawn = await drawStock(0);
    expect((rooms[1].view['log'] as List).last, [
      1,
      0,
      'draw',
      'Drew a card from stock',
    ]);
    expect(
      rooms
          .skip(1)
          .every((room) => !(room.view['hand'] as List).contains(drawn)),
      true,
    );
    host.send('draw', {'fromDiscard': false});
    await _waitForMarriage(host, () => host.notice != null);
    await act(0, 'discard', {'card': drawn});
    expect(host.view['topDiscard'], drawn);
    expect((rooms[1].view['log'] as List).last, [
      1,
      0,
      'discard',
      'Discarded ${marriageCardLabel(drawn)}',
    ]);
    await act(1, 'draw', {'fromDiscard': true});
    expect(rooms[1].view['hand'], contains(drawn));
    expect((host.view['log'] as List).last, [
      1,
      1,
      'draw',
      'Picked up ${marriageCardLabel(drawn)} from the discard pile',
    ]);
    expect(rooms[1].view['discardable'], isNot(contains(drawn)));
    rooms[1].send('discard', {'card': drawn});
    await _waitForMarriage(rooms[1], () => rooms[1].notice != null);
    await act(1, 'discard', {
      'card': (rooms[1].view['discardable'] as List).first as int,
    });
    for (var seat = 2; seat < rooms.length; seat++) {
      final card = await drawStock(seat);
      await act(seat, 'discard', {'card': card});
    }

    for (
      var group = MarriageGame.groupsToReveal;
      group < MarriageGame.groupsToWin;
      group++
    ) {
      await lay(group);
    }
    for (final room in rooms) {
      expect(room.view['phase'], 'roundEnd');
      expect(room.view['winner'], 0);
      expect(room.view['log'], host.view['log']);
      expect(_marriagePlayers(room).map((p) => p['roundPoints']), [
        48,
        -12,
        -12,
        -12,
        -12,
      ]);
    }
    rooms.last.send('next');
    await _waitForMarriage(rooms.last, () => rooms.last.notice != null);
    await act(0, 'next');
    expect(host.view['round'], 2);
    expect(rooms.map((room) => room.view['maal']), everyElement(isNull));
  });

  test(
    'LAN validates Dublee actions and keeps unrevealed maal private',
    () async {
      final host = await hostMarriageRoom(
        'Host',
        2,
        port: 0,
        random: _DealHand(_dubleeHand, stockTop: [74, 62]),
      );
      addTearDown(host.dispose);
      final guest = await joinMarriageRoom(
        '127.0.0.1',
        'Guest',
        host.roomCode!,
        port: host.port!,
      );
      addTearDown(guest.dispose);

      Future<void> act(
        String action, [
        Map<String, Object?> fields = const {},
      ]) async {
        final before = host.view['revision'];
        host.send(action, fields);
        await _waitForMarriage(host, () => host.view['revision'] != before);
        await _waitForMarriage(
          guest,
          () => guest.view['revision'] == host.view['revision'],
        );
      }

      await act('ready', {'ready': true});
      guest.send('ready', {'ready': true});
      await _waitForMarriage(
        host,
        () => _marriagePlayers(host).every((player) => player['ready'] == true),
      );
      await act('start');
      expect(host.view['availableDublees'], 8);
      expect(host.view['maal'], isNull);
      await act('showDublees');
      expect(guest.view['maal'], isNull);
      expect(_marriagePlayers(guest).first['dublees'], 7);
      expect(host.view['canTakeDiscard'], true);
      await act('draw', {'fromDiscard': true});
      host.send('layDublee', {
        'cards': [20, 72],
      });
      await _waitForMarriage(host, () => host.notice != null);
      expect(host.view['discardable'], isEmpty);
      await act('layDublee', {
        'cards': [10, 62],
      });
      await act('discard', {'card': 30});
      expect(guest.view['winner'], 0);
      expect(_marriagePlayers(guest).map((player) => player['roundPoints']), [
        25,
        -25,
      ]);
      expect(_marriagePlayers(guest).first['maalPoints'], 10);
      expect(guest.view['maal'], isNull);
    },
  );
}

final _marriageWinningHand = [
  ...List.generate(12, (index) => index),
  ...List.generate(9, (index) => index + 13),
];

final _dubleeHand = [
  for (var face = 0; face < 7; face++) ...[face, face + standardDeckSize],
  10,
  20,
  72,
  21,
  22,
  23,
  30,
];

List<Map<String, dynamic>> _marriagePlayers(LanRoom<MarriageGame> room) =>
    (room.view['players'] as List).cast<Map<String, dynamic>>();

Future<void> _waitForMarriage(
  LanRoom<MarriageGame> room,
  bool Function() condition,
) {
  if (condition()) return Future.value();
  final done = Completer<void>();
  void listener() {
    if (!done.isCompleted && condition()) done.complete();
  }

  room.addListener(listener);
  return done.future
      .timeout(const Duration(seconds: 3))
      .whenComplete(() => room.removeListener(listener));
}

// List.shuffle swaps from its last index toward its first. Supply the swaps
// for one fixture deck with known cards in a player's hand and the stock.
class _DealHand implements Random {
  _DealHand(List<int> hand, {int seat = 0, List<int> stockTop = const []})
    : _target = _fixtureDeck(hand, seat, stockTop);

  static List<int> _fixtureDeck(List<int> hand, int seat, List<int> stockTop) {
    final specified = {
      for (var index = 0; index < hand.length; index++)
        marriageDeckSize - (seat + 1) * MarriageGame.handSize + index:
            hand[index],
      for (var index = 0; index < stockTop.length; index++)
        marriageDeckSize - 2 * MarriageGame.handSize - index - 1:
            stockTop[index],
    };
    final rest = List.generate(marriageDeckSize, (card) => card)
      ..removeWhere(specified.values.contains);
    var next = 0;
    return List.generate(
      marriageDeckSize,
      (index) => specified[index] ?? rest[next++],
    );
  }

  final List<int> _target;
  final _current = List.generate(marriageDeckSize, (card) => card);
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
