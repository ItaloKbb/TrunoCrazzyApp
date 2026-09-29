import '../../domain/entities/auth_session.dart';
import '../../domain/entities/player_user.dart';

/// Conversão entre JSON (`AuthResponse`/`UserResponse`) e entidades de domínio.
abstract final class AuthSessionMapper {
  static AuthSession fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      token: json['token'] as String,
      user: PlayerUser(
        id: (user['id'] as num).toInt(),
        nickname: user['nickname'] as String,
        rankingPoints: (user['rankingPoints'] as num).toInt(),
      ),
    );
  }

  static Map<String, dynamic> toJson(AuthSession session) => {
        'token': session.token,
        'user': {
          'id': session.user.id,
          'nickname': session.user.nickname,
          'rankingPoints': session.user.rankingPoints,
        },
      };
}
