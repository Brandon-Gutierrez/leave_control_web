/// Rutas del backend (routes/api.php) usadas por el panel de administración.
class ApiRoutes {
  static const String csrfCookie = '/sanctum/csrf-cookie';

  // Sesión
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';

  // Administración
  static const String premises = '/api/admin/premises';
  static const String reasons = '/api/admin/reasons';
  static const String syncReasons = '/api/admin/reasons/sync';

  static String premiseReasons(int premiseId) =>
      '/api/admin/premises/$premiseId/reasons';

  static String premiseQrTokens(int premiseId) =>
      '/api/admin/premises/$premiseId/qr-tokens';
}
