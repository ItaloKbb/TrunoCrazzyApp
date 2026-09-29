import '../entities/catalog_card.dart';

abstract interface class CardCatalogRepository {
  /// GET /cards
  Future<List<CatalogCard>> listCards();

  /// GET /cards/{id}
  Future<CatalogCard> getCard(int id);
}
