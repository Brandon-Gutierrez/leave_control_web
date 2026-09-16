import 'package:dio/dio.dart';

import '../config/api_routes.dart';
import '../models/premise_model.dart';
import 'api_client.dart';

class QrToken {
  final String token;
  final int ttl;

  QrToken({required this.token, required this.ttl});
}

class PremiseService {
  final ApiClient _apiClient;

  PremiseService([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Obtiene la lista completa de predios con sus razones asignadas
  Future<List<Premise>> getPremisesWithReasons() async {
    try {
      final response = await _dio.get(ApiRoutes.premises);
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => Premise.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al obtener predios.');
    }
  }

  /// Obtiene el catálogo completo de razones de salida disponibles
  Future<List<Reason>> getAllReasons() async {
    try {
      final response = await _dio.get(ApiRoutes.reasons);
      final List<dynamic> reasonsList = response.data['reasons'] ?? [];
      return reasonsList.map((reason) => Reason.fromJson(reason)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al obtener motivos.');
    }
  }

  /// Genera un nuevo token dinámico para el QR de un predio
  Future<QrToken> createQrToken(int premiseId) async {
    try {
      final response = await _dio.post(ApiRoutes.premiseQrTokens(premiseId));
      return QrToken(
        token: response.data['token'],
        ttl: response.data['TTL'] ?? 60,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al generar el QR.');
    }
  }
}
