import 'auth_user.dart' show kManagePremiseRole;

/// Rol asignable a un usuario (EMPLOYEE, ADMIN, ...).
class AppRole {
  final int id;
  final String name;

  AppRole({required this.id, required this.name});

  factory AppRole.fromJson(Map<String, dynamic> json) =>
      AppRole(id: json['role_id'] ?? 0, name: (json['name'] ?? '').toString());
}

class UserPremise {
  final int id;
  final String name;

  const UserPremise({required this.id, required this.name});

  factory UserPremise.fromJson(Map<dynamic, dynamic> json) => UserPremise(
    id: int.tryParse('${json['premise_id'] ?? json['id'] ?? 0}') ?? 0,
    name: (json['name'] ?? '').toString(),
  );
}

/// Usuario del sistema tal como lo ve el panel de administración.
class ManagedUser {
  final int id;
  final String name;
  final String item;
  final AppRole? role;
  final UserPremise? premise;

  /// Usuario de acceso (solo las cuentas locales de responsable lo tienen).
  final String? username;

  ManagedUser({
    required this.id,
    required this.name,
    required this.item,
    this.role,
    this.premise,
    this.username,
  });

  bool get isAdmin => role?.name.toUpperCase() == 'ADMIN';
  bool get managesPremise => role?.name.toUpperCase() == kManagePremiseRole;

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final roleJson = json['role'];
    final premiseJson = json['premise'];
    return ManagedUser(
      id: json['user_id'] ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      item: (json['item'] ?? '').toString(),
      role: roleJson is Map<String, dynamic>
          ? AppRole.fromJson(roleJson)
          : null,
      premise: premiseJson is Map ? UserPremise.fromJson(premiseJson) : null,
      username: json['username'] as String?,
    );
  }

  ManagedUser copyWith({AppRole? role, UserPremise? premise}) => ManagedUser(
    id: id,
    name: name,
    item: item,
    role: role ?? this.role,
    premise: premise ?? this.premise,
    username: username,
  );
}
