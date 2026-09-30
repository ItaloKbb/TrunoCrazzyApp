import '../entities/auth_session.dart';
import '../repositories/session_repository.dart';

final class GetCurrentSessionUseCase {
  final SessionRepository _sessions;

  const GetCurrentSessionUseCase(this._sessions);

  Future<AuthSession?> call() => _sessions.getCurrentSession();
}
