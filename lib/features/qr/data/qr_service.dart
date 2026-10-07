import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/qr_token.dart';

/// Genera los códigos QR del predio asignado al responsable.
class QrService {
  final ApiClient _apiClient;

  QrService([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Genera un token para el predio del usuario autenticado.
  Future<QrToken> createQrToken() async {
    try {
      final response = await _dio.post(ApiRoutes.managerQrToken);
      return QrToken(
        token: response.data['token'] as String,
        ttl: (response.data['TTL'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.parse(response.data['expires_at'] as String),
        premiseName: (response.data['premise'] is Map)
            ? (response.data['premise']['name'] as String?)
            : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al generar el QR.');
    }
  }
}
