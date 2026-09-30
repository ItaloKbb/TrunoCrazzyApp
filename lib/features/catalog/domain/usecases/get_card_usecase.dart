import '../entities/catalog_card.dart';
import '../repositories/card_catalog_repository.dart';

final class GetCardUseCase {
  final CardCatalogRepository _repository;

  const GetCardUseCase(this._repository);

  Future<CatalogCard> call(int id) => _repository.getCard(id);
}
