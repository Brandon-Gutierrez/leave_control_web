import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../config/api_routes.dart';
import 'platform/browser_http.dart';
import 'platform/device_storage.dart';

/// Error de API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  factory ApiException.fromDio(DioException e, {String? fallback}) {
    final data = e.response?.data;
    final serverMessage = data is Map ? data['message'] as String? : null;
    return ApiException(
      serverMessage ?? fallback ?? 'Error de conexión con el servidor.',
      statusCode: e.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}

/// Cliente HTTP único para la app web. Usa las cookies del navegador
/// (sesión de Laravel Sanctum) y envía el encabezado X-XSRF-TOKEN.
class ApiClient {
  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {
          'Accept': 'application/json',
          // El backend decide qué roles entran según la aplicación: en la
          // web, ADMIN y MANAGE_PREMISE (los empleados usan la app móvil).
          'X-Client-Platform': 'web',
        },
      ),
    );

    dio.httpClientAdapter = createHttpAdapter();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Cada cuenta queda vinculada a un único navegador: el servidor lo
          // comprueba en todas las peticiones, no solo al iniciar sesión.
          options.headers['DeviceId'] = readDeviceId();
          if (_requiresCsrf(options.method)) {
            var xsrfToken = readCookie('XSRF-TOKEN');
            if (xsrfToken == null) {
              await ensureCsrfCookie();
              xsrfToken = readCookie('XSRF-TOKEN');
            }
            if (xsrfToken != null) {
              options.headers['X-XSRF-TOKEN'] = Uri.decodeComponent(xsrfToken);
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio dio;

  /// Solicita a Laravel la cookie XSRF-TOKEN.
  Future<void> ensureCsrfCookie() async {
    final csrfDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
      ..httpClientAdapter = dio.httpClientAdapter;
    await csrfDio.get(ApiRoutes.csrfCookie);
  }

  bool _requiresCsrf(String method) {
    final m = method.toUpperCase();
    return m != 'GET' && m != 'HEAD' && m != 'OPTIONS';
  }
}
