final class LoginCredentials {
  static const int maxNicknameLength = 30;
  static const int minCodeLength = 4;
  static const int maxCodeLength = 30;

  final String nickname;
  final String code;

  const LoginCredentials({required this.nickname, required this.code});

  bool get isValid =>
      nickname.trim().isNotEmpty &&
      nickname.length <= maxNicknameLength &&
      code.length >= minCodeLength &&
      code.length <= maxCodeLength;
}
