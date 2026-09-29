final class PendingPuzzle {
  final int challengeId;
  final String question;
  final List<String> alternatives;

  const PendingPuzzle({
    required this.challengeId,
    required this.question,
    required this.alternatives,
  });
}
