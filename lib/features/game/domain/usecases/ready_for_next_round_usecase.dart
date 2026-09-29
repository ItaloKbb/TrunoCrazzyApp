import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class ReadyForNextRoundUseCase {
  final GameRepository _repository;

  const ReadyForNextRoundUseCase(this._repository);

  Future<GameState> call(int gameId) => _repository.readyForNextRound(gameId);
}
