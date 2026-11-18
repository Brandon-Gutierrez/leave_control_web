import 'package:control_leaves_web/core/network/api_exception.dart';
import 'package:control_leaves_web/features/qr/data/qr_service.dart';
import 'package:control_leaves_web/features/qr/models/manual_entry_step.dart';
import 'package:control_leaves_web/features/qr/models/qr_token.dart';
import 'package:control_leaves_web/features/qr/presentation/manual_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQrService implements QrService {
  ManualEntryStep step = ManualEntryStep(
    action: 'showReasons',
    person: 'Juan Pérez',
    item: '2057',
    premise: 'Prado',
    reasons: const ['Trámite bancario', 'Cita médica'],
    leaveTicket: 'tk-1',
    ticketExpiresAt: DateTime.now().add(const Duration(seconds: 30)),
  );
  ApiException? validateError;
  String? validatedItem;
  String? validatedCarnet;
  String? confirmedReason;

  @override
  Future<ManualEntryStep> validateManualEntry({
    required String item,
    required String carnet,
  }) async {
    validatedItem = item;
    validatedCarnet = carnet;
    if (validateError != null) throw validateError!;
    return step;
  }

  /// Hora que "devuelve" el servidor al confirmar la salida.
  DateTime? leftAt = DateTime(2026, 3, 2, 8, 15, 30);

  @override
  Future<DateTime?> confirmManualEntry({
    required String item,
    required String leaveTicket,
    required String reason,
  }) async {
    confirmedReason = reason;
    return leftAt;
  }

  @override
  Future<QrToken> createQrToken() => throw UnimplementedError();
}

Future<bool?> _open(WidgetTester tester, _FakeQrService service) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => ManualEntryDialog(
                  service: service,
                  resultDuration: const Duration(milliseconds: 200),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('pide item y carnet y no valida si están vacíos', (tester) async {
    final service = _FakeQrService();
    await _open(tester, service);

    expect(find.text('Registro manual'), findsOneWidget);
    await tester.tap(find.text('Validar'));
    await tester.pump();

    expect(find.text('Ingrese su item'), findsOneWidget);
    expect(find.text('Ingrese su carnet'), findsOneWidget);
    expect(service.validatedItem, isNull);
  });

  testWidgets(
    'un carnet de solo espacios no pasa y los espacios sobrantes se quitan',
    (tester) async {
      final service = _FakeQrService();
      await _open(tester, service);

      await tester.enterText(find.byType(TextFormField).at(0), '2057');
      await tester.enterText(find.byType(TextFormField).at(1), '   ');
      await tester.tap(find.text('Validar'));
      await tester.pump();
      expect(find.text('Ingrese su carnet'), findsOneWidget);
      expect(service.validatedItem, isNull);

      await tester.enterText(find.byType(TextFormField).at(1), '  1234567  ');
      await tester.tap(find.text('Validar'));
      await tester.pumpAndSettle();
      expect(service.validatedItem, '2057');
      expect(service.validatedCarnet, '1234567');
    },
  );

  testWidgets(
    'al agotarse el tiempo de los motivos se cierra todo el diálogo',
    (tester) async {
      final service = _FakeQrService()
        ..step = ManualEntryStep(
          action: 'showReasons',
          person: 'Juan Pérez',
          item: '2057',
          premise: 'Prado',
          reasons: const ['Trámite bancario'],
          leaveTicket: 'tk-1',
          // Comprobante ya vencido: el contador lo detecta de inmediato.
          ticketExpiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        );
      await _open(tester, service);

      await tester.enterText(find.byType(TextFormField).at(0), '2057');
      await tester.enterText(find.byType(TextFormField).at(1), '1234567');
      await tester.tap(find.text('Validar'));
      await tester.pumpAndSettle();

      // Ni los motivos ni el formulario de datos siguen abiertos.
      expect(find.text('Hola, Juan Pérez'), findsNothing);
      expect(find.text('Registro manual'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    },
  );

  testWidgets('valida, muestra los motivos, confirma y vuelve solo', (
    tester,
  ) async {
    final service = _FakeQrService();
    await _open(tester, service);

    await tester.enterText(find.byType(TextFormField).at(0), '2057');
    await tester.enterText(find.byType(TextFormField).at(1), '1234567');
    await tester.tap(find.text('Validar'));
    await tester.pumpAndSettle();

    expect(service.validatedItem, '2057');
    expect(service.validatedCarnet, '1234567');
    expect(find.text('Hola, Juan Pérez'), findsOneWidget);
    expect(find.text('Trámite bancario'), findsOneWidget);

    // No hay botón de confirmar: tocar el motivo registra la salida.
    expect(find.text('Confirmar salida'), findsNothing);

    await tester.tap(find.text('Cita médica'));
    await tester.pump();
    await tester.pump();

    expect(service.confirmedReason, 'Cita médica');
    // El popup de confirmación muestra la hora de salida.
    expect(
      find.textContaining('Salida registrada a las 08:15'),
      findsOneWidget,
    );

    // Se cierra solo y vuelve a la pantalla anterior (el QR).
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('Registro manual'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('un motivo que llegó a su límite sale no permitido', (
    tester,
  ) async {
    final service = _FakeQrService()
      ..step = ManualEntryStep(
        action: 'showReasons',
        person: 'Juan Pérez',
        item: '2057',
        premise: 'Prado',
        reasons: const ['Almuerzo', 'Cita médica'],
        blockedReasons: const [
          BlockedReason(name: 'Almuerzo', limit: 1, period: 'day'),
        ],
        leaveTicket: 'tk-1',
        ticketExpiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );
    await _open(tester, service);

    await tester.enterText(find.byType(TextFormField).at(0), '2057');
    await tester.enterText(find.byType(TextFormField).at(1), '1234567');
    await tester.tap(find.text('Validar'));
    await tester.pumpAndSettle();

    expect(find.text('Límite alcanzado: 1 vez por día'), findsOneWidget);

    // El motivo agotado no registra nada; el otro sí.
    await tester.tap(find.text('Almuerzo'));
    await tester.pump();
    expect(service.confirmedReason, isNull);

    await tester.tap(find.text('Cita médica'));
    await tester.pump();
    await tester.pump();
    expect(service.confirmedReason, 'Cita médica');
  });

  testWidgets('si ya estaba fuera registra el retorno y vuelve solo', (
    tester,
  ) async {
    final service = _FakeQrService()
      ..step = ManualEntryStep(
        action: 'showHome',
        person: 'Juan Pérez',
        item: '2057',
        returnedAt: DateTime(2026, 3, 2, 17, 45),
      );
    await _open(tester, service);

    await tester.enterText(find.byType(TextFormField).at(0), '2057');
    await tester.enterText(find.byType(TextFormField).at(1), '1234567');
    await tester.tap(find.text('Validar'));
    await tester.pump();
    await tester.pump();

    // El popup de confirmación muestra la hora de retorno.
    expect(
      find.textContaining('Retorno registrado a las 17:45'),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('muestra el error cuando item o carnet no coinciden', (
    tester,
  ) async {
    final service = _FakeQrService()
      ..validateError = ApiException('El item o el carnet no son correctos.');
    await _open(tester, service);

    await tester.enterText(find.byType(TextFormField).at(0), '2057');
    await tester.enterText(find.byType(TextFormField).at(1), 'mal');
    await tester.tap(find.text('Validar'));
    await tester.pumpAndSettle();

    expect(find.text('El item o el carnet no son correctos.'), findsOneWidget);
    expect(find.text('Hola, Juan Pérez'), findsNothing);
  });
}
