import 'package:dio/dio.dart';

import '../config/api_routes.dart';
import '../models/managed_user.dart';
import 'api_client.dart';

/// Gestión de usuarios y roles desde el panel de administración.
class UserAdminService {
  final ApiClient _apiClient;

  UserAdminService([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Obtiene todos los usuarios registrados con su rol actual
  Future<List<ManagedUser>> getUsers() async {
    try {
      final response = await _dio.get(ApiRoutes.users);
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => ManagedUser.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al obtener usuarios.');
    }
  }

  /// Obtiene el catálogo de roles disponibles (EMPLOYEE, ADMIN, ...)
  Future<List<AppRole>> getRoles() async {
    try {
      final response = await _dio.get(ApiRoutes.roles);
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => AppRole.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al obtener roles.');
    }
  }

  /// Asigna un rol a un usuario (p. ej. otorgar o quitar permisos de ADMIN)
  Future<ManagedUser> updateUserRole(int userId, int roleId) async {
    try {
      final response = await _dio.put(
        ApiRoutes.userRole(userId),
        data: {'role_id': roleId},
      );
      return ManagedUser.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al actualizar el rol.');
    }
  }
}
