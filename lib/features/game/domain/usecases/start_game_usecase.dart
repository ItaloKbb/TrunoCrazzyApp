import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class StartGameUseCase {
  final GameRepository _repository;

  const StartGameUseCase(this._repository);

  Future<GameState> call(int gameId) => _repository.startGame(gameId);
}
