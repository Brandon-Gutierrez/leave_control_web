import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/auth/models/auth_user.dart';
import 'package:control_leaves_web/features/auth/state/session_controller.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:control_leaves_web/features/users/models/managed_user.dart';
import 'package:control_leaves_web/features/users/presentation/users_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

Map<String, dynamic> _device(String platform, String code) => {
  'id': 1,
  'user_id': 1,
  'platform': platform,
  'bound_at': '2026-11-18T08:15:00',
  'code': code,
};

Map<String, dynamic> _user(
  int id,
  String name,
  String role, {
  int? item,
  List<Map<String, dynamic>>? devices,
  String? username,
  String? premise,
}) => {
  'user_id': id,
  'name': name,
  'item': item ?? 1000 + id,
  'role_id': switch (role) {
    'ADMIN' => 2,
    'MANAGE_PREMISE' => 3,
    _ => 1,
  },
  'role': {'name': role},
  'devices': devices ?? <Map<String, dynamic>>[],
  'username': ?username,
  if (premise != null) 'premise': {'premise_id': id, 'name': premise},
};

List<Map<String, dynamic>> _people() => [
  _user(1, 'Ana Flores', 'EMPLOYEE', item: 1488),
  _user(
    2,
    'Álvaro Ríos',
    'EMPLOYEE',
    item: 1500,
    devices: [_device('mobile', 'AB3D-EF7H')],
  ),
  _user(
    3,
    'Beto Prestatario',
    'EMPLOYEE',
    item: 3120,
    devices: [_device('mobile', 'BB2C-DD4F')],
  ),
  _user(
    4,
    'Carlos Quispe',
    'ADMIN',
    item: 1020,
    devices: [_device('mobile', 'XY2Z-KM9N'), _device('web', 'PQ4R-ST6V')],
  ),
  _user(
    5,
    'Juan Pérez',
    'EMPLOYEE',
    item: 2057,
    devices: [_device('mobile', 'K7M4-Q9XB')],
  ),
  _user(
    6,
    'Marta Rojas',
    'MANAGE_PREMISE',
    username: 'marta',
    premise: 'Central',
    devices: [_device('web', 'WW8E-RT5Y')],
  ),
  _user(7, 'Rosa Mendoza', 'MANAGE_PREMISE', username: 'rosa'),
];

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(1280, 1500),
  double scale = 1,
}) async {
  _size(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(body: UsersView()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  late FakeAdminBackend backend;

  setUp(() {
    backend = FakeAdminBackend()
      ..users = _people()
      ..premises = [
        {
          'id': 6,
          'name': 'Central',
          'latitude': '-17.39',
          'longitude': '-66.15',
          'manager': {'user_id': 6, 'name': 'Marta Rojas'},
          'reason_names': ['Banco'],
        },
        {
          'id': 8,
          'name': 'Prado',
          'latitude': '-17.39',
          'longitude': '-66.15',
          'reason_names': ['Banco'],
        },
      ]
      ..install();
    AdminDataStore.instance.clear();
    SessionController.instance.set(null);
  });

  tearDown(() => SessionController.instance.set(null));

  group('lista', () {
    testWidgets('agrupa por letra, ordena sin mirar tildes y cuenta', (
      tester,
    ) async {
      await _open(tester);

      for (final letter in ['A', 'B', 'C', 'J', 'M', 'R']) {
        expect(find.text(letter), findsOneWidget, reason: letter);
      }
      // «Álvaro» va con la A y antes que «Ana» aunque lleve tilde.
      final alvaro = tester.getTopLeft(find.text('Álvaro Ríos')).dy;
      final ana = tester.getTopLeft(find.text('Ana Flores')).dy;
      expect(alvaro, lessThan(ana));

      expect(find.text('Todos 7'), findsOneWidget);
      expect(find.text('Empleados 4'), findsOneWidget);
      expect(find.text('Admin 1'), findsOneWidget);
      expect(find.text('Responsables 2'), findsOneWidget);
    });

    testWidgets('cada fila dice item y rol, o el predio si es responsable', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Item 2057 · Empleado'), findsOneWidget);
      expect(find.text('Item 1020 · Administrador'), findsOneWidget);
      expect(find.text('Responsable de Central'), findsOneWidget);
      expect(find.text('Responsable sin predio asignado'), findsOneWidget);
    });

    testWidgets('la nota de la derecha dice qué tiene vinculado', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('sin teléfono'), findsOneWidget); // Ana
      expect(find.text('teléfono'), findsNWidgets(3)); // Álvaro, Beto, Juan
      expect(find.text('teléfono + web'), findsOneWidget); // Carlos
      expect(find.text('navegador'), findsOneWidget); // Marta
      expect(find.text('sin navegador'), findsOneWidget); // Rosa
    });

    testWidgets('buscar por nombre ignora tildes y mayúsculas', (tester) async {
      await _open(tester);

      await tester.enterText(find.byType(TextField), 'ALVARO');
      await tester.pumpAndSettle();

      expect(find.text('Álvaro Ríos'), findsOneWidget);
      expect(find.text('Ana Flores'), findsNothing);
    });

    testWidgets('buscar por item', (tester) async {
      await _open(tester);

      await tester.enterText(find.byType(TextField), '2057');
      await tester.pumpAndSettle();

      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('Ana Flores'), findsNothing);
    });

    testWidgets('sin resultados lo dice', (tester) async {
      await _open(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontraron usuarios con esos filtros.'),
        findsOneWidget,
      );
    });

    testWidgets('las pestañas filtran por tipo de persona', (tester) async {
      await _open(tester);

      await tester.tap(find.text('Admin 1'));
      await tester.pumpAndSettle();
      expect(find.text('Carlos Quispe'), findsOneWidget);
      expect(find.text('Ana Flores'), findsNothing);

      await tester.tap(find.text('Responsables 2'));
      await tester.pumpAndSettle();
      expect(find.text('Marta Rojas'), findsOneWidget);
      expect(find.text('Rosa Mendoza'), findsOneWidget);
      expect(find.text('Carlos Quispe'), findsNothing);

      await tester.tap(find.text('Empleados 4'));
      await tester.pumpAndSettle();
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('Marta Rojas'), findsNothing);
    });

    testWidgets('la pestaña y la búsqueda se combinan', (tester) async {
      await _open(tester);

      await tester.tap(find.text('Empleados 4'));
      await tester.enterText(find.byType(TextField), 'carlos');
      await tester.pumpAndSettle();

      expect(find.text('Carlos Quispe'), findsNothing); // es administrador
      expect(
        find.text('No se encontraron usuarios con esos filtros.'),
        findsOneWidget,
      );
    });

    testWidgets('mientras nadie está elegido se invita a elegir', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Elige a una persona de la lista'), findsOneWidget);
    });
  });

  group('detalle', () {
    testWidgets('un empleado con teléfono: rol, código y fecha', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Juan Pérez');

      expect(find.text('Elige a una persona de la lista'), findsNothing);
      expect(
        find.text('Item 2057 · Empleado · cuenta de Comteco'),
        findsOneWidget,
      );
      for (final role in [
        'Empleado',
        'Administrador',
        'Responsable de predio',
      ]) {
        expect(find.text(role), findsOneWidget, reason: role);
      }
      expect(
        find.textContaining('Un empleado registra sus salidas'),
        findsOneWidget,
      );
      expect(find.text('Vinculado'), findsOneWidget);
      expect(find.text('Desde el 18/11/2026 a las 08:15'), findsOneWidget);
      expect(find.text('K7M4-Q9XB'), findsOneWidget);
      expect(find.text('Desvincular teléfono'), findsOneWidget);
      expect(
        find.text(
          'Este rol no usa el panel web, no hay navegador que vincular.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('un empleado sin teléfono no ofrece desvincular', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Ana Flores');

      expect(find.text('Sin teléfono vinculado'), findsOneWidget);
      expect(
        find.text('Se vincula solo cuando inicia sesión en la app.'),
        findsOneWidget,
      );
      expect(find.text('Desvincular teléfono'), findsNothing);
    });

    testWidgets('un administrador tiene teléfono y navegador', (tester) async {
      await _open(tester);
      await _pick(tester, 'Carlos Quispe');

      expect(find.text('XY2Z-KM9N'), findsOneWidget);
      expect(find.text('PQ4R-ST6V'), findsOneWidget);
      expect(find.text('Desvincular teléfono'), findsOneWidget);
      expect(find.text('Desvincular navegador'), findsOneWidget);
      expect(find.textContaining('Un administrador gestiona'), findsOneWidget);
    });

    testWidgets('un responsable: predio, navegador y acceso al panel', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Marta Rojas');

      expect(find.text('Predio asignado'.toUpperCase()), findsOneWidget);
      expect(find.text('Central'), findsOneWidget);
      expect(find.text('Cambiar predio'), findsOneWidget);
      expect(
        find.text(
          'Este rol no usa la app móvil, no hay teléfono que vincular.',
        ),
        findsOneWidget,
      );
      expect(find.text('WW8E-RT5Y'), findsOneWidget);
      expect(find.text('Usuario: marta'), findsOneWidget);
      expect(find.text('Cambiar o regenerar contraseña'), findsOneWidget);
      // Una cuenta del sistema solo puede ser responsable.
      expect(find.text('Empleado'), findsNothing);
      expect(
        find.textContaining('solo puede ser responsable de predio'),
        findsOneWidget,
      );
    });

    testWidgets('un responsable sin predio lo señala', (tester) async {
      await _open(tester);
      await _pick(tester, 'Rosa Mendoza');

      expect(find.text('Sin predio asignado'), findsOneWidget);
      expect(find.text('Asignar predio'), findsOneWidget);
      expect(find.text('Sin navegador vinculado'), findsOneWidget);
    });

    testWidgets('solo las cuentas del sistema tienen contraseña propia', (
      tester,
    ) async {
      await _open(tester);

      await _pick(tester, 'Juan Pérez');
      expect(find.text('Cambiar o regenerar contraseña'), findsNothing);

      await _pick(tester, 'Carlos Quispe');
      expect(find.text('Cambiar o regenerar contraseña'), findsNothing);
    });

    testWidgets('la fila elegida cambia al elegir a otra persona', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Juan Pérez');
      expect(find.text('K7M4-Q9XB'), findsOneWidget);

      await _pick(tester, 'Ana Flores');
      expect(find.text('K7M4-Q9XB'), findsNothing);
      expect(find.text('Sin teléfono vinculado'), findsOneWidget);
    });
  });

  group('cambios', () {
    testWidgets('desvincular pide confirmación y quita el código', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Juan Pérez');

      await tester.tap(find.text('Desvincular teléfono'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      // Cancelar no toca nada.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(backend.deviceResets, isEmpty);
      expect(find.text('K7M4-Q9XB'), findsOneWidget);

      await tester.tap(find.text('Desvincular teléfono'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desvincular'));
      await tester.pumpAndSettle();

      expect(backend.deviceResets, ['5:mobile']);
      expect(find.textContaining('desvinculado'), findsOneWidget);
      expect(find.text('K7M4-Q9XB'), findsNothing);
      expect(find.text('Sin teléfono vinculado'), findsOneWidget);
    });

    testWidgets('cambiar el rol pide confirmación y actualiza la lista', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Beto Prestatario');

      await tester.tap(find.text('Administrador'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar rol'), findsOneWidget);
      expect(backend.roleChanges, isEmpty);

      await tester.tap(find.text('Guardar cambio'));
      await tester.pumpAndSettle();

      expect(backend.roleChanges, ['3:2']);
      expect(
        find.textContaining('Beto Prestatario ahora es Administrador'),
        findsOneWidget,
      );
      expect(find.text('Item 3120 · Administrador'), findsOneWidget);
    });

    testWidgets('tocar el rol actual no hace nada', (tester) async {
      await _open(tester);
      await _pick(tester, 'Juan Pérez');

      await tester.tap(find.text('Empleado'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(backend.roleChanges, isEmpty);
    });

    testWidgets('nadie cambia su propio rol', (tester) async {
      SessionController.instance.set(
        AuthUser(id: 1, name: 'Ana Flores', item: '1488', roleName: 'ADMIN'),
      );
      await _open(tester);
      await _pick(tester, 'Ana Flores');

      await tester.tap(find.text('Administrador'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(backend.roleChanges, isEmpty);
      expect(
        find.text(
          'No puede cambiar su propio rol. Pídalo a otro administrador.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('«Cambiar predio» abre el cuadro con el rol de responsable', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Marta Rojas');

      await tester.tap(find.text('Cambiar predio'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar rol'), findsOneWidget);
      expect(find.text('Guardar cambio'), findsOneWidget);
      // Sin tocar nada no hay cambio que guardar.
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar cambio'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets(
      '«Cambiar o regenerar contraseña» abre el cuadro de contraseña',
      (tester) async {
        await _open(tester);
        await _pick(tester, 'Marta Rojas');

        await tester.tap(find.text('Cambiar o regenerar contraseña'));
        await tester.pumpAndSettle();

        expect(find.text('Cambiar contraseña'), findsOneWidget);
      },
    );

    testWidgets('«Buscar por código de dispositivo» abre la búsqueda', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Buscar por código de dispositivo'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('pantallas angostas', () {
    testWidgets('se ve la lista; al elegir a alguien, su detalle', (
      tester,
    ) async {
      await _open(tester, size: const Size(390, 1400));

      expect(find.text('Elige a una persona de la lista'), findsNothing);
      expect(find.text('Volver a la lista'), findsNothing);
      await _pick(tester, 'Juan Pérez');

      expect(find.text('K7M4-Q9XB'), findsOneWidget);
      expect(find.text('Volver a la lista'), findsOneWidget);
      expect(find.text('Ana Flores'), findsNothing); // la lista ya no se ve

      await tester.tap(find.text('Volver a la lista'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Flores'), findsOneWidget);
      expect(find.text('K7M4-Q9XB'), findsNothing);
    });

    testWidgets('en pantallas anchas no hay botón de volver', (tester) async {
      await _open(tester);
      await _pick(tester, 'Juan Pérez');

      expect(find.text('Volver a la lista'), findsNothing);
      expect(find.text('Ana Flores'), findsOneWidget); // lista y detalle juntos
    });
  });

  group('ayudas', () {
    test('foldText quita tildes y mayúsculas', () {
      expect(UsersViewState.foldText('Álvaro Ñandú'), 'alvaro nandu');
      expect(UsersViewState.foldText('ÉÍÓÚ üç'), 'eiou uc');
    });

    test('groupLetterOf agrupa por inicial sin tilde', () {
      expect(UsersViewState.groupLetterOf('Álvaro'), 'A');
      expect(UsersViewState.groupLetterOf('  beto'), 'B');
      expect(UsersViewState.groupLetterOf('Ñandú'), 'N');
      expect(UsersViewState.groupLetterOf('1234'), '#');
      expect(UsersViewState.groupLetterOf('   '), '#');
    });

    test('subtitleOf y deviceNote según el rol y lo vinculado', () {
      ManagedUser u(Map<String, dynamic> json) => ManagedUser.fromJson(json);

      final employee = u(_user(1, 'A', 'EMPLOYEE', item: 7));
      expect(UsersViewState.subtitleOf(employee), 'Item 7 · Empleado');
      expect(UsersViewState.deviceNote(employee).$1, 'sin teléfono');

      final admin = u(_user(2, 'B', 'ADMIN', item: 8));
      expect(UsersViewState.deviceNote(admin).$1, 'sin vincular');

      final adminWeb = u(
        _user(2, 'B', 'ADMIN', item: 8, devices: [_device('web', 'WW8E-RT5Y')]),
      );
      expect(UsersViewState.deviceNote(adminWeb).$1, 'web');

      final manager = u(
        _user(3, 'C', 'MANAGE_PREMISE', username: 'c', premise: 'Prado'),
      );
      expect(UsersViewState.subtitleOf(manager), 'Responsable de Prado');
      expect(UsersViewState.deviceNote(manager).$1, 'sin navegador');
    });

    test('el modelo lee el código de cada dispositivo', () {
      final user = ManagedUser.fromJson(
        _user(
          4,
          'Carlos',
          'ADMIN',
          devices: [
            _device('mobile', 'XY2Z-KM9N'),
            _device('web', 'PQ4R-ST6V'),
          ],
        ),
      );

      expect(user.deviceCodes[ClientPlatform.mobile], 'XY2Z-KM9N');
      expect(user.deviceCodes[ClientPlatform.web], 'PQ4R-ST6V');

      // Un servidor antiguo no envía el código: el resto sigue funcionando.
      final old = ManagedUser.fromJson({
        'user_id': 1,
        'name': 'A',
        'item': 1,
        'role': {'name': 'EMPLOYEE'},
        'devices': [
          {'platform': 'mobile', 'bound_at': '2026-11-18T08:15:00'},
        ],
      });
      expect(old.devices.containsKey(ClientPlatform.mobile), isTrue);
      expect(old.deviceCodes, isEmpty);
    });
  });

  group('tamaños y letra grande', () {
    for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
      for (final entry in const {
        'monitor 1920x1080': Size(1920, 1080),
        'laptop 1366x768': Size(1366, 768),
        'tableta 800x1024': Size(800, 1024),
        'teléfono 390x844': Size(390, 844),
        'teléfono chico 320x568': Size(320, 568),
      }.entries) {
        testWidgets('Usuarios no desborda (${entry.key}, letra x$scale)', (
          tester,
        ) async {
          backend.users = [
            _user(
              1,
              'María Fernanda Rodríguez de la Quintana Villarroel',
              'ADMIN',
              item: 123456,
              devices: [
                _device('mobile', 'XY2Z-KM9N'),
                _device('web', 'PQ4R-ST6V'),
              ],
            ),
            _user(
              2,
              'Responsable del Predio Central Norte',
              'MANAGE_PREMISE',
              username: 'responsable_central_norte',
              premise: 'Predio Central Norte del Departamento de La Paz',
            ),
            ..._people(),
          ];
          await _open(tester, size: entry.value, scale: scale);

          // El detalle de la cuenta con más contenido (la lista solo construye
          // las filas cercanas: se busca para tenerla a la vista).
          await tester.enterText(find.byType(TextField), 'Rodriguez');
          await tester.pumpAndSettle();
          await tester.tap(
            find.text('María Fernanda Rodríguez de la Quintana Villarroel'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Y el de un responsable de una cuenta del sistema (en angostas
          // primero se vuelve a la lista).
          if (find.text('Volver a la lista').evaluate().isNotEmpty) {
            await tester.ensureVisible(find.text('Volver a la lista'));
            await tester.tap(find.text('Volver a la lista'));
            await tester.pumpAndSettle();
          }
          await tester.enterText(find.byType(TextField), 'Responsable del');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Responsable del Predio Central Norte'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
