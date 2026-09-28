/// Rutas del backend (routes/api.php) usadas por el panel de administración.
class ApiRoutes {
  static const String csrfCookie = '/sanctum/csrf-cookie';

  // Sesión
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';

  // Administración - predios
  static const String premises = '/api/admin/premises';
  static const String reasons = '/api/admin/reasons';
  static const String syncReasons = '/api/admin/reasons/sync';

  static String premise(int premiseId) => '/api/admin/premises/$premiseId';
  static String premiseReasons(int premiseId) =>
      '/api/admin/premises/$premiseId/reasons';

  static const String managerQrToken = '/api/manager/qr-token';

  // Administración - usuarios y roles
  static const String users = '/api/admin/users';
  static const String roles = '/api/admin/roles';

  static String userRole(int userId) => '/api/admin/users/$userId/role';

  static String userPremise(int userId) => '/api/admin/users/$userId/premise';
  static String userPassword(int userId) => '/api/admin/users/$userId/password';
  static String userDeviceReset(int userId) =>
      '/api/admin/users/$userId/device/reset';
  static String userLeavePolicy(int userId) =>
      '/api/admin/users/$userId/leave-policy';

  static const String premiseManagers = '/api/admin/users/premise-managers';

  // Administración - configuración
  static const String settingsQr = '/api/admin/settings/qr';
}
