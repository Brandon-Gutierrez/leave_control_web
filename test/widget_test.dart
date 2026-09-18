// Pruebas de diseño responsivo con datos falsos (sin backend).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:control_leaves_web/models/premise_model.dart';
import 'package:control_leaves_web/screens/admin_dashboard_page.dart';
import 'package:control_leaves_web/screens/generator_qr_page.dart';
import 'package:control_leaves_web/screens/login_admin_page.dart';
import 'package:control_leaves_web/services/api_client.dart';

const _premisesPayload = {
  'status': 0,
  'data': [
    {
      'id': 1,
      'name': 'Predio 1',
      'reason_names': ['Banco', 'Médico'],
    },
    {
      'id': 2,
      'name': 'Predio 2',
      'reason_names': ['Banco', 'Médico'],
    },
    {
      'id': 3,
      'name': 'Predio con un nombre bastante largo para probar el ajuste 3',
      'reason_names': ['Banco', 'Médico'],
    },
    {
      'id': 4,
      'name': 'Predio 4',
      'reason_names': ['Banco', 'Médico'],
    },
    {
      'id': 5,
      'name': 'Predio 5',
      'reason_names': ['Banco', 'Médico'],
    },
    {
      'id': 6,
      'name': 'Predio 6',
      'reason_names': ['Banco', 'Médico'],
    },
    {
      'id': 7,
      'name': 'Predio 7',
      'reason_names': ['Banco', 'Médico'],
    },
  ],
};

const _usersPayload = {
  'status': 0,
  'data': [
    {
      'user_id': 1,
      'name': 'Ana Pérez',
      'item': 1001,
      'role_id': 1,
      'role': {'role_id': 1, 'name': 'EMPLOYEE'},
    },
    {
      'user_id': 2,
      'name': 'Luis Gómez',
      'item': 1002,
      'role_id': 2,
      'role': {'role_id': 2, 'name': 'ADMIN'},
    },
  ],
};

const _rolesPayload = {
  'status': 0,
  'data': [
    {'role_id': 1, 'name': 'EMPLOYEE'},
    {'role_id': 2, 'name': 'ADMIN'},
  ],
};

/// Responde con datos de ejemplo sin llamar al backend.
class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();

    final Object body;
    var statusCode = 200;

    if (path.endsWith('/qr-tokens')) {
      body = {'status': 0, 'token': 'Predio Central+123e4567', 'TTL': 60};
    } else if (path == '/api/admin/reasons' && method == 'GET') {
      body = {
        'status': 0,
        'reasons': ['Banco', 'Comisión de servicio', 'Médico', 'Personal'],
      };
    } else if (path == '/api/admin/reasons/sync' && method == 'POST') {
      body = {
        'status': 0,
        'message': 'Motivos de salida actualizados correctamente',
      };
    } else if (path == '/api/admin/premises' && method == 'POST') {
      statusCode = 201;
      body = {
        'status': 0,
        'data': {'id': 99, 'name': 'Predio Demo', 'reason_names': <String>[]},
      };
    } else if (path == '/api/admin/premises' && method == 'GET') {
      body = _premisesPayload;
    } else if (path == '/api/admin/users' && method == 'GET') {
      body = _usersPayload;
    } else if (path == '/api/admin/roles' && method == 'GET') {
      body = _rolesPayload;
    } else if (path.endsWith('/role') && method == 'PUT') {
      body = {
        'status': 0,
        'data': {
          'user_id': 1,
          'name': 'Ana Pérez',
          'item': 1001,
          'role_id': 2,
          'role': {'role_id': 2, 'name': 'ADMIN'},
        },
      };
    } else {
      body = {'status': 0};
    }

    return ResponseBody.fromString(jsonEncode(body), statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _sizes = <String, Size>{
  'teléfono': Size(360, 740),
  'tablet': Size(800, 1024),
  'laptop': Size(1366, 768),
  'monitor': Size(1920, 1080),
};

void main() {
  setUp(() => ApiClient().dio.httpClientAdapter = _FakeAdapter());

  for (final entry in _sizes.entries) {
    Future<void> setSize(WidgetTester tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Login no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginAdminPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('Inicio no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(
        const MaterialApp(home: AdminDashboardPage(adminName: 'Ana')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Hola'), findsOneWidget);
      expect(find.text('Predios registrados'), findsOneWidget);
      expect(find.text('Agregar un predio nuevo'), findsOneWidget);
      expect(find.text('Actualizar motivos de salida'), findsOneWidget);
      expect(find.text('Administrar usuarios'), findsOneWidget);
    });

    testWidgets('Predios no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Predios'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Predio 1'), findsOneWidget);

      // Expandir una tarjeta
      await tester.tap(find.text('Predio 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Motivos de salida permitidos'), findsOneWidget);
    });

    testWidgets('Usuarios no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Luis Gómez'), findsOneWidget);

      // Vuelve a Inicio y confirma que no quedó nada roto
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Crear predio no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Predios'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agregar predio'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Crear predio'), findsOneWidget);

      // Nombre vacío: debe mostrar la validación
      await tester.tap(find.text('Crear predio'));
      await tester.pumpAndSettle();
      expect(find.text('Campo requerido'), findsOneWidget);

      // Completa el nombre y confirma
      await tester.enterText(find.byType(TextFormField).first, 'Predio Demo');
      await tester.tap(find.text('Crear predio'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Predio creado correctamente'), findsOneWidget);
    });

    testWidgets('QR no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(MaterialApp(
        home: QrPage(
          premise: Premise(id: 1, name: 'Predio Central', reasonNames: []),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Se actualiza en: 60 s'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('El acceso directo de Inicio abre el formulario de predio nuevo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar un predio nuevo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Crear predio'), findsOneWidget);
  });

  testWidgets('Sincronizar motivos desde Inicio muestra confirmación', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actualizar motivos de salida'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Motivos de salida actualizados correctamente'), findsOneWidget);
  });

  testWidgets('Cambiar el rol de un usuario pide confirmación', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Administrar usuarios'));
    await tester.tap(find.text('Administrar usuarios'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsOneWidget);

    // Toca la fila de Ana para abrir el selector de rol
    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final dialogFinder = find.byType(Dialog);
    expect(dialogFinder, findsOneWidget);
    expect(find.text('Cambiar rol'), findsOneWidget);
    final adminOptionFinder =
        find.descendant(of: dialogFinder, matching: find.text('Administrador'));
    expect(adminOptionFinder, findsOneWidget);
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Empleado')),
      findsOneWidget,
    );

    // El botón de guardar empieza deshabilitado hasta elegir un rol distinto
    final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Guardar cambio');
    expect(tester.widget<ElevatedButton>(saveButtonFinder).onPressed, isNull);

    await tester.tap(adminOptionFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(saveButtonFinder).onPressed, isNotNull);

    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('ahora es Administrador'), findsOneWidget);
  });
}
