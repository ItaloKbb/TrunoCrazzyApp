import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class PlayCardUseCase {
  final GameRepository _repository;

  const PlayCardUseCase(this._repository);

  Future<GameState> call(int gameId, int handCardId) => _repository.playCard(gameId, handCardId);
}
