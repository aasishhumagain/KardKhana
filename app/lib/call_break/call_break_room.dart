import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'call_break_game.dart';
import 'call_break_session.dart';

const callBreakPort = 45678;
const _endpoint = '/call-break';
const _timeout = Duration(seconds: 8);

class CallBreakRoomException implements Exception {
  const CallBreakRoomException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CallBreakRoom extends CallBreakSession {
  CallBreakRoom._(this._socket, this._host) {
    _subscription = _socket.listen(
      _receive,
      onError: (Object _) => _disconnect(),
      onDone: _disconnect,
    );
  }

  final WebSocket _socket;
  final _RoomHost? _host;
  final _joined = Completer<void>();
  late final StreamSubscription<dynamic> _subscription;
  bool _connected = true;
  bool _disposed = false;

  @override
  Map<String, dynamic> view = {};
  String? notice;
  bool get connected => _connected;
  bool get isHost => _host != null;
  String? get roomCode => _host?.code;
  int? get port => _host?.server.port;

  static Future<CallBreakRoom> host(
    String name, {
    int port = callBreakPort,
  }) async {
    final host = _RoomHost(
      await HttpServer.bind(InternetAddress.anyIPv4, port),
    );
    try {
      return await _connect(
        InternetAddress.loopbackIPv4.address,
        host.server.port,
        name,
        host.code,
        host,
      );
    } catch (_) {
      await host.close();
      rethrow;
    }
  }

  static Future<CallBreakRoom> join(
    String address,
    String name,
    String code, {
    int port = callBreakPort,
  }) {
    final ip = InternetAddress.tryParse(address);
    if (ip == null || ip.type != InternetAddressType.IPv4) {
      throw const CallBreakRoomException(
        'Enter the host phone’s IPv4 address.',
      );
    }
    return _connect(ip.address, port, name, code, null);
  }

  static Future<CallBreakRoom> _connect(
    String address,
    int port,
    String name,
    String code,
    _RoomHost? host,
  ) async {
    final uri = Uri(scheme: 'ws', host: address, port: port, path: _endpoint);
    // Give the socket attempt a deadline and close its HTTP client on failure.
    final http = HttpClient()..connectionTimeout = _timeout;
    late final WebSocket socket;
    try {
      socket = await WebSocket.connect(
        uri.toString(),
        customClient: http,
      ).timeout(_timeout);
    } catch (_) {
      http.close(force: true);
      rethrow;
    }
    http.close();
    socket.pingInterval = const Duration(seconds: 10);

    final room = CallBreakRoom._(socket, host);
    try {
      room.send('join', {'name': name, 'code': code, 'hostKey': host?.key});
      await room._joined.future.timeout(_timeout);
      return room;
    } catch (_) {
      room.dispose();
      rethrow;
    }
  }

  @override
  void send(String action, [Map<String, Object?> fields = const {}]) {
    if (!_connected || _disposed) return;
    _socket.add(
      jsonEncode({'action': action, 'revision': view['revision'], ...fields}),
    );
  }

  void _receive(dynamic data) {
    if (_disposed || data is! String) return;
    try {
      final message = jsonDecode(data) as Map<String, dynamic>;
      if (message['type'] == 'view') {
        if (!_validView(message)) {
          _disconnect();
          return;
        }
        view = message;
        notice = null;
        if (!_joined.isCompleted) _joined.complete();
      } else if (message['type'] == 'error') {
        notice = message['message'] as String;
        if (!_joined.isCompleted) {
          _joined.completeError(CallBreakRoomException(notice!));
        }
      }
      notifyListeners();
    } on FormatException {
      _disconnect();
    } on TypeError {
      _disconnect();
    }
  }

  void _disconnect() {
    if (_disposed || !_connected) return;
    _connected = false;
    notice ??= 'The room disconnected.';
    if (!_joined.isCompleted) {
      _joined.completeError(CallBreakRoomException(notice!));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(_closeSocket(_socket));
    if (_host case final host?) unawaited(host.close());
    super.dispose();
  }
}

class _Seat {
  _Seat(this.socket, this.name);

  final WebSocket socket;
  final String name;
  bool ready = false;
}

class _RoomHost {
  _RoomHost(this.server) {
    server.listen(_accept);
  }

  static final _random = Random.secure();
  final code = (100000 + _random.nextInt(900000)).toString();
  final key = List.generate(24, (_) => _random.nextInt(256)).join('.');
  final HttpServer server;
  final _seats = List<_Seat?>.filled(CallBreakGame.playerCount, null);
  final _sockets = <WebSocket>{};
  CallBreakGame? _game;
  String? _ended;
  int _revision = 0;
  bool _closing = false;

  Future<void> _accept(HttpRequest request) async {
    if (request.uri.path != _endpoint ||
        !WebSocketTransformer.isUpgradeRequest(request) ||
        _sockets.length >= 12) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final loopback = request.connectionInfo?.remoteAddress.isLoopback ?? false;
    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
    } on WebSocketException {
      return;
    }
    if (_closing) {
      await _closeSocket(socket);
      return;
    }
    _sockets.add(socket);
    socket.pingInterval = const Duration(seconds: 10);
    var seat = -1;
    final deadline = Timer(_timeout, () {
      if (seat == -1) unawaited(_closeSocket(socket));
    });

    void remove() {
      deadline.cancel();
      if (!_sockets.remove(socket) || seat == -1 || _closing) return;
      _seats[seat] = null;
      if (seat == 0) {
        unawaited(close());
        return;
      }
      if (_game != null) {
        _ended = 'A player left. Return to the catalog to start a new room.';
      }
      _broadcast();
    }

    socket.listen(
      (dynamic data) {
        final message = _readMessage(data);
        if (message == null) {
          _error(socket, 'Invalid room message.');
          return;
        }
        if (seat == -1) {
          seat = _join(socket, message, loopback: loopback);
          if (seat == -1) {
            unawaited(_closeSocket(socket));
          } else {
            deadline.cancel();
            _broadcast();
          }
          return;
        }
        _act(seat, message);
      },
      onError: (Object _) => remove(),
      onDone: remove,
      cancelOnError: true,
    );
  }

  int _join(
    WebSocket socket,
    Map<String, dynamic> message, {
    required bool loopback,
  }) {
    final name = message['name'];
    final host = loopback && message['hostKey'] == key;
    if (message['action'] != 'join' || message['code'] != code) {
      _error(socket, 'That room code is incorrect.');
    } else if (name is! String || name.trim().isEmpty || name.length > 40) {
      _error(socket, 'Enter a nickname of up to 20 characters.');
    } else if (_game != null || _ended != null) {
      _error(socket, 'This room already started a match.');
    } else if (!host && _seats[0] == null) {
      _error(socket, 'The host is still setting up the room.');
    } else {
      final seat = host ? 0 : _seats.indexOf(null);
      if (seat >= 0 && _seats[seat] == null) {
        _seats[seat] = _Seat(socket, name.trim());
        return seat;
      }
      _error(socket, 'Call Break has four seats. This room is full.');
    }
    return -1;
  }

  void _act(int seat, Map<String, dynamic> message) {
    final player = _seats[seat];
    if (player == null || _ended != null) return;
    if (message['action'] != 'ready' && message['revision'] != _revision) {
      _error(player.socket, 'The table changed. Try the action again.');
      return;
    }
    final game = _game;

    final accepted = switch (message['action']) {
      'ready' when game == null && message['ready'] is bool => _setReady(
        player,
        message['ready'] as bool,
      ),
      'start' when seat == 0 && game == null => _start(),
      'bid' when game != null && message['bid'] is int => game.bid(
        seat,
        message['bid'] as int,
      ),
      'play' when game != null && message['card'] is int => game.play(
        seat,
        message['card'] as int,
      ),
      'next' when seat == 0 && game != null => game.nextRound(),
      'rematch' when seat == 0 && game?.phase == CallBreakPhase.matchEnd =>
        _start(),
      _ => false,
    };
    if (accepted) {
      _broadcast();
    } else {
      _error(player.socket, 'That action is unavailable right now.');
    }
  }

  bool _setReady(_Seat player, bool ready) {
    player.ready = ready;
    return true;
  }

  bool _start() {
    if (!_seats.every((seat) => seat?.ready == true)) return false;
    _game = CallBreakGame();
    return true;
  }

  void _broadcast() {
    final game = _game;
    final public = {
      'type': 'view',
      'revision': ++_revision,
      ...callBreakTableView(game, [
        for (final seat in _seats)
          (name: seat?.name, ready: seat?.ready ?? false),
      ], ended: _ended),
    };
    for (var seat = 0; seat < _seats.length; seat++) {
      final socket = _seats[seat]?.socket;
      if (socket == null || socket.readyState != WebSocket.open) continue;
      socket.add(jsonEncode({...public, ...callBreakSeatView(game, seat)}));
    }
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    final sockets = _sockets.toList();
    _sockets.clear();
    await server.close(force: true);
    await Future.wait(sockets.map(_closeSocket));
  }
}

Map<String, dynamic>? _readMessage(dynamic data) {
  if (data is! String || data.length > 1024) return null;
  try {
    final message = jsonDecode(data);
    return message is Map<String, dynamic> ? message : null;
  } on FormatException {
    return null;
  }
}

bool _validView(Map<String, dynamic> view) {
  final phase = view['phase'];
  final players = view['players'];
  if (players is! List ||
      players.length != CallBreakGame.playerCount ||
      view['revision'] is! int ||
      !_validSeat(view['seat']) ||
      !_validCards(view['hand']) ||
      !_validCards(view['legal']) ||
      !_validTrick(view['trick']) ||
      !_validTrick(view['lastTrick']) ||
      (view['lastWinner'] != null && !_validSeat(view['lastWinner'])) ||
      (view['ended'] != null && view['ended'] is! String)) {
    return false;
  }
  final atTable = phase != 'lobby' && phase != 'ended';
  if (atTable &&
      (!CallBreakPhase.values.any((value) => value.name == phase) ||
          view['round'] is! int ||
          !_validSeat(view['turn']))) {
    return false;
  }
  return players.every(
    (player) =>
        player is Map<String, dynamic> &&
        (player['name'] is String || (!atTable && player['name'] == null)) &&
        player['ready'] is bool &&
        (player['bid'] == null || player['bid'] is int) &&
        player['tricks'] is int &&
        player['score'] is int &&
        player['roundScore'] is int,
  );
}

bool _validSeat(Object? seat) =>
    seat is int && seat >= 0 && seat < CallBreakGame.playerCount;

bool _validCard(Object? card) =>
    card is int &&
    card >= 0 &&
    card < CallBreakGame.playerCount * CallBreakGame.cardsPerHand;

bool _validCards(Object? cards) =>
    cards is List &&
    cards.length <= CallBreakGame.cardsPerHand &&
    cards.every(_validCard);

bool _validTrick(Object? trick) =>
    trick is List &&
    trick.length <= CallBreakGame.playerCount &&
    trick.every(
      (play) =>
          play is List &&
          play.length == 2 &&
          _validSeat(play[0]) &&
          _validCard(play[1]),
    );

void _error(WebSocket socket, String message) {
  if (socket.readyState == WebSocket.open) {
    socket.add(jsonEncode({'type': 'error', 'message': message}));
  }
}

Future<void> _closeSocket(WebSocket socket) async {
  try {
    await socket.close();
  } on IOException {
    // A peer may already have disconnected.
  }
}
