/// Puzzle publico. Nunca contem a alternativa correta.
final class PuzzleDefinition {
  final int id;
  final String question;
  final List<String> alternatives;

  const PuzzleDefinition({
    required this.id,
    required this.question,
    required this.alternatives,
  });
}
