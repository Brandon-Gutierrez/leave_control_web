// Pruebas del rol MANAGE_PREMISE en la web: bloqueo a la pantalla de QR de su
// predio y administración de estas cuentas desde el panel (datos falsos).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:control_leaves_web/main.dart';
import 'package:control_leaves_web/models/auth_user.dart';
import 'package:control_leaves_web/screens/admin_dashboard_page.dart';
import 'package:control_leaves_web/services/api_client.dart';
import 'package:control_leaves_web/session/session_controller.dart';

Map<String, dynamic> _manager({Map<String, dynamic>? premise}) => {
  'user_id': 50,
  'name': 'Ana Gestora',
  'item': '2000000001',
  'username': 'ana_gestora',
  'role': {'role_id': 3, 'name': 'MANAGE_PREMISE'},
  'premise': premise ?? {'premise_id': 7, 'name': 'Predio Central'},
};

Map<String, dynamic> _admin() => {
  'user_id': 1,
  'name': 'Admin Uno',
  'item': '1',
  'role': {'role_id': 2, 'name': 'ADMIN'},
  'premise': null,
};

/// Backend falso configurable por prueba.
class _Backend implements HttpClientAdapter {
  /// Respuesta de GET /api/auth/me (null = 401 sin sesión).
  Map<String, dynamic>? me;

  /// Respuesta de POST /api/auth/login (null = 401 credenciales inválidas).
  Map<String, dynamic>? loginUser;

  /// Código con el que responde POST /api/manager/qr-token.
  int qrStatus = 200;

  final List<String> calls = [];
  Map<String, dynamic>? lastBody;

