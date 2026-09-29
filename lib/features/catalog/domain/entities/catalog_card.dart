import '../../../game/domain/enums/card_suit.dart';
import '../../../game/domain/enums/card_value.dart';

/// Carta do catalogo publico: sem handCardId nem skill embutida.
final class CatalogCard {
  final int id;
  final CardValue value;
  final CardSuit suit;

  const CatalogCard({
    required this.id,
    required this.value,
    required this.suit,
  });
}
