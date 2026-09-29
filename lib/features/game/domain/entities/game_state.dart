import '../enums/game_direction.dart';
import '../enums/game_phase.dart';
import '../enums/round_status.dart';
import 'game_card.dart';
import 'game_play.dart';
import 'game_player.dart';
import 'game_settings.dart';
import 'pending_puzzle.dart';

final class GameState {
  final int id;
  final String code;
  final String name;
  final GamePhase phase;
  final int stateVersion;
  final GameSettings settings;
  final GameDirection direction;
  final int roundNumber;
  final RoundStatus? roundStatus;
  final GameCard? vira;

  /// ID de um [GamePlayer], nao de um `PlayerUser`.
  final int? currentPlayerId;
  final List<GamePlayer> players;
  final List<GamePlay> plays;

  /// Somente a mao do usuario autenticado.
  final List<GameCard> hand;
  final PendingPuzzle? pendingPuzzle;
  final int? winnerPlayerId;

  const GameState({
    required this.id,
    required this.code,
    required this.name,
    required this.phase,
    required this.stateVersion,
    required this.settings,
    required this.direction,
    required this.roundNumber,
    this.roundStatus,
    this.vira,
    this.currentPlayerId,
    required this.players,
    required this.plays,
    required this.hand,
    this.pendingPuzzle,
    this.winnerPlayerId,
  });
}
