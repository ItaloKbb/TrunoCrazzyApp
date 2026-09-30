final class GameSettings {
  final int maxPlayers;
  final int initialCards;
  final int roundReward;
  final int emptyHandReward;
  final int trophyPrice;

  const GameSettings({
    required this.maxPlayers,
    required this.initialCards,
    required this.roundReward,
    required this.emptyHandReward,
    required this.trophyPrice,
  });
}
