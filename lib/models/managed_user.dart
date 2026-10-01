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

  /// Dispositivo vinculado en cada aplicación ([ClientPlatform]) y desde
  /// cuándo. Si una aplicación no aparece, la cuenta aún no tiene dispositivo
  /// ahí (nunca entró, o administración desvinculó el anterior).
  final Map<ClientPlatform, DateTime> devices;

  ManagedUser({
    required this.id,
    required this.name,
    required this.item,
    this.role,
    this.premise,
    this.username,
    this.devices = const {},
  });

  bool get isAdmin => role?.name.toUpperCase() == 'ADMIN';
  bool get managesPremise => role?.name.toUpperCase() == kManagePremiseRole;
  bool get isEmployee => role?.name.toUpperCase() == 'EMPLOYEE';

  /// Aplicaciones que puede usar según su rol (mismas reglas que el servidor).
  List<ClientPlatform> get platforms => [
    if (isAdmin || managesPremise) ClientPlatform.web,
    if (isAdmin || isEmployee) ClientPlatform.mobile,
  ];

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final roleJson = json['role'];
    final premiseJson = json['premise'];
    final devices = <ClientPlatform, DateTime>{};
    for (final device in (json['devices'] as List? ?? const [])) {
      if (device is! Map) continue;
      final platform = ClientPlatform.fromApi(device['platform']?.toString());
      final boundAt = DateTime.tryParse('${device['bound_at']}');
      if (platform != null && boundAt != null) devices[platform] = boundAt;
    }
    return ManagedUser(
      id: json['user_id'] ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      item: (json['item'] ?? '').toString(),
      role: roleJson is Map<String, dynamic>
          ? AppRole.fromJson(roleJson)
          : null,
      premise: premiseJson is Map ? UserPremise.fromJson(premiseJson) : null,
      username: json['username'] as String?,
      devices: devices,
    );
  }

  ManagedUser copyWith({
    AppRole? role,
    UserPremise? premise,
    Map<ClientPlatform, DateTime>? devices,
  }) => ManagedUser(
    id: id,
    name: name,
    item: item,
    role: role ?? this.role,
    premise: premise ?? this.premise,
    username: username,
    devices: devices ?? this.devices,
  );
}

/// Aplicación desde la que se usa una cuenta; cada una tiene su propio
/// dispositivo autorizado.
enum ClientPlatform {
  web('web', 'Panel web', 'navegador'),
  mobile('mobile', 'App móvil', 'teléfono');

  const ClientPlatform(this.apiValue, this.label, this.deviceNoun);

  final String apiValue;
  final String label;
  final String deviceNoun;

  static ClientPlatform? fromApi(String? value) {
    for (final p in values) {
      if (p.apiValue == value) return p;
    }
    return null;
  }
}

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
