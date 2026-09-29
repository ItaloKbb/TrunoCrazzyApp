import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_parsing.dart';
import '../../domain/entities/catalog_card.dart';
import '../../domain/repositories/card_catalog_repository.dart';
import '../mappers/catalog_mapper.dart';

final class CardCatalogRepositoryImpl implements CardCatalogRepository {
  final ApiClient _api;

  const CardCatalogRepositoryImpl(this._api);

  @override
  Future<List<CatalogCard>> listCards() async =>
      parseList(await _api.get('/cards'), CatalogMapper.card);

  @override
  Future<CatalogCard> getCard(int id) async =>
      parseObject(await _api.get('/cards/$id'), CatalogMapper.card);
}
