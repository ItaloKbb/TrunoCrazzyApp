import '../entities/game_state.dart';
import '../inputs/create_game_input.dart';
import '../repositories/game_repository.dart';

final class CreateGameUseCase {
  final GameRepository _repository;

  const CreateGameUseCase(this._repository);

  Future<GameState> call(CreateGameInput input) => _repository.createGame(input);
}
