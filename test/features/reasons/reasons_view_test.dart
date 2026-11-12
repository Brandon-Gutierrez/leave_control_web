import 'dart:async';

import 'package:control_leaves_web/core/network/api_client.dart';
import 'package:control_leaves_web/features/auth/models/auth_user.dart';
import 'package:control_leaves_web/features/auth/state/session_controller.dart';
import 'package:control_leaves_web/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:control_leaves_web/features/dashboard/state/admin_data_store.dart';
import 'package:control_leaves_web/features/reasons/models/reason_catalog.dart';
import 'package:control_leaves_web/features/reasons/presentation/reasons_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/counting_adapter.dart';

const _catalog = '/api/admin/reasons/catalog';
const _sync = '/api/admin/reasons/sync';
const _summary = '/api/admin/summary';

Map<String, Object?> _reasons() => {
  'reasons': [
    {
      'reason_id': 1,
      'name': 'Almuerzo',
      'code': 'A',
      'active': true,
      'premises_count': 3,
    },
    {
      'reason_id': 2,
      'name': 'Médico',
      'code': 'M',
      'active': true,
      'premises_count': 1,
    },
    {
      'reason_id': 3,
      'name': 'Comisión antigua',
      'code': 'C',
      'active': false,
      'premises_count': 0,
    },
  ],
};

Map<String, Object?> _catalogBody(Map<String, Object?>? sync) => {
  'status': 0,
  'data': {..._reasons(), 'sync': sync},
};

Map<String, Object?> _summaryBody(Map<String, Object?>? sync) => {
  'status': 0,
  'data': {
    'premises': {'total': 1},
    'users': {'total': 1},
    'reasons_sync': sync,
  },
};

CountingAdapter _adapter({Map<String, Object?>? sync}) => CountingAdapter({
  _catalog: _catalogBody(sync),
  _summary: _summaryBody(sync),
  _sync: {
    'status': 0,
    'message': 'Motivos de salida actualizados correctamente',
    'result': {'added': 2, 'updated': 0, 'reactivated': 0, 'deactivated': 1},
  },
});

const _success = {
  'status': 'success',
  'source': 'scheduled',
  'at': '2026-11-11T00:00:00-04:00',
  'actor': null,
  'added': 2,
  'updated': 1,
  'reactivated': 0,
  'deactivated': 1,
  'error': null,
  'last_success_at': '2026-11-11T00:00:00-04:00',
};

const _failed = {
  'status': 'failed',
  'source': 'scheduled',
  'at': '2026-11-12T00:30:00-04:00',
  'actor': null,
  'added': null,
  'updated': null,
  'reactivated': null,
  'deactivated': null,
  'error': 'Comteco devolvió una lista de motivos vacía; se conserva el catálogo actual.',
  'last_success_at': '2026-11-11T00:00:00-04:00',
};

