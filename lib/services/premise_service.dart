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

  /// Crea un predio y, opcionalmente, le asigna motivos de salida por nombre
  Future<Premise> createPremise(String name, List<String> reasonNames) async {
    try {
      final response = await _dio.post(
        ApiRoutes.premises,
        data: {
          'name': name,
          if (reasonNames.isNotEmpty) 'reasons': reasonNames,
        },
      );
      return Premise.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al crear el predio.');
    }
  }

  /// Reemplaza los motivos de salida asignados a un predio.
  Future<void> updatePremiseReasons(
    int premiseId,
    List<String> reasonNames,
  ) async {
    try {
      await _dio.put(
        ApiRoutes.premiseReasons(premiseId),
        data: {'reasons': reasonNames},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'Error al actualizar los motivos del predio.',
      );
    }
  }

  /// Sincroniza el catálogo de motivos de salida con el servicio externo
  Future<String> syncReasons() async {
    try {
      final response = await _dio.post(ApiRoutes.syncReasons);
      return (response.data['message'] as String?) ??
          'Motivos sincronizados correctamente.';
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al sincronizar los motivos.');
    }
  }
}
