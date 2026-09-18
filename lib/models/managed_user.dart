/// Rol asignable a un usuario (EMPLOYEE, ADMIN, ...).
class AppRole {
  final int id;
  final String name;

  AppRole({required this.id, required this.name});

  factory AppRole.fromJson(Map<String, dynamic> json) => AppRole(
        id: json['role_id'] ?? 0,
        name: (json['name'] ?? '').toString(),
      );
}

/// Usuario del sistema tal como lo ve el panel de administración.
class ManagedUser {
  final int id;
  final String name;
  final String item;
  final AppRole? role;

  ManagedUser({
    required this.id,
    required this.name,
    required this.item,
    this.role,
  });

  bool get isAdmin => role?.name.toUpperCase() == 'ADMIN';

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final roleJson = json['role'];
    return ManagedUser(
      id: json['user_id'] ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      item: (json['item'] ?? '').toString(),
      role: roleJson is Map<String, dynamic> ? AppRole.fromJson(roleJson) : null,
    );
  }

  ManagedUser copyWith({AppRole? role}) => ManagedUser(
        id: id,
        name: name,
        item: item,
        role: role ?? this.role,
      );
}
