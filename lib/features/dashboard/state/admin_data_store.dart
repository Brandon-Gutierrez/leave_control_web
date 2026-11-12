import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../map/constants/map_defaults.dart';
import '../../premises/data/premise_service.dart';
import '../../premises/models/premise.dart';
import '../../premises/models/reason.dart';
import '../../reasons/data/reason_catalog_service.dart';
import '../../reasons/models/reason_catalog.dart';
import '../../users/data/user_admin_service.dart';
import '../../users/models/managed_user.dart';
import '../data/summary_service.dart';
import '../models/admin_summary.dart';

enum LoadStatus { idle, loading, loaded, error }

/// Un dato del panel (predios, usuarios, roles...) con su propio estado de
/// carga. Cada uno se pide por separado, así que las pantallas muestran cada
/// parte en cuanto llega y una falla no afecta a las demás.
///
/// - Una sola petición a la vez: si ya hay una en curso, [load] devuelve esa.
/// - Vigencia: un dato cargado hace menos de [AdminDataStore.freshFor] no se
///   vuelve a pedir, salvo con `force`.
/// - Si una recarga falla se conserva el último valor bueno.
class StoreResource<T> {
  StoreResource._(this._store, this._fetch, this._empty, this._failMessage)
    : value = _empty;

  final AdminDataStore _store;
  final Future<T> Function() _fetch;
  final T _empty;
  final String _failMessage;

  T value;
  LoadStatus status = LoadStatus.idle;
  String? error;
  DateTime? loadedAt;
  Future<void>? _inFlight;
  int _epoch = 0;

  /// Ya se cargó con éxito alguna vez.
  bool get hasLoaded => loadedAt != null;

  bool get isLoading => status == LoadStatus.loading;

  /// Primera carga: todavía no hay nada que mostrar (ni error).
  bool get isInitialLoad => !hasLoaded && status != LoadStatus.error;

  bool get hasFailed => status == LoadStatus.error;

  bool get _isFresh =>
      status == LoadStatus.loaded &&
      loadedAt != null &&
      _store._now().difference(loadedAt!) < AdminDataStore.freshFor;

  /// Pide el dato si no está vigente. Nunca lanza: el resultado queda en
  /// [status], [value] y [error].
  Future<void> load({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    if (!force && _isFresh) return Future<void>.value();
    return _inFlight = _run();
  }

  Future<void> _run() async {
    final epoch = _epoch;
    status = LoadStatus.loading;
    error = null;
    _store._notifySoon();
    try {
      final result = await _fetch();
      if (epoch != _epoch) return;
      value = result;
      loadedAt = _store._now();
      status = LoadStatus.loaded;
    } on ApiException catch (e) {
      if (epoch != _epoch) return;
      status = LoadStatus.error;
      error = e.message;
      if (e.isUnauthorized) _store._unauthorized();
    } catch (_) {
      if (epoch != _epoch) return;
      status = LoadStatus.error;
      error = _failMessage;
    } finally {
      // Si se cerró la sesión mientras tanto, la respuesta se descarta.
      if (epoch == _epoch) {
        _inFlight = null;
        _store._changed();
      }
    }
  }

  void _reset() {
    _epoch++;
    value = _empty;
    status = LoadStatus.idle;
    error = null;
    loadedAt = null;
    _inFlight = null;
  }
}

/// Datos del panel de administración compartidos por todas las secciones.
///
/// Cada dato es un [StoreResource] independiente. Las secciones piden solo lo
/// que muestran (Inicio: el resumen; Predios: los predios; Usuarios: los
/// usuarios) y los diálogos piden lo que necesitan (roles, motivos...) al
/// abrirse. Cuando algo cambia se avisa a todas las secciones a la vez.
class AdminDataStore extends ChangeNotifier {
  AdminDataStore._();

  static final AdminDataStore instance = AdminDataStore._();

  /// Tiempo durante el cual un dato cargado se considera al día.
  static Duration freshFor = const Duration(seconds: 60);

  /// Reloj del almacén; las pruebas lo sustituyen para adelantar el tiempo.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  DateTime _now() => clock();

