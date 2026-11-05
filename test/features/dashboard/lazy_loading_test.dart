import 'dart:async';

import 'package:control_leaves_web/core/network/api_client.dart';
import 'package:control_leaves_web/core/widgets/lazy_card_grid.dart';
import 'package:control_leaves_web/core/widgets/skeleton.dart';
import 'package:control_leaves_web/features/auth/models/auth_user.dart';
import 'package:control_leaves_web/features/auth/state/session_controller.dart';
import 'package:control_leaves_web/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/counting_adapter.dart';

const _premises = '/api/admin/premises';
const _users = '/api/admin/users';
const _roles = '/api/admin/roles';
const _reasons = '/api/admin/reasons';
const _summary = '/api/admin/summary';

CountingAdapter _adapter() => CountingAdapter({
  _summary: {
    'status': 0,
    'data': {
      'premises': {
        'total': 12,
        'without_location': 2,
        'without_manager': 0,
        'without_reasons': 0,
      },
      'users': {
        'total': 340,
        'admins': 3,
        'managers_without_premise': 0,
        'employees_without_app': 0,
      },
    },
  },
  _premises: {
    'status': 0,
    'data': [
      for (var i = 1; i <= 40; i++)
        {
          'id': i,
          'name': 'Predio $i',
          'latitude': '-17.39',
          'longitude': '-66.15',
          'reason_names': ['Banco'],
        },
    ],
  },
  _users: {
    'status': 0,
    'data': [
      for (var i = 1; i <= 60; i++)
        {
          'user_id': i,
          'name': 'Persona $i',
          'item': 1000 + i,
          'role': {'role_id': 1, 'name': 'EMPLOYEE'},
        },
    ],
  },
  _roles: {
    'status': 0,
    'data': [
      {'role_id': 1, 'name': 'EMPLOYEE'},
      {'role_id': 2, 'name': 'ADMIN'},
    ],
  },
  _reasons: {
    'status': 0,
    'reasons': ['Banco'],
  },
});

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AdminDashboardPage(
        user: AuthUser(id: 99, name: 'Admin', item: '1', roleName: 'ADMIN'),
      ),
    ),
  );
}

void main() {
  late CountingAdapter adapter;

  setUp(() {
    adapter = _adapter();
    ApiClient().dio.httpClientAdapter = adapter;
    SessionController.instance.set(null);
    AdminDataStore.instance.clear();
  });

  group('carga por partes del panel', () {
    testWidgets('al iniciar solo se pide el resumen de Inicio', (tester) async {
      await _open(tester);
      await tester.pumpAndSettle();

      expect(adapter.hitsOf(_summary), 1);
      expect(adapter.hitsOf(_premises), 0);
      expect(adapter.hitsOf(_users), 0);
      expect(adapter.hitsOf(_roles), 0);
      expect(adapter.hitsOf(_reasons), 0);
      // Los contadores salen del resumen, no de listas descargadas.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('mientras llega el resumen se ven esqueletos', (tester) async {
      adapter.gate = Completer<void>();
      await _open(tester);
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.text('340'), findsNothing);

      adapter.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('Predios y Usuarios se piden al abrirlos, una sola vez', (
      tester,
    ) async {
      await _open(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();
      expect(adapter.hitsOf(_users), 1);
      // Ni roles ni predios hacen falta para ver la lista.
      expect(adapter.hitsOf(_roles), 0);
      expect(adapter.hitsOf(_premises), 0);

      await tester.tap(find.text('Predios'));
      await tester.pumpAndSettle();
      expect(adapter.hitsOf(_premises), 1);

      // Volver a una sección al día no repite la petición.
      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(adapter.hitsOf(_users), 1);
      expect(adapter.hitsOf(_premises), 1);
      expect(adapter.hitsOf(_summary), 1);
    });

    testWidgets('los roles se piden al abrir el diálogo de cambio de rol', (
      tester,
    ) async {
      await _open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();
      expect(adapter.hitsOf(_roles), 0);

      await tester.tap(find.text('Persona 1'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar rol'), findsOneWidget);
      expect(adapter.hitsOf(_roles), 1);
      expect(adapter.hitsOf(_premises), 1);
    });

    testWidgets('si el resumen falla se avisa y se puede reintentar', (
      tester,
    ) async {
      adapter.failStatus[_summary] = 500;
      await _open(tester);
      await tester.pumpAndSettle();

      expect(find.text('Fallo 500 en $_summary'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      adapter.failStatus.remove(_summary);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('una lista que falla no impide ver las demás secciones', (
      tester,
    ) async {
      adapter.failStatus[_users] = 500;
      await _open(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Predios'));
      await tester.pumpAndSettle();
      expect(find.text('Predio 1'), findsOneWidget);
    });

    testWidgets('sincronizar desde Inicio funciona sin abrir Predios', (
      tester,
    ) async {
      await _open(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Actualizar motivos de salida'));
      await tester.pumpAndSettle();

      expect(adapter.hitsOf('/api/admin/reasons/sync'), 1);
      // Se refresca lo que estaba cargado (el resumen), no lo demás.
      expect(adapter.hitsOf(_summary), 2);
      expect(adapter.hitsOf(_premises), 0);
    });
  });

  group('listas perezosas', () {
    testWidgets('Usuarios solo construye las filas cercanas a la pantalla', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuarios'));
      await tester.pumpAndSettle();

      // 60 usuarios, 10 por página: solo se construyen las filas visibles.
      expect(find.text('Persona 1'), findsOneWidget);
      expect(find.text('Persona 10'), findsNothing);
    });

    testWidgets('LazyCardGrid construye solo lo que se ve', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: LazyCardGrid<int>(
                items: List.generate(500, (i) => i),
                columns: 2,
                itemBuilder: (context, i) => SizedBox(
                  height: 50,
                  child: Text('Tarjeta $i'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tarjeta 0'), findsOneWidget);
      expect(find.text('Tarjeta 1'), findsOneWidget);
      expect(find.text('Tarjeta 499'), findsNothing);
      expect(
        find.textContaining('Tarjeta').evaluate().length,
        lessThan(40),
        reason: 'no debe construir las 500 tarjetas',
      );

      // Al desplazarse se construyen las siguientes.
      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(find.text('Tarjeta 499'), findsOneWidget);
      expect(find.text('Tarjeta 0'), findsNothing);
    });

    testWidgets('LazyCardGrid rellena la última fila incompleta', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazyCardGrid<int>(
              items: const [1, 2, 3],
              columns: 2,
              itemBuilder: (context, i) => SizedBox(
                height: 40,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 3'), findsOneWidget);
      // Cada tarjeta ocupa la mitad del ancho (menos la separación).
      final first = tester.getSize(find.text('Item 1').first).width;
      expect(first, lessThan(400));
    });
  });
}
