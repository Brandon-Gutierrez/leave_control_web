import '../../../core/constants/role_names.dart';

/// Persona que inició sesión, con su rol y, si es responsable, su predio.
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

  AuthUser({
    required this.id,
    required this.name,
    required this.item,
    this.roleName,
    this.premise,
    this.photoUrl,
    this.jobTitle,
  });

  bool get isAdmin => RoleNames.matches(roleName, RoleNames.admin);

  /// Responsable de un predio (rol MANAGE_PREMISE): experiencia bloqueada.
  bool get isPremiseManager =>
      RoleNames.matches(roleName, RoleNames.managePremise);

  /// Cargo mostrado en el módulo de usuario.
  String get roleTitle {
    switch (roleName?.toUpperCase()) {
      case RoleNames.admin:
        return 'Administrador del sistema';
      case RoleNames.managePremise:
        return 'Responsable de predio';
      case RoleNames.employee:
        return 'Empleado';
      default:
        return roleName ?? 'Usuario';
    }
  }

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

class AssignedPremise {
  final int id;
  final String name;

  const AssignedPremise({required this.id, required this.name});

  factory AssignedPremise.fromJson(Map<dynamic, dynamic> json) {
    return AssignedPremise(
      id: int.tryParse('${json['premise_id'] ?? json['id'] ?? 0}') ?? 0,
      name: (json['name'] ?? '').toString().trim(),
    );
  }
}

String? _photo(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
