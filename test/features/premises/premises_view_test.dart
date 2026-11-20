import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:control_leaves_web/features/premises/presentation/premises_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/blank_tile_provider.dart';
import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

Map<String, dynamic> _manager(int id, String name, {String? premise}) => {
  'user_id': id,
  'name': name,
  'item': 2000 + id,
  'role_id': 3,
  'role': {'name': 'MANAGE_PREMISE'},
  'username': name.split(' ').first.toLowerCase(),
  'devices': <Map<String, dynamic>>[],
  if (premise != null) 'premise': {'premise_id': 1, 'name': premise},
};

/// Central (completo), Prado (sin responsable), Sopocachi (sin ubicación y sin
/// motivos) y Álamos (para probar el orden alfabético sin tildes).
void _fill(FakeAdminBackend backend) {
  backend
    ..users = [
      _manager(6, 'Marta Rojas', premise: 'Central'),
      _manager(7, 'Rosa Mendoza'),
      {
        'user_id': 1,
        'name': 'Ana Flores',
        'item': 1488,
        'role_id': 1,
        'role': {'name': 'EMPLOYEE'},
        'devices': <Map<String, dynamic>>[],
      },
    ]
    ..premises = [
      {
        'id': 1,
        'name': 'Central',
        'latitude': '-17.3935000',
        'longitude': '-66.1570000',
        'manager': {'user_id': 6, 'name': 'Marta Rojas'},
        'reason_names': ['Banco', 'Médico'],
      },
      {
        'id': 2,
        'name': 'Prado',
        'latitude': '-17.4000000',
        'longitude': '-66.1600000',
        'reason_names': ['Banco'],
      },
      {
        'id': 3,
        'name': 'Sopocachi',
        'manager': {'user_id': 7, 'name': 'Rosa Mendoza'},
        'reason_names': <String>[],
      },
      {
        'id': 4,
        'name': 'Álamos',
        'latitude': '-17.4100000',
        'longitude': '-66.1700000',
        'manager': {'user_id': 8, 'name': 'Luis Vargas'},
        'reason_names': ['Banco', 'Médico', 'Trámite'],
      },
    ];
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(1280, 2200),
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
      home: const Scaffold(body: PremisesView()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Elige un predio en la lista (el nombre también sale en el detalle, por eso
/// se toca el primero).
Future<void> _pick(WidgetTester tester, String name) async {
  // En pantallas bajas la fila puede quedar bajo el borde: se desplaza hasta
  // ella.
  await tester.ensureVisible(find.text(name).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
}

Finder get _nameField => find.byKey(const ValueKey('premise-name'));

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(Dialog), matching: finder);

/// Toca el mapa del cuadro abierto (espera el doble toque).
Future<void> _tapMapInDialog(WidgetTester tester, {double dx = 60}) async {
  final map = _inDialog(find.byType(FlutterMap));
  await tester.tapAt(tester.getCenter(map) + Offset(dx, 0));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  late FakeAdminBackend backend;

  setUp(() {
    backend = FakeAdminBackend();
    _fill(backend);
    backend.install();
    AdminDataStore.instance.clear();
    BlankTileProvider.install();
  });

  group('lista', () {
    testWidgets('muestra de 10 en 10 y vuelve a la primera al buscar', (
      tester,
    ) async {
      backend.premises = [
        for (var i = 1; i <= 25; i++)
          {
            'id': i,
            'name': 'Predio ${i.toString().padLeft(2, '0')}',
            'latitude': '-17.39',
            'longitude': '-66.15',
            'reason_names': <String>[],
          },
      ];
      await _open(tester);

      expect(find.text('Predio 01'), findsOneWidget);
      expect(find.text('Predio 10'), findsOneWidget);
      expect(find.text('Predio 11'), findsNothing);
      expect(find.text('1–10 de 25'), findsOneWidget);

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Predio 01'), findsNothing);
      expect(find.text('Predio 11'), findsOneWidget);
      expect(find.text('11–20 de 25'), findsOneWidget);

      // Otra búsqueda: de nuevo la primera página.
      await tester.enterText(find.byType(TextField).first, 'Predio');
      await tester.pumpAndSettle();
      expect(find.text('Predio 01'), findsOneWidget);
      expect(find.text('1–10 de 25'), findsOneWidget);
    });

    testWidgets(
      'muestra los predios con letras, lo que les falta y sus motivos',
      (tester) async {
        await _open(tester);

        // Sin tildes: «Álamos» va con la A, antes que Central.
        final alamos = tester.getTopLeft(find.text('Álamos')).dy;
        final central = tester.getTopLeft(find.text('Central')).dy;
        expect(alamos, lessThan(central));
        expect(find.text('A'), findsOneWidget);
        expect(find.text('S'), findsOneWidget);

        expect(find.text('Responsable: Marta Rojas'), findsOneWidget);
        expect(find.text('Sin responsable'), findsOneWidget); // Prado
        expect(find.text('Sin ubicación en el mapa'), findsOneWidget);
        expect(find.text('2 motivos'), findsOneWidget);
        expect(find.text('1 motivo'), findsOneWidget);
        expect(find.text('Sin motivos'), findsWidgets);

        // Al principio no hay nada elegido.
        expect(find.text('Elige un predio de la lista'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('las pestañas dicen cuántos hay y filtran', (tester) async {
      await _open(tester);

      expect(find.text('Todos 4'), findsOneWidget);
      expect(find.text('Sin responsable 1'), findsOneWidget);
      // Incompletos: sin ubicación o sin motivos (aquí, Sopocachi).
      expect(find.text('Incompletos 1'), findsOneWidget);

      await tester.tap(find.text('Incompletos 1'));
      await tester.pumpAndSettle();
      expect(find.text('Sopocachi'), findsOneWidget);
      expect(find.text('Central'), findsNothing);

      await tester.tap(find.text('Sin responsable 1'));
      await tester.pumpAndSettle();
      expect(find.text('Prado'), findsOneWidget);
      expect(find.text('Sopocachi'), findsNothing);
    });

    testWidgets(
      'la búsqueda ignora tildes y mayúsculas y mira al responsable',
      (tester) async {
        await _open(tester);

        await tester.enterText(find.byType(TextField).first, 'ALAMOS');
        await tester.pumpAndSettle();
        expect(find.text('Álamos'), findsOneWidget);
        expect(find.text('Central'), findsNothing);

        await tester.enterText(find.byType(TextField).first, 'rojas');
        await tester.pumpAndSettle();
        expect(find.text('Central'), findsOneWidget);
        expect(find.text('Álamos'), findsNothing);

        await tester.enterText(find.byType(TextField).first, 'zzz');
        await tester.pumpAndSettle();
        expect(
          find.text('No se encontraron predios con esos filtros.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('sin predios explica cómo crear el primero', (tester) async {
      backend.premises = [];
      await _open(tester);

      expect(find.textContaining('Aún no hay predios.'), findsOneWidget);
      expect(find.textContaining('+ Nuevo predio'), findsWidgets);
    });

    testWidgets('los usuarios solo se piden al elegir un predio', (
      tester,
    ) async {
      await _open(tester);
      expect(backend.requests, contains('GET /api/admin/premises'));
      expect(backend.requests, contains('GET /api/admin/reasons'));
      expect(backend.requests, isNot(contains('GET /api/admin/users')));

      await _pick(tester, 'Central');
      await _pick(tester, 'Prado');
      expect(
        backend.requests.where((r) => r == 'GET /api/admin/users').length,
        1,
      );
    });
  });

  group('detalle', () {
    testWidgets('muestra ubicación, responsable y motivos del predio', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Central');

      expect(
        find.text('Responsable: Marta Rojas · 2 motivos habilitados'),
        findsOneWidget,
      );
      expect(find.text('NOMBRE DEL PREDIO'), findsOneWidget);
      expect(find.text('UBICACIÓN'), findsOneWidget);
      expect(find.text('-17.3935, -66.1570'), findsOneWidget);
      expect(find.textContaining('El círculo marca los 50 m'), findsOneWidget);
      expect(find.text('Cambiar en el mapa'), findsOneWidget);
      expect(find.text('RESPONSABLE DEL PREDIO'), findsOneWidget);
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.text('Trámite'), findsOneWidget);

      // Sin cambios no hay nada que guardar ni descartar.
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar cambios'),
      );
      expect(save.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un predio sin ubicación ni motivos lo avisa', (tester) async {
      await _open(tester);
      await _pick(tester, 'Sopocachi');

      expect(
        find.text(
          'Responsable: Rosa Mendoza · Sin ubicación · '
          'Sin motivos habilitados',
        ),
        findsOneWidget,
      );
      expect(find.text('Sin ubicación fijada'), findsOneWidget);
      expect(find.text('Fijar en el mapa'), findsOneWidget);
      expect(find.text('0 de 3'), findsOneWidget);
    });

    testWidgets(
      'guardar envía nombre, ubicación y motivos sin el responsable',
      (tester) async {
        await _open(tester);
        await _pick(tester, 'Prado');

        await tester.enterText(_nameField, 'Prado Sur');
        await tester.tap(find.text('Trámite'));
        await tester.pumpAndSettle();
        expect(find.text('2 de 3'), findsOneWidget);

        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(backend.premiseUpdates, hasLength(1));
        final sent = backend.premiseUpdates.single;
        expect(sent['id'], 2);
        expect(sent['name'], 'Prado Sur');
        expect(sent['latitude'], -17.4);
        expect(sent['longitude'], -66.16);
        expect(sent['reasons'], ['Banco', 'Trámite']);
        expect(sent.containsKey('manager_user_id'), isFalse);

        expect(find.text('Predio actualizado correctamente'), findsOneWidget);
        // La lista y el detalle ya muestran el nuevo nombre; no queda nada
        // pendiente.
        expect(find.text('Prado Sur'), findsWidgets);
        final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Guardar cambios'),
        );
        expect(save.onPressed, isNull);
      },
    );

    testWidgets('Cancelar devuelve el borrador a lo guardado', (tester) async {
      await _open(tester);
      await _pick(tester, 'Central');

      await tester.enterText(_nameField, 'Otro nombre');
      await tester.tap(find.text('Médico'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 3'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('2 de 3'), findsOneWidget);
      expect(tester.widget<TextField>(_nameField).controller!.text, 'Central');
      expect(backend.premiseUpdates, isEmpty);
    });

    testWidgets('el nombre no puede quedar vacío', (tester) async {
      await _open(tester);
      await _pick(tester, 'Central');

      await tester.enterText(_nameField, '   ');
      await tester.pumpAndSettle();

      expect(find.text('Campo requerido'), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar cambios'),
      );
      expect(save.onPressed, isNull);

      await tester.enterText(_nameField, 'Central 2');
      await tester.pumpAndSettle();
      expect(find.text('Campo requerido'), findsNothing);
    });

    testWidgets('marcar todos y quitar todos cambian el contador', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Prado');

      await tester.tap(find.text('Marcar todos'));
      await tester.pumpAndSettle();
      expect(find.text('3 de 3'), findsOneWidget);

      await tester.tap(find.text('Quitar todos'));
      await tester.pumpAndSettle();
      expect(find.text('0 de 3'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el guardado, el borrador se conserva', (
      tester,
    ) async {
      backend.premiseUpdateError = 'Ya existe un predio con ese nombre.';
      await _open(tester);
      await _pick(tester, 'Prado');

      await tester.enterText(_nameField, 'Central');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe un predio con ese nombre.'), findsOneWidget);
      expect(find.text('Predio actualizado correctamente'), findsNothing);
      expect(tester.widget<TextField>(_nameField).controller!.text, 'Central');
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar cambios'),
      );
      expect(save.onPressed, isNotNull);
    });

    testWidgets('cambiar de predio con cambios sin guardar pregunta antes', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Central');
      await tester.enterText(_nameField, 'Central editado');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prado'));
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsOneWidget);

      // Seguir editando deja todo como estaba.
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsNothing);
      expect(
        tester.widget<TextField>(_nameField).controller!.text,
        'Central editado',
      );

      // Descartar pasa al otro predio y pierde lo escrito.
      await tester.tap(find.text('Prado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_nameField).controller!.text, 'Prado');
      expect(backend.premiseUpdates, isEmpty);
    });

    testWidgets('sin cambios, cambiar de predio no pregunta nada', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Central');
      await tester.tap(find.text('Prado'));
      await tester.pumpAndSettle();

      expect(find.text('Cambios sin guardar'), findsNothing);
      expect(tester.widget<TextField>(_nameField).controller!.text, 'Prado');
    });
  });

  group('ubicación', () {
    testWidgets('cambiarla en el mapa se guarda con Guardar cambios', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Prado');

      await tester.tap(find.text('Cambiar en el mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar ubicación'), findsOneWidget);

      // Hasta tocar el mapa no hay punto nuevo que usar.
      FilledButton useButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Usar esta ubicación'),
      );
      expect(useButton().onPressed, isNull);
      await _tapMapInDialog(tester);
      expect(useButton().onPressed, isNotNull);

      await tester.tap(find.text('Usar esta ubicación'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar ubicación'), findsNothing);
      expect(
        find.textContaining('Ubicación cambiada: se guarda con'),
        findsOneWidget,
      );
      expect(backend.premiseUpdates, isEmpty);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final sent = backend.premiseUpdates.single;
      expect(sent['longitude'], isNot(-66.16));
      expect(sent['longitude'], greaterThan(-66.16)); // se tocó a la derecha
    });

    testWidgets('cancelar el cuadro no cambia la ubicación', (tester) async {
      await _open(tester);
      await _pick(tester, 'Prado');

      await tester.tap(find.text('Cambiar en el mapa'));
      await tester.pumpAndSettle();
      await _tapMapInDialog(tester);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ubicación cambiada'), findsNothing);
      expect(find.text('-17.4000, -66.1600'), findsOneWidget);
    });

    testWidgets('un predio sin ubicación puede fijarla', (tester) async {
      await _open(tester);
      await _pick(tester, 'Sopocachi');

      await tester.tap(find.text('Fijar en el mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Fijar ubicación'), findsOneWidget);
      await _tapMapInDialog(tester);
      await tester.tap(find.text('Usar esta ubicación'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar en el mapa'), findsOneWidget);
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final sent = backend.premiseUpdates.single;
      expect(sent['id'], 3);
      expect(sent['latitude'], isA<double>());
      expect(sent['longitude'], isA<double>());
    });
  });

  group('responsable', () {
    testWidgets('asignar pide confirmación y no toca lo demás', (tester) async {
      await _open(tester);
      await _pick(tester, 'Prado');

      // Prado no tiene responsable: el desplegable invita a elegir uno.
      expect(find.text('Elegir responsable...'), findsOneWidget);
      var assign = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Asignar'),
      );
      expect(assign.onPressed, isNull);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      // Solo los usuarios con rol de responsable; el que ya tiene otro predio
      // lo dice.
      expect(find.text('Ana Flores'), findsNothing);
      expect(find.text('Marta Rojas (Central)'), findsWidgets);
      await tester.tap(find.text('Rosa Mendoza').last);
      await tester.pumpAndSettle();

      assign = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Asignar'),
      );
      expect(assign.onPressed, isNotNull);
      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();

      expect(find.text('Asignar responsable'), findsOneWidget);
      expect(
        find.text('Rosa Mendoza será el responsable de Prado.'),
        findsOneWidget,
      );
      // Todavía no se pidió nada.
      expect(backend.premiseUpdates, isEmpty);

      await tester.tap(_inDialog(find.text('Asignar')));
      await tester.pumpAndSettle();

      expect(backend.premiseUpdates.single, {'id': 2, 'manager_user_id': 7});
      expect(
        find.text('Rosa Mendoza ahora es responsable de Prado'),
        findsOneWidget,
      );
      expect(find.text('Responsable: Rosa Mendoza'), findsWidgets);
    });

    testWidgets('elegir a quien ya es responsable de otro predio lo advierte', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Prado');

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marta Rojas (Central)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Marta Rojas pasará de «Central» a este predio.'),
        findsOneWidget,
      );

      // Cancelar no cambia nada.
      await tester.tap(_inDialog(find.text('Cancelar')));
      await tester.pumpAndSettle();
      expect(backend.premiseUpdates, isEmpty);
    });

    testWidgets('cambiar al responsable actual avisa que el anterior pierde '
        'la sesión', (tester) async {
      await _open(tester);
      await _pick(tester, 'Central');

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rosa Mendoza').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Marta Rojas dejará de ser responsable y su sesión se cerrará.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('quitar al responsable lo deja sin responsable', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Central');

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin responsable (quitar)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Quitar responsable'), findsOneWidget);

      await tester.tap(_inDialog(find.text('Quitar')));
      await tester.pumpAndSettle();

      expect(backend.premiseUpdates.single, {'id': 1, 'manager_user_id': null});
      expect(find.text('Central quedó sin responsable'), findsOneWidget);
      expect(find.text('Elegir responsable...'), findsOneWidget);
    });

    testWidgets('asignar no descarta lo que se escribió en el nombre', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Prado');
      await tester.enterText(_nameField, 'Prado en edición');

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rosa Mendoza').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.text('Asignar')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(_nameField).controller!.text,
        'Prado en edición',
      );
    });
  });

  group('predio nuevo', () {
    testWidgets('al crearlo queda elegido en el detalle', (tester) async {
      await _open(tester);

      await tester.tap(find.text('+ Nuevo predio'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del predio'),
        'Villa Nueva',
      );
      final map = _inDialog(find.byType(FlutterMap));
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(map) + const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Crear predio'));
      await tester.pumpAndSettle();

      expect(find.text('Predio creado correctamente'), findsOneWidget);
      expect(find.text('NOMBRE DEL PREDIO'), findsOneWidget);
      expect(
        tester.widget<TextField>(_nameField).controller!.text,
        'Villa Nueva',
      );
    });
  });

  group('pantallas angostas', () {
    testWidgets('el detalle reemplaza a la lista y se vuelve con el botón', (
      tester,
    ) async {
      await _open(tester, size: const Size(390, 844));

      expect(find.text('Elige un predio de la lista'), findsNothing);
      await _pick(tester, 'Central');
      expect(find.text('Volver a la lista'), findsOneWidget);
      expect(find.text('Prado'), findsNothing);

      await tester.tap(find.text('Volver a la lista'));
      await tester.pumpAndSettle();
      expect(find.text('Prado'), findsOneWidget);
      expect(find.text('Volver a la lista'), findsNothing);
    });

    testWidgets('volver con cambios sin guardar pregunta antes', (
      tester,
    ) async {
      await _open(tester, size: const Size(390, 844));
      await _pick(tester, 'Central');
      await tester.enterText(_nameField, 'Central editado');

      await tester.ensureVisible(find.text('Volver a la lista'));
      await tester.tap(find.text('Volver a la lista'));
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsOneWidget);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('Prado'), findsOneWidget);
    });
  });

  group('letra grande', () {
    for (final scale in const [1.0, 1.3, 2.0]) {
      for (final entry in const {
        'monitor 1280x800': Size(1280, 800),
        'ventana justa 1000x700': Size(1000, 700),
        'teléfono 390x844': Size(390, 844),
        'teléfono chico 320x568': Size(320, 568),
      }.entries) {
        testWidgets('lista y detalle no desbordan (${entry.key}, x$scale)', (
          tester,
        ) async {
          await _open(tester, size: entry.value, scale: scale);
          expect(tester.takeException(), isNull);

          await _pick(tester, 'Central');
          expect(tester.takeException(), isNull);
          expect(find.text('NOMBRE DEL PREDIO'), findsOneWidget);

          // El predio sin ubicación y el cuadro del mapa también caben.
          if (entry.value.width < 900) {
            await tester.ensureVisible(find.text('Volver a la lista'));
            await tester.tap(find.text('Volver a la lista'));
            await tester.pumpAndSettle();
          }
          await tester.enterText(find.byType(TextField).first, 'Sopo');
          await tester.pumpAndSettle();
          await _pick(tester, 'Sopocachi');
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Fijar en el mapa'));
          await tester.tap(find.text('Fijar en el mapa'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Usar esta ubicación'), findsOneWidget);
        });
      }
    }
  });
}
