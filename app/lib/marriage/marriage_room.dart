import 'dart:math';

import '../cards/standard_cards.dart';
import '../lan/lan_room.dart';
import 'marriage_game.dart';

Future<LanRoom<MarriageGame>> hostMarriageRoom(
  String name,
  int seats, {
  int port = lanRoomPort,
  Random? random,
}) => LanRoom.hostRoom<MarriageGame, LanRoom<MarriageGame>>(
  LanRoom(_rules(random)),
  name,
  seats: seats,
  port: port,
);

Future<LanRoom<MarriageGame>> joinMarriageRoom(
  String address,
  String name,
  String code, {
  int port = lanRoomPort,
}) => LanRoom.joinRoom<MarriageGame, LanRoom<MarriageGame>>(
  LanRoom(_rules()),
  address,
  name,
  code,
  port: port,
);

LanGame<MarriageGame> _rules([Random? random]) => LanGame<MarriageGame>(
  title: 'Marriage',
  endpoint: '/marriage',
  minPlayers: MarriageGame.minPlayers,
  maxPlayers: MarriageGame.maxPlayers,
  create: (seats) => MarriageGame(seats, random: random),
  act: (game, seat, message) {
    final fromDiscard = message['fromDiscard'];
    final card = message['card'];
    final cards = message['cards'];
    return switch (message['action']) {
      'draw' when fromDiscard is bool => game.draw(
        seat,
        fromDiscard: fromDiscard,
      ),
      'lay'
          when cards is List &&
              cards.length == marriageGroupSize &&
              cards.every(_validCard) =>
        game.layGroup(seat, cards.cast<int>()),
      'discard' when card is int && _validCard(card) => game.discard(
        seat,
        card,
      ),
      'next' when seat == 0 => game.nextRound(),
      _ => false,
    };
  },
  canRematch: (_) => false,
  tableView: marriageTableView,
  seatView: marriageSeatView,
  validView: _validView,
);

Map<String, dynamic> marriageTableView(
  MarriageGame? game,
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
        'groups': game?.groupCount(seat) ?? 0,
        'points': game?.pointsFor(seat) ?? 0,
        'roundPoints': game?.roundPointsFor(seat) ?? 0,
        'note': game?.noteFor(seat) ?? '',
      },
  ],
  'round': game?.round ?? 0,
  'turn': game?.turn,
  'winner': game?.winner,
  'stockCount': game?.stockCount ?? 0,
  'topDiscard': game?.topDiscard,
  'hasDrawn': game?.hasDrawn ?? false,
  'log': game?.logView,
};

Map<String, dynamic> marriageSeatView(MarriageGame? game, int seat) {
  final hand = game?.handFor(seat) ?? const <int>[];
  return {
    'seat': seat,
    'hand': hand,
    'maal': game?.maalFor(seat),
    'discardable': game == null
        ? const <int>[]
        : hand.where((card) => game.canDiscard(seat, card)).toList(),
  };
}

bool _validView(Map<String, dynamic> view) {
  final players = (view['players'] as List).cast<Map<String, dynamic>>();
  final phase = view['phase'];
  final hand = view['hand'];
  final discardable = view['discardable'];
  final maal = view['maal'];
  bool validSeat(Object? seat) =>
      seat is int && seat >= 0 && seat < players.length;
  return (phase == 'lobby' ||
          phase == 'ended' ||
          ((phase == 'playing' || phase == 'roundEnd') &&
              validSeat(view['turn']))) &&
      (view['winner'] == null || validSeat(view['winner'])) &&
      view['round'] is int &&
      view['stockCount'] is int &&
      view['hasDrawn'] is bool &&
      (view['topDiscard'] == null || _validCard(view['topDiscard'])) &&
      (maal == null || (maal is int && maal >= 0 && maal < standardDeckSize)) &&
      hand is List &&
      hand.length <= MarriageGame.handSize + 1 &&
      hand.every(_validCard) &&
      discardable is List &&
      discardable.length <= hand.length &&
      discardable.every(hand.contains) &&
      players.every(
        (player) =>
            player['groups'] is int &&
            player['points'] is int &&
            player['roundPoints'] is int &&
            player['note'] is String,
      );
}

bool _validCard(Object? card) =>
    card is int && card >= 0 && card < marriageDeckSize;
