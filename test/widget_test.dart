// Pruebas de diseño responsivo con datos falsos (sin backend).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:control_leaves_web/models/auth_user.dart';
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
      'latitude': '-17.3935000',
      'longitude': '-66.1570000',
      'manager': {'user_id': 5, 'name': 'Marta Gestora'},
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
    {
      'user_id': 3,
      'name': 'Marta Gestora',
      'item': 1003,
      'username': 'marta',
      'role_id': 3,
      'role': {'role_id': 3, 'name': 'MANAGE_PREMISE'},
      'premise': {'premise_id': 1, 'name': 'Predio 1'},
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
  /// Obtiene los datos.
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

    if (path == '/api/manager/qr-token' && method == 'POST') {
      body = {
        'status': 0,
        'token': 'Predio Central+123e4567',
        'TTL': 60,
        'expires_at': DateTime.now()
            .add(const Duration(seconds: 60))
            .toUtc()
            .toIso8601String(),
      };
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
    } else if (path == '/api/auth/login' && method == 'POST') {
      statusCode = 401;
      body = {'status': 'ERROR', 'message': 'Credenciales inválidas.'};
    } else if (path.endsWith('/password') && method == 'PUT') {
      body = {'status': 0, 'generated_password': 'ClaveGenerada-123456'};
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

    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  /// Cierra el recurso.
  @override
  void close({bool force = false}) {}
}

const _sizes = <String, Size>{
  'teléfono': Size(360, 740),
  'tablet': Size(800, 1024),
  'laptop': Size(1366, 768),
  'monitor': Size(1920, 1080),
};

/// Inicia la aplicacion.
void main() {
  passwordAndLoginTests();
  filtersTests();
  setUp(() {
    ApiClient().dio.httpClientAdapter = _FakeAdapter();
  });

  for (final entry in _sizes.entries) {
    /// Ejecuta la tarea.
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
        MaterialApp(
          home: AdminDashboardPage(
            user: AuthUser(
              id: 1,
              name: 'Ana Pérez',
              item: '1',
              roleName: 'ADMIN',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Hola'), findsNothing);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Administrador del sistema'), findsOneWidget);
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

      // Sin lista desplegable: cada predio muestra su botón Editar y su QR
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Editar'), findsWidgets);
      expect(find.text('QR'), findsNothing); // ya no hay botón de QR
      expect(find.textContaining('Responsable:'), findsWidgets);

      // Tres tarjetas por fila como mínimo en pantallas anchas
      if (entry.value.width >= 1366) {
        final y1 = tester.getTopLeft(find.text('Predio 1')).dy;
        expect(tester.getTopLeft(find.text('Predio 2')).dy, y1);
        expect(
          tester.getTopLeft(find.textContaining('Predio con un nombre')).dy,
          y1,
        );
      }
    });

    testWidgets('Usuarios no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();
      final ex = tester.takeException();
      expect(ex, isNull);
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
      await tester.ensureVisible(find.byType(FlutterMap));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(150, 80),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Crear predio'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Predio creado correctamente'), findsOneWidget);
    });

    testWidgets('QR no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: QrPage(
            premise: Premise(id: 1, name: 'Predio Central', reasonNames: []),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Se actualiza en: 60 s'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'El acceso directo de Inicio abre el formulario de predio nuevo',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Agregar un predio nuevo'));
      await tester.tap(find.text('Agregar un predio nuevo'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Crear predio'), findsOneWidget);
    },
  );

  testWidgets('Sincronizar motivos desde Inicio muestra confirmación', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Actualizar motivos de salida'));
    await tester.tap(find.text('Actualizar motivos de salida'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Motivos de salida actualizados correctamente'),
      findsOneWidget,
    );
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
    final adminOptionFinder = find.descendant(
      of: dialogFinder,
      matching: find.text('Administrador'),
    );
    expect(adminOptionFinder, findsOneWidget);
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Empleado')),
      findsOneWidget,
    );

    // El botón de guardar empieza deshabilitado hasta elegir un rol distinto
    final saveButtonFinder = find.widgetWithText(
      FilledButton,
      'Guardar cambio',
    );
    expect(tester.widget<FilledButton>(saveButtonFinder).onPressed, isNull);

    await tester.tap(adminOptionFinder);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(saveButtonFinder).onPressed,
      isNotNull,
    );

    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('ahora es Administrador'), findsOneWidget);
  });
}

/// Ejecuta la tarea.
void filtersTests() {
  testWidgets('La barra de filtros de predios filtra por responsable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Predios'));
    await tester.pumpAndSettle();

    expect(find.text('Filtros'), findsOneWidget); // panel lateral fijo
    expect(find.text('Predio 2'), findsOneWidget);

    await tester.tap(find.text('Con responsable'));
    await tester.pumpAndSettle();
    expect(find.text('Predio 1'), findsOneWidget); // único con responsable
    expect(find.text('Predio 2'), findsNothing);
    expect(find.text('1 de 7 predios'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Predio 2'), findsOneWidget);
  });

  testWidgets('La barra de filtros de usuarios filtra por tipo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuarios'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsOneWidget);
    await tester.tap(find.text('Administradores'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsNothing);
    expect(find.text('Luis Gómez'), findsOneWidget);
  });

  testWidgets('En teléfono los filtros se despliegan con el botón Filtros', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Predios'));
    await tester.pumpAndSettle();

    expect(find.text('Limpiar filtros'), findsNothing);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Limpiar filtros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Ejecuta la tarea.
void passwordAndLoginTests() {
  testWidgets(
    'Tras un error de login la contraseña sigue editable y se puede reintentar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: LoginAdminPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'admin');
      await tester.enterText(find.byType(TextFormField).at(1), 'mala-clave');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Credenciales incorrectas'), findsOneWidget);
      final passwordField = tester.widget<TextField>(
        find.byType(TextField).at(1),
      );
      expect(passwordField.enabled, isNot(false));
      expect(
        passwordField.controller!.text,
        isEmpty,
      ); // se vació para reintentar
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      // Se puede volver a escribir y enviar
      await tester.enterText(find.byType(TextFormField).at(1), 'otra');
      expect(passwordField.controller!.text, 'otra');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'El admin regenera la contraseña de un responsable y la ve una sola vez',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cambiar o regenerar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar contraseña'), findsOneWidget);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(find.text('ClaveGenerada-123456'), findsOneWidget);
      await tester.tap(find.text('Ya la guardé'));
      await tester.pumpAndSettle();
      expect(find.text('ClaveGenerada-123456'), findsNothing);
    },
  );

  testWidgets('Una contraseña escrita a mano exige 10 caracteres', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuarios'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cambiar o regenerar contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escribir una contraseña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'corta');
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(find.text('Debe tener al menos 10 caracteres'), findsOneWidget);
  });
}
