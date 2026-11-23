import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../table_log.dart';
import '../table_session.dart';

const lanRoomPort = 45678;
const _timeout = Duration(seconds: 8);

class LanRoomException implements Exception {
  const LanRoomException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef LanSeat = ({String? name, bool ready});

class LanGame<GameState extends Object> {
  const LanGame({
    required this.title,
    required this.endpoint,
    required this.minPlayers,
    required this.maxPlayers,
    required this.create,
    required this.act,
    required this.canRematch,
    required this.tableView,
    required this.seatView,
    required this.validView,
  });

  final String title;
  final String endpoint;
  final int minPlayers;
  final int maxPlayers;
  final GameState Function(int players) create;
  final bool Function(GameState match, int seat, Map<String, dynamic> message)
  act;
  final bool Function(GameState match) canRematch;
  final Map<String, dynamic> Function(
    GameState? match,
    List<LanSeat> seats, {
    String? ended,
  })
  tableView;
  final Map<String, dynamic> Function(GameState? match, int seat) seatView;
  final bool Function(Map<String, dynamic> view) validView;
}

class LanRoom<GameState extends Object> extends TableSession {
  LanRoom(this.game);

  final LanGame<GameState> game;
  late final WebSocket _socket;
  _RoomHost<GameState>? _host;
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

  static Future<Room>
  hostRoom<GameState extends Object, Room extends LanRoom<GameState>>(
    Room room,
    String name, {
    required int seats,
    int port = lanRoomPort,
  }) async {
    if (seats < room.game.minPlayers || seats > room.game.maxPlayers) {
      throw const LanRoomException('Choose a valid table size.');
    }
    final host = _RoomHost<GameState>(
      await HttpServer.bind(InternetAddress.anyIPv4, port),
      room.game,
      seats,
    );
    try {
      room._host = host;
      await room._connect(
        InternetAddress.loopbackIPv4.address,
        host.server.port,
        name,
        host.code,
      );
      return room;
    } catch (_) {
      await host.close();
      rethrow;
    }
  }

  static Future<Room>
  joinRoom<GameState extends Object, Room extends LanRoom<GameState>>(
    Room room,
    String address,
    String name,
    String code, {
    int port = lanRoomPort,
  }) async {
    final ip = InternetAddress.tryParse(address);
    if (ip == null || ip.type != InternetAddressType.IPv4) {
      throw const LanRoomException('Enter the host phone’s IPv4 address.');
    }
    await room._connect(ip.address, port, name, code);
    return room;
  }

  Future<void> _connect(
    String address,
    int port,
    String name,
    String code,
  ) async {
    final uri = Uri(
      scheme: 'ws',
      host: address,
      port: port,
      path: game.endpoint,
    );
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

    _socket = socket;
    _subscription = socket.listen(
      _receive,
      onError: (Object _) => _disconnect(),
      onDone: _disconnect,
    );
    try {
      send('join', {'name': name, 'code': code, 'hostKey': _host?.key});
      await _joined.future.timeout(_timeout);
    } catch (_) {
      dispose();
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
        if (!_validLobby(message) || !game.validView(message)) {
          _disconnect();
          return;
        }
        view = message;
        notice = null;
        if (!_joined.isCompleted) _joined.complete();
      } else if (message['type'] == 'error') {
        notice = message['message'] as String;
        if (!_joined.isCompleted) {
          _joined.completeError(LanRoomException(notice!));
        }
      }
      notifyListeners();
    } on FormatException {
      _disconnect();
    } on TypeError {
      _disconnect();
    }
  }

  bool _validLobby(Map<String, dynamic> view) {
    final players = view['players'];
    final seat = view['seat'];
    final phase = view['phase'];
    if (players is! List ||
        players.length < game.minPlayers ||
        players.length > game.maxPlayers ||
        seat is! int ||
        seat < 0 ||
        seat >= players.length ||
        view['revision'] is! int ||
        phase is! String ||
        !TableLog.validView(view['log'], players.length) ||
        (view['ended'] != null && view['ended'] is! String)) {
      return false;
    }
    final active = phase != 'lobby' && phase != 'ended';
    return players.every(
      (player) =>
          player is Map<String, dynamic> &&
          player['ready'] is bool &&
          (player['name'] is String || (!active && player['name'] == null)),
    );
  }

  void _disconnect() {
    if (_disposed || !_connected) return;
    _connected = false;
    notice ??= 'The room disconnected.';
    if (!_joined.isCompleted) {
      _joined.completeError(LanRoomException(notice!));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
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

class _RoomHost<GameState extends Object> {
  _RoomHost(this.server, this.rules, int seats)
    : _seats = List<_Seat?>.filled(seats, null) {
    server.listen(_accept);
  }

  static final _random = Random.secure();
  final code = (100000 + _random.nextInt(900000)).toString();
  final key = List.generate(24, (_) => _random.nextInt(256)).join('.');
  final HttpServer server;
  final LanGame<GameState> rules;
  final List<_Seat?> _seats;
  final _sockets = <WebSocket>{};
  GameState? _game;
  String? _ended;
  int _revision = 0;
  bool _closing = false;

  Future<void> _accept(HttpRequest request) async {
    if (request.uri.path != rules.endpoint ||
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
      _error(socket, '${rules.title} room is full (${_seats.length} seats).');
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
      'rematch' when seat == 0 && game != null && rules.canRematch(game) =>
        _start(),
      'ready' || 'start' || 'rematch' => false,
      _ when game != null => rules.act(game, seat, message),
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
    _game = rules.create(_seats.length);
    return true;
  }

  void _broadcast() {
    final game = _game;
    final public = {
      'type': 'view',
      'revision': ++_revision,
      ...rules.tableView(game, [
        for (final seat in _seats)
          (name: seat?.name, ready: seat?.ready ?? false),
      ], ended: _ended),
    };
    for (var seat = 0; seat < _seats.length; seat++) {
      final socket = _seats[seat]?.socket;
      if (socket == null || socket.readyState != WebSocket.open) continue;
      socket.add(
        jsonEncode({...public, 'seat': seat, ...rules.seatView(game, seat)}),
      );
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
