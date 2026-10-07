import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/managed_user.dart';

/// Resultado de crear una cuenta de responsable de predio.
class CreatedManager {
  final ManagedUser user;

  /// Contraseña generada por el servidor. Solo llega si administración no
  /// escribió una; se muestra una única vez.
  final String? generatedPassword;

  const CreatedManager({required this.user, this.generatedPassword});
}

/// Gestión de usuarios y roles desde el panel de administración.
class UserAdminService {
  final ApiClient _apiClient;

  UserAdminService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

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

  /// Asigna un rol a un usuario. Para el rol MANAGE_PREMISE se envía en la
  /// misma petición el predio del que será responsable.
  Future<ManagedUser> updateUserRole(
    int userId,
    int roleId, {
    int? premiseId,
  }) async {
    try {
      final response = await _dio.put(
        ApiRoutes.userRole(userId),
        data: {'role_id': roleId, 'premise_id': ?premiseId},
      );
      return ManagedUser.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'Error al actualizar el rol.');
    }
  }

  /// Cambia el predio de un responsable que ya tiene el rol MANAGE_PREMISE.
  Future<ManagedUser> assignUserPremise(int userId, int premiseId) async {
    try {
      final response = await _dio.put(
        ApiRoutes.userPremise(userId),
        data: {'premise_id': premiseId},
      );
      return ManagedUser.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'Error al asignar el predio al usuario.',
      );
    }
  }

  /// Cambia la contraseña de un responsable. Sin [password] el servidor genera
  /// una nueva y la devuelve (solo se muestra una vez).
  Future<String?> resetManagerPassword(int userId, {String? password}) async {
    try {
      final response = await _dio.put(
        ApiRoutes.userPassword(userId),
        data: {if (password != null && password.isNotEmpty) 'password': password},
      );
      return response.data['generated_password'] as String?;
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo cambiar la contraseña.',
      );
    }
  }


  /// Desvincula el dispositivo de una cuenta en [platform] y cierra su sesión
  /// ahí, para que pueda iniciar sesión desde un dispositivo nuevo.
  Future<void> resetUserDevice(int userId, ClientPlatform platform) async {
    try {
      await _dio.post(
        ApiRoutes.userDeviceReset(userId),
        data: {'platform': platform.apiValue},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo desvincular el dispositivo.',
      );
    }
  }

  /// Crea una cuenta de responsable de predio con usuario y contraseña propios.
  Future<CreatedManager> createPremiseManager({
    required String name,
    required String username,
    required int premiseId,
    String? password,
  }) async {
    try {
      final response = await _dio.post(
        ApiRoutes.premiseManagers,
        data: {
          'name': name,
          'username': username,
          'premise_id': premiseId,
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      return CreatedManager(
        user: ManagedUser.fromJson(response.data['data']),
        generatedPassword: response.data['generated_password'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(
        e,
        fallback: 'No se pudo crear la cuenta del responsable.',
      );
    }
  }
}
