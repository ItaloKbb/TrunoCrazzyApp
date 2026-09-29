import '../entities/puzzle_definition.dart';
import '../repositories/puzzle_catalog_repository.dart';

final class GetPuzzleUseCase {
  final PuzzleCatalogRepository _repository;

  const GetPuzzleUseCase(this._repository);

  Future<PuzzleDefinition> call(int id) => _repository.getPuzzle(id);
}
