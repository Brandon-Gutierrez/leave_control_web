import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:control_leaves_web/features/settings/presentation/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

const _leavePath = '/api/admin/settings/leave-limits';
const _qrPath = '/api/admin/settings/qr';

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(1280, 1800),
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
      home: const Scaffold(body: SettingsView()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _person => find.byKey(const ValueKey('limit-person'));
Finder get _general => find.byKey(const ValueKey('limit-reason-general'));
Finder get _qr => find.byKey(const ValueKey('qr-seconds'));

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

/// El botón «Guardar cambios» de la tarjeta de límites (0) o del QR (1).
FilledButton _save(WidgetTester tester, int card) =>
    tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar cambios').at(card),
    );

Future<void> _tapSave(WidgetTester tester, int card) async {
  final button = find.widgetWithText(FilledButton, 'Guardar cambios').at(card);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  late FakeAdminBackend backend;

  setUp(() {
    backend = FakeAdminBackend()
      ..leavePeriod = 'week'
      ..maxExits = 3
      ..catalogReasons = []
      ..reasonLimit = {
        'period': 'day',
        'mode': 'general',
        'general': 1,
        'custom': [
          {'reason_id': 1, 'name': 'Almuerzo', 'max': null},
          {'reason_id': 2, 'name': 'Médico', 'max': 4},
        ],
      };
    backend.install();
    AdminDataStore.instance.clear();
  });

  group('lectura', () {
    testWidgets('muestra las dos reglas con sus valores actuales', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Límite de salidas'), findsOneWidget);
      expect(find.text('Vida del código QR'), findsOneWidget);
      expect(_text(tester, _person), '3');
      expect(_text(tester, _general), '1');
      expect(find.text('Semana'), findsNWidgets(2));
      expect(find.text('General'), findsOneWidget);
      expect(_text(tester, _qr), '300');
      expect(find.text('Segundos (30 a 3600)'), findsOneWidget);
      expect(find.text('5 minutos'), findsOneWidget);

      // Sin cambios no hay nada que guardar ni descartar.
      expect(_save(tester, 0).onPressed, isNull);
      expect(_save(tester, 1).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las reglas se piden al abrir la página', (tester) async {
      await _open(tester);

      expect(backend.requests, contains('GET $_leavePath'));
      expect(backend.requests, contains('GET $_qrPath'));
    });
  });

  group('límite de salidas', () {
    testWidgets('guardar envía el período, el tope y el límite por motivo', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Mes').first); // período por persona
      await tester.enterText(_person, '5');
      await tester.enterText(_general, '2');
      await tester.pumpAndSettle();
      expect(_save(tester, 0).onPressed, isNotNull);

      await _tapSave(tester, 0);

      final sent = backend.settingsUpdates.single;
      expect(sent['path'], _leavePath);
      expect(sent['period'], 'month');
      expect(sent['max_exits'], 5);
      expect(sent['reason_limit']['mode'], 'general');
      expect(sent['reason_limit']['general'], 2);
      expect(sent['reason_limit']['period'], 'day');
      expect(
        find.text('Límites de salidas actualizados para todo el personal'),
        findsOneWidget,
      );
      // Ya no queda nada pendiente y el QR no se tocó.
      expect(_save(tester, 0).onPressed, isNull);
      expect(find.byKey(const ValueKey('qr-seconds')), findsOneWidget);
      expect(
        backend.settingsUpdates.where((u) => u['path'] == _qrPath),
        isEmpty,
      );
    });

    testWidgets('el período por motivo se cambia aparte', (tester) async {
      await _open(tester);

      await tester.tap(find.text('Semana').last); // período por motivo
      await tester.pumpAndSettle();
      await _tapSave(tester, 0);

      final sent = backend.settingsUpdates.single;
      expect(sent['period'], 'week'); // el de la persona sigue igual
      expect(sent['reason_limit']['period'], 'week');
    });

    testWidgets('vacío es sin tope', (tester) async {
      await _open(tester);

      await tester.enterText(_person, '');
      await tester.pumpAndSettle();
      await _tapSave(tester, 0);

      expect(backend.settingsUpdates.single['max_exits'], isNull);
    });

    testWidgets('el modo personalizado pide un tope por motivo', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Personalizado'));
      await tester.pumpAndSettle();

      expect(_general, findsNothing);
      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.text('Médico'), findsOneWidget);
      expect(_text(tester, find.byKey(const ValueKey('limit-reason-2'))), '4');

      // Una sola salida de almuerzo; el médico queda sin tope.
      await tester.enterText(find.byKey(const ValueKey('limit-reason-1')), '1');
      await tester.enterText(find.byKey(const ValueKey('limit-reason-2')), '');
      await tester.pumpAndSettle();
      await _tapSave(tester, 0);

      final limit = backend.settingsUpdates.single['reason_limit'];
      expect(limit['mode'], 'custom');
      expect([for (final c in limit['custom']) c['reason_id']], [1, 2]);
      expect([for (final c in limit['custom']) c['max']], [1, null]);
    });

    testWidgets('un tope en cero se marca y no se guarda', (tester) async {
      await _open(tester);

      await tester.enterText(_person, '0');
      await tester.pumpAndSettle();

      expect(find.textContaining('Mínimo 1'), findsOneWidget);
      expect(_save(tester, 0).onPressed, isNull);
      expect(backend.settingsUpdates, isEmpty);
    });

    testWidgets('un tope en cero de un motivo oculto no estorba', (
      tester,
    ) async {
      await _open(tester);

      // En modo general solo cuenta el tope general: se escribe 0 en un motivo
      // del modo personalizado y se vuelve a General.
      await tester.tap(find.text('Personalizado'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('limit-reason-1')), '0');
      await tester.pumpAndSettle();
      expect(_save(tester, 0).onPressed, isNull);

      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      // El 0 escrito en un motivo no cuenta en modo general: no se marca, no
      // bloquea y no viaja al servidor (no hay nada que guardar).
      expect(find.textContaining('Mínimo 1'), findsNothing);
      expect(_save(tester, 0).onPressed, isNull);
    });

    testWidgets('Cancelar devuelve los campos a lo guardado', (tester) async {
      await _open(tester);

      await tester.enterText(_person, '9');
      await tester.tap(find.text('Mes').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar').first);
      await tester.pumpAndSettle();

      expect(_text(tester, _person), '3');
      expect(_save(tester, 0).onPressed, isNull);
      expect(backend.settingsUpdates, isEmpty);
    });

    testWidgets(
      'si el servidor lo rechaza, se avisa y se conserva lo escrito',
      (tester) async {
        backend.settingsError = 'El período no es válido.';
        await _open(tester);

        await tester.enterText(_person, '4');
        await tester.pumpAndSettle();
        await _tapSave(tester, 0);

        expect(find.text('El período no es válido.'), findsOneWidget);
        expect(_text(tester, _person), '4');
        expect(_save(tester, 0).onPressed, isNotNull);
      },
    );
  });

  group('vida del QR', () {
    testWidgets('muestra a cuánto equivale lo escrito', (tester) async {
      await _open(tester);

      await tester.enterText(_qr, '90');
      await tester.pumpAndSettle();
      expect(find.text('1 min 30 s'), findsOneWidget);

      await tester.enterText(_qr, '45');
      await tester.pumpAndSettle();
      expect(find.text('45 segundos'), findsOneWidget);
    });

    testWidgets('fuera del rango se marca y no se guarda', (tester) async {
      await _open(tester);

      await tester.enterText(_qr, '10');
      await tester.pumpAndSettle();
      expect(
        find.text('Ingresa un valor entre 30 y 3600 segundos.'),
        findsOneWidget,
      );
      expect(find.text('—'), findsOneWidget);
      expect(_save(tester, 1).onPressed, isNull);

      await tester.enterText(_qr, '5000');
      await tester.pumpAndSettle();
      expect(_save(tester, 1).onPressed, isNull);
    });

    testWidgets('guardar cambia solo el QR y avisa', (tester) async {
      await _open(tester);

      await tester.enterText(_qr, '600');
      await tester.pumpAndSettle();
      await _tapSave(tester, 1);

      final sent = backend.settingsUpdates.single;
      expect(sent['path'], _qrPath);
      expect(sent['qr_ttl_seconds'], 600);
      expect(
        find.text('Vida del código QR actualizada a 10 minutos'),
        findsOneWidget,
      );
      expect(_save(tester, 1).onPressed, isNull);
      // Inicio y los demás ven el valor nuevo.
      expect(AdminDataStore.instance.qrSettingsData.value?.ttlSeconds, 600);
    });

    testWidgets('lo escrito en una tarjeta no se pierde al guardar la otra', (
      tester,
    ) async {
      await _open(tester);

      await tester.enterText(_person, '7');
      await tester.enterText(_qr, '120');
      await tester.pumpAndSettle();
      await _tapSave(tester, 1);

      expect(backend.settingsUpdates.single['path'], _qrPath);
      expect(_text(tester, _person), '7');
      expect(_save(tester, 0).onPressed, isNotNull);
    });

    testWidgets('Cancelar devuelve el valor guardado', (tester) async {
      await _open(tester);

      await tester.enterText(_qr, '120');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar').last);
      await tester.pumpAndSettle();

      expect(_text(tester, _qr), '300');
    });

    testWidgets('si el servidor lo rechaza, se avisa y se conserva', (
      tester,
    ) async {
      backend.settingsError = 'No se pudo actualizar el QR.';
      await _open(tester);

      await tester.enterText(_qr, '120');
      await tester.pumpAndSettle();
      await _tapSave(tester, 1);

      expect(find.text('No se pudo actualizar el QR.'), findsOneWidget);
      expect(_text(tester, _qr), '120');
    });
  });

  group('distribución', () {
    testWidgets('en pantallas anchas las tarjetas van lado a lado', (
      tester,
    ) async {
      await _open(tester);

      final left = tester.getTopLeft(find.text('Límite de salidas'));
      final right = tester.getTopLeft(find.text('Vida del código QR'));
      expect(right.dx, greaterThan(left.dx));
      expect(right.dy, left.dy);
    });

    testWidgets('en pantallas angostas van una debajo de la otra', (
      tester,
    ) async {
      await _open(tester, size: const Size(390, 2600));

      final top = tester.getTopLeft(find.text('Límite de salidas'));
      final below = tester.getTopLeft(find.text('Vida del código QR'));
      expect(below.dy, greaterThan(top.dy));
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
        testWidgets('no desborda (${entry.key}, x$scale)', (tester) async {
          await _open(tester, size: entry.value, scale: scale);
          expect(tester.takeException(), isNull);

          // También con el modo personalizado y un error a la vista.
          await tester.ensureVisible(find.text('Personalizado'));
          await tester.tap(find.text('Personalizado'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('limit-reason-1')),
            '0',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(_qr);
          await tester.enterText(_qr, '10');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
