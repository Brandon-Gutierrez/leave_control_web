import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/auth/models/auth_user.dart';
import 'package:control_leaves_web/features/auth/presentation/admin_login_page.dart';
import 'package:control_leaves_web/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:control_leaves_web/features/dashboard/presentation/user_profile_header.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

final _admin = AuthUser(
  id: 1,
  name: 'María Fernanda Rodríguez de la Quintana',
  item: '1',
  roleName: 'ADMIN',
);

/// Pantalla con la letra del navegador ampliada (accesibilidad).
Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  theme: buildAppTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  setUp(() {
    FakeAdminBackend().install();
    AdminDataStore.instance.clear();
  });

  group('barra superior (pantallas anchas)', () {
    testWidgets('muestra las cinco pestañas y a quién inició sesión', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(AdminDashboardPage(user: _admin)));
      await tester.pumpAndSettle();

      for (final tab in [
        'Inicio',
        'Predios',
        'Usuarios',
        'Motivos',
        'Ajustes',
      ]) {
        expect(find.text(tab), findsOneWidget, reason: tab);
      }
      expect(find.text(_admin.name), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      // Sin barra inferior ni barra lateral.
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('cambiar de pestaña muestra su sección', (tester) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(AdminDashboardPage(user: _admin)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reglas que aplican a todas las personas y predios.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Flores'), findsOneWidget);
      expect(
        find.text('Reglas que aplican a todas las personas y predios.'),
        findsNothing,
      );
    });

    testWidgets('la pestaña activa se marca en negrita y con otro color', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(AdminDashboardPage(user: _admin)));
      await tester.pumpAndSettle();

      // El título de la página repite el nombre de la pestaña: la del
      // encabezado es la primera.
      TextStyle? styleOf(String tab) =>
          tester.widget<Text>(find.text(tab).first).style;
      expect(styleOf('Inicio')?.fontWeight, FontWeight.w800);
      expect(styleOf('Predios')?.fontWeight, FontWeight.w700);
      expect(styleOf('Inicio')?.color, isNot(styleOf('Predios')?.color));

      await tester.tap(find.text('Predios'));
      await tester.pumpAndSettle();
      expect(styleOf('Predios')?.fontWeight, FontWeight.w800);
      expect(styleOf('Inicio')?.fontWeight, FontWeight.w700);
    });

    testWidgets('Ajustes muestra las dos reglas en la misma página', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(AdminDashboardPage(user: _admin)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      // Sin cuadros emergentes: cada regla es una tarjeta con sus campos.
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Límite de salidas'), findsOneWidget);
      expect(find.text('Vida del código QR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('pantallas angostas', () {
    for (final size in const [Size(390, 844), Size(800, 1024)]) {
      testWidgets('usan barra inferior y una barra superior corta en '
          '${size.width.toInt()} px', (tester) async {
        _size(tester, size);
        await tester.pumpWidget(_app(AdminDashboardPage(user: _admin)));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Ajustes'), findsOneWidget);
        expect(find.text('MF'), findsOneWidget); // iniciales de la persona
        expect(find.byTooltip('Cerrar sesión'), findsOneWidget);

        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();
        expect(
          find.text('Reglas que aplican a todas las personas y predios.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('inicio de sesión', () {
    testWidgets('en pantallas anchas muestra la marca y el formulario', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(const AdminLoginPage()));
      await tester.pumpAndSettle();

      expect(find.text('Salidas Temporales'), findsOneWidget);
      expect(
        find.text('Panel de administración y pantalla del QR de cada predio.'),
        findsOneWidget,
      );
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(
        find.textContaining('queda vinculado a su cuenta'),
        findsOneWidget,
      );
    });

    testWidgets('en pantallas angostas va todo en una columna', (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app(const AdminLoginPage()));
      await tester.pumpAndSettle();

      expect(find.text('Salidas Temporales'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('los campos vacíos piden completarse', (tester) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(const AdminLoginPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Campo requerido'), findsNWidgets(2));
    });

    testWidgets('el ojo muestra y oculta la contraseña', (tester) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_app(const AdminLoginPage()));
      await tester.pumpAndSettle();

      EditableText password() =>
          tester.widget<EditableText>(find.byType(EditableText).at(1));
      expect(password().obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(password().obscureText, isFalse);
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });
  });

  test('las iniciales salen de las dos primeras palabras', () {
    expect(UserAvatar.initials('Ana Pérez'), 'AP');
    expect(UserAvatar.initials('  luis   gómez  ruiz '), 'LG');
    expect(UserAvatar.initials('Administrador'), 'A');
    expect(UserAvatar.initials(''), '');
  });

  group('letra grande', () {
    for (final scale in const [1.3, 1.6, 2.0]) {
      for (final entry in const {
        'monitor 1280x800': Size(1280, 800),
        'ventana justa 1000x700': Size(1000, 700),
        'teléfono 390x844': Size(390, 844),
        'teléfono chico 320x568': Size(320, 568),
      }.entries) {
        testWidgets('el panel no desborda (${entry.key}, letra x$scale)', (
          tester,
        ) async {
          _size(tester, entry.value);
          await tester.pumpWidget(
            _app(AdminDashboardPage(user: _admin), scale: scale),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ajustes'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('el login no desborda (${entry.key}, letra x$scale)', (
          tester,
        ) async {
          _size(tester, entry.value);
          await tester.pumpWidget(_app(const AdminLoginPage(), scale: scale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