  final SummaryService _summaryService = SummaryService();
  final PremiseService _premiseService = PremiseService();
  final UserAdminService _userService = UserAdminService();
  final ReasonCatalogService _catalogService = ReasonCatalogService();

  /// Se llama (una sola vez) cuando una petición responde 401: la sesión
  /// caducó y hay que volver al inicio de sesión.
  VoidCallback? onUnauthorized;
  bool _unauthorizedHandled = false;

  late final StoreResource<AdminSummary?> summaryData =
      StoreResource<AdminSummary?>._(
        this,
        _summaryService.getSummary,
        null,
        'No se pudo cargar el resumen',
      );
  late final StoreResource<List<Premise>> premisesData =
      StoreResource<List<Premise>>._(
        this,
        _loadPremises,
        const [],
        'No se pudieron cargar los predios',
      );
  late final StoreResource<List<ManagedUser>> usersData =
      StoreResource<List<ManagedUser>>._(
        this,
        _userService.getUsers,
        const [],
        'No se pudo cargar la lista de usuarios',
      );
  late final StoreResource<List<AppRole>> rolesData =
      StoreResource<List<AppRole>>._(
        this,
        _userService.getRoles,
        const [],
        'No se pudieron cargar los roles',
      );
  late final StoreResource<List<Reason>> reasonsData =
      StoreResource<List<Reason>>._(
        this,
        _premiseService.getAllReasons,
        const [],
        'No se pudieron cargar los motivos',
      );

  /// Radio (metros) dentro del cual el servidor acepta los escaneos de un
  /// predio. Lo entrega la API junto con los predios; hasta entonces se usa el
  /// valor por defecto.
  double get geofenceRadiusMeters =>
      _geofenceRadiusMeters ?? MapDefaults.premiseRadiusMeters;
  double? _geofenceRadiusMeters;

  Future<List<Premise>> _loadPremises() async {
    final listing = await _premiseService.getPremisesListing();
    _geofenceRadiusMeters = listing.geofenceRadiusMeters;
    return listing.premises;
  }

  /// Catálogo completo (activos y retirados) y estado de la sincronización.
  late final StoreResource<ReasonCatalog> reasonCatalogData =
      StoreResource<ReasonCatalog>._(
        this,
        _catalogService.getCatalog,
        const ReasonCatalog(),
        'No se pudo cargar el catálogo de motivos',
      );

  List<StoreResource<Object?>> get _all => [
    summaryData,
    premisesData,
    usersData,
    rolesData,
    reasonsData,
    reasonCatalogData,
  ];

  AdminSummary? get summary => summaryData.value;
  List<Premise> get premises => premisesData.value;
  List<ManagedUser> get users => usersData.value;
  List<AppRole> get roles => rolesData.value;
  List<Reason> get reasons => reasonsData.value;

  /// Vuelve a pedir, sin mostrar errores, lo que ya se había cargado. Se usa
  /// tras una acción (crear, editar, sincronizar...) para que todas las
  /// secciones reflejen el cambio. Lo que nunca se abrió no se pide.
  Future<void> refreshQuietly() => Future.wait([
    for (final resource in _all)
      if (resource.hasLoaded || resource.isLoading) resource.load(force: true),
  ]);

  /// Olvida los datos (al cerrar sesión). Las respuestas que aún estén en
  /// camino se descartan.
  void clear() {
    for (final resource in _all) {
      resource._reset();
    }
    _geofenceRadiusMeters = null;
    _unauthorizedHandled = false;
    notifyListeners();
  }

  /// La sesión caducó (401). Lo usan las acciones que no pasan por un
  /// recurso (guardar, desvincular...). Solo avisa una vez.
  void sessionExpired() => _unauthorized();

  void _unauthorized() {
    if (_unauthorizedHandled) return;
    _unauthorizedHandled = true;
    onUnauthorized?.call();
  }

  bool _notifyScheduled = false;

  /// Avisa en cuanto termine la construcción actual: [load] puede llamarse
  /// desde `initState`, donde no se permite reconstruir otros widgets.
  void _notifySoon() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void _changed() => notifyListeners();
}
