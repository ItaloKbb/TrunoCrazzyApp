import '../entities/catalog_card.dart';
import '../repositories/card_catalog_repository.dart';

final class ListCardsUseCase {
  final CardCatalogRepository _repository;

  const ListCardsUseCase(this._repository);

  Future<List<CatalogCard>> call() => _repository.listCards();
}
