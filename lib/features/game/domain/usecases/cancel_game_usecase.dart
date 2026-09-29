import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class CancelGameUseCase {
  final GameRepository _repository;

  const CancelGameUseCase(this._repository);

  Future<GameState> call(int gameId) => _repository.cancelGame(gameId);
}
