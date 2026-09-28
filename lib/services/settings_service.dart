import 'package:dio/dio.dart';

import '../config/api_routes.dart';
import 'api_client.dart';

class QrSettings {
  final int ttlSeconds;
  final int minSeconds;
  final int maxSeconds;

  const QrSettings({
    required this.ttlSeconds,
    required this.minSeconds,
    required this.maxSeconds,
  });

  factory QrSettings.fromJson(Map<String, dynamic> json) => QrSettings(
    ttlSeconds: (json['qr_ttl_seconds'] as num?)?.toInt() ?? 300,
    minSeconds: (json['qr_ttl_seconds_min'] as num?)?.toInt() ?? 30,
    maxSeconds: (json['qr_ttl_seconds_max'] as num?)?.toInt() ?? 3600,
  );
}

/// Configuración global del sistema editable desde el panel de administración.
class SettingsService {
  final ApiClient _apiClient;

  SettingsService([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  Future<QrSettings> getQrSettings() async {
    try {
      final response = await _dio.get(ApiRoutes.settingsQr);
      return QrSettings.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo obtener la configuración del QR.',
      );
    }
  }

  Future<void> updateQrTtl(int ttlSeconds) async {
    try {
      await _dio.put(ApiRoutes.settingsQr, data: {'qr_ttl_seconds': ttlSeconds});
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo actualizar el tiempo de vida del QR.',
      );
    }
  }
}
