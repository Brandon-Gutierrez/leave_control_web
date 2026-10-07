import 'package:dio/dio.dart';

/// Error de API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  /// Usa el mensaje que envió el servidor; si no hay, [fallback] o uno genérico.
  factory ApiException.fromDio(DioException e, {String? fallback}) {
    final data = e.response?.data;
    final serverMessage = data is Map ? data['message'] as String? : null;
    return ApiException(
      serverMessage ?? fallback ?? 'Error de conexión con el servidor.',
      statusCode: e.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
