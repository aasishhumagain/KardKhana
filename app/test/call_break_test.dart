import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/call_break/call_break_game.dart';
import 'package:kardkhana/call_break/call_break_room.dart';

void main() {
  test('players follow suit, trump, and beat a trick when possible', () {
    const clubLead = [PlayedCard(0, 3)];
    const trumped = [PlayedCard(0, 3), PlayedCard(1, 44)];
    expect(CallBreakGame.legalPlays([0, 4, 10, 39], clubLead), [4, 10]);
    expect(CallBreakGame.legalPlays([0, 4, 39], trumped), [0, 4]);
    expect(CallBreakGame.legalPlays([37, 39, 45], trumped), [45]);
    expect(CallBreakGame.legalPlays([37, 39], trumped), [39]);
    expect(CallBreakGame.legalPlays([25, 37], trumped), [25, 37]);
    expect(CallBreakGame.scoreFor(4, 4), 40);
    expect(CallBreakGame.scoreFor(4, 6), 42);
    expect(CallBreakGame.scoreFor(4, 3), -40);
  });

  test(
    'four private WebSocket seats can play and score a full match',
    () async {
      final host = await CallBreakRoom.host('Host', port: 0);
      final clients = [host];
      addTearDown(() {
        for (final room in clients.reversed) {
          room.dispose();
        }
      });

      Future<CallBreakRoom> join(String name, String code) =>
          CallBreakRoom.join('127.0.0.1', name, code, port: host.port!);

      await expectLater(
        join('Guest', host.roomCode == '100000' ? '100001' : '100000'),
        throwsA(isA<CallBreakRoomException>()),
      );
      host.send('ready', {'ready': true});
      await _waitFor(host, () => _players(host).first['ready'] == true);
      host.send('start');
      await _waitFor(host, () => host.notice != null);
      expect(host.view['phase'], 'lobby');

      for (var seat = 1; seat < CallBreakGame.playerCount; seat++) {
        clients.add(await join('Guest $seat', host.roomCode!));
      }
      await expectLater(
        join('Extra guest', host.roomCode!),
        throwsA(isA<CallBreakRoomException>()),
      );
      for (final client in clients.skip(1)) {
        client.send('ready', {'ready': true});
      }
      await _waitFor(
        host,
        () => _players(host).every((player) => player['ready'] == true),
      );

      Future<void> act(
        CallBreakRoom client,
        String action, [
        Map<String, Object?> fields = const {},
      ]) async {
        final revision = host.view['revision'];
        await _waitFor(client, () => client.view['revision'] == revision);
        client.send(action, fields);
        await _waitFor(host, () => host.view['revision'] != revision);
      }

      await act(host, 'start');
      for (final client in clients) {
        final revision = host.view['revision'];
        await _waitFor(client, () => client.view['revision'] == revision);
        expect((client.view['hand'] as List).length, 13);
        expect(
          _players(client).any((player) => player.containsKey('hand')),
          false,
        );
      }
      expect(
        clients
            .expand((client) => (client.view['hand'] as List).cast<int>())
            .toSet(),
        hasLength(52),
      );
      final firstTurn = host.view['turn'] as int;
      final inactive = clients[(firstTurn + 1) % clients.length];
      inactive.send('bid', {'bid': 1});
      await _waitFor(inactive, () => inactive.notice != null);

      final totals = List.filled(clients.length, 0);
      for (var round = 1; round <= CallBreakGame.roundsPerMatch; round++) {
        for (var bid = 0; bid < clients.length; bid++) {
          await act(clients[host.view['turn'] as int], 'bid', {'bid': 3});
        }
        expect(host.view['phase'], 'playing');
        for (var card = 0; card < 52; card++) {
          final revision = host.view['revision'];
          final current = clients[host.view['turn'] as int];
          await _waitFor(current, () => current.view['revision'] == revision);
          final legal = (current.view['legal'] as List).cast<int>();
          await act(current, 'play', {'card': legal.first});
        }
        final players = _players(host);
        expect(
          players.fold(0, (sum, player) => sum + (player['tricks'] as int)),
          13,
        );
        for (var seat = 0; seat < players.length; seat++) {
          final points = CallBreakGame.scoreFor(
            3,
            players[seat]['tricks'] as int,
          );
          totals[seat] += points;
          expect(players[seat]['roundScore'], points);
          expect(players[seat]['score'], totals[seat]);
        }
        if (round < CallBreakGame.roundsPerMatch) {
          expect(host.view['phase'], 'roundEnd');
          await act(host, 'next');
        }
      }
      expect(host.view['phase'], 'matchEnd');
      final revision = host.view['revision'];
      for (final client in clients) {
        await _waitFor(client, () => client.view['revision'] == revision);
        expect(client.view['phase'], 'matchEnd');
        expect(client.view['hand'], isEmpty);
      }
    },
  );
}

List<Map<String, dynamic>> _players(CallBreakRoom room) =>
    (room.view['players'] as List).cast<Map<String, dynamic>>();

Future<void> _waitFor(CallBreakRoom room, bool Function() condition) {
  if (condition()) return Future.value();
  final done = Completer<void>();
  void listen() {
    if (!done.isCompleted && condition()) done.complete();
  }

  room.addListener(listen);
  return done.future
      .timeout(const Duration(seconds: 3))
      .whenComplete(() => room.removeListener(listen));
}
