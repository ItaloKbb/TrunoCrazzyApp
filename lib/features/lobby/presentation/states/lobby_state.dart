import '../../../../core/error/app_exception.dart';
import '../../../game/domain/entities/game_state.dart';

enum LobbyStatus { idle, loading, success, failure }

final class LobbyState {
  final LobbyStatus status;
  final GameState? game;
  final AppException? error;

  const LobbyState._({required this.status, this.game, this.error});

  const LobbyState.idle() : this._(status: LobbyStatus.idle);
  const LobbyState.loading() : this._(status: LobbyStatus.loading);
  const LobbyState.success(GameState game)
      : this._(status: LobbyStatus.success, game: game);
  const LobbyState.failure(AppException error)
      : this._(status: LobbyStatus.failure, error: error);

  bool get isLoading => status == LobbyStatus.loading;      
}