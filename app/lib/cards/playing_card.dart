import 'package:material_ui/material_ui.dart';

import 'standard_cards.dart';

class PlayingCard extends StatelessWidget {
  const PlayingCard(
    this.card, {
    this.wild = false,
    this.selected = false,
    this.portrait = false,
    this.compact = false,
    this.dimmed = false,
    this.onPressed,
    super.key,
  }) : _faceDown = false;

  const PlayingCard.faceDown({super.key})
    : card = null,
      wild = false,
      selected = false,
      portrait = true,
      compact = false,
      dimmed = false,
      onPressed = null,
      _faceDown = true;

  final int? card;
  final bool wild;
  final bool selected;
  final bool portrait;
  final bool compact;
  final bool dimmed;
  final VoidCallback? onPressed;
  final bool _faceDown;

  static const _corners = BorderRadius.all(Radius.circular(7));
  static const _gold = Color(0xFFDCAE60);

  @override
  Widget build(BuildContext context) {
    final width = compact
        ? 40.0
        : portrait
        ? 50.0
        : 44.0;
    final height = compact
        ? 54.0
        : portrait
        ? 67.0
        : 59.0;
    if (_faceDown) {
      return Semantics(
        label: 'Face-down card',
        child: ExcludeSemantics(
          child: Container(
            width: width,
            height: height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: _corners,
              border: Border.all(color: const Color(0xFF9D854D)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B4F3D), Color(0xFF202F28)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x251E1330),
                  offset: Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xBBDCAE60)),
              ),
              child: const Center(
                child: _SuitMark(CardSuit.diamonds, size: 17, color: _gold),
              ),
            ),
          ),
        ),
      );
    }

    final face = card;
    final suit = face == null ? null : cardSuit(face);
    final rank = face == null ? 'Joker' : cardRankLabel(face);
    final red = suit == CardSuit.diamonds || suit == CardSuit.hearts;
    final baseInk = red ? const Color(0xFFA02E40) : const Color(0xFF1B2821);
    final ink = dimmed
        ? Color.lerp(baseInk, const Color(0xFFDED7CD), .27)!
        : baseInk;
    final label = suit == null ? rank : '$rank ${suit.name}';
    final border = selected
        ? const Color(0xFFAC751D)
        : onPressed != null
        ? const Color(0xFFBDAA87)
        : const Color(0xFFD9CEB6);

    return Semantics(
      label: wild ? '$label, wild' : label,
      button: onPressed != null,
      enabled: !dimmed,
      selected: selected,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, selected ? -8 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: _corners,
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0x855B400F)
                    : const Color(0x231E1330),
                offset: Offset(0, selected ? 4 : 2),
                blurRadius: selected ? 6 : 3,
              ),
            ],
          ),
          child: Material(
            color: selected
                ? const Color(0xFFFFECC3)
                : dimmed
                ? const Color(0xFFEDE7DF)
                : const Color(0xFFFFFCF5),
            shape: RoundedRectangleBorder(
              borderRadius: _corners,
              side: BorderSide(color: border, width: selected ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (suit != null) ...[
                      Positioned(
                        left: 4,
                        top: 4,
                        child: _CardCorner(rank: rank, suit: suit, ink: ink),
                      ),
                      Center(
                        child: _SuitMark(
                          suit,
                          color: ink,
                          size: compact
                              ? 18
                              : portrait
                              ? 24
                              : 21,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: RotatedBox(
                          quarterTurns: 2,
                          child: _CardCorner(rank: rank, suit: suit, ink: ink),
                        ),
                      ),
                    ] else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 2,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                              color: Color(0xFF875313),
                            ),
                            Text(
                              'Joker',
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (wild)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7DCA4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            child: Text(
                              'Wild',
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                color: Color(0xFF623D06),
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardCorner extends StatelessWidget {
  const _CardCorner({
    required this.rank,
    required this.suit,
    required this.ink,
  });

  final String rank;
  final CardSuit suit;
  final Color ink;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 1,
    children: [
      Text(
        rank,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      _SuitMark(suit, size: 8, color: ink),
    ],
  );
}

class _SuitMark extends StatelessWidget {
  const _SuitMark(this.suit, {required this.size, required this.color});

  final CardSuit suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SuitPainter(suit, color));
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter(this.suit, this.color);

  final CardSuit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = switch (suit) {
      CardSuit.hearts =>
        Path()
          ..moveTo(12, 21.5)
          ..cubicTo(9.4, 18.5, 2, 13.6, 2, 8.2)
          ..cubicTo(2, 2.6, 9, 1.4, 12, 6.5)
          ..cubicTo(15, 1.4, 22, 2.6, 22, 8.2)
          ..cubicTo(22, 13.6, 14.6, 18.5, 12, 21.5)
          ..close(),
      CardSuit.diamonds =>
        Path()
          ..moveTo(12, 1)
          ..lineTo(21, 12)
          ..lineTo(12, 23)
          ..lineTo(3, 12)
          ..close(),
      CardSuit.spades =>
        Path()
          ..moveTo(12, 1)
          ..cubicTo(9, 5.6, 2.7, 9.2, 2.7, 14)
          ..cubicTo(2.7, 19, 7.9, 20, 10.9, 16.3)
          ..cubicTo(10.4, 19.9, 9.1, 21.2, 7.3, 22.5)
          ..lineTo(16.7, 22.5)
          ..cubicTo(14.9, 21.2, 13.6, 19.9, 13.1, 16.3)
          ..cubicTo(16.1, 20, 21.3, 19, 21.3, 14)
          ..cubicTo(21.3, 9.2, 15, 5.6, 12, 1)
          ..close(),
      CardSuit.clubs =>
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(12, 6), radius: 4.7))
          ..addOval(Rect.fromCircle(center: const Offset(6.6, 13), radius: 4.8))
          ..addOval(
            Rect.fromCircle(center: const Offset(17.4, 13), radius: 4.8),
          )
          ..moveTo(10, 10)
          ..lineTo(14, 10)
          ..cubicTo(13, 17, 14.5, 20, 16.6, 22.6)
          ..lineTo(7.4, 22.6)
          ..cubicTo(9.5, 20, 11, 17, 10, 10)
          ..close(),
    };
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(shape, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}
