import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'card_flights.dart';
import 'table_widgets.dart';

typedef SceneSeat = ({String name, String detail});

class TableScene extends StatelessWidget {
  const TableScene({
    required this.seats,
    required this.localSeat,
    required this.activeSeat,
    required this.status,
    required this.progress,
    required this.center,
    required this.hand,
    required this.round,
    this.cards = const [],
    this.landingZone = LandingZone.trick,
    this.notice,
    super.key,
  });

  final List<SceneSeat> seats;
  final int localSeat;
  final int? activeSeat;
  final String status;
  final String progress;
  final Widget center;
  final Widget hand;
  final String? notice;
  final int round;
  final List<FeltCard> cards;
  final LandingZone landingZone;

  @override
  Widget build(BuildContext context) {
    final labelGrowth = math.max(
      0.0,
      MediaQuery.textScalerOf(context).scale(12) - 12,
    );
    final others = [
      for (var offset = 1; offset < seats.length; offset++)
        (localSeat + offset) % seats.length,
    ];
    return LayoutBuilder(
      builder: (context, limits) {
        final width = limits.maxWidth;
        final height = math.max(200 + 6 * labelGrowth, limits.maxHeight);
        final portraitSize = height >= 232 ? 43.0 : 36.0;
        final seatsHeight = portraitSize + 31 + 2 * labelGrowth;
        final leftReadout = (width * .235).clamp(84, 154).toDouble();
        final middleOrigin = Offset(leftReadout + 16, 2 + seatsHeight);
        final anchors = List<Offset>.filled(
          seats.length,
          Offset(width / 2, height - 35),
        );
        for (var i = 0; i < others.length; i++) {
          final fraction = switch (others.length) {
            1 => .50,
            2 => [.31, .69][i],
            3 => [.17, .50, .83][i],
            _ => [.13, .365, .635, .87][i],
          };
          final outside =
              others.length >= 3 && (i == 0 || i == others.length - 1);
          anchors[others[i]] = Offset(
            width * fraction,
            portraitSize / 2 + (outside ? 12 : 2),
          );
        }
        return SingleChildScrollView(
          child: SizedBox(
            height: height,
            width: width,
            child: TableScenery(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                child: Column(
                  children: [
                    SizedBox(
                      height: seatsHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final seat in others)
                            Positioned(
                              left:
                                  anchors[seat].dx -
                                  10 -
                                  math.min(width * .22, 112) / 2,
                              top: anchors[seat].dy - portraitSize / 2 - 2,
                              width: math.min(width * .22, 112),
                              child: _SeatedPlayer(
                                index: seat,
                                seat: seats[seat],
                                active: seat == activeSeat,
                                diameter: portraitSize,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        spacing: 6,
                        children: [
                          SizedBox(
                            width: leftReadout,
                            child: _TableReadout(
                              top: progress,
                              main: status,
                              highlight: localSeat == activeSeat,
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.none,
                              children: [
                                Center(child: center),
                                CardFlights(
                                  key: ValueKey(round),
                                  cards: cards,
                                  origins: [
                                    for (final anchor in anchors)
                                      anchor - middleOrigin,
                                  ],
                                  round: round,
                                  zone: landingZone,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: (limits.maxWidth * .16)
                                .clamp(57, 104)
                                .toDouble(),
                            child: _TableReadout(
                              top: seats[localSeat].name,
                              main: seats[localSeat].detail,
                              highlight: localSeat == activeSeat,
                              portrait: localSeat,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notice case final message?)
                      Tooltip(
                        message: message,
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: const Color(0xFFFFBCA5)),
                        ),
                      ),
                    hand,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TableScenery extends StatelessWidget {
  const TableScenery({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.7),
            radius: 1.15,
            colors: [Color(0xFF692783), Color(0xFF38144C), tableRoom],
          ),
        ),
      ),
      const CustomPaint(painter: _FeltAndRail()),
      child,
    ],
  );
}

class _FeltAndRail extends CustomPainter {
  const _FeltAndRail();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The player sits at the near edge, which extends behind the hand.
    final motif = Paint()
      ..color = const Color(0x147E4F95)
      ..strokeWidth = 1;
    for (var x = -h; x < w; x += 24) {
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), motif);
    }
    final outer = Rect.fromLTRB(w * .045, h * .16, w * .955, h * 1.40);
    final inner = outer.deflate(8);
    final shadow = Paint()..color = const Color(0x99090810);
    canvas.drawOval(outer.translate(0, 5).inflate(1), shadow);
    canvas.drawOval(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD99A), Color(0xFFC7832E), Color(0xFF693D52)],
          stops: [0, .48, 1],
        ).createShader(outer),
    );
    canvas.drawOval(
      outer.deflate(2),
      Paint()
        ..color = const Color(0x88E9A74C)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawOval(inner.inflate(1), Paint()..color = const Color(0xFF5B314D));
    canvas.drawOval(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.28),
          radius: .72,
          colors: [Color(0xFF72338B), Color(0xFF551C6E), Color(0xFF321043)],
          stops: [0, .50, 1],
        ).createShader(inner),
    );
    canvas.drawOval(
      inner.deflate(7),
      Paint()
        ..color = const Color(0x8DEAC991)
        ..strokeWidth = .8
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_FeltAndRail oldDelegate) => false;
}

class _SeatedPlayer extends StatelessWidget {
  const _SeatedPlayer({
    required this.index,
    required this.seat,
    required this.active,
    required this.diameter,
  });

  final int index;
  final SceneSeat seat;
  final bool active;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final accent = active ? const Color(0xFFFCDD95) : const Color(0xFFB88957);
    final type = Theme.of(context).textTheme;
    return Tooltip(
      message: '${seat.name} · ${seat.detail}',
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Portrait(index: index, diameter: diameter, active: active),
            Container(
              constraints: const BoxConstraints(minWidth: 46),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF65482E)
                    : const Color(0xEE30133E),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: accent.withValues(alpha: .68)),
              ),
              child: Text(
                seat.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelMedium?.copyWith(
                  color: const Color(0xFFFFEBC9),
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
            ),
            Text(
              seat.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.labelSmall?.copyWith(
                color: active ? accent : const Color(0xFFFFEAD7),
                height: 1.12,
                shadows: const [
                  Shadow(color: Color(0xD9110808), blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.index,
    required this.diameter,
    required this.active,
  });

  final int index;
  final double diameter;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: diameter,
    height: diameter,
    padding: EdgeInsets.all(active ? 2 : 1.2),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFFFD578) : const Color(0xFFC38B59),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: active ? const Color(0xB3FFD578) : const Color(0x990C0418),
          blurRadius: active ? 10 : 4,
        ),
      ],
    ),
    child: ClipOval(
      child: Image.asset(
        'assets/tables/portraits/seat_${index % 6}.jpg',
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class _TableReadout extends StatelessWidget {
  const _TableReadout({
    required this.top,
    required this.main,
    required this.highlight,
    this.portrait,
  });

  final String top;
  final String main;
  final bool highlight;
  final int? portrait;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Tooltip(
      message: '$top · $main',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD12C103C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight
                ? const Color(0xB3D49C61)
                : const Color(0x6DAA70B9),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            spacing: 5,
            children: [
              if (portrait case final index?)
                _Portrait(index: index, diameter: 23, active: highlight),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.labelSmall?.copyWith(
                        color: const Color(0xFFF9DFCE),
                        height: 1.15,
                      ),
                    ),
                    Text(
                      main,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.labelMedium?.copyWith(
                        color: highlight
                            ? const Color(0xFFFFDB93)
                            : const Color(0xFFFFF0DF),
                        fontWeight: FontWeight.w800,
                        height: 1.17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HandSpread extends StatelessWidget {
  const HandSpread({required this.cards, this.large = false, super.key});

  final List<Widget> cards;
  final bool large;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) {
      if (cards.isEmpty) return const SizedBox.shrink();
      final width = large ? 50.0 : 40.0;
      final height = large ? 67.0 : 54.0;
      final gap = cards.length == 1
          ? 0.0
          : ((limits.maxWidth - width - 12) / (cards.length - 1))
                .clamp(width * .54, width + 4)
                .toDouble();
      return Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width + gap * (cards.length - 1) + 12,
            height: height + (large ? 11 : 15),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < cards.length; index++)
                  Positioned(
                    key: cards[index].key,
                    left: 6 + index * gap,
                    top: (large ? 5 : 9) + 4 * _fanPosition(index).abs(),
                    child: Transform.rotate(
                      angle: _fanPosition(index) * .055,
                      child: cards[index],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  double _fanPosition(int index) =>
      cards.length == 1 ? 0 : 2 * index / (cards.length - 1) - 1;
}
