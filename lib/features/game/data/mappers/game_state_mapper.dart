import '../../domain/entities/game_card.dart';
import '../../domain/entities/game_play.dart';
import '../../domain/entities/game_player.dart';
import '../../domain/entities/game_settings.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/entities/pending_puzzle.dart';
import 'enum_mappers.dart';

typedef Json = Map<String, dynamic>;

/// JSON (`GameStateResponse`) -> entidades de dominio.
/// Atencao: a API usa as chaves `valor` e `naipe` nas cartas.
abstract final class GameStateMapper {
  static GameState fromJson(Json j) => GameState(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String,
        name: j['name'] as String,
        phase: EnumMappers.phase(j['phase']),
        stateVersion: (j['stateVersion'] as num).toInt(),
        settings: _settings(j['settings'] as Json),
        direction: EnumMappers.direction(j['direction']),
        roundNumber: (j['roundNumber'] as num).toInt(),
        roundStatus: EnumMappers.roundStatusOrNull(j['roundStatus']),
        vira: j['vira'] == null ? null : _card(j['vira'] as Json),
        currentPlayerId: (j['currentPlayerId'] as num?)?.toInt(),
        players: _list(j['players'], _player),
        plays: _list(j['plays'], _play),
        hand: _list(j['hand'], _card),
        pendingPuzzle: j['pendingPuzzle'] == null
            ? null
            : _puzzle(j['pendingPuzzle'] as Json),
        winnerPlayerId: (j['winnerPlayerId'] as num?)?.toInt(),
      );

  static List<T> _list<T>(Object? raw, T Function(Json) map) =>
      ((raw as List?) ?? const []).map((e) => map(e as Json)).toList();

  static GameSettings _settings(Json j) => GameSettings(
        maxPlayers: (j['maxPlayers'] as num).toInt(),
        initialCards: (j['initialCards'] as num).toInt(),
        roundReward: (j['roundReward'] as num).toInt(),
        emptyHandReward: (j['emptyHandReward'] as num).toInt(),
        trophyPrice: (j['trophyPrice'] as num).toInt(),
      );

  static GamePlayer _player(Json j) => GamePlayer(
        id: (j['id'] as num).toInt(),
        nickname: j['nickname'] as String,
        position: (j['position'] as num).toInt(),
        matchCoins: (j['matchCoins'] as num).toInt(),
        trophies: (j['trophies'] as num).toInt(),
        handSize: (j['handSize'] as num).toInt(),
        ready: j['ready'] as bool,
        host: j['host'] as bool,
      );

  static GameCard _card(Json j) => GameCard(
        handCardId: (j['handCardId'] as num?)?.toInt(),
        catalogCardId: (j['catalogCardId'] as num).toInt(),
        valor: EnumMappers.cardValue(j['valor']),
        naipe: EnumMappers.cardSuit(j['naipe']),
        skill: EnumMappers.skillTypeOrNull(j['skill']),
      );

  static GamePlay _play(Json j) => GamePlay(
        playerId: (j['playerId'] as num).toInt(),
        nickname: j['nickname'] as String,
        card: _card(j['card'] as Json),
        order: (j['order'] as num).toInt(),
      );

  static PendingPuzzle _puzzle(Json j) => PendingPuzzle(
        challengeId: (j['challengeId'] as num).toInt(),
        question: j['question'] as String,
        alternatives: (j['alternatives'] as List).cast<String>(),
      );
}
