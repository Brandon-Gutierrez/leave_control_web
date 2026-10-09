import 'package:flutter/foundation.dart';

import '../../premises/data/premise_service.dart';
import '../../premises/models/premise.dart';
import '../../premises/models/reason.dart';
import '../../users/data/user_admin_service.dart';
import '../../users/models/managed_user.dart';

/// Datos del panel de administración compartidos por todas las secciones.
///
/// Inicio, Predios y Usuarios muestran los mismos datos (predios, usuarios,
/// roles y motivos). Cada uno se pide al backend por separado y, cuando
/// cambia, avisa a todas las secciones a la vez: así crear un predio se ve de
/// inmediato en Usuarios sin tener que refrescar.
class AdminDataStore extends ChangeNotifier {
  AdminDataStore._();

  static final AdminDataStore instance = AdminDataStore._();

  final PremiseService _premiseService = PremiseService();
  final UserAdminService _userService = UserAdminService();

  List<Premise> _premises = const [];
  List<ManagedUser> _users = const [];
  List<AppRole> _roles = const [];
  List<Reason> _reasons = const [];

  List<Premise> get premises => _premises;
  List<ManagedUser> get users => _users;
  List<AppRole> get roles => _roles;
  List<Reason> get reasons => _reasons;

  Future<void> refreshPremises() async {
    _premises = await _premiseService.getPremisesWithReasons();
    notifyListeners();
  }

  Future<void> refreshUsers() async {
    _users = await _userService.getUsers();
    notifyListeners();
  }

  Future<void> refreshRoles() async {
    _roles = await _userService.getRoles();
    notifyListeners();
  }

  Future<void> refreshReasons() async {
    _reasons = await _premiseService.getAllReasons();
    notifyListeners();
  }

  /// Vuelve a pedir lo que suele cambiar (predios, usuarios y motivos) sin
  /// mostrar errores: se usa tras una acción o al cambiar de sección, y si
  /// falla se conservan los datos que ya había.
  Future<void> refreshQuietly() async {
    await Future.wait([
      refreshPremises().catchError((Object _) {}),
      refreshUsers().catchError((Object _) {}),
      refreshReasons().catchError((Object _) {}),
    ]);
  }

  /// Olvida los datos (al cerrar sesión).
  void clear() {
    _premises = const [];
    _users = const [];
    _roles = const [];
    _reasons = const [];
    notifyListeners();
  }
}
