import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/reason_catalog.dart';

/// Catálogo de motivos de salida y su sincronización con Comteco.
class ReasonCatalogService {
  final ApiClient _apiClient;

  ReasonCatalogService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Motivos activos y retirados, y el estado de la última sincronización.
  Future<ReasonCatalog> getCatalog() async {
    try {
      final response = await _dio.get(ApiRoutes.reasonCatalog);
      return ReasonCatalog.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo obtener el catálogo de motivos.',
      );
    }
  }

  /// Sincroniza ahora con Comteco (acción manual del administrador).
  Future<ReasonSyncResult> syncNow() async {
    try {
      final response = await _dio.post(ApiRoutes.syncReasons);
      return ReasonSyncResult.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'Error al sincronizar los motivos.',
      );
    }
  }
}
