import '../table_session.dart';
import 'call_break_game.dart';

typedef CallBreakSession = TableSession;

Map<String, dynamic> callBreakTableView(
  CallBreakGame? game,
  List<({String? name, bool ready})> seats, {
  String? ended,
}) => {
  'players': [
    for (var seat = 0; seat < seats.length; seat++)
      {
        'name': seats[seat].name,
        'ready': seats[seat].ready,
        'bid': game?.bids[seat],
        'tricks': game?.tricksWon[seat] ?? 0,
        'score': game?.scores[seat] ?? 0,
        'roundScore': game?.roundScores[seat] ?? 0,
      },
  ],
  'phase': ended != null ? 'ended' : game?.phase.name ?? 'lobby',
  'ended': ended,
  'round': game?.round,
  'turn': game?.turn,
  'trick': _encodeTrick(game?.trick),
  'lastTrick': _encodeTrick(game?.lastTrick),
  'lastWinner': game?.lastWinner,
  'log': game?.logView,
};

Map<String, dynamic> callBreakSeatView(CallBreakGame? game, int seat) => {
  'seat': seat,
  'hand': game?.handFor(seat) ?? const <int>[],
  'legal': game?.legalCardsFor(seat) ?? const <int>[],
};

List<List<int>> _encodeTrick(List<PlayedCard>? trick) => [
  for (final play in trick ?? const <PlayedCard>[]) [play.seat, play.card],
];
