import '../entities/auth_session.dart';
import '../entities/login_credentials.dart';

abstract interface class AuthRepository {
  /// POST /auth/sessions
  Future<AuthSession> login(LoginCredentials credentials);
}
