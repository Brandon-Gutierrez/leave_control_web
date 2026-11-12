// Estados vacíos del panel cuando todavía no hay predios (sin backend).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:control_leaves_web/core/network/api_client.dart';
import 'package:control_leaves_web/core/widgets/skeleton.dart';
import 'package:control_leaves_web/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _emptySummary = {
  'status': 0,
  'data': {
    'premises': {
      'total': 0,
      'without_location': 0,
      'without_manager': 0,
      'without_reasons': 0,
    },
    'users': {
      'total': 1,
      'admins': 1,
      'managers_without_premise': 0,
      'employees_without_app': 0,
    },
  },
};

/// Sin predios. Si [gate] existe, la segunda lista de predios espera a que se
/// complete (simula la recarga que sigue a crear un predio).
class _EmptyAdapter implements HttpClientAdapter {
  Completer<void>? gate;
  var premiseListings = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();
    Object body = {'status': 0};

    if (path == '/api/admin/summary' && method == 'GET') {
      body = _emptySummary;
    } else if (path == '/api/admin/premises' && method == 'GET') {
      premiseListings++;
      if (premiseListings > 1) await gate?.future;
      body = {
        'status': 0,
        'data': premiseListings > 1
            ? [
                {'id': 1, 'name': 'Predio Nuevo', 'reason_names': <String>[]},
              ]
            : <Object>[],
      };
    } else if (path == '/api/admin/reasons' && method == 'GET') {
      body = {'status': 0, 'reasons': <String>[]};
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _EmptyAdapter adapter;

  setUp(() {
    adapter = _EmptyAdapter();
    ApiClient().dio.httpClientAdapter = adapter;
    AdminDataStore.instance.clear();
  });

  Future<void> setSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'Inicio sin predios pide agregar el primero, no dice "en orden"',
    (tester) async {
      await setSize(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
      await tester.pumpAndSettle();

      expect(find.text('Todo está en orden'), findsNothing);
      expect(find.text('Aún no hay predios registrados'), findsOneWidget);
      expect(find.text('Agregar predio'), findsOneWidget);
    },
  );

  testWidgets('Predios vacío explica cómo crear el primero', (tester) async {
    await setSize(tester);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Predios'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no hay predios.'), findsOneWidget);
    expect(
      find.text('No se encontraron predios con esos filtros.'),
      findsNothing,
    );
  });

  testWidgets('recargar con la lista vacía no muestra "sin resultados"', (
    tester,
  ) async {
    await setSize(tester);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Predios'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay predios.'), findsOneWidget);

    // Se pide la lista de nuevo (como tras crear un predio) y la respuesta tarda.
    adapter.gate = Completer<void>();
    unawaited(AdminDataStore.instance.refreshQuietly());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Aún no hay predios.'), findsNothing);
    expect(
      find.text('No se encontraron predios con esos filtros.'),
      findsNothing,
    );
    expect(find.byType(SkeletonBox), findsWidgets);

    adapter.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Predio Nuevo'), findsOneWidget);
  });
}
