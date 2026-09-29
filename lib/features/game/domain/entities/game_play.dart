import 'game_card.dart';

final class GamePlay {
  final int playerId;
  final String nickname;
  final GameCard card;
  final int order;

  const GamePlay({
    required this.playerId,
    required this.nickname,
    required this.card,
    required this.order,
  });
}
