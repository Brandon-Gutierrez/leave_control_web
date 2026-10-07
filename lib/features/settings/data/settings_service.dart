import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/leave_limits.dart';
import '../models/qr_settings.dart';

/// Configuración global del sistema editable desde el panel de administración.
class SettingsService {
  final ApiClient _apiClient;

  SettingsService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

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
      await _dio.put(
        ApiRoutes.settingsQr,
        data: {'qr_ttl_seconds': ttlSeconds},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo actualizar el tiempo de vida del QR.',
      );
    }
  }

  Future<LeaveLimits> getLeaveLimits() async {
    try {
      final response = await _dio.get(ApiRoutes.settingsLeaveLimits);
      return LeaveLimits.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo obtener el límite de salidas.',
      );
    }
  }

  Future<LeaveLimits> updateLeaveLimits(LeaveLimits limits) async {
    try {
      final response = await _dio.put(
        ApiRoutes.settingsLeaveLimits,
        data: {
          'period': limits.period,
          'max_exits': limits.maxExits,
          'max_exits_per_premise': limits.maxExitsPerPremise,
        },
      );
      return LeaveLimits.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo guardar el límite de salidas.',
      );
    }
  }
}
