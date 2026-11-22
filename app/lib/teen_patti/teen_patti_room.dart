import '../cards/standard_cards.dart';
import '../lan/lan_room.dart';
import 'teen_patti_game.dart';

Future<LanRoom<TeenPattiGame>> hostTeenPattiRoom(
  String name,
  int seats, {
  int port = lanRoomPort,
}) => LanRoom.hostRoom(LanRoom(_rules), name, seats: seats, port: port);

Future<LanRoom<TeenPattiGame>> joinTeenPattiRoom(
  String address,
  String name,
  String code, {
  int port = lanRoomPort,
}) => LanRoom.joinRoom(LanRoom(_rules), address, name, code, port: port);

final _rules = LanGame<TeenPattiGame>(
  title: 'Teen Patti',
  endpoint: '/teen-patti',
  minPlayers: TeenPattiGame.minPlayers,
  maxPlayers: TeenPattiGame.maxPlayers,
  create: TeenPattiGame.new,
  act: (game, seat, message) {
    if (message['action'] == 'next') return seat == 0 && game.nextRound();
    for (final action in TeenPattiAction.values) {
      if (message['action'] == action.name) return game.act(seat, action);
    }
    return false;
  },
  canRematch: (game) => game.complete && !game.canDeal,
  tableView: teenPattiTableView,
  seatView: teenPattiSeatView,
  validView: _validView,
);

Map<String, dynamic> teenPattiTableView(
  TeenPattiGame? game,
  List<LanSeat> seats, {
  String? ended,
}) => {
  'phase': ended != null
      ? 'ended'
      : game == null
      ? 'lobby'
      : game.complete
      ? 'roundEnd'
      : 'playing',
  'ended': ended,
  'players': [
    for (var seat = 0; seat < seats.length; seat++)
      {
        'name': seats[seat].name,
        'ready': seats[seat].ready,
        'points': game?.pointsFor(seat) ?? 0,
        'note': game?.noteFor(seat) ?? '',
        'reveal': game?.visibleHand(seat, viewer: null) ?? const <int>[],
      },
  ],
  'round': game?.round ?? 0,
  'turn': game?.turn,
  'pot': game?.pot ?? 0,
  'winners': game?.winners ?? const <int>[],
  'canDeal': game?.canDeal ?? false,
};

Map<String, dynamic> teenPattiSeatView(TeenPattiGame? game, int seat) => {
  'seat': seat,
  'hand': game?.visibleHand(seat, viewer: seat) ?? const <int>[],
  'actions': [
    for (final action in game?.actionsFor(seat) ?? const {}) action.name,
  ],
  'callCost': game?.callCost(seat) ?? 0,
  'raiseCost': game?.raiseCost(seat) ?? 0,
};

bool _validView(Map<String, dynamic> view) {
  final players = (view['players'] as List).cast<Map<String, dynamic>>();
  final phase = view['phase'];
  bool validSeat(Object? seat) =>
      seat is int && seat >= 0 && seat < players.length;
  return (phase == 'lobby' ||
          phase == 'ended' ||
          ((phase == 'playing' || phase == 'roundEnd') &&
              validSeat(view['turn']))) &&
      view['round'] is int &&
      view['pot'] is int &&
      view['canDeal'] is bool &&
      view['callCost'] is int &&
      view['raiseCost'] is int &&
      view['winners'] is List &&
      (view['winners'] as List).every(validSeat) &&
      view['actions'] is List &&
      (view['actions'] as List).every(
        (action) => TeenPattiAction.values.any((value) => value.name == action),
      ) &&
      _validHand(view['hand']) &&
      players.every(
        (player) =>
            player['points'] is int &&
            player['note'] is String &&
            _validHand(player['reveal']),
      );
}

bool _validHand(Object? hand) =>
    hand is List &&
    (hand.isEmpty || hand.length == 3) &&
    hand.every((card) => card is int && card >= 0 && card < standardDeckSize);
