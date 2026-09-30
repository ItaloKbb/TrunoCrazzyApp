import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class GetGameStateUseCase {
  final GameRepository _repository;

  const GetGameStateUseCase(this._repository);

  Future<GameState> call(int gameId) => _repository.getGameState(gameId);
}
