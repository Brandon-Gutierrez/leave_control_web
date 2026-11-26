import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/qr/models/season.dart';
import 'package:control_leaves_web/features/qr/presentation/festive_backdrop.dart';
import 'package:control_leaves_web/features/qr/presentation/manual_entry_dialog.dart';
import 'package:control_leaves_web/features/qr/presentation/qr_generator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester, {
  Season season = Season.none,
  Size size = const Size(1280, 800),
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
      home: QrGeneratorPage.forPremiseManager(
        premiseName: 'Prado',
        season: season,
      ),
    ),
  );
  // Con la fiesta la pantalla nunca queda quieta: se avanza a mano.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Cierra la pantalla (y sus temporizadores) al terminar la prueba.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  late FakeAdminBackend backend;

  setUp(() {
    backend = FakeAdminBackend()..qrPremiseName = 'Prado';
    backend.install();
  });

  group('pantalla del responsable', () {
    testWidgets('muestra el predio, los pasos, el QR y la cuenta regresiva', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('PREDIO'), findsOneWidget);
      expect(find.text('Prado'), findsOneWidget);
      expect(find.text('Registre su salida o retorno'), findsOneWidget);
      expect(find.text('Abra la app Salidas Temporales'), findsOneWidget);
      expect(find.text('Escanee el código'), findsOneWidget);
      expect(find.text('Elija su motivo si va a salir'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('El código se renueva solo'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _close(tester);
    });

    testWidgets('el contador arranca completo aunque el código se pidió antes '
        'de mostrarse', (tester) async {
      // El servidor emitió el código hace 4 s (la animación de fiestas).
      backend.qrIssuedAgo = 4;
      await _open(tester);
      expect(find.text('5:00'), findsOneWidget);

      // Pasa un segundo de verdad: baja de a uno, sin saltar de golpe.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('4:59'), findsOneWidget);

      await _close(tester);
    });

    testWidgets('usa el nombre del predio que manda el servidor', (
      tester,
    ) async {
      backend.qrPremiseName = 'Prado Norte';
      await _open(tester);

      expect(find.text('Prado Norte'), findsOneWidget);

      await _close(tester);
    });

    testWidgets('fuera de temporada es un fondo oscuro liso, sin adornos', (
      tester,
    ) async {
      await _open(tester, season: Season.none);

      expect(find.text('¡Felices fiestas!'), findsNothing);
      expect(find.byType(FestiveBackdrop), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);

      await _close(tester);
    });

    testWidgets('en temporada se viste de fiesta', (tester) async {
      await _open(tester, season: Season.christmas);

      expect(find.text('¡Felices fiestas!'), findsOneWidget);
      expect(find.byType(FestiveBackdrop), findsOneWidget);
      // El QR real sigue ahí, quieto, entre cambios de código.
      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _close(tester);
    });

    testWidgets('el registro manual abre su formulario', (tester) async {
      await _open(tester);

      await tester.tap(find.text('Registro manual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ManualEntryDialog), findsOneWidget);
      expect(find.text('Escriba su item y su carnet'), findsOneWidget);

      await _close(tester);
    });

    testWidgets('si el QR falla se explica y se reintentará solo', (
      tester,
    ) async {
      backend.qrError = 'Error del servidor';
      await _open(tester);

      expect(find.text('Error del servidor'), findsOneWidget);
      expect(find.text('Se reintentará automáticamente.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      // Sin código no hay cuenta regresiva.
      expect(find.text('El código se renueva solo'), findsNothing);

      await _close(tester);
    });

    testWidgets('el reintento manual vuelve a pedir el código', (tester) async {
      backend.qrError = 'Error del servidor';
      await _open(tester);

      backend.qrError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Error del servidor'), findsNothing);

      await _close(tester);
    });
  });

  group('tamaños y letra grande', () {
    for (final season in Season.values) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final entry in const {
          'monitor 1920x1080': Size(1920, 1080),
          'monitor 1280x800': Size(1280, 800),
          'ventana justa 1000x600': Size(1000, 600),
          'tableta 800x1024': Size(800, 1024),
          'teléfono 390x844': Size(390, 844),
          'teléfono chico 320x568': Size(320, 568),
        }.entries) {
          testWidgets('no desborda (${season.name}, ${entry.key}, x$scale)', (
            tester,
          ) async {
            await _open(
              tester,
              season: season,
              size: entry.value,
              scale: scale,
            );

            expect(tester.takeException(), isNull);
            expect(find.byType(QrImageView), findsOneWidget);
            expect(find.text('Registro manual'), findsOneWidget);

            await _close(tester);
          });
        }
      }
    }
  });
}
