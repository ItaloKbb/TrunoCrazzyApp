import '../entities/auth_session.dart';
import '../entities/login_credentials.dart';
import '../repositories/auth_repository.dart';
import '../repositories/session_repository.dart';

final class LoginUseCase {
  final AuthRepository _auth;
  final SessionRepository _sessions;

  const LoginUseCase(this._auth, this._sessions);

  Future<AuthSession> call(LoginCredentials credentials) async {
    final session = await _auth.login(credentials);
    await _sessions.saveSession(session);
    return session;
  }
}
