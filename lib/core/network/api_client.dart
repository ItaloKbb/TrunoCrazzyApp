import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/app_exception.dart';

typedef TokenProvider = Future<String?> Function();

/// Cliente HTTP da API Truno Crazzy. Anexa `X-Player-Token` automaticamente
/// e converte falhas em [AppException] preservando a mensagem da API.
class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    this.tokenProvider,
    this.onUnauthorized,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl;

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _codespacesUrl =
      'https://verbose-broccoli-p5wx9jvjpqq3674g-3000.app.github.dev';

  /// Pode ser sobrescrita com `--dart-define=API_BASE_URL=...`.
  static String get defaultBaseUrl {
    final url = _envBaseUrl.isNotEmpty ? _envBaseUrl : _codespacesUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  final http.Client _client;
  final String baseUrl;
  final TokenProvider? tokenProvider;

  /// Chamado em respostas 401 para limpar/invalidar a sessão local.
  final Future<void> Function()? onUnauthorized;

  Future<Object?> post(String path, {Map<String, Object?>? body}) =>
      _send('POST', path, body: body);

  Future<Object?> get(String path) => _send('GET', path);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final token = await tokenProvider?.call();
    if (token != null) headers['X-Player-Token'] = token;

    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      );
    } catch (e) {
      throw NetworkException(cause: e);
    }

    final raw = utf8.decode(response.bodyBytes);
    Object? decoded;
    if (raw.isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final message = (decoded is Map && decoded['message'] is String)
        ? decoded['message'] as String
        : 'Erro ${response.statusCode} ao comunicar com o servidor.';
    switch (response.statusCode) {
      case 400:
        throw BadRequestException(message: message);
      case 401:
        await onUnauthorized?.call();
        throw UnauthorizedException(message: message);
      case 403:
        throw ForbiddenException(message: message);
      case 404:
        throw NotFoundException(message: message);
      case 409:
        throw ConflictException(message: message);
      default:
        throw UnexpectedException(message: message);
    }
  }
}
