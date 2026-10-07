import 'dart:typed_data';

import 'package:control_leaves_web/core/network/api_client.dart';
import 'package:control_leaves_web/features/users/models/managed_user.dart';
import 'package:control_leaves_web/features/users/presentation/devices_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  /// Obtiene los datos.
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      '{"user":{"user_id":1}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  /// Cierra el recurso.
  @override
  void close({bool force = false}) {}
}

ManagedUser _user(String role, {Map<ClientPlatform, DateTime> devices = const {}}) =>
    ManagedUser(
      id: 7,
      name: 'Ana Pérez',
      item: '123',
      role: AppRole(id: 1, name: role),
      devices: devices,
    );

Future<void> _openDialog(WidgetTester tester, ManagedUser user) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => DevicesDialog(user: user),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// Inicia la aplicacion.
void main() {
  test('cada petición web se identifica como web y con el id del navegador', () async {
    final adapter = _RecordingAdapter();
    ApiClient().dio.httpClientAdapter = adapter;

    await ApiClient().dio.get('/api/auth/me');

    expect(adapter.lastRequest!.headers['X-Client-Platform'], 'web');
    expect((adapter.lastRequest!.headers['DeviceId'] as String).length, greaterThanOrEqualTo(16));
  });

  test('aplicaciones por rol: igual que el servidor', () {
    expect(_user('ADMIN').platforms, [ClientPlatform.web, ClientPlatform.mobile]);
    expect(_user('MANAGE_PREMISE').platforms, [ClientPlatform.web]);
    expect(_user('EMPLOYEE').platforms, [ClientPlatform.mobile]);
  });

  test('lee los dispositivos del listado del servidor', () {
    final user = ManagedUser.fromJson({
      'user_id': 7,
      'name': 'Ana',
      'item': 1,
      'role': {'role_id': 2, 'name': 'ADMIN'},
      'devices': [
        {'platform': 'mobile', 'bound_at': '2026-09-30T10:00:00Z'},
      ],
    });

    expect(user.devices.keys, [ClientPlatform.mobile]);
  });

  testWidgets('admin: muestra web y móvil, y solo ofrece desvincular lo vinculado', (tester) async {
    await _openDialog(
      tester,
      _user('ADMIN', devices: {ClientPlatform.web: DateTime(2026, 9, 30, 9, 5)}),
    );

    expect(find.text('Panel web'), findsOneWidget);
    expect(find.text('App móvil'), findsOneWidget);
    expect(find.textContaining('Vinculado desde 30/09/2026'), findsOneWidget);
    expect(find.text('Sin teléfono vinculado'), findsOneWidget);
    expect(find.text('Desvincular'), findsOneWidget);
  });

  testWidgets('empleado: solo la app móvil y el diálogo devuelve la aplicación elegida', (tester) async {
    ClientPlatform? chosen;
    final user = _user('EMPLOYEE', devices: {ClientPlatform.mobile: DateTime(2026, 9, 30)});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showDialog<ClientPlatform>(
              context: context,
              builder: (_) => DevicesDialog(user: user),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Panel web'), findsNothing);
    await tester.tap(find.text('Desvincular'));
    await tester.pumpAndSettle();

    expect(chosen, ClientPlatform.mobile);
  });
}
