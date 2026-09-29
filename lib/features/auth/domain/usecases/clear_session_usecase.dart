import '../repositories/session_repository.dart';

final class ClearSessionUseCase {
  final SessionRepository _sessions;

  const ClearSessionUseCase(this._sessions);

  Future<void> call() => _sessions.clearSession();
}
