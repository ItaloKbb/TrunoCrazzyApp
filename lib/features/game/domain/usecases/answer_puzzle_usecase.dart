import '../entities/game_state.dart';
import '../repositories/game_repository.dart';

final class AnswerPuzzleUseCase {
  final GameRepository _repository;

  const AnswerPuzzleUseCase(this._repository);

  Future<GameState> call(int gameId, int challengeId, int alternativeIndex) => _repository.answerPuzzle(gameId, challengeId, alternativeIndex);
}
