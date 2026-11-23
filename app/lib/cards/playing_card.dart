import 'package:material_ui/material_ui.dart';

import 'standard_cards.dart';

class PlayingCard extends StatelessWidget {
  const PlayingCard(
    this.card, {
    this.wild = false,
    this.selected = false,
    this.portrait = false,
    this.onPressed,
    super.key,
  });

  final int? card;
  final bool wild;
  final bool selected;
  final bool portrait;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final suit = card == null ? null : cardSuit(card);
    final red = suit == CardSuit.diamonds || suit == CardSuit.hearts;
    final ink = red ? const Color(0xFFAD294A) : const Color(0xFF271E30);
    final label = card == null
        ? 'Joker'
        : '${cardRankLabel(card)} ${suit!.name}';
    final rank = Text(
      card == null ? 'Joker' : cardRankLabel(card),
      style: TextStyle(
        color: ink,
        fontSize: card == null ? 13 : 17,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    );
    final pip = Text(
      suit == null ? '✦' : '${suit.symbol}\uFE0E',
      style: TextStyle(color: ink, fontSize: portrait ? 24 : 17, height: 1),
    );

    return Semantics(
      label: wild ? '$label, wild' : label,
      button: onPressed != null,
      selected: selected,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? const Color(0xFFF1DDF7) : const Color(0xFFFFFCF6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected
                  ? const Color(0xFF71338B)
                  : onPressed != null
                  ? const Color(0xFF9770AA)
                  : const Color(0xFFD8CDD4),
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: portrait ? 43 : 44,
                minHeight: portrait ? 58 : 48,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (portrait) ...[
                      rank,
                      const SizedBox(height: 4),
                      pip,
                    ] else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 3,
                        children: [rank, pip],
                      ),
                    if (wild)
                      const Text(
                        'Wild',
                        style: TextStyle(
                          color: Color(0xFF794D0A),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
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
