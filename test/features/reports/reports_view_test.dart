import 'package:control_leaves_web/features/reports/data/report_service.dart';
import 'package:control_leaves_web/features/reports/models/leave_report.dart';
import 'package:control_leaves_web/features/reports/presentation/reports_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReportService implements ReportService {
  int calls = 0;
  String? lastSearch;
  int? lastPremiseId;

  @override
  Future<LeaveReport> getLeaveReport({
    required DateTime from,
    required DateTime to,
    int? premiseId,
    String? reason,
    String? search,
  }) async {
    calls++;
    lastSearch = search;
    lastPremiseId = premiseId;
    return LeaveReport.fromJson({
      'summary': {
        'exits': 12,
        'minutes': 190,
        'average_minutes': 16,
        'people': 4,
        'outside_now': 1,
        'unreturned': 1,
      },
      'by_premise': [
        {
          'premise_id': 1,
          'name': 'Prado',
          'exits': 8,
          'minutes': 130,
          'average_minutes': 16,
          'people': 3,
        },
        {
          'premise_id': 2,
          'name': 'Central',
          'exits': 4,
          'minutes': 60,
          'average_minutes': 15,
          'people': 2,
        },
      ],
      'by_reason': [
        {
          'reason_id': 1,
          'name': 'Trámite bancario',
          'exits': 9,
          'minutes': 150,
          'average_minutes': 17,
          'people': 4,
        },
      ],
      'by_user': [
        {
          'user_id': 1,
          'name': 'Juan Pérez',
          'item': 2057,
          'exits': 7,
          'minutes': 120,
          'average_minutes': 17,
          'longest_minutes': 45,
          'unreturned': 1,
        },
      ],
      'unreturned': [
        {
          'name': 'Juan Pérez',
          'item': 2057,
          'premise': 'Prado',
          'reason': 'Trámite bancario',
          'left_at': '2026-10-10T09:00:00-04:00',
          'minutes': 0,
        },
      ],
      'outside_now': [
        {
          'name': 'Ana Rojas',
          'item': 3001,
          'premise': 'Central',
          'reason': 'Médico',
          'left_at': DateTime.now().toIso8601String(),
          'minutes': 25,
        },
      ],
    });
  }
}

void main() {
  const sizes = <String, Size>{
    'móvil': Size(390, 844),
    'tablet': Size(820, 1180),
    'escritorio': Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    testWidgets(
      'Reportes muestra el resumen y las advertencias en ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final service = _FakeReportService();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReportsView(onUnauthorized: () {}, service: service),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: error is FlutterError ? error.toStringDeep() : '$error',
        );
        expect(find.text('Advertencias de no retorno'), findsOneWidget);
        expect(find.text('A dónde salen'), findsOneWidget);
        expect(find.text('Por qué salen'), findsOneWidget);
        expect(find.text('Por persona'), findsOneWidget);
        expect(find.text('Prado'), findsWidgets);
        expect(find.text('3 h 10 min'), findsOneWidget); // tiempo total
      },
    );
  }

  testWidgets('Buscar vuelve a pedir el reporte con el texto', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeReportService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportsView(onUnauthorized: () {}, service: service),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.calls, 1);

    await tester.enterText(find.byType(TextField).first, 'ana');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(service.calls, 2);
    expect(service.lastSearch, 'ana');
  });
}
