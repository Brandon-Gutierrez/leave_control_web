import 'package:control_leaves_web/core/format/date_text.dart';
import 'package:control_leaves_web/core/theme/app_colors.dart';
import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/auth/models/auth_user.dart';
import 'package:control_leaves_web/features/dashboard/models/admin_summary.dart';
import 'package:control_leaves_web/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:control_leaves_web/features/dashboard/presentation/home_parts.dart';
import 'package:control_leaves_web/features/dashboard/presentation/home_view.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:control_leaves_web/features/premises/models/premise.dart';
import 'package:control_leaves_web/features/settings/models/leave_limits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

/// Jueves 19/11/2026: así el saludo y la fecha no dependen del día de la prueba.
DateTime _at(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 19, hour, minute);

final _admin = AuthUser(id: 1, name: 'Ana Pérez', item: '1', roleName: 'ADMIN');

Map<String, dynamic> _premise(
  int id,
  String name, {
  bool located = true,
  String? manager,
  int reasons = 3,
}) => {
  'id': id,
  'name': name,
  if (located) 'latitude': '-17.39',
  if (located) 'longitude': '-66.15',
  if (manager != null) 'manager': {'user_id': id, 'name': manager},
  'reason_names': [for (var i = 0; i < reasons; i++) 'Motivo $i'],
};

