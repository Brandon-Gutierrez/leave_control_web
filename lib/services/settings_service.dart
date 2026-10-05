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

  Dio get dio => _apiClient.dio;
  Dio get _dio => dio;

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

/// Límite de salidas general: se aplica igual a todas las personas.
class LeaveLimits {
  final String period;
  final int? maxExits;
  final int? maxExitsPerPremise;

  const LeaveLimits({required this.period, this.maxExits, this.maxExitsPerPremise});

  factory LeaveLimits.fromJson(Map<String, dynamic> json) => LeaveLimits(
    period: (json['period'] ?? 'day').toString(),
    maxExits: (json['max_exits'] as num?)?.toInt(),
    maxExitsPerPremise: (json['max_exits_per_premise'] as num?)?.toInt(),
  );

  static const periods = ['day', 'week', 'month'];

  static String periodLabel(String p) => switch (p) {
    'day' => 'Cada día',
    'week' => 'Cada semana',
    'month' => 'Cada mes',
    _ => p,
  };
}

extension LeaveLimitsApi on SettingsService {
  Future<LeaveLimits> getLeaveLimits() async {
    try {
      final r = await dio.get(ApiRoutes.settingsLeaveLimits);
      return LeaveLimits.fromJson(r.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'No se pudo obtener el límite de salidas.');
    }
  }

  Future<LeaveLimits> updateLeaveLimits(LeaveLimits limits) async {
    try {
      final r = await dio.put(
        ApiRoutes.settingsLeaveLimits,
        data: {
          'period': limits.period,
          'max_exits': limits.maxExits,
          'max_exits_per_premise': limits.maxExitsPerPremise,
        },
      );
      return LeaveLimits.fromJson(r.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'No se pudo guardar el límite de salidas.');
    }
  }
}
