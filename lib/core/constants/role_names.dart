/// Nombres de los roles del backend (`roles.name`).
abstract final class RoleNames {
  static const String admin = 'ADMIN';
  static const String employee = 'EMPLOYEE';

  /// Responsable de un único predio: solo ve la pantalla de QR del suyo.
  static const String managePremise = 'MANAGE_PREMISE';

  /// El rol llamado [roleName] es [expected] (el servidor no distingue
  /// mayúsculas de minúsculas).
  static bool matches(String? roleName, String expected) =>
      roleName?.toUpperCase() == expected;

  /// Nombre del rol para mostrar en listas y selectores.
  static String label(String roleName) => switch (roleName.toUpperCase()) {
    admin => 'Administrador',
    managePremise => 'Gestor de predio',
    employee => 'Empleado',
    _ => roleName,
  };
}
