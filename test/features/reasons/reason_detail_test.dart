import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:control_leaves_web/features/reasons/presentation/reasons_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

Map<String, dynamic> _reason(
  int id,
  String name,
  String code, {
  bool active = true,
}) => {'reason_id': id, 'name': name, 'code': code, 'active': active};

Map<String, dynamic> _premise(
  int id,
  String name,
  List<String> reasons, {
  String? manager,
}) => {
  'id': id,
  'name': name,
  'latitude': '-17.39',
  'longitude': '-66.15',
  'reason_names': reasons,
  if (manager != null) 'manager': {'user_id': id + 10, 'name': manager},
};

const _failedSync = {
  'status': 'failed',
  'source': 'scheduled',
  'at': '2026-11-12T00:30:00-04:00',
  'actor': null,
  'added': null,
  'updated': null,
  'reactivated': null,
  'deactivated': null,
  'error': 'Comteco devolvió una lista de motivos vacía.',
  'last_success_at': '2026-11-11T00:00:00-04:00',
};

void _fill(FakeAdminBackend backend) {
  backend
    ..catalogReasons = [
      _reason(1, 'Almuerzo', 'AL-03'),
      _reason(2, 'Banco', 'TB-01'),
      _reason(3, 'Gestión personal (antiguo)', 'GP-09', active: false),
    ]
    ..premises = [
      _premise(1, 'Central', ['Almuerzo', 'Banco'], manager: 'Marta Rojas'),
      _premise(2, 'Prado', ['Banco']),
      _premise(3, 'Sopocachi', ['Almuerzo'], manager: 'Rosa Mendoza'),
      _premise(4, 'Villa Fátima', <String>[], manager: 'Luis Vargas'),
    ]
    ..reasonLimit = {
      'period': 'week',
      'mode': 'custom',
      'general': null,
      'custom': [
        {'reason_id': 1, 'name': 'Almuerzo', 'max': 2},
      ],
    };
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(1280, 2000),
  double scale = 1,
  VoidCallback? onOpenSettings,
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
      home: Scaffold(body: ReasonsView(onOpenSettings: onOpenSettings)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
}

FilledButton _button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  late FakeAdminBackend backend;

  setUp(() {
    backend = FakeAdminBackend();
    _fill(backend);
    backend.install();
    AdminDataStore.instance.clear();
  });

  group('lista', () {
    testWidgets('muestra código, en cuántos predios se ofrece y el estado', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Motivos de salida'), findsOneWidget);
      expect(find.text('AL-03 · 2 de 4 predios'), findsOneWidget);
      expect(find.text('TB-01 · 2 de 4 predios'), findsOneWidget);
      expect(find.text('GP-09 · ya no se ofrece'), findsOneWidget);
      expect(find.text('Activo'), findsNWidgets(2));
      expect(find.text('Retirado'), findsOneWidget);
      expect(find.text('Todos 3'), findsOneWidget);
      expect(find.text('Activos 2'), findsOneWidget);
      expect(find.text('Retirados 1'), findsOneWidget);
      // El motivo retirado va tachado.
      final retired = tester.widget<Text>(
        find.text('Gestión personal (antiguo)'),
      );
      expect(retired.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('Elige un motivo de la lista'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las pestañas filtran por estado', (tester) async {
      await _open(tester);

      await tester.tap(find.text('Retirados 1'));
      await tester.pumpAndSettle();
      expect(find.text('Gestión personal (antiguo)'), findsOneWidget);
      expect(find.text('Almuerzo'), findsNothing);

      await tester.tap(find.text('Activos 2'));
      await tester.pumpAndSettle();
      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.text('Gestión personal (antiguo)'), findsNothing);
    });

    testWidgets('se busca por nombre o por código, sin tildes', (tester) async {
      await _open(tester);

      await tester.enterText(find.byType(TextField).first, 'gestion');
      await tester.pumpAndSettle();
      expect(find.text('Gestión personal (antiguo)'), findsOneWidget);
      expect(find.text('Almuerzo'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'tb-01');
      await tester.pumpAndSettle();
      expect(find.text('Banco'), findsOneWidget);
      expect(find.text('Almuerzo'), findsNothing);
    });

    testWidgets('los predios y el límite se piden al abrir la sección', (
      tester,
    ) async {
      await _open(tester);

      expect(backend.requests, contains('GET /api/admin/reasons/catalog'));
      expect(backend.requests, contains('GET /api/admin/premises'));
      expect(
        backend.requests,
        contains('GET /api/admin/settings/leave-limits'),
      );
    });
  });

  group('aviso de sincronización', () {
    testWidgets('si falló, el aviso lo dice y explica los reintentos', (
      tester,
    ) async {
      backend.sync = Map<String, dynamic>.of(_failedSync);
      await _open(tester);

      expect(
        find.text('La última sincronización con Comteco falló'),
        findsOneWidget,
      );
      expect(
        find.text('Fue el 12/11/2026 00:30 (automática).'),
        findsOneWidget,
      );
      expect(find.textContaining('lista de motivos vacía'), findsOneWidget);
      expect(
        find.textContaining('Mientras tanto se usan los motivos ya guardados'),
        findsOneWidget,
      );
      expect(find.textContaining('00:15 y 00:30'), findsOneWidget);
    });

    testWidgets('Sincronizar ahora pide la sincronización y avisa', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pumpAndSettle();

      expect(backend.syncCalls, 1);
      expect(
        find.text('Motivos de salida actualizados correctamente (1 nuevo)'),
        findsOneWidget,
      );
    });
  });

  group('detalle', () {
    testWidgets('muestra los predios con su interruptor y el límite', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Almuerzo');

      expect(
        find.textContaining('Código AL-03 · Activo · viene de Comteco'),
        findsOneWidget,
      );
      expect(find.text('PREDIOS DONDE SE OFRECE'), findsOneWidget);
      expect(find.text('2 de 4'), findsOneWidget);
      expect(find.text('Se ofrece'), findsNWidgets(2));
      expect(find.text('No se ofrece'), findsNWidgets(2));
      expect(find.text('Responsable: Marta Rojas'), findsOneWidget);
      expect(find.text('Sin responsable'), findsOneWidget); // Prado

      // Límite de este motivo: personalizado, 2 por semana.
      expect(find.text('LÍMITE POR PERSONA'), findsOneWidget);
      expect(find.text('2 veces por semana'), findsOneWidget);
      expect(find.text('Cambiar en Ajustes'), findsOneWidget);
      expect(find.text('ESTADO EN COMTECO'), findsOneWidget);

      // Sin cambios no hay nada que guardar ni descartar.
      expect(_button(tester, 'Guardar cambios').onPressed, isNull);
      expect(_button(tester, 'Cancelar').onPressed, isNull);
    });

    testWidgets('el límite general se describe', (tester) async {
      backend.reasonLimit = {
        'period': 'day',
        'mode': 'general',
        'general': 1,
        'custom': <Object>[],
      };
      await _open(tester);
      await _pick(tester, 'Almuerzo');
      expect(find.text('1 vez por día'), findsOneWidget);
    });

    testWidgets('un motivo sin tope propio dice Sin tope', (tester) async {
      backend.reasonLimit = {
        'period': 'month',
        'mode': 'custom',
        'general': null,
        'custom': <Object>[],
      };
      await _open(tester);
      await _pick(tester, 'Banco');
      expect(find.text('Sin tope'), findsOneWidget);
    });

    testWidgets('Cambiar en Ajustes lleva a Ajustes', (tester) async {
      var opened = 0;
      await _open(tester, onOpenSettings: () => opened++);
      await _pick(tester, 'Almuerzo');

      await tester.tap(find.text('Cambiar en Ajustes'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('guardar cambia solo los predios que difieren', (tester) async {
      await _open(tester);
      await _pick(tester, 'Almuerzo');

      // Se ofrece en Prado y se quita de Central.
      await tester.tap(find.text('Prado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 4'), findsOneWidget); // Prado +1, Central −1

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      // Cada predio conserva sus demás motivos; Sopocachi ni se toca.
      final updates = {
        for (final u in backend.premiseUpdates) u['id']: u['reasons'],
      };
      expect(backend.premiseUpdates, hasLength(2));
      expect(updates[1], ['Banco']);
      expect(updates[2], ['Banco', 'Almuerzo']);
      expect(backend.premiseUpdates.every((u) => u.length == 2), isTrue);
      expect(find.text('Almuerzo se actualizó en 2 predios'), findsOneWidget);

      // La lista ya cuenta los predios nuevos y no queda nada pendiente.
      expect(find.text('AL-03 · 2 de 4 predios'), findsOneWidget);
      expect(_button(tester, 'Guardar cambios').onPressed, isNull);
    });

    testWidgets('Cancelar devuelve los interruptores a lo guardado', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Almuerzo');

      await tester.tap(find.text('Prado'));
      await tester.pumpAndSettle();
      expect(find.text('3 de 4'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 4'), findsOneWidget);
      expect(backend.premiseUpdates, isEmpty);
    });

    testWidgets('si el servidor rechaza el cambio, se avisa y se conserva', (
      tester,
    ) async {
      backend.premiseUpdateError = 'No se pudo guardar el predio.';
      await _open(tester);
      await _pick(tester, 'Almuerzo');

      await tester.tap(find.text('Prado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo guardar en Prado: No se pudo guardar el predio.'),
        findsOneWidget,
      );
      // El interruptor sigue encendido para reintentar.
      expect(find.text('3 de 4'), findsOneWidget);
      expect(_button(tester, 'Guardar cambios').onPressed, isNotNull);
    });

    testWidgets('un motivo retirado no se puede editar', (tester) async {
      await _open(tester);
      await _pick(tester, 'Gestión personal (antiguo)');

      expect(
        find.textContaining('Código GP-09 · Retirado · viene de Comteco'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ya no se ofrece en ningún predio'),
        findsOneWidget,
      );
      expect(find.text('Se ofrece'), findsNothing);
      expect(find.text('LÍMITE POR PERSONA'), findsNothing);
      expect(find.text('Guardar cambios'), findsNothing);
      expect(find.textContaining('se reactiva en la próxima'), findsOneWidget);
    });

    testWidgets('cambiar de motivo con cambios sin guardar pregunta antes', (
      tester,
    ) async {
      await _open(tester);
      await _pick(tester, 'Almuerzo');
      await tester.tap(find.text('Prado'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Banco').first);
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Código AL-03'), findsOneWidget);
      expect(find.text('3 de 4'), findsOneWidget);

      await tester.tap(find.text('Banco').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Código TB-01'), findsOneWidget);
      expect(backend.premiseUpdates, isEmpty);
    });
  });

  group('pantallas angostas', () {
    testWidgets('el detalle reemplaza a la lista y se vuelve con el botón', (
      tester,
    ) async {
      await _open(tester, size: const Size(390, 844));
      expect(find.text('Elige un motivo de la lista'), findsNothing);

      await _pick(tester, 'Almuerzo');
      expect(find.text('Volver a la lista'), findsOneWidget);
      expect(find.text('Banco'), findsNothing);

      await tester.ensureVisible(find.text('Volver a la lista'));
      await tester.tap(find.text('Volver a la lista'));
      await tester.pumpAndSettle();
      expect(find.text('Banco'), findsOneWidget);
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
          backend.sync = Map<String, dynamic>.of(_failedSync);
          await _open(tester, size: entry.value, scale: scale);
          expect(tester.takeException(), isNull);

          await _pick(tester, 'Almuerzo');
          expect(tester.takeException(), isNull);
          expect(find.text('PREDIOS DONDE SE OFRECE'), findsOneWidget);

          if (entry.value.width < 900) {
            await tester.ensureVisible(find.text('Volver a la lista'));
            await tester.tap(find.text('Volver a la lista'));
            await tester.pumpAndSettle();
          }
          // La lista construye solo las filas cercanas: se busca el motivo.
          await tester.enterText(find.byType(TextField).first, 'gestion');
          await tester.pumpAndSettle();
          await _pick(tester, 'Gestión personal (antiguo)');
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
