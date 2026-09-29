import '../../../../core/error/app_exception.dart';
import '../../domain/entities/auth_session.dart';

enum LoginStatus { idle, loading, success, failure }

final class LoginState {
  final LoginStatus status;
  final AuthSession? session;
  final AppException? error;

  const LoginState._({required this.status, this.session, this.error});

  const LoginState.idle() : this._(status: LoginStatus.idle);
  const LoginState.loading() : this._(status: LoginStatus.loading);
  const LoginState.success(AuthSession session)
      : this._(status: LoginStatus.success, session: session);
  const LoginState.failure(AppException error)
      : this._(status: LoginStatus.failure, error: error);

  bool get isLoading => status == LoginStatus.loading;
}
