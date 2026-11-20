import 'package:control_leaves_web/core/theme/app_theme.dart';
import 'package:control_leaves_web/features/auth/models/auth_user.dart';
import 'package:control_leaves_web/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_admin_backend.dart';
import '../../support/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('tocar un predio de la vista rápida abre ese predio', (
    tester,
  ) async {
    FakeAdminBackend().install();
    AdminDataStore.instance.clear();
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AdminDashboardPage(
          user: AuthUser(id: 1, name: 'Admin', item: '1', roleName: 'ADMIN'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // «Prado» es el segundo predio de la vista rápida.
    await tester.tap(find.text('Prado'));
    await tester.pumpAndSettle();

    // Ya está en Predios, con el detalle de Prado abierto.
    expect(find.text('NOMBRE DEL PREDIO'), findsOneWidget);
    final name = tester.widget<TextField>(
      find.byKey(const ValueKey('premise-name')),
    );
    expect(name.controller!.text, 'Prado');
  });
}
