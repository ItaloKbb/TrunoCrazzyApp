import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_parsing.dart';
import '../../domain/entities/puzzle_definition.dart';
import '../../domain/repositories/puzzle_catalog_repository.dart';
import '../mappers/catalog_mapper.dart';

final class PuzzleCatalogRepositoryImpl implements PuzzleCatalogRepository {
  final ApiClient _api;

  const PuzzleCatalogRepositoryImpl(this._api);

  @override
  Future<List<PuzzleDefinition>> listPuzzles() async =>
      parseList(await _api.get('/puzzles'), CatalogMapper.puzzle);

  @override
  Future<PuzzleDefinition> getPuzzle(int id) async =>
      parseObject(await _api.get('/puzzles/$id'), CatalogMapper.puzzle);
}
