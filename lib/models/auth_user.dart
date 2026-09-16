class AuthUser {
  final int id;
  final String name;
  final String item;
  final String? roleName;

  AuthUser({
    required this.id,
    required this.name,
    required this.item,
    this.roleName,
  });

  bool get isAdmin => roleName?.toUpperCase() == 'ADMIN';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    return AuthUser(
      id: json['user_id'] ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      item: (json['item'] ?? '').toString(),
      roleName: role is Map ? role['name'] as String? : null,
    );
  }
}
