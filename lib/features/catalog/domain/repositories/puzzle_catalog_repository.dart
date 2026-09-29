import '../entities/puzzle_definition.dart';

/// Nao responde desafios de partida; isso e do GameRepository.
abstract interface class PuzzleCatalogRepository {
  /// GET /puzzles
  Future<List<PuzzleDefinition>> listPuzzles();

  /// GET /puzzles/{id}
  Future<PuzzleDefinition> getPuzzle(int id);
}