Future<void> _openReasons(WidgetTester tester, CountingAdapter adapter) async {
  ApiClient().dio.httpClientAdapter = adapter;
  SessionController.instance.set(null);
  AdminDataStore.instance.clear();
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AdminDashboardPage(
        user: AuthUser(id: 1, name: 'Admin', item: '1', roleName: 'ADMIN'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Motivos').first);
  await tester.pumpAndSettle();
}

void main() {
  test('las fechas se muestran en hora de Bolivia (UTC−4)', () {
    expect(
      ReasonsViewState.formatDate(DateTime.utc(2026, 11, 11, 4, 0)),
      '11/11/2026 00:00',
    );
    expect(
      ReasonsViewState.formatDate(DateTime.parse('2026-11-12T00:30:00-04:00')),
      '12/11/2026 00:30',
    );
    expect(ReasonsViewState.formatDate(null), '—');
  });

  test('describe los cambios de una sincronización', () {
    expect(describeReasonChanges(), isNull);
    expect(
      describeReasonChanges(added: 2, updated: 1, reactivated: 1, deactivated: 1),
      '2 nuevos · 1 actualizado · 1 reactivado · 1 retirado',
    );
  });

  group('sección Motivos de salida', () {
    testWidgets('lista activos y retirados con su uso', (tester) async {
      await _openReasons(tester, _adapter(sync: _success));

      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.text('Habilitado en 3 predios'), findsOneWidget);
      expect(find.text('Médico'), findsOneWidget);
      expect(find.text('Habilitado en 1 predio'), findsOneWidget);
      expect(find.text('Comisión antigua'), findsOneWidget);
      expect(find.text('Retirado por Comteco'), findsOneWidget);
      expect(find.text('3 de 3 motivos'), findsOneWidget);
    });

    testWidgets('muestra la última sincronización correcta', (tester) async {
      await _openReasons(tester, _adapter(sync: _success));

      expect(
        find.text('Última sincronización: 11/11/2026 00:00 (automática).'),
        findsOneWidget,
      );
      expect(
        find.text('2 nuevos · 1 actualizado · 1 retirado'),
        findsOneWidget,
      );
      expect(
        find.textContaining('lunes a viernes a las 00:00 (hora de Bolivia)'),
        findsOneWidget,
      );
    });

    testWidgets('si nunca se sincronizó lo dice', (tester) async {
      await _openReasons(tester, _adapter());

      expect(find.text('Todavía no se ha sincronizado.'), findsOneWidget);
    });

    testWidgets('si falló muestra el motivo y la última correcta', (
      tester,
    ) async {
      await _openReasons(tester, _adapter(sync: _failed));

      expect(
        find.text('La última sincronización falló el 12/11/2026 00:30 (automática).'),
        findsOneWidget,
      );
      expect(find.textContaining('lista de motivos vacía'), findsOneWidget);
      expect(
        find.textContaining('Última correcta: 11/11/2026 00:00'),
        findsOneWidget,
      );
    });

    testWidgets('el filtro de estado deja solo los retirados', (tester) async {
      await _openReasons(tester, _adapter(sync: _success));

      await tester.tap(find.text('Retirados por Comteco'));
      await tester.pumpAndSettle();

      expect(find.text('Comisión antigua'), findsOneWidget);
      expect(find.text('Almuerzo'), findsNothing);
      expect(find.text('1 de 3 motivos'), findsOneWidget);
    });

    testWidgets('se puede buscar por nombre', (tester) async {
      await _openReasons(tester, _adapter(sync: _success));

      await tester.enterText(find.byType(TextField).first, 'méd');
      await tester.pumpAndSettle();
      expect(find.text('Médico'), findsOneWidget);
      expect(find.text('Almuerzo'), findsNothing);
    });

    testWidgets('mientras sincroniza el botón avisa y se bloquea', (
      tester,
    ) async {
      final adapter = _adapter(sync: _success);
      await _openReasons(tester, adapter);

      adapter.gate = Completer<void>();
      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pump();

      expect(find.text('Sincronizando...'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull);

      adapter.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Sincronizar ahora'), findsOneWidget);
      expect(adapter.hitsOf(_sync), 1);
      expect(
        find.text('Motivos de salida actualizados correctamente (2 nuevos · 1 retirado)'),
        findsOneWidget,
      );
    });

    testWidgets('si la sincronización falla lo avisa y vuelve a leer el estado', (
      tester,
    ) async {
      final adapter = _adapter(sync: _success)..failStatus[_sync] = 502;
      await _openReasons(tester, adapter);

      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pumpAndSettle();

      expect(find.text('Fallo 502 en $_sync'), findsOneWidget);
      // El servidor guarda el fallo: se vuelve a leer el catálogo.
      expect(adapter.hitsOf(_catalog), 2);
      expect(find.text('Sincronizar ahora'), findsOneWidget);
    });

    testWidgets('si el catálogo no carga se puede reintentar', (tester) async {
      final adapter = _adapter(sync: _success)..failStatus[_catalog] = 500;
      await _openReasons(tester, adapter);

      expect(find.text('Reintentar'), findsOneWidget);

      adapter.failStatus.remove(_catalog);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Almuerzo'), findsOneWidget);
    });
  });

  group('aviso en Inicio', () {
    Future<void> openHome(WidgetTester tester, CountingAdapter adapter) async {
      ApiClient().dio.httpClientAdapter = adapter;
      AdminDataStore.instance.clear();
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardPage(
            user: AuthUser(id: 1, name: 'Admin', item: '1', roleName: 'ADMIN'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('si la última sincronización falló, Inicio lo avisa y lleva a Motivos', (
      tester,
    ) async {
      await openHome(tester, _adapter(sync: _failed));

      expect(
        find.text('No se pudieron sincronizar los motivos con Comteco'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver motivos'));
      await tester.pumpAndSettle();

      expect(find.text('Sincronización con Comteco'), findsOneWidget);
    });

    testWidgets('si la última sincronización fue bien, Inicio no avisa nada', (
      tester,
    ) async {
      await openHome(tester, _adapter(sync: _success));

      expect(
        find.text('No se pudieron sincronizar los motivos con Comteco'),
        findsNothing,
      );
    });
  });
}
