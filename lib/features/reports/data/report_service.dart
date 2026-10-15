import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/leave_report.dart';

/// Reporte de salidas para el administrador.
class ReportService {
  final ApiClient _apiClient;

  ReportService([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<LeaveReport> getLeaveReport({
    required DateTime from,
    required DateTime to,
    int? premiseId,
    String? reason,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        ApiRoutes.leaveReport,
        queryParameters: {
          'from': _ymd(from),
          'to': _ymd(to),
          'premise_id': ?premiseId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      return LeaveReport.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo obtener el reporte de salidas.',
      );
    }
  }
}
