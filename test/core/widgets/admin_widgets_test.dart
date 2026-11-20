import 'package:control_leaves_web/core/theme/app_colors.dart';
import 'package:control_leaves_web/core/theme/app_text_styles.dart';
import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/core/widgets/admin_button.dart';
import 'package:control_leaves_web/core/widgets/admin_page.dart';
import 'package:control_leaves_web/core/widgets/app_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/load_app_fonts.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  test('la tipografía Manrope está declarada y sus archivos existen', () async {
    for (final file in [
      'Manrope_400Regular',
      'Manrope_500Medium',
      'Manrope_600SemiBold',
      'Manrope_700Bold',
      'Manrope_800ExtraBold',
    ]) {
      final data = await rootBundle.load('rsc/fonts/$file.ttf');
      expect(data.lengthInBytes, greaterThan(10000), reason: file);
    }
    final theme = buildAppTheme();
    expect(theme.textTheme.bodyMedium?.fontFamily, appFontFamily);
    // Sin color por defecto, todo texto que no lo indica sale blanco.
    expect(theme.textTheme.bodyMedium?.color, AppColors.darkText);
    expect(theme.textTheme.titleLarge?.color, AppColors.darkText);
  });

  testWidgets('un texto sin color explícito se dibuja oscuro', (tester) async {
    await tester.pumpWidget(_app(const Center(child: Text('Hola'))));

    final style = DefaultTextStyle.of(tester.element(find.text('Hola'))).style;
    expect(style.color, AppColors.darkText);
    expect(style.fontFamily, appFontFamily);
  });

  group('AppPrimaryButton', () {
    testWidgets('usa Manrope y responde al toque', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(AppPrimaryButton(label: 'Ingresar', onPressed: () => taps++)),
      );

      final style = DefaultTextStyle.of(tester.element(find.text('Ingresar')));
      expect(style.style.fontFamily, appFontFamily);
      await tester.tap(find.text('Ingresar'));
      expect(taps, 1);
    });

    testWidgets('con loading muestra el indicador y no se puede tocar', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          AppPrimaryButton(
            label: 'Ingresar',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Ingresar'), findsNothing);
      await tester.tap(find.byType(AppPrimaryButton));
      expect(taps, 0);
    });
  });

  group('AdminButton', () {
    testWidgets('los cuatro tipos se dibujan con su color', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              AdminButton(label: 'Secundario', onPressed: () {}),
              AdminButton.primary(label: 'Principal', onPressed: () {}),
              AdminButton.dark(label: 'Oscuro', onPressed: () {}),
              AdminButton.danger(label: 'Peligro', onPressed: () {}),
            ],
          ),
        ),
      );

      Color? bg(String label) {
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, label),
        );
        return button.style?.backgroundColor?.resolve({});
      }

      expect(bg('Secundario'), Colors.white);
      expect(bg('Principal'), AppColors.primaryRed);
      expect(bg('Oscuro'), AppColors.darkText);
      expect(bg('Peligro'), Colors.white);
      final danger = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Peligro'),
      );
      expect(danger.style?.foregroundColor?.resolve({}), AppColors.danger);
    });

    testWidgets('mide 42 px de alto y usa Manrope', (tester) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: AdminButton(label: 'Guardar', onPressed: () {}),
          ),
        ),
      );

      expect(tester.getSize(find.byType(FilledButton)).height, 42);
      final style = DefaultTextStyle.of(tester.element(find.text('Guardar')));
      expect(style.style.fontFamily, appFontFamily);
    });

    testWidgets('sin acción queda deshabilitado', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(child: AdminButton(label: 'Guardar', onPressed: null)),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AdminPage', () {
    Widget page({int actions = 1}) => AdminPage(
      title: 'Usuarios',
      subtitle: 'Elige a una persona de la lista.',
      actions: [
        for (var i = 0; i < actions; i++)
          AdminButton.primary(label: 'Acción $i', onPressed: () {}),
      ],
      child: const Text('contenido'),
    );

    testWidgets('muestra título, ayuda, acciones y contenido', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(page()));

      expect(find.text('Usuarios'), findsOneWidget);
      expect(find.text('Elige a una persona de la lista.'), findsOneWidget);
      expect(find.text('Acción 0'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets('la hoja blanca no pasa de 1240 px y llega hasta abajo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(page()));

      final sheet = find
          .ancestor(
            of: find.text('contenido'),
            matching: find.byType(ColoredBox),
          )
          .first;
      final size = tester.getSize(sheet);
      expect(size.width, AppDimens.pageMaxWidth);
      expect(size.height, greaterThanOrEqualTo(900 - 1));
    });

    for (final width in [320.0, 390.0, 800.0, 1280.0]) {
      testWidgets('no desborda en $width px con varias acciones', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(page(actions: 3)));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
