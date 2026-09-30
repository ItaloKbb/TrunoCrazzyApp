import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/inputs/create_game_input.dart';
import '../../domain/repositories/game_repository.dart';
import '../mappers/game_state_mapper.dart';

final class GameRepositoryImpl implements GameRepository {
  final ApiClient _api;

  const GameRepositoryImpl(this._api);

  @override
  Future<GameState> createGame(CreateGameInput input) => _post('/games', {
        'name': input.name.trim(),
        'maxPlayers': input.maxPlayers,
        'initialCards': input.initialCards,
        'roundReward': input.roundReward,
        'emptyHandReward': input.emptyHandReward,
        'trophyPrice': input.trophyPrice,
      });

  @override
  Future<GameState> accessGame(String code) =>
      _post('/games/access', {'code': code.trim().toUpperCase()});

  @override
  Future<GameState> startGame(int gameId) => _post('/games/$gameId/start');

  @override
  Future<GameState> getGameState(int gameId) async =>
      _parse(await _api.get('/games/$gameId/state'));

  @override
  Future<GameState> playCard(int gameId, int handCardId) =>
      _post('/games/$gameId/plays', {'handCardId': handCardId});

  @override
  Future<GameState> answerPuzzle(
    int gameId,
    int challengeId,
    int alternativeIndex,
  ) =>
      _post('/games/$gameId/puzzle-answers', {
        'challengeId': challengeId,
        'alternativeIndex': alternativeIndex,
      });

  @override
  Future<GameState> buyTrophy(int gameId) => _post('/games/$gameId/trophies');

  @override
  Future<GameState> readyForNextRound(int gameId) =>
      _post('/games/$gameId/ready');

  @override
  Future<GameState> cancelGame(int gameId) => _post('/games/$gameId/cancel');

  Future<GameState> _post(String path, [Map<String, Object?>? body]) async =>
      _parse(await _api.post(path, body: body));

  GameState _parse(Object? json) {
    if (json is! Map<String, dynamic>) throw const UnexpectedException();
    try {
      return GameStateMapper.fromJson(json);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(cause: e);
    }
  }
}
