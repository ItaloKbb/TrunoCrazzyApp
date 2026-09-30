import '../entities/auth_session.dart';

/// Armazenamento local da sessao. Nao existe logout na API.
abstract interface class SessionRepository {
  Future<void> saveSession(AuthSession session);
  Future<AuthSession?> getCurrentSession();
  Future<void> clearSession();
}
