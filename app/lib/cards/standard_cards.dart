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
  return '${cardRankLabel(card)}${cardSuit(card).symbol}';
}

String cardRankLabel(int card) => switch (cardRank(card)) {
  11 => 'J',
  12 => 'Q',
  13 => 'K',
  14 => 'A',
  final rank => '$rank',
};
