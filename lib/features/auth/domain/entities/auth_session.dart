import 'player_user.dart';

final class AuthSession {
  final String token;
  final PlayerUser user;

  const AuthSession({required this.token, required this.user});
}