  int count(String call) => calls.where((c) => c == call).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    final path = options.path;
    calls.add('$method $path');

    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) {
        lastBody = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
    }

    Object body = {'status': 0};
    var status = 200;

    if (path == '/api/auth/me') {
      // Una sesión invalidada en el servidor falla igual en /me y en el QR.
      if (me == null || qrStatus == 401) {
        status = 401;
        body = {'message': 'Unauthenticated.'};
      } else {
        body = {'status': 'SUCCESS', 'user': me};
      }
    } else if (path == '/api/auth/login') {
      if (loginUser == null) {
        status = 401;
        body = {'message': 'Credenciales inválidas.'};
      } else {
        body = {'status': 'SUCCESS', 'user': loginUser};
      }
    } else if (path == '/api/manager/qr-token') {
      if (qrStatus == 200) {
        body = {
          'status': 0,
          'token': 'Predio Central+uuid',
          'TTL': 300,
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
          'premise': {'premise_id': 7, 'name': 'Predio Central'},
        };
      } else {
        status = qrStatus;
        body = {'message': qrStatus == 401 ? 'Unauthenticated.' : 'Error del servidor'};
      }
    } else if (path == '/api/admin/users' && method == 'GET') {
      body = {
        'status': 0,
        'data': [
          {
            'user_id': 2,
            'name': 'Ana Pérez',
            'item': 1001,
            'role': {'role_id': 1, 'name': 'EMPLOYEE'},
            'premise': null,
          },
          _manager(),
        ],
      };
    } else if (path == '/api/admin/roles') {
      body = {
        'status': 0,
        'data': [
          {'role_id': 2, 'name': 'ADMIN'},
          {'role_id': 1, 'name': 'EMPLOYEE'},
          {'role_id': 3, 'name': 'MANAGE_PREMISE'},
        ],
      };
    } else if (path == '/api/admin/premises' && method == 'GET') {
      body = {
        'status': 0,
        'data': [
          {'id': 7, 'name': 'Predio Central', 'reason_names': <String>[]},
          {'id': 8, 'name': 'Predio Norte', 'reason_names': <String>[]},
        ],
      };
    } else if (path == '/api/admin/reasons') {
      body = {'status': 0, 'reasons': <String>[]};
    } else if (path == '/api/admin/users/premise-managers') {
      status = 201;
      body = {
        'status': 0,
        'data': _manager(),
        'generated_password': 'Clave-Generada-2026',
      };
    } else if (path == '/api/admin/users/2/role') {
      body = {
        'status': 0,
        'data': {
          'user_id': 2,
          'name': 'Ana Pérez',
          'item': 1001,
          'role': {'role_id': 3, 'name': 'MANAGE_PREMISE'},
          'premise': {'premise_id': 8, 'name': 'Predio Norte'},
        },
      };
    }

    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  late _Backend backend;

  setUp(() {
    backend = _Backend();
    ApiClient().dio.httpClientAdapter = backend;
    SessionController.instance.clear();
  });

  tearDown(() => SessionController.instance.clear());

  group('AuthUser', () {
    test('solo MANAGE_PREMISE es responsable de predio', () {
      AuthUser role(String name) => AuthUser(id: 1, name: 'x', item: '1', roleName: name);

      expect(role('MANAGE_PREMISE').isPremiseManager, isTrue);
      expect(role('manage_premise').isPremiseManager, isTrue);
      expect(role('PREMISE_MANAGER').isPremiseManager, isFalse);
      expect(role('ADMIN').isPremiseManager, isFalse);
      expect(role('EMPLOYEE').isPremiseManager, isFalse);
    });
  });

  group('Responsable de predio (bloqueo)', () {
    testWidgets('con sesión abierta solo ve el QR de su predio', (tester) async {
      backend.me = _manager();

      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('Predio Central'), findsWidgets);
      // Nada de navegación ni de cierre de sesión.
      expect(find.byTooltip('Cerrar sesión'), findsNothing);
      expect(find.text('Cerrar sesión'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Iniciar Sesión'), findsNothing);
      expect(backend.count('POST /api/manager/qr-token'), 1);

      await _teardown(tester);
    });

    testWidgets('el botón "atrás" no lo saca de la pantalla', (tester) async {
      backend.me = _manager();
      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      await tester.binding.handlePopRoute();
      await _settle(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Iniciar Sesión'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('un enlace a otra ruta no cambia lo que ve', (tester) async {
      backend.me = _manager();
      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      for (final route in ['/admin', '/admin/users', '/login', '/premises']) {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/navigation',
          const JSONMethodCodec().encodeMethodCall(MethodCall('pushRoute', route)),
          (_) {},
        );
        await _settle(tester);

        expect(find.byType(QrImageView), findsOneWidget, reason: route);
        expect(find.byType(AdminDashboardPage), findsNothing, reason: route);
        expect(find.text('Iniciar Sesión'), findsNothing, reason: route);
      }

      await _teardown(tester);
    });

    testWidgets('al iniciar sesión queda bloqueado y nunca se cierra la sesión', (tester) async {
      backend.loginUser = _manager();

      await tester.pumpWidget(const MyApp());
      await _settle(tester);
      expect(find.text('Iniciar Sesión'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'ana_gestora');
      await tester.enterText(find.byType(TextFormField).at(1), 'clave-segura-123');
      await tester.tap(find.text('Ingresar'));
      await _settle(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Iniciar Sesión'), findsNothing);
      expect(find.byTooltip('Cerrar sesión'), findsNothing);
      expect(SessionController.instance.user.value?.isPremiseManager, isTrue);
      expect(backend.count('POST /api/auth/logout'), 0);

      await _teardown(tester);
    });

    testWidgets('si el servidor cierra su sesión (401) vuelve al inicio de sesión', (tester) async {
      backend.me = _manager();
      backend.qrStatus = 401;

      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(SessionController.instance.user.value, isNull);

      await _teardown(tester);
    });

    testWidgets('si el QR falla se reintenta solo, sin tocar nada', (tester) async {
      backend.me = _manager();
      backend.qrStatus = 500;

      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      expect(find.text('Error del servidor'), findsOneWidget);
      expect(find.text('Se reintentará automáticamente.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      backend.qrStatus = 200;
      await tester.pump(const Duration(seconds: 11));
      await _settle(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Error del servidor'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('sin predio asignado muestra un aviso y tampoco puede navegar', (tester) async {
      backend.me = {..._manager(), 'premise': null};

      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      expect(find.text('Esta cuenta no tiene un predio asignado.'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      // Administración le asigna un predio: "Volver a comprobar" lo recupera.
      backend.me = _manager();
      await tester.tap(find.text('Volver a comprobar'));
      await _settle(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Esta cuenta no tiene un predio asignado.'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('el administrador conserva su panel y puede cerrar sesión', (tester) async {
      backend.me = _admin();

      await tester.pumpWidget(const MyApp());
      await _settle(tester);

      expect(find.byType(AdminDashboardPage), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await _settle(tester);

      expect(backend.count('POST /api/auth/logout'), 1);
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(SessionController.instance.user.value, isNull);

      await _teardown(tester);
    });
  });

  group('Administración de responsables de predio', () {
    Future<void> openUsers(WidgetTester tester) async {
      // Pantalla alta: los diálogos con formulario caben sin desplazarse.
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await _settle(tester);
      await tester.tap(find.text('Usuarios'));
      await _settle(tester);
    }

    testWidgets('la lista muestra al responsable con su predio', (tester) async {
      await openUsers(tester);

      expect(find.text('Ana Gestora'), findsOneWidget);
      expect(find.text('Predio: Predio Central'), findsOneWidget);
      expect(find.text('Gestor de predio'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('crea un responsable y muestra la contraseña una sola vez', (tester) async {
      await openUsers(tester);

      await tester.tap(find.text('Nuevo responsable de predio'));
      await _settle(tester);
      expect(find.text('Nuevo responsable de predio'), findsWidgets);

      // Validaciones: campos vacíos y usuario con espacios.
      await tester.tap(find.text('Crear cuenta'));
      await _settle(tester);
      expect(find.text('Campo requerido'), findsWidgets);
      expect(find.text('Elija un predio'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Ana Gestora');
      await tester.enterText(find.byType(TextFormField).at(1), 'ana gestora');
      await tester.tap(find.text('Crear cuenta'));
      await _settle(tester);
      expect(find.text('Use solo letras, números, - o _ (sin espacios)'), findsOneWidget);
      expect(backend.count('POST /api/admin/users/premise-managers'), 0);

      await tester.enterText(find.byType(TextFormField).at(1), 'ana_gestora');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await _settle(tester);
      await tester.tap(find.text('Predio Central').last);
      await _settle(tester);
      await tester.tap(find.text('Crear cuenta'));
      await _settle(tester);

      expect(backend.lastBody?['premise_id'], 7);
      expect(backend.lastBody?['username'], 'ana_gestora');
      expect(backend.lastBody?.containsKey('password'), isFalse);
      expect(find.text('Cuenta creada'), findsOneWidget);
      expect(find.text('Clave-Generada-2026'), findsOneWidget);
      expect(find.text('Ya la guardé'), findsOneWidget);

      await tester.tap(find.text('Ya la guardé'));
      await _settle(tester);
      expect(find.text('Clave-Generada-2026'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('asignar el rol de gestor exige elegir un predio', (tester) async {
      await openUsers(tester);

      await tester.tap(find.text('Ana Pérez'));
      await _settle(tester);

      final save = find.widgetWithText(FilledButton, 'Guardar cambio');
      final dialog = find.byType(Dialog);
      await tester.tap(find.descendant(of: dialog, matching: find.text('Gestor de predio')));
      await _settle(tester);

      // Con el rol elegido pero sin predio no se puede guardar.
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await _settle(tester);
      await tester.tap(find.text('Predio Norte').last);
      await _settle(tester);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tester.tap(save);
      await _settle(tester);

      // Rol y predio viajan juntos en una sola petición.
      expect(backend.lastBody, {'role_id': 3, 'premise_id': 8});
      expect(backend.count('PUT /api/admin/users/2/role'), 1);
      expect(find.textContaining('ahora es Gestor de predio en Predio Norte'), findsOneWidget);

      await _teardown(tester);
    });
  });
}
