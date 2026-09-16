// Ejecutar con: flutter test --platform chrome
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:control_leaves_web/models/premise_model.dart';
import 'package:control_leaves_web/screens/admin_dashboard_page.dart';
import 'package:control_leaves_web/screens/generator_qr_page.dart';
import 'package:control_leaves_web/screens/login_admin_page.dart';
import 'package:control_leaves_web/services/api_client.dart';

/// Responde con datos de ejemplo sin llamar al backend.
class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body;
    if (options.path.endsWith('/qr-tokens')) {
      body = {'status': 0, 'token': 'Predio Central+123e4567', 'TTL': 60};
    } else if (options.path == '/api/admin/reasons') {
      body = {
        'status': 0,
        'reasons': ['Banco', 'Comisión de servicio', 'Médico', 'Personal'],
      };
    } else {
      body = {
        'status': 0,
        'data': [
          for (var i = 1; i <= 7; i++)
            {
              'id': i,
              'name': i == 3
                  ? 'Predio con un nombre bastante largo para probar el ajuste $i'
                  : 'Predio $i',
              'reason_names': ['Banco', 'Médico'],
            },
        ],
      };
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _sizes = <String, Size>{
  'teléfono': Size(360, 740),
  'tablet': Size(800, 1024),
  'laptop': Size(1366, 768),
  'monitor': Size(1920, 1080),
};

void main() {
  setUp(() => ApiClient().dio.httpClientAdapter = _FakeAdapter());

  for (final entry in _sizes.entries) {
    Future<void> setSize(WidgetTester tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Login no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginAdminPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('Dashboard no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Predio 1'), findsOneWidget);

      // Expandir una tarjeta
      await tester.tap(find.text('Predio 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Motivos de salida permitidos'), findsOneWidget);
    });

    testWidgets('QR no desborda en ${entry.key}', (tester) async {
      await setSize(tester);
      await tester.pumpWidget(MaterialApp(
        home: QrPage(
          premise: Premise(id: 1, name: 'Predio Central', reasonNames: []),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Se actualiza en: 60 s'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
