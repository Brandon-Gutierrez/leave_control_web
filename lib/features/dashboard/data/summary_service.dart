import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/admin_summary.dart';

class SummaryService {
  final ApiClient _apiClient;

  SummaryService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Contadores de la pantalla de inicio.
  Future<AdminSummary> getSummary() async {
    try {
      final response = await _dio.get(ApiRoutes.adminSummary);
      return AdminSummary.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al obtener el resumen.');
    }
  }
}
