import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class AccessGameUseCase {
  final GameRepository _repository;

  const AccessGameUseCase(this._repository);

  Future<GameState> call(String code) => _repository.accessGame(code);
}
