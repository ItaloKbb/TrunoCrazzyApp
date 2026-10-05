import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../game/domain/entities/game_state.dart';
import '../../../game/domain/inputs/create_game_input.dart';
import '../../../game/domain/usecases/access_game_usecase.dart';
import '../../../game/domain/usecases/create_game_usecase.dart';
import '../states/lobby_state.dart';

class LobbyController extends ChangeNotifier {
  final CreateGameUseCase _create;
  final AccessGameUseCase _access;

  LobbyController({
    required CreateGameUseCase create,
    required AccessGameUseCase access,
  })  : _create = create,
        _access = access;

  LobbyState _state = const LobbyState.idle();
  LobbyState get state => _state;

  void _emit(LobbyState state) {
    _state = state;
    notifyListeners();                                           // 6
  }

  Future<void> create(CreateGameInput input) {
    if (!input.isValid) {
      _emit(const LobbyState.failure(BadRequestException(message:'Confira os campos: há valores fora do permitido.'
      )));
      return Future.value();
    }
    return _run(() => _create(input));
  }

  Future<void> access(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.length != 6) {
      _emit(const LobbyState.failure(BadRequestException(message: 'O código da partida tem 6 caracteres.',
      )));
      return Future.value();
    }
    return _run(() => _access(normalized));
  }

  void reset() => _emit(const LobbyState.idle());

  Future<void> _run(Future<GameState> Function() action) async {
    if (_state.isLoading) return;
    _emit(const LobbyState.loading());
    try {
      _emit(LobbyState.success(await action()));
    } on AppException catch (e) {
      _emit(LobbyState.failure(e));
    } catch (e) {
      _emit(LobbyState.failure(UnexpectedException(cause: e)));
    }
  }
}