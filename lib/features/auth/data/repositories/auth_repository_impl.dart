import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/login_credentials.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/auth_session_model.dart';

final class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;

  const AuthRepositoryImpl(this._api);

  @override
  Future<AuthSession> login(LoginCredentials credentials) async {
    final json = await _api.post('/auth/sessions', body: {
      'nickname': credentials.nickname.trim(),
      'code': credentials.code,
    });
    if (json is! Map<String, dynamic>) {
      throw const UnexpectedException();
    }
    try {
      return AuthSessionMapper.fromJson(json);
    } catch (e) {
      throw UnexpectedException(cause: e);
    }
  }
}
