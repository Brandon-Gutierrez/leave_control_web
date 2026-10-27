import 'package:control_leaves_web/features/settings/data/settings_service.dart';
import 'package:control_leaves_web/features/settings/models/leave_limits.dart';
import 'package:control_leaves_web/features/settings/models/qr_settings.dart';
import 'package:control_leaves_web/features/settings/presentation/leave_limits_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettings implements SettingsService {
  LeaveLimits current = const LeaveLimits(
    period: 'week',
    maxExits: 3,
    reasonLimit: ReasonLimit(
      period: 'day',
      mode: ReasonLimit.general,
      caps: [
        ReasonCap(reasonId: 1, name: 'Almuerzo'),
        ReasonCap(reasonId: 2, name: 'Médico', max: 4),
      ],
    ),
  );
  LeaveLimits? saved;

  @override
  Future<LeaveLimits> getLeaveLimits() async => current;

  @override
  Future<LeaveLimits> updateLeaveLimits(LeaveLimits limits) async {
    saved = limits;
    return limits;
  }

  @override
  Future<QrSettings> getQrSettings() => throw UnimplementedError();

  @override
  Future<void> updateQrTtl(int ttlSeconds) => throw UnimplementedError();
}

Future<void> _open(WidgetTester tester, _FakeSettings service) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: LeaveLimitsDialog(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el límite por persona y por motivo ya configurados', (
    tester,
  ) async {
    final service = _FakeSettings();
    await _open(tester, service);

    expect(find.text('Por persona'), findsOneWidget);
    expect(find.text('Por motivo'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('limit-person')))
          .controller!
          .text,
      '3',
    );
    // Modo general: un solo campo, sin la lista por motivo.
    expect(find.byKey(const ValueKey('limit-reason-general')), findsOneWidget);
    expect(find.byKey(const ValueKey('limit-reason-1')), findsNothing);
  });

  testWidgets('modo general guarda un tope para todos los motivos', (
    tester,
  ) async {
    final service = _FakeSettings();
    await _open(tester, service);

    await tester.enterText(find.byKey(const ValueKey('limit-person')), '5');
    await tester.enterText(
      find.byKey(const ValueKey('limit-reason-general')),
      '2',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = service.saved!;
    expect(saved.period, 'week');
    expect(saved.maxExits, 5);
    expect(saved.reasonLimit.mode, ReasonLimit.general);
    expect(saved.reasonLimit.maxGeneral, 2);
  });

  testWidgets('modo personalizado pide un tope por motivo (vacío = sin tope)', (
    tester,
  ) async {
    final service = _FakeSettings();
    await _open(tester, service);

    await tester.tap(find.text('Personalizado'));
    await tester.pumpAndSettle();

    // Aparece la lista de motivos con su tope actual.
    expect(find.text('Almuerzo'), findsOneWidget);
    expect(find.text('Médico'), findsOneWidget);
    expect(find.byKey(const ValueKey('limit-reason-general')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('limit-reason-2')))
          .controller!
          .text,
      '4',
    );

    // Una sola salida de almuerzo; el médico queda sin tope.
    await tester.enterText(find.byKey(const ValueKey('limit-reason-1')), '1');
    await tester.enterText(find.byKey(const ValueKey('limit-reason-2')), '');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = service.saved!;
    expect(saved.reasonLimit.mode, ReasonLimit.custom);
    expect(saved.reasonLimit.caps.map((c) => c.max), [1, null]);
    expect(saved.reasonLimit.caps.map((c) => c.reasonId), [1, 2]);
  });

  testWidgets('un tope en cero no se guarda', (tester) async {
    final service = _FakeSettings();
    await _open(tester, service);

    await tester.enterText(find.byKey(const ValueKey('limit-person')), '0');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('deben ser 1 o más'), findsOneWidget);
    expect(service.saved, isNull);
  });
}
