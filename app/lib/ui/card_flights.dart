import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

enum LandingZone { trick, discard, fold }

typedef FeltCard = ({int serial, int? seat, Widget face});

class CardFlights extends StatefulWidget {
  const CardFlights({
    required this.cards,
    required this.origins,
    required this.round,
    required this.zone,
    super.key,
  });

  final List<FeltCard> cards;
  final List<Offset> origins;
  final int round;
  final LandingZone zone;

  @override
  State<CardFlights> createState() => _CardFlightsState();
}

class _CardFlightsState extends State<CardFlights> {
  late final Set<int> _seen;
  Set<int> _arrivals = {};

  @override
  void initState() {
    super.initState();
    // A table can mount with an already settled pile or trick.
    _seen = widget.cards.map((card) => card.serial).toSet();
  }

  @override
  void didUpdateWidget(CardFlights oldWidget) {
    super.didUpdateWidget(oldWidget);
    _arrivals = {
      for (final card in widget.cards)
        if (_seen.add(card.serial) && card.seat != null) card.serial,
    };
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, limits) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < widget.cards.length; i++)
            _flight(
              widget.cards[i],
              i,
              limits.biggest,
              MediaQuery.disableAnimationsOf(context),
            ),
        ],
      ),
    ),
  );

  Widget _flight(FeltCard card, int order, Size area, bool reduceMotion) {
    // Per-card scatter keeps the felt stable when another card lands or UI rebuilds.
    final random = math.Random(widget.round * 1543 + card.serial * 103);
    final drift = Offset(
      random.nextDouble() * 2 - 1,
      random.nextDouble() * 2 - 1,
    );
    final tilt = drift.dx * .23;
    final height = switch (widget.zone) {
      LandingZone.trick => math.min(
        44.0,
        math.min(area.width / 5, area.height * .60),
      ),
      LandingZone.discard => math.min(40.0, area.height * .68),
      LandingZone.fold => math.min(25.0, area.height * .46),
    };
    final width = height * .75;
    final landing = switch (widget.zone) {
      LandingZone.trick => Offset(
        area.width * (.19 + order * .205) + 6 * drift.dx,
        area.height * .58 + drift.dy * 5,
      ),
      LandingZone.discard => Offset(
        area.width * .75 + drift.dx * 5,
        area.height / 2 - 8 + drift.dy * 4,
      ),
      LandingZone.fold => Offset(
        area.width * .78 + drift.dx * 16,
        area.height * .68 + drift.dy * 6,
      ),
    };
    final seat = card.seat;
    final origin = seat == null ? landing : widget.origins[seat];
    final animate = _arrivals.contains(card.serial) && !reduceMotion;

    return Positioned(
      key: ValueKey(card.serial),
      left: landing.dx - width / 2,
      top: landing.dy - height / 2,
      width: width,
      height: height,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 365),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: animate ? 0 : 1, end: 1),
        child: FittedBox(child: card.face),
        builder: (context, t, face) => Transform.translate(
          offset:
              (origin - landing) * (1 - t) -
              Offset(0, 13 * math.sin(math.pi * t)),
          child: Transform.rotate(
            angle: tilt + drift.dy * (1 - t) * .55,
            child: Transform.scale(
              scale: 1 + .16 * math.sin(math.pi * t),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}