Map<String, dynamic> _summary({
  int premises = 6,
  int withoutLocation = 0,
  int withoutManager = 0,
  int withoutReasons = 0,
  int users = 248,
  int admins = 3,
  int? managers = 5,
  int managersWithoutPremise = 0,
  int employeesWithoutApp = 0,
  int? activeReasons = 14,
  Map<String, dynamic>? sync,
}) => {
  'premises': {
    'total': premises,
    'without_location': withoutLocation,
    'without_manager': withoutManager,
    'without_reasons': withoutReasons,
  },
  'users': {
    'total': users,
    'admins': admins,
    'managers': ?managers,
    'managers_without_premise': managersWithoutPremise,
    'employees_without_app': employeesWithoutApp,
  },
  if (activeReasons != null) 'reasons': {'active': activeReasons},
  'reasons_sync': sync,
};

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Abre solo la sección Inicio, con los accesos directos que se indiquen.
Future<void> _openHome(
  WidgetTester tester, {
  DateTime? now,
  AuthUser? user,
  VoidCallback? onAddPremise,
  VoidCallback? onOpenPremises,
  VoidCallback? onOpenUsers,
  VoidCallback? onAddManager,
  VoidCallback? onSearchDevice,
  VoidCallback? onOpenSettings,
  VoidCallback? onOpenReasons,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: HomeView(
          user: user ?? _admin,
          clock: () => now ?? _at(9),
          onAddPremise: onAddPremise ?? () {},
          onOpenPremises: onOpenPremises,
          onOpenUsers: onOpenUsers ?? () {},
          onAddManager: onAddManager,
          onSearchDevice: onSearchDevice,
          onOpenSettings: onOpenSettings,
          onOpenReasons: onOpenReasons,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  late FakeAdminBackend backend;

  setUp(() {
    backend = FakeAdminBackend()
      ..summary = _summary()
      ..premises = [
        _premise(1, 'Central', manager: 'Marta Rojas', reasons: 9),
        _premise(2, 'Prado', reasons: 7),
        _premise(3, 'San Pedro', manager: 'Luis Vargas', reasons: 11),
      ]
      ..install();
    AdminDataStore.instance.clear();
  });

  group('saludo y fecha', () {
    testWidgets('dice la fecha y saluda por nombre', (tester) async {
      _size(tester, const Size(1280, 900));
      await _openHome(tester);

      expect(find.text('JUEVES 19 DE NOVIEMBRE'), findsOneWidget);
      expect(find.text('Buenos días, Ana Pérez'), findsOneWidget);
    });

    testWidgets('el saludo cambia con la hora', (tester) async {
      _size(tester, const Size(1280, 900));
      for (final (hour, greeting) in [
        (9, 'Buenos días'),
        (15, 'Buenas tardes'),
        (21, 'Buenas noches'),
      ]) {
        await _openHome(tester, now: _at(hour));
        expect(find.text('$greeting, Ana Pérez'), findsOneWidget);
      }
    });

    testWidgets('sin nombre saluda al administrador', (tester) async {
      _size(tester, const Size(1280, 900));
      await _openHome(
        tester,
        user: AuthUser(id: 1, name: '', item: '1', roleName: 'ADMIN'),
      );

      expect(find.text('Buenos días, Administrador'), findsOneWidget);
    });

    test('DateText escribe fechas y cifras en español', () {
      expect(
        DateText.longDate(DateTime(2026, 11, 19)),
        'Jueves 19 de noviembre',
      );
      expect(DateText.longDate(DateTime(2026, 3, 1)), 'Domingo 1 de marzo');
      expect(DateText.dayMonthYear(DateTime(2026, 3, 2)), '02/03/2026');
      expect(DateText.hm(DateTime(2026, 3, 2, 8, 5)), '08:05');
      expect(DateText.seconds(1), '1 segundo');
      expect(DateText.seconds(45), '45 segundos');
      expect(DateText.seconds(60), '1 minuto');
      expect(DateText.seconds(300), '5 minutos');
      expect(DateText.seconds(90), '1 min 30 s');
      final now = _at(10);
      expect(DateText.whenText(_at(0), now), 'hoy a las 00:00');
      expect(
        DateText.whenText(DateTime(2026, 11, 18, 0, 15), now),
        'ayer a las 00:15',
      );
      expect(
        DateText.whenText(DateTime(2026, 11, 10, 8), now),
        '10/11/2026 a las 08:00',
      );
    });
  });

  group('franja de cifras', () {
    testWidgets('muestra las cuatro cifras con su nota', (tester) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(
        withoutManager: 1,
        sync: {
          'status': 'failed',
          'source': 'scheduled',
          'at': DateTime(2026, 11, 19).toIso8601String(),
          'error': 'Error',
        },
      );
      await _openHome(tester);

      expect(find.text('6'), findsOneWidget);
      expect(find.text('1 sin responsable'), findsOneWidget);
      expect(find.text('248'), findsOneWidget);
      expect(find.text('3 administradores'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Todos con predio asignado'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Sincronización con error'), findsOneWidget);
    });

    testWidgets('con una sincronización buena dice cuándo fue', (tester) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(
        sync: {
          'status': 'success',
          'source': 'scheduled',
          'at': DateTime(2026, 11, 19, 0, 0).toIso8601String(),
        },
      );
      await _openHome(tester, now: _at(9));

      expect(find.text('Sincronizado hoy a las 00:00'), findsOneWidget);
    });

    testWidgets('notas cuando algo falta: predios, responsables y motivos', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(
        premises: 0,
        managers: 2,
        managersWithoutPremise: 2,
        admins: 1,
      );
      await _openHome(tester);

      expect(find.text('Aún no hay predios'), findsOneWidget);
      expect(find.text('2 sin predio asignado'), findsOneWidget);
      expect(find.text('1 administrador'), findsOneWidget);
      expect(find.text('Aún sin sincronizar'), findsOneWidget);
    });

    testWidgets('un predio sin ubicación pesa más que uno sin responsable', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(withoutLocation: 2, withoutManager: 3);
      await _openHome(tester);

      expect(find.text('2 sin ubicación'), findsOneWidget);
      expect(find.text('3 sin responsable'), findsNothing);
    });

    testWidgets('un servidor antiguo sin los contadores nuevos no falla', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(managers: null, activeReasons: null);
      await _openHome(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Ninguno todavía'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2)); // responsables y motivos
    });

    test('AdminSummary lee los contadores nuevos y usa 0 si faltan', () {
      final full = AdminSummary.fromJson(_summary());
      expect(full.managers, 5);
      expect(full.activeReasons, 14);

      final old = AdminSummary.fromJson(
        _summary(managers: null, activeReasons: null),
      );
      expect(old.managers, 0);
      expect(old.activeReasons, 0);
    });
  });

  group('vista rápida de predios', () {
    testWidgets('los predios con algo pendiente van primero y resaltados', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      await _openHome(tester);

      final prado = tester.getTopLeft(find.text('Prado')).dy;
      final central = tester.getTopLeft(find.text('Central')).dy;
      final sanPedro = tester.getTopLeft(find.text('San Pedro')).dy;
      expect(prado, lessThan(central));
      expect(central, lessThan(sanPedro));

      expect(
        find.text('Sin responsable · nadie muestra el QR'),
        findsOneWidget,
      );
      expect(find.text('Asignar →'), findsOneWidget);
      expect(find.text('Marta Rojas'), findsOneWidget);
      expect(find.text('9 habilitados'), findsOneWidget);
      expect(find.text('11 habilitados'), findsOneWidget);
    });

    testWidgets('dice qué le pasa a cada predio y cómo resolverlo', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      backend.premises = [
        _premise(1, 'A sin mapa', located: false, manager: 'Ana'),
        _premise(2, 'B sin motivos', manager: 'Beto', reasons: 0),
        _premise(3, 'C completo', manager: 'Carla', reasons: 1),
      ];
      await _openHome(tester);

      expect(find.text('Sin ubicación · nadie puede escanear'), findsOneWidget);
      expect(find.text('Marcar →'), findsOneWidget);
      expect(find.text('Sin motivos habilitados'), findsOneWidget);
      expect(find.text('Elegir →'), findsOneWidget);
      expect(find.text('1 habilitado'), findsOneWidget);
    });

    testWidgets('muestra como máximo seis predios', (tester) async {
      _size(tester, const Size(1280, 1200));
      backend.premises = [
        for (var i = 1; i <= 9; i++)
          _premise(i, 'Predio $i', manager: 'Persona $i'),
      ];
      await _openHome(tester);

      expect(
        find.textContaining('Predio '),
        findsNWidgets(PremisesGlance.limit),
      );
    });

    test('pick ordena por prioridad y luego por nombre, y corta en seis', () {
      Premise p(
        int id,
        String name, {
        bool located = true,
        bool manager = true,
      }) => Premise.fromJson(
        _premise(id, name, located: located, manager: manager ? 'M' : null),
      );
      final picked = PremisesGlance.pick([
        p(1, 'Zeta'),
        p(2, 'Beta'),
        p(3, 'Omega', manager: false),
        p(4, 'Alfa', located: false),
        p(5, 'Gamma'),
        p(6, 'Delta'),
        p(7, 'Epsilon'),
      ]);

      expect(picked.map((x) => x.name), [
        'Alfa', // sin ubicación
        'Omega', // sin responsable
        'Beta',
        'Delta',
        'Epsilon',
        'Gamma',
      ]);
    });

    testWidgets('tocar un predio o «Ver todos» lleva a Predios', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      var opened = 0;
      await _openHome(tester, onOpenPremises: () => opened++);

      await tester.tap(find.text('Ver todos →'));
      await tester.tap(find.text('Central'));
      expect(opened, 2);
    });

    testWidgets('sin predios lo dice', (tester) async {
      _size(tester, const Size(1280, 900));
      backend
        ..summary = _summary(premises: 0)
        ..premises = [];
      await _openHome(tester);

      expect(find.text('Aún no hay predios registrados.'), findsOneWidget);
    });
  });

  group('pendientes', () {
    testWidgets('van numerados y la cantidad solo si es más de una', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(
        withoutLocation: 3,
        withoutManager: 1,
        employeesWithoutApp: 12,
      );
      await _openHome(tester);

      expect(find.text('3 predios sin ubicación en el mapa'), findsOneWidget);
      expect(find.text('Predio sin responsable'), findsOneWidget);
      expect(find.text('12 empleados que aún no usan la app'), findsOneWidget);
      for (final n in ['1', '2', '3']) {
        expect(find.text(n), findsWidgets, reason: 'número $n');
      }
    });

    testWidgets('cada pendiente lleva a donde se resuelve', (tester) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(
        withoutLocation: 1,
        managersWithoutPremise: 1,
        employeesWithoutApp: 4,
        sync: {
          'status': 'failed',
          'source': 'scheduled',
          'at': DateTime(2026, 11, 19).toIso8601String(),
          'error': 'Comteco no responde',
        },
      );
      final opened = <String>[];
      await _openHome(
        tester,
        onOpenPremises: () => opened.add('predios'),
        onOpenUsers: () => opened.add('usuarios'),
        onOpenReasons: () => opened.add('motivos'),
      );

      await tester.tap(find.text('Marcar ubicación'));
      await tester.tap(find.text('Asignar predio'));
      await tester.tap(find.text('Ver usuarios'));
      await tester.tap(find.text('Ver motivos'));
      expect(opened, ['predios', 'usuarios', 'usuarios', 'motivos']);
    });

    testWidgets('el error de la sincronización se lee como frase completa', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      backend.summary = _summary(
        sync: {
          'status': 'failed',
          'source': 'scheduled',
          'at': DateTime(2026, 11, 19).toIso8601String(),
          'error': 'Comteco no responde',
        },
      );
      await _openHome(tester);

      expect(
        find.textContaining('Comteco no responde. Se reintenta solo'),
        findsOneWidget,
      );
    });

    testWidgets('si no hay nada pendiente dice que todo está en orden', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      await _openHome(tester);

      expect(find.text('Todo está en orden'), findsOneWidget);
    });
  });

  group('configuración vigente', () {
    testWidgets('muestra las reglas en uso', (tester) async {
      _size(tester, const Size(1280, 900));
      await _openHome(tester);

      expect(find.text('Configuración vigente'), findsOneWidget);
      expect(find.text('5 minutos'), findsOneWidget);
      expect(find.text('3 por día'), findsOneWidget);
      expect(find.text('50 metros'), findsOneWidget);
      expect(find.text('Lun a vie, 00:00'), findsOneWidget);
    });

    testWidgets('«Editar» lleva a Ajustes', (tester) async {
      _size(tester, const Size(1280, 900));
      var opened = 0;
      await _openHome(tester, onOpenSettings: () => opened++);

      await tester.tap(find.text('Editar →'));
      expect(opened, 1);
    });

    test('el límite de salidas se escribe por período', () {
      expect(
        CurrentRules.limitText(const LeaveLimits(period: 'day', maxExits: 3)),
        '3 por día',
      );
      expect(
        CurrentRules.limitText(const LeaveLimits(period: 'week', maxExits: 5)),
        '5 por semana',
      );
      expect(
        CurrentRules.limitText(const LeaveLimits(period: 'month', maxExits: 1)),
        '1 por mes',
      );
      expect(
        CurrentRules.limitText(const LeaveLimits(period: 'day')),
        'Sin tope',
      );
    });
  });

  group('accesos directos', () {
    testWidgets('los cuatro botones del encabezado', (tester) async {
      _size(tester, const Size(1280, 900));
      final calls = <String>[];
      await _openHome(
        tester,
        onAddPremise: () => calls.add('predio'),
        onAddManager: () => calls.add('responsable'),
        onSearchDevice: () => calls.add('dispositivo'),
      );

      await tester.tap(find.text('+ Nuevo predio'));
      await tester.tap(find.text('Crear responsable'));
      await tester.tap(find.text('Código de dispositivo'));
      await tester.tap(find.text('Sincronizar motivos'));
      await tester.pumpAndSettle();

      expect(calls, ['predio', 'responsable', 'dispositivo']);
      expect(backend.syncCalls, 1);
      expect(
        find.textContaining('Motivos de salida actualizados correctamente'),
        findsOneWidget,
      );
    });

    testWidgets('sin acciones de usuarios esos botones no aparecen', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      await _openHome(tester);

      expect(find.text('Crear responsable'), findsNothing);
      expect(find.text('Código de dispositivo'), findsNothing);
      expect(find.text('+ Nuevo predio'), findsOneWidget);
      expect(find.text('Sincronizar motivos'), findsOneWidget);
    });

    testWidgets('«Código de dispositivo» abre la búsqueda en Usuarios', (
      tester,
    ) async {
      _size(tester, const Size(1280, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AdminDashboardPage(user: _admin),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Código de dispositivo').first);
      await tester.pumpAndSettle();

      expect(find.text('Buscar por código de dispositivo'), findsWidgets);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('«Editar» de la configuración abre Ajustes', (tester) async {
      _size(tester, const Size(1280, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AdminDashboardPage(user: _admin),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar →'));
      await tester.pumpAndSettle();

      expect(
        find.text('Reglas que aplican a todas las personas y predios.'),
        findsOneWidget,
      );
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
        testWidgets('Inicio no desborda (${entry.key}, letra x$scale)', (
          tester,
        ) async {
          _size(tester, entry.value);
          backend
            ..summary = _summary(
              withoutLocation: 2,
              withoutManager: 3,
              managersWithoutPremise: 1,
              employeesWithoutApp: 12,
              sync: {
                'status': 'failed',
                'source': 'scheduled',
                'at': DateTime(2026, 11, 19).toIso8601String(),
                'error': 'Error al obtener los motivos de salida de Comteco',
              },
            )
            ..premises = [
              _premise(
                1,
                'Predio Central Norte del Departamento de La Paz',
                manager: 'María Fernanda Rodríguez de la Quintana',
                reasons: 12,
              ),
              _premise(2, 'Prado', reasons: 7),
              _premise(3, 'Sin mapa', located: false, manager: 'Luis Vargas'),
              _premise(4, 'Sin motivos', manager: 'Ana Flores', reasons: 0),
              for (var i = 5; i <= 8; i++)
                _premise(i, 'Predio $i', manager: 'Persona $i'),
            ];
          await _openHome(
            tester,
            scale: scale,
            onAddManager: () {},
            onSearchDevice: () {},
            onOpenSettings: () {},
          );
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -4000),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('Configuración vigente'), findsOneWidget);
        });
      }
    }
  });

  test('los colores del diseño siguen siendo los acordados', () {
    expect(AppColors.lightBg, const Color(0xFFF6F6F3));
    expect(AppColors.primaryRed, const Color(0xFFD32F2F));
  });
}
