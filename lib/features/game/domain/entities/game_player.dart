/// Jogador dentro de uma partida. [id] NAO e o `PlayerUser.id`.
final class GamePlayer {
  final int id;
  final String nickname;
  final int position;
  final int matchCoins;
  final int trophies;
  final int handSize;
  final bool ready;
  final bool host;

  const GamePlayer({
    required this.id,
    required this.nickname,
    required this.position,
    required this.matchCoins,
    required this.trophies,
    required this.handSize,
    required this.ready,
    required this.host,
  });
}
