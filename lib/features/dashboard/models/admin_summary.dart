import '../../reasons/models/reason_catalog.dart';

/// Contadores de la pantalla de inicio (`GET /admin/summary`): el servidor los
/// calcula, así "Inicio" no descarga las listas completas solo para contarlas.
class AdminSummary {
  final int premises;
  final int premisesWithoutLocation;
  final int premisesWithoutManager;
  final int premisesWithoutReasons;
  final int users;
  final int admins;

  /// Cuentas de responsable de predio (0 si el servidor no lo informa).
  final int managers;
  final int managersWithoutPremise;
  final int employeesWithoutApp;

  /// Motivos que Comteco ofrece hoy, sin los retirados (0 si el servidor no
  /// lo informa).
  final int activeReasons;

  /// Última sincronización de motivos con Comteco (null si nunca se hizo).
  final ReasonSyncStatus? reasonsSync;

  const AdminSummary({
    required this.premises,
    required this.premisesWithoutLocation,
    required this.premisesWithoutManager,
    required this.premisesWithoutReasons,
    required this.users,
    required this.admins,
    this.managers = 0,
    required this.managersWithoutPremise,
    required this.employeesWithoutApp,
    this.activeReasons = 0,
    this.reasonsSync,
  });

  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    int count(Object? map, String key) =>
        map is Map ? (map[key] as num?)?.toInt() ?? 0 : 0;
    final premises = json['premises'];
    final users = json['users'];
    final reasons = json['reasons'];
    final sync = json['reasons_sync'];
    return AdminSummary(
      premises: count(premises, 'total'),
      premisesWithoutLocation: count(premises, 'without_location'),
      premisesWithoutManager: count(premises, 'without_manager'),
      premisesWithoutReasons: count(premises, 'without_reasons'),
      users: count(users, 'total'),
      admins: count(users, 'admins'),
      managers: count(users, 'managers'),
      managersWithoutPremise: count(users, 'managers_without_premise'),
      employeesWithoutApp: count(users, 'employees_without_app'),
      activeReasons: count(reasons, 'active'),
      reasonsSync: sync is Map<String, dynamic>
          ? ReasonSyncStatus.fromJson(sync)
          : null,
    );
  }
}
