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

  /// Fecha en la que la cuenta quedó vinculada a un dispositivo (app móvil).
  /// Null si nunca inició sesión o si administración desvinculó el anterior.
  final DateTime? deviceBoundAt;

  ManagedUser({
    required this.id,
    required this.name,
    required this.item,
    this.role,
    this.premise,
    this.username,
    this.deviceBoundAt,
  });

  bool get isAdmin => role?.name.toUpperCase() == 'ADMIN';
  bool get managesPremise => role?.name.toUpperCase() == kManagePremiseRole;
  bool get isEmployee => role?.name.toUpperCase() == 'EMPLOYEE';
  bool get hasBoundDevice => deviceBoundAt != null;

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
      deviceBoundAt: json['device_bound_at'] != null
          ? DateTime.tryParse(json['device_bound_at'].toString())
          : null,
    );
  }

  ManagedUser copyWith({
    AppRole? role,
    UserPremise? premise,
    Object? deviceBoundAt = _unset,
  }) => ManagedUser(
    id: id,
    name: name,
    item: item,
    role: role ?? this.role,
    premise: premise ?? this.premise,
    username: username,
    deviceBoundAt: deviceBoundAt == _unset
        ? this.deviceBoundAt
        : deviceBoundAt as DateTime?,
  );
}

const _unset = Object();

/// Límite de salidas de un empleado: cuántas veces puede salir (en total y a
/// un mismo predio) dentro del período elegido. `null` en un límite significa
/// "sin tope".
class LeavePolicy {
  final String period;
  final int? maxExits;
  final int? maxExitsPerPremise;

  const LeavePolicy({
    required this.period,
    this.maxExits,
    this.maxExitsPerPremise,
  });

  bool get hasLimits => maxExits != null || maxExitsPerPremise != null;

  static const List<String> periods = ['day', 'week', 'month'];

  static String periodLabel(String period) => switch (period) {
    'day' => 'Por día',
    'week' => 'Por semana',
    'month' => 'Por mes',
    _ => period,
  };

  factory LeavePolicy.fromJson(Map<String, dynamic> json) => LeavePolicy(
    period: (json['period'] ?? 'day').toString(),
    maxExits: (json['max_exits'] as num?)?.toInt(),
    maxExitsPerPremise: (json['max_exits_per_premise'] as num?)?.toInt(),
  );

  static const empty = LeavePolicy(period: 'day');
}
