import 'package:dio/dio.dart';

import '../config/api_routes.dart';
import '../models/auth_user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Inicia sesión con Sanctum (cookie de sesión + XSRF).
  Future<AuthUser> login(String username, String password) async {
    try {
      await _apiClient.ensureCsrfCookie();
      final response = await _dio.post(
        ApiRoutes.login,
        data: {'username': username, 'password': password},
      );
      return AuthUser.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: 'No se pudo iniciar sesión.');
    }
  }

  /// Devuelve el usuario de la sesión actual o null si no hay sesión.
  Future<AuthUser?> currentUser() async {
    try {
      final response = await _dio.get(ApiRoutes.me);
      return AuthUser.fromJson(response.data['user']);
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiRoutes.logout);
    } on DioException {
      // La sesión ya no es válida en el servidor; no hay nada más que hacer.
    }
  }
}
