import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/lan/lan_room.dart';
import 'package:kardkhana/teen_patti/teen_patti_game.dart';
import 'package:kardkhana/teen_patti/teen_patti_room.dart';

void main() {
  test('five LAN players play a hand with private cards until show', () async {
    await expectLater(
      hostTeenPattiRoom('Host', 6, port: 0),
      throwsA(isA<LanRoomException>()),
    );
    final host = await hostTeenPattiRoom('Host', 5, port: 0);
    final rooms = [host];
    addTearDown(() {
      for (final room in rooms.reversed) {
        room.dispose();
      }
    });

    Future<LanRoom<TeenPattiGame>> join(String name, String code) =>
        joinTeenPattiRoom('127.0.0.1', name, code, port: host.port!);

    await expectLater(
      join('Wrong code', host.roomCode == '100000' ? '100001' : '100000'),
      throwsA(isA<LanRoomException>()),
    );
    host.send('ready', {'ready': true});
    await _waitFor(host, () => _players(host)[0]['ready'] == true);
    host.send('start');
    await _waitFor(host, () => host.notice != null);
    expect(host.view['phase'], 'lobby');

    for (var seat = 1; seat < 5; seat++) {
      rooms.add(await join('Guest $seat', host.roomCode!));
    }
    await expectLater(
      join('Extra guest', host.roomCode!),
      throwsA(isA<LanRoomException>()),
    );
    for (final room in rooms.skip(1)) {
      room.send('ready', {'ready': true});
    }
    await _waitFor(host, () => _players(host).every((p) => p['ready'] == true));

    Future<void> act(int seat, String action) async {
      final before = host.view['revision'];
      final room = rooms[seat];
      await _waitFor(room, () => room.view['revision'] == before);
      room.send(action);
      await _waitFor(host, () => host.view['revision'] != before);
      final after = host.view['revision'];
      for (final room in rooms) {
        await _waitFor(room, () => room.view['revision'] == after);
      }
    }

    await act(0, 'start');
    expect(rooms.map((room) => room.view['hand']), everyElement(isEmpty));
    rooms[1].send('look');
    await _waitFor(rooms[1], () => rooms[1].notice != null);
    await act(0, 'look');
    expect(host.view['hand'], hasLength(3));
    expect(_players(rooms[1]).map((p) => p['reveal']), everyElement(isEmpty));
    await act(0, 'call');
    await act(1, 'look');
    expect(rooms[1].view['hand'], hasLength(3));
    expect(_players(host)[1]['reveal'], isEmpty);
    await act(1, 'call');
    for (var seat = 2; seat < 5; seat++) {
      await act(seat, 'pack');
    }
    await act(0, 'show');
    for (final room in rooms) {
      expect(room.view['phase'], 'roundEnd');
      expect(room.view['winners'], isNotEmpty);
      expect(_players(room).map((p) => (p['reveal'] as List).length), [
        3,
        3,
        0,
        0,
        0,
      ]);
      expect(
        _players(room).fold(0, (sum, p) => sum + (p['points'] as int)),
        150,
      );
    }

    rooms.last.send('next');
    await _waitFor(rooms.last, () => rooms.last.notice != null);
    await act(0, 'next');
    expect(host.view['round'], 2);
    expect(rooms.map((room) => room.view['hand']), everyElement(isEmpty));
    rooms.last.dispose();
    await _waitFor(host, () => host.view['phase'] == 'ended');
  });
}

List<Map<String, dynamic>> _players(LanRoom<TeenPattiGame> room) =>
    (room.view['players'] as List).cast<Map<String, dynamic>>();

Future<void> _waitFor(LanRoom<TeenPattiGame> room, bool Function() condition) {
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
