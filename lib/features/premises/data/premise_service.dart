import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/premise.dart';
import '../models/reason.dart';

class PremiseService {
  final ApiClient _apiClient;

  PremiseService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Obtiene la lista completa de predios con sus razones asignadas y el
  /// radio (metros) de la geocerca que usa el servidor.
  Future<({List<Premise> premises, double? geofenceRadiusMeters})>
  getPremisesListing() async {
    try {
      final response = await _dio.get(ApiRoutes.premises);
      final List<dynamic> data = response.data['data'] ?? [];
      return (
        premises: data.map((json) => Premise.fromJson(json)).toList(),
        geofenceRadiusMeters: (response.data['geofence_radius_m'] as num?)
            ?.toDouble(),
      );
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

  /// Crea un predio con su ubicación, responsable y motivos permitidos.
  Future<Premise> createPremise({
    required String name,
    required double latitude,
    required double longitude,
    List<String> reasonNames = const [],
    int? managerUserId,
  }) async {
    try {
      final response = await _dio.post(
        ApiRoutes.premises,
        data: {
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          if (reasonNames.isNotEmpty) 'reasons': reasonNames,
          'manager_user_id': ?managerUserId,
        },
      );
      return Premise.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al crear el predio.');
    }
  }

  /// Guarda nombre, ubicación y motivos sin tocar al responsable. Sin
  /// coordenadas (un predio que todavía no tiene ubicación) solo viajan el
  /// nombre y los motivos.
  Future<Premise> updateDetails(
    int premiseId, {
    required String name,
    double? latitude,
    double? longitude,
    required List<String> reasonNames,
  }) async {
    try {
      final response = await _dio.put(
        ApiRoutes.premise(premiseId),
        data: {
          'name': name,
          'latitude': ?latitude,
          'longitude': ?longitude,
          'reasons': reasonNames,
        },
      );
      return Premise.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al guardar el predio.');
    }
  }

  /// Cambia solo los motivos de salida que ofrece el predio (la lista
  /// completa; el servidor reemplaza la anterior).
  Future<Premise> setReasons(int premiseId, List<String> reasonNames) async {
    try {
      final response = await _dio.put(
        ApiRoutes.premise(premiseId),
        data: {'reasons': reasonNames},
      );
      return Premise.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'Error al cambiar los motivos del predio.',
      );
    }
  }

  /// Cambia solo al responsable del predio (`userId` null lo deja sin
  /// responsable). El servidor cierra la sesión del responsable anterior y
  /// mueve aquí al nuevo si ya tenía otro predio.
  Future<Premise> assignManager(int premiseId, int? userId) async {
    try {
      final response = await _dio.put(
        ApiRoutes.premise(premiseId),
        data: {'manager_user_id': userId},
      );
      return Premise.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'Error al cambiar el responsable del predio.',
      );
    }
  }
}
