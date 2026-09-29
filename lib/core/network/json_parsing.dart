import '../error/app_exception.dart';

/// Ajudantes para transformar a resposta do [ApiClient] em entidades,
/// convertendo qualquer erro de formato em [UnexpectedException].
T parseObject<T>(Object? json, T Function(Map<String, dynamic>) map) {
  if (json is! Map<String, dynamic>) throw const UnexpectedException();
  try {
    return map(json);
  } catch (e) {
    throw UnexpectedException(cause: e);
  }
}

List<T> parseList<T>(Object? json, T Function(Map<String, dynamic>) map) {
  if (json is! List) throw const UnexpectedException();
  try {
    return json.map((e) => map(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw UnexpectedException(cause: e);
  }
}
