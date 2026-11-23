import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

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
    this.notice,
    super.key,
  });

  final List<SceneSeat> seats;
  final int localSeat;
  final int activeSeat;
  final String status;
  final String progress;
  final Widget center;
  final Widget hand;
  final String? notice;

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
      builder: (context, limits) => SingleChildScrollView(
        child: SizedBox(
          height: math.max(198 + 6 * labelGrowth, limits.maxHeight),
          width: limits.maxWidth,
          child: TableScenery(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
              child: Column(
                children: [
                  SizedBox(
                    height: 67 + 2 * labelGrowth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < others.length; i++)
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top:
                                    others.length > 2 &&
                                        (i == 0 || i == others.length - 1)
                                    ? 8
                                    : 0,
                              ),
                              child: _SeatedPlayer(
                                index: others[i],
                                seat: seats[others[i]],
                                active: others[i] == activeSeat,
                              ),
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
                          width: (limits.maxWidth * .235)
                              .clamp(84, 154)
                              .toDouble(),
                          child: _TableReadout(
                            top: progress,
                            main: status,
                            highlight: localSeat == activeSeat,
                          ),
                        ),
                        Expanded(child: Center(child: center)),
                        SizedBox(
                          width: (limits.maxWidth * .16)
                              .clamp(57, 104)
                              .toDouble(),
                          child: _TableReadout(
                            top: seats[localSeat].name,
                            main: seats[localSeat].detail,
                            highlight: localSeat == activeSeat,
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
      ),
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
      const ColoredBox(color: Color(0xFF1B192A)),
      Image.asset(
        'assets/tables/blue_wood.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
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
          colors: [Color(0xFFE3A665), Color(0xFF8A492D), Color(0xFF4B2B26)],
          stops: [0, .48, 1],
        ).createShader(outer),
    );
    canvas.drawOval(
      outer.deflate(2),
      Paint()
        ..color = const Color(0x889C5935)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawOval(inner.inflate(1), Paint()..color = const Color(0xFF4A2C24));
    canvas.drawOval(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.28),
          radius: .72,
          colors: [Color(0xFF347964), Color(0xFF216450), Color(0xFF12372E)],
          stops: [0, .50, 1],
        ).createShader(inner),
    );
    canvas.drawOval(
      inner.deflate(7),
      Paint()
        ..color = const Color(0x7795D1AF)
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
  });

  final int index;
  final SceneSeat seat;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const palettes = [
      Color(0xFF624559),
      Color(0xFF3E546D),
      Color(0xFF775136),
      Color(0xFF40635E),
      Color(0xFF704943),
    ];
    final accent = active ? const Color(0xFFFCDD95) : const Color(0xFFB88957);
    final type = Theme.of(context).textTheme;
    final cpu = seat.name.startsWith('CPU ');
    return Tooltip(
      message: '${seat.name} · ${seat.detail}',
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palettes[index % palettes.length],
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: active ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? accent.withValues(alpha: .36)
                        : const Color(0xA5120B0B),
                    blurRadius: active ? 10 : 4,
                  ),
                ],
              ),
              child: Icon(
                cpu ? Icons.smart_toy_rounded : Icons.person_rounded,
                size: 16,
                color: const Color(0xFFF9E4C4),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 46),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF65482E)
                    : const Color(0xEE21192B),
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
                color: active ? accent : const Color(0xFFE3EDDC),
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

class _TableReadout extends StatelessWidget {
  const _TableReadout({
    required this.top,
    required this.main,
    required this.highlight,
  });

  final String top;
  final String main;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Tooltip(
      message: '$top · $main',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xB5172B25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight
                ? const Color(0x997B9D75)
                : const Color(0x553A8D72),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                top,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelSmall?.copyWith(
                  color: const Color(0xFFD3DECD),
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
                      : const Color(0xFFF0F4E3),
                  fontWeight: FontWeight.w800,
                  height: 1.17,
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
            height: height + 15,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < cards.length; index++)
                  Positioned(
                    key: cards[index].key,
                    left: 6 + index * gap,
                    top: 9 + 4 * _fanPosition(index).abs(),
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
