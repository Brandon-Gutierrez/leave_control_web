/// Nombre del rol que solo puede generar el QR de su predio asignado.
const String kManagePremiseRole = 'MANAGE_PREMISE';

/// Representa esta entidad.
class AuthUser {
  final int id;
  final String name;
  final String item;
  final String? roleName;
  final AssignedPremise? premise;

  /// Foto de perfil si el servidor la envía; null usa la imagen predeterminada.
  final String? photoUrl;

  /// Cargo real de la persona según el sistema de RR.HH. (p. ej. Funcionario).
  final String? jobTitle;

  /// Ejecuta la tarea.
  AuthUser({
    required this.id,
    required this.name,
    required this.item,
    this.roleName,
    this.premise,
    this.photoUrl,
    this.jobTitle,
  });

  bool get isAdmin => roleName?.toUpperCase() == 'ADMIN';

  /// Cargo mostrado en el módulo de usuario.
  String get cargo {
    switch (roleName?.toUpperCase()) {
      case 'ADMIN':
        return 'Administrador del sistema';
      case kManagePremiseRole:
        return 'Responsable de predio';
      case 'EMPLOYEE':
        return 'Empleado';
      default:
        return roleName ?? 'Usuario';
    }
  }

  /// Responsable de un predio (rol MANAGE_PREMISE): experiencia bloqueada.
  bool get isPremiseManager => roleName?.toUpperCase() == kManagePremiseRole;

  /// Ejecuta la tarea.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final premise = json['premise'];
    return AuthUser(
      id: json['user_id'] ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      item: (json['item'] ?? '').toString(),
      roleName: role is Map ? role['name'] as String? : null,
      premise: premise is Map ? AssignedPremise.fromJson(premise) : null,
      photoUrl: _photo(json['photo_url'] ?? json['photo'] ?? json['avatar']),
      jobTitle: _photo(json['job_title']),
    );
  }
}

/// Representa esta entidad.
class AssignedPremise {
  final int id;
  final String name;

  /// Ejecuta la tarea.
  const AssignedPremise({required this.id, required this.name});

  /// Ejecuta la tarea.
  factory AssignedPremise.fromJson(Map<dynamic, dynamic> json) {
    return AssignedPremise(
      id: int.tryParse('${json['premise_id'] ?? json['id'] ?? 0}') ?? 0,
      name: (json['name'] ?? '').toString().trim(),
    );
  }
}

/// Ejecuta la tarea.
String? _photo(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
