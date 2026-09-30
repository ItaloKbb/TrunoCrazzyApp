import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/login_credentials.dart';
import '../../domain/usecases/login_usecase.dart';
import '../state/login_state.dart';

class LoginController extends ChangeNotifier {
  final LoginUseCase _login;

  LoginController(this._login);

  LoginState _state = const LoginState.idle();
  LoginState get state => _state;

  Future<void> login(String nickname, String code) async {
    if (_state.isLoading) return;
    final credentials = LoginCredentials(nickname: nickname, code: code);
    if (!credentials.isValid) {
      _emit(
        const LoginState.failure(
          BadRequestException(
            message:
                'Informe um apelido (até 30 caracteres) e um código de 4 a 30 caracteres.',
          ),
        ),
      );
      return;
    }
    _emit(const LoginState.loading());
    try {
      _emit(LoginState.success(await _login(credentials)));
    } on AppException catch (e) {
      _emit(LoginState.failure(e));
    } catch (e) {
      _emit(LoginState.failure(UnexpectedException(cause: e)));
    }
  }

  void _emit(LoginState state) {
    _state = state;
    notifyListeners();
  }
}
