class AuthUser {
  final int id;
  final String name;
  final String item;
  final String? roleName;
  final AssignedPremise? premise;

  AuthUser({
    required this.id,
    required this.name,
    required this.item,
    this.roleName,
    this.premise,
  });

  bool get isAdmin => roleName?.toUpperCase() == 'ADMIN';
  bool get isPremiseManager =>
      roleName?.toUpperCase() == 'PREMISE_MANAGER';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final premise = json['premise'];
    return AuthUser(
      id: json['user_id'] ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      item: (json['item'] ?? '').toString(),
      roleName: role is Map ? role['name'] as String? : null,
      premise: premise is Map ? AssignedPremise.fromJson(premise) : null,
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
