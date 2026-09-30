import '../entities/puzzle_definition.dart';
import '../repositories/puzzle_catalog_repository.dart';

final class ListPuzzlesUseCase {
  final PuzzleCatalogRepository _repository;

  const ListPuzzlesUseCase(this._repository);

  Future<List<PuzzleDefinition>> call() => _repository.listPuzzles();
}
