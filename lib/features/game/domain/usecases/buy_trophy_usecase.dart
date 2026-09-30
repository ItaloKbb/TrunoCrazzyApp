import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class BuyTrophyUseCase {
  final GameRepository _repository;

  const BuyTrophyUseCase(this._repository);

  Future<GameState> call(int gameId) => _repository.buyTrophy(gameId);
}
