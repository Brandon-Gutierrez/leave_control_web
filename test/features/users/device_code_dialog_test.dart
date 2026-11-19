import 'package:control_leaves_web/core/network/api_exception.dart';
import 'package:control_leaves_web/features/users/data/user_admin_service.dart';
import 'package:control_leaves_web/features/users/models/device_match.dart';
import 'package:control_leaves_web/features/users/models/managed_user.dart';
import 'package:control_leaves_web/features/users/presentation/device_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUsers implements UserAdminService {
  List<DeviceMatch> matches = [];
  ApiException? error;
  String? searchedCode;

  @override
  Future<List<DeviceMatch>> findDevicesByCode(String code) async {
    searchedCode = code;
    if (error != null) throw error!;
    return matches;
  }

  /// Gestiona metodos no implementados.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _show(
  WidgetTester tester,
  _FakeUsers service,
  void Function(DeviceMatch?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(
              await showDialog<DeviceMatch>(
                context: context,
                builder: (_) => DeviceCodeDialog(service: service),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no busca con el campo vacío', (tester) async {
    final service = _FakeUsers();
    await _show(tester, service, (_) {});

    await tester.tap(find.text('Buscar'));
    await tester.pump();

    expect(
      find.text('Escriba el código que le dictó la persona.'),
      findsOneWidget,
    );
    expect(service.searchedCode, isNull);
  });

  testWidgets(
    'busca el código en mayúsculas y muestra a quién está vinculado',
    (tester) async {
      final service = _FakeUsers()
        ..matches = [
          DeviceMatch(
            userId: 20,
            name: 'Beto Prestatario',
            item: 2057,
            platform: ClientPlatform.mobile,
            boundAt: DateTime(2026, 3, 2, 8, 15),
            code: 'K7M4-Q9XB',
          ),
        ];
      await _show(tester, service, (_) {});

      await tester.enterText(find.byType(TextField), 'k7m4-q9xb');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();

      expect(service.searchedCode, 'K7M4-Q9XB');
      expect(find.text('Beto Prestatario'), findsOneWidget);
      expect(find.textContaining('Item 2057'), findsOneWidget);
      expect(find.text('Desvincular'), findsOneWidget);
    },
  );

  testWidgets('Desvincular devuelve la cuenta encontrada', (tester) async {
    final match = DeviceMatch(
      userId: 20,
      name: 'Beto Prestatario',
      item: 2057,
      platform: ClientPlatform.mobile,
      code: 'K7M4-Q9XB',
    );
    final service = _FakeUsers()..matches = [match];
    DeviceMatch? picked;
    await _show(tester, service, (m) => picked = m);

    await tester.enterText(find.byType(TextField), 'K7M4-Q9XB');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desvincular'));
    await tester.pumpAndSettle();

    expect(picked?.userId, 20);
    expect(picked?.platform, ClientPlatform.mobile);
  });

  testWidgets('avisa si ninguna cuenta tiene ese dispositivo', (tester) async {
    final service = _FakeUsers();
    await _show(tester, service, (_) {});

    await tester.enterText(find.byType(TextField), 'ABCD-2345');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ninguna cuenta tiene vinculado ese dispositivo'),
      findsOneWidget,
    );
    expect(find.text('Desvincular'), findsNothing);
  });

  testWidgets('muestra el error del servidor cuando el código no es válido', (
    tester,
  ) async {
    final service = _FakeUsers()
      ..error = ApiException('El código no es válido.');
    await _show(tester, service, (_) {});

    await tester.enterText(find.byType(TextField), 'XYZ');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('El código no es válido.'), findsOneWidget);
  });
}
