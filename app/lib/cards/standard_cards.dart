const standardDeckSize = 52;

enum CardSuit {
  clubs('♣'),
  diamonds('♦'),
  hearts('♥'),
  spades('♠');

  const CardSuit(this.symbol);
  final String symbol;
}

CardSuit cardSuit(int card) => CardSuit.values[card ~/ 13];
int cardRank(int card) => card % 13 + 2;

String cardLabel(int card) {
  final rank = cardRank(card);
  final face = switch (rank) {
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    14 => 'A',
    _ => '$rank',
  };
  return '$face${cardSuit(card).symbol}';
}
