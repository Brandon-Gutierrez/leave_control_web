import 'dart:async';

import 'package:control_leaves_web/core/network/api_client.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/counting_adapter.dart';

const _premises = '/api/admin/premises';
const _users = '/api/admin/users';
const _roles = '/api/admin/roles';
const _summary = '/api/admin/summary';

CountingAdapter _adapter() => CountingAdapter({
  _premises: {
    'status': 0,
    'data': [
      {'id': 1, 'name': 'Predio 1'},
    ],
    'geofence_radius_m': 80,
  },
  _users: {
    'status': 0,
    'data': [
      {
        'user_id': 1,
        'name': 'Ana',
        'item': 1,
        'role': {'role_id': 1, 'name': 'EMPLOYEE'},
      },
    ],
  },
  _roles: {
    'status': 0,
    'data': [
      {'role_id': 1, 'name': 'EMPLOYEE'},
    ],
  },
  _summary: {
    'status': 0,
    'data': {
      'premises': {'total': 4, 'without_location': 1},
      'users': {'total': 9, 'admins': 2},
    },
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = AdminDataStore.instance;
  late CountingAdapter adapter;
  late DateTime now;

  setUp(() {
    adapter = _adapter();
    ApiClient().dio.httpClientAdapter = adapter;
    now = DateTime(2026, 11, 5, 10);
    store
      ..clock = (() => now)
      ..onUnauthorized = null
      ..clear();
    AdminDataStore.freshFor = const Duration(seconds: 60);
  });

  tearDown(() {
    store
      ..clock = DateTime.now
      ..onUnauthorized = null
      ..clear();
  });

  test('cada dato se pide por separado y solo cuando se necesita', () async {
    await store.premisesData.load();

    expect(adapter.hitsOf(_premises), 1);
    expect(adapter.hitsOf(_users), 0);
    expect(adapter.hitsOf(_roles), 0);
    expect(store.premises.single.name, 'Predio 1');
    expect(store.usersData.hasLoaded, isFalse);
    expect(store.usersData.isInitialLoad, isTrue);
  });

  test('cargas simultáneas del mismo dato hacen una sola petición', () async {
    adapter.gate = Completer<void>();

    final first = store.premisesData.load();
    final second = store.premisesData.load();
    final third = store.premisesData.load(force: true);
    expect(store.premisesData.isLoading, isTrue);

    adapter.gate!.complete();
    await Future.wait([first, second, third]);

    expect(adapter.hitsOf(_premises), 1);
    expect(store.premisesData.status, LoadStatus.loaded);
  });

  test('un dato al día no se vuelve a pedir; vencido o forzado, sí', () async {
    await store.usersData.load();
    await store.usersData.load();
    expect(adapter.hitsOf(_users), 1);

    now = now.add(const Duration(seconds: 59));
    await store.usersData.load();
    expect(adapter.hitsOf(_users), 1);

    now = now.add(const Duration(seconds: 2));
    await store.usersData.load();
    expect(adapter.hitsOf(_users), 2);

    await store.usersData.load(force: true);
    expect(adapter.hitsOf(_users), 3);
  });

  test('si una recarga falla se conserva el último valor bueno', () async {
    await store.usersData.load();
    adapter.failStatus[_users] = 500;

    await store.usersData.load(force: true);

    expect(store.usersData.hasFailed, isTrue);
    expect(store.usersData.error, 'Fallo 500 en $_users');
    expect(store.users.single.name, 'Ana');
    expect(store.usersData.hasLoaded, isTrue);

    // Un dato en error no cuenta como vigente: el siguiente intento lo pide.
    adapter.failStatus.remove(_users);
    await store.usersData.load();
    expect(adapter.hitsOf(_users), 3);
    expect(store.usersData.status, LoadStatus.loaded);
    expect(store.usersData.error, isNull);
  });

  test('una falla no afecta a los demás datos', () async {
    adapter.failStatus[_roles] = 500;

    await Future.wait([store.premisesData.load(), store.rolesData.load()]);

    expect(store.premisesData.status, LoadStatus.loaded);
    expect(store.rolesData.hasFailed, isTrue);
    expect(store.rolesData.hasLoaded, isFalse);
    expect(store.rolesData.isInitialLoad, isFalse);
  });

  test('una sesión caducada avisa una sola vez', () async {
    var calls = 0;
    store.onUnauthorized = () => calls++;
    adapter.failStatus
      ..[_users] = 401
      ..[_premises] = 401
      ..[_roles] = 401;

    await Future.wait([
      store.usersData.load(),
      store.premisesData.load(),
      store.rolesData.load(),
    ]);
    store.sessionExpired();

    expect(calls, 1);
  });

  test('al limpiar se descartan las respuestas que iban en camino', () async {
    adapter.gate = Completer<void>();
    final loading = store.premisesData.load();

    store.clear();
    adapter.gate!.complete();
    await loading;

    expect(store.premisesData.hasLoaded, isFalse);
    expect(store.premises, isEmpty);
    expect(store.premisesData.status, LoadStatus.idle);
  });

  test('refreshQuietly solo vuelve a pedir lo que ya estaba cargado', () async {
    await store.premisesData.load();

    await store.refreshQuietly();

    expect(adapter.hitsOf(_premises), 2);
    expect(adapter.hitsOf(_users), 0);
    expect(adapter.hitsOf(_roles), 0);
    expect(adapter.hitsOf(_summary), 0);
  });

  test('el resumen se lee del endpoint de contadores', () async {
    await store.summaryData.load();

    final summary = store.summary!;
    expect(summary.premises, 4);
    expect(summary.premisesWithoutLocation, 1);
    expect(summary.users, 9);
    expect(summary.admins, 2);
    // Lo que el servidor no envía cuenta como cero.
    expect(summary.employeesWithoutApp, 0);
    expect(adapter.hitsOf(_premises), 0);
    expect(adapter.hitsOf(_users), 0);
  });

  test('el radio de la geocerca llega con la lista de predios', () async {
    // Antes de cargar se usa el valor por defecto.
    expect(store.geofenceRadiusMeters, 50);

    await store.premisesData.load();

    expect(store.geofenceRadiusMeters, 80);
  });
}
