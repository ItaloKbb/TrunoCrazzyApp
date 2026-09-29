abstract class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException({required this.message, this.cause});

  @override
  String toString() => message;
}

final class UnexpectedException extends AppException {
  const UnexpectedException({
    super.message =
        'Ocorreu um erro inesperado. Por favor, tente novamente mais tarde.',
    super.cause,
  });
}

/// HTTP 400: requisicao invalida. Preserva a mensagem devolvida pela API.
final class BadRequestException extends AppException {
  const BadRequestException({required super.message, super.cause});
}

/// HTTP 401: token ausente/invalido. A sessao local deve ser invalidada.
final class UnauthorizedException extends AppException {
  const UnauthorizedException({required super.message, super.cause});
}

/// HTTP 403: acao nao permitida para o jogador.
final class ForbiddenException extends AppException {
  const ForbiddenException({required super.message, super.cause});
}

/// HTTP 404: recurso nao encontrado.
final class NotFoundException extends AppException {
  const NotFoundException({required super.message, super.cause});
}

/// HTTP 409: conflito de estado. Consulte o estado da partida de novo.
final class ConflictException extends AppException {
  const ConflictException({required super.message, super.cause});
}

/// Falha de conexão (servidor fora do ar, sem internet, timeout).
final class NetworkException extends AppException {
  const NetworkException({
    super.message =
        "Não foi possível conectar ao servidor. Verifique sua conexão.",
    super.cause,
  });
}
