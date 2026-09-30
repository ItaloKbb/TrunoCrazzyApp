import '../entities/game_state.dart';
import '../inputs/create_game_input.dart';

/// Todas as mutacoes devolvem o estado agregado atualizado.
abstract interface class GameRepository {
  /// POST /games
  Future<GameState> createGame(CreateGameInput input);

  /// POST /games/access (codigo de 6 caracteres)
  Future<GameState> accessGame(String code);

  /// POST /games/{id}/start
  Future<GameState> startGame(int gameId);

  /// GET /games/{id}/state
  Future<GameState> getGameState(int gameId);

  /// POST /games/{id}/plays
  Future<GameState> playCard(int gameId, int handCardId);

  /// POST /games/{id}/puzzle-answers
  Future<GameState> answerPuzzle(
    int gameId,
    int challengeId,
    int alternativeIndex,
  );

  /// POST /games/{id}/trophies
  Future<GameState> buyTrophy(int gameId);

  /// POST /games/{id}/ready
  Future<GameState> readyForNextRound(int gameId);

  /// POST /games/{id}/cancel
  Future<GameState> cancelGame(int gameId);
}
