final class CreateGameInput {
  final String name;
  final int maxPlayers;
  final int initialCards;
  final int roundReward;
  final int emptyHandReward;
  final int trophyPrice;

  const CreateGameInput({
    required this.name,
    required this.maxPlayers,
    required this.initialCards,
    required this.roundReward,
    required this.emptyHandReward,
    required this.trophyPrice,
  });

  bool get isValid =>
      name.trim().isNotEmpty &&
      name.length <= 60 &&
      maxPlayers >= 2 &&
      maxPlayers <= 6 &&
      initialCards >= 1 &&
      initialCards <= 10 &&
      roundReward >= 0 &&
      emptyHandReward >= 0 &&
      trophyPrice > 0;
}
