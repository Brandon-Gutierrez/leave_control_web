/// Contadores de la pantalla de inicio (`GET /admin/summary`): el servidor los
/// calcula, así "Inicio" no descarga las listas completas solo para contarlas.
class AdminSummary {
  final int premises;
  final int premisesWithoutLocation;
  final int premisesWithoutManager;
  final int premisesWithoutReasons;
  final int users;
  final int admins;
  final int managersWithoutPremise;
  final int employeesWithoutApp;

  const AdminSummary({
    required this.premises,
    required this.premisesWithoutLocation,
    required this.premisesWithoutManager,
    required this.premisesWithoutReasons,
    required this.users,
    required this.admins,
    required this.managersWithoutPremise,
    required this.employeesWithoutApp,
  });

  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    int count(Object? map, String key) =>
        map is Map ? (map[key] as num?)?.toInt() ?? 0 : 0;
    final premises = json['premises'];
    final users = json['users'];
    return AdminSummary(
      premises: count(premises, 'total'),
      premisesWithoutLocation: count(premises, 'without_location'),
      premisesWithoutManager: count(premises, 'without_manager'),
      premisesWithoutReasons: count(premises, 'without_reasons'),
      users: count(users, 'total'),
      admins: count(users, 'admins'),
      managersWithoutPremise: count(users, 'managers_without_premise'),
      employeesWithoutApp: count(users, 'employees_without_app'),
    );
  }
}
