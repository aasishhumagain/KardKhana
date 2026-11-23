import 'dart:collection';

enum TableMove { draw, discard, play, decision, result }

typedef TableLogEntry = ({int round, int seat, TableMove move, String message});

class TableLog {
  // A full five-round Call Break match fits within this history. Keeping a
  // limit also bounds each snapshot in rooms that play many hands.
  static const _limit = 400;
  static final _movesByName = TableMove.values.asNameMap();
  final _entries = Queue<TableLogEntry>();

  void add(int round, int seat, TableMove move, String message) {
    if (_entries.length == _limit) _entries.removeFirst();
    _entries.addLast((round: round, seat: seat, move: move, message: message));
  }

  List<List<Object>> toView() => [
    for (final entry in _entries)
      [entry.round, entry.seat, entry.move.name, entry.message],
  ];

  static bool validView(Object? data, int seats) =>
      data == null ||
      (data is List &&
          data.length <= _limit &&
          data.every((row) {
            final entry = _read(row);
            return entry != null && entry.seat < seats;
          }));

  static List<TableLogEntry> readView(Object? data) =>
      data is List ? [for (final row in data) ?_read(row)] : const [];

  static TableLogEntry? _read(Object? row) {
    if (row case [
      final int round,
      final int seat,
      final String kind,
      final String message,
    ]) {
      final move = _movesByName[kind];
      if (move != null &&
          round > 0 &&
          seat >= 0 &&
          message.isNotEmpty &&
          message.length <= 100) {
        return (round: round, seat: seat, move: move, message: message);
      }
    }
    return null;
  }
}
