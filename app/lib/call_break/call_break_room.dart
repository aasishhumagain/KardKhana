import '../lan/lan_room.dart';
import 'call_break_game.dart';
import 'call_break_session.dart';

const callBreakPort = lanRoomPort;
typedef CallBreakRoomException = LanRoomException;

class CallBreakRoom extends LanRoom<CallBreakGame> {
  CallBreakRoom._() : super(_rules);

  static Future<CallBreakRoom> host(String name, {int port = callBreakPort}) =>
      LanRoom.hostRoom<CallBreakGame, CallBreakRoom>(
        CallBreakRoom._(),
        name,
        seats: CallBreakGame.playerCount,
        port: port,
      );

  static Future<CallBreakRoom> join(
    String address,
    String name,
    String code, {
    int port = callBreakPort,
  }) => LanRoom.joinRoom<CallBreakGame, CallBreakRoom>(
    CallBreakRoom._(),
    address,
    name,
    code,
    port: port,
  );
}

final _rules = LanGame<CallBreakGame>(
  title: 'Call Break',
  endpoint: '/call-break',
  minPlayers: CallBreakGame.playerCount,
  maxPlayers: CallBreakGame.playerCount,
  create: (_) => CallBreakGame(),
  act: (game, seat, message) => switch (message['action']) {
    'bid' when message['bid'] is int => game.bid(seat, message['bid'] as int),
    'play' when message['card'] is int => game.play(
      seat,
      message['card'] as int,
    ),
    'next' when seat == 0 => game.nextRound(),
    _ => false,
  },
  canRematch: (game) => game.phase == CallBreakPhase.matchEnd,
  tableView: callBreakTableView,
  seatView: callBreakSeatView,
  validView: _validView,
);

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
