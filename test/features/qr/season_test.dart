import 'dart:async';

import 'package:control_leaves_web/features/qr/models/season.dart';
import 'package:control_leaves_web/features/qr/presentation/qr_screen.dart';
import 'package:control_leaves_web/features/qr/presentation/season_qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.white,
    body: Center(child: child),
  ),
);

/// Deja pasar el tiempo cuadro a cuadro: una animaciÃ³n necesita varios cuadros
/// para avanzar (un solo `pump` largo no basta).
Future<void> _elapse(WidgetTester tester, int milliseconds) async {
  for (var t = 0; t < milliseconds; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _a = 'Prado+primero-1234567890123456789012345678901234';
const _b = 'Prado+segundo-abcdefghijklmnopqrstuvwxyz0123456789';
const _c = 'Prado+tercero-zyxwvutsrqponmlkjihgfedcba9876543210';

void main() {
  group('temporada', () {
    test('la navideña va del 1 de diciembre al 6 de enero', () {
      expect(Season.at(DateTime(2026, 11, 30)), Season.none);
      expect(Season.at(DateTime(2026, 12, 1)), Season.christmas);
      expect(Season.at(DateTime(2026, 12, 25)), Season.christmas);
      expect(Season.at(DateTime(2026, 12, 31, 23, 59)), Season.christmas);
      expect(Season.at(DateTime(2027, 1, 1)), Season.christmas);
      expect(Season.at(DateTime(2027, 1, 6, 23, 59)), Season.christmas);
      expect(Season.at(DateTime(2027, 1, 7)), Season.none);
      expect(Season.at(DateTime(2027, 6, 15)), Season.none);
    });

    test('solo la navideña es festiva', () {
      expect(Season.none.isFestive, isFalse);
      expect(Season.christmas.isFestive, isTrue);
    });
  });

  test('la cuenta regresiva se escribe como minutos y segundos', () {
    expect(formatClock(642), '10:42');
    expect(formatClock(300), '5:00');
    expect(formatClock(60), '1:00');
    expect(formatClock(45), '0:45');
    expect(formatClock(9), '0:09');
    expect(formatClock(3600), '60:00');
    expect(formatClock(-3), '0:00');
  });

  group('árbol', () {
    final tree = TreeLayout.instance;

    test('cabe en la cuadrícula y no repite celdas', () {
      final keys = <int>{};
      for (final cell in tree.cells) {
        expect(cell.row, inInclusiveRange(0, TreeLayout.grid - 1));
        expect(cell.col, inInclusiveRange(0, TreeLayout.grid - 1));
        expect(keys.add(cell.row * TreeLayout.grid + cell.col), isTrue);
      }
      expect(tree.cells.length, inInclusiveRange(200, 320));
    });

    test('tiene copa verde, tronco, estrella y adornos que titilan', () {
      expect(tree.cells.first.row, 0); // la punta de la estrella
      expect(tree.cells.last.row, 24); // el tronco llega al piso
      final twinkling = tree.cells.where((c) => c.twinkle).length;
      expect(twinkling, greaterThan(10));
    });

    test('la nieve no se encima con el árbol', () {
      final used = {
        for (final c in tree.cells) c.row * TreeLayout.grid + c.col,
      };
      expect(tree.snow.length, 160);
      for (final flake in tree.snow) {
        expect(used.contains(flake.row * TreeLayout.grid + flake.col), isFalse);
      }
    });
  });

  group('módulos del QR', () {
    test('son los del código real: tres esquinas y alrededor de la mitad', () {
      final matrix = QrMatrix.fromData(_a);
      expect(matrix.count, greaterThanOrEqualTo(21));
      final dark = {for (final m in matrix.dark) m.row * matrix.count + m.col};
      // Esquina superior izquierda: el borde del cuadro de ubicación.
      for (var i = 0; i < 7; i++) {
        expect(dark.contains(i), isTrue); // fila 0
        expect(dark.contains(i * matrix.count), isTrue); // columna 0
      }
      final ratio = matrix.dark.length / (matrix.count * matrix.count);
      expect(ratio, inInclusiveRange(0.35, 0.6));
    });

    test('un código distinto da módulos distintos', () {
      final a = QrMatrix.fromData(_a);
      final b = QrMatrix.fromData(_b);
      expect([
        for (final m in a.dark) (m.row, m.col),
      ], isNot([for (final m in b.dark) (m.row, m.col)]));
    });
  });

  group('QR de temporada', () {
    Finder pieces() => find.byKey(const ValueKey('season-qr-pieces'));
    final key = GlobalKey<SeasonQrState>();

    Future<void> open(WidgetTester tester) =>
        tester.pumpWidget(_host(SeasonQr(key: key, data: _a, size: 300)));

    testWidgets('quieto es un QR real', (tester) async {
      await open(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(pieces(), findsNothing);
      expect(key.currentState!.isRenewing, isFalse);
    });

    testWidgets('renovar: el QR forma el árbol, pide el código con el árbol '
        'a la vista y aparece el nuevo', (tester) async {
      await open(tester);
      final fetch = Completer<String>();
      var fetched = 0;
      String? applied;

      final future = key.currentState!.renew<String>(
        fetch: () {
          fetched++;
          return fetch.future;
        },
        tokenOf: (t) => t,
      );
      unawaited(future.then((v) => applied = v));
      await tester.pump();
      // Todavía no se pidió nada: el QR se está deshaciendo.
      expect(fetched, 0);
      expect(pieces(), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      // Con el árbol armado se pide el código.
      await _elapse(tester, 1500);
      expect(fetched, 1);
      expect(pieces(), findsOneWidget);
      expect(applied, isNull);

      // El servidor tarda: el árbol espera.
      await _elapse(tester, 3000);
      expect(pieces(), findsOneWidget);
      expect(applied, isNull);

      fetch.complete(_b);
      await _elapse(tester, 2500);
      expect(applied, _b);
      expect(pieces(), findsNothing);
      expect(
        tester.widget<SeasonQr>(find.byType(SeasonQr)).data,
        _a,
        reason: 'el padre pasa el código nuevo después',
      );
      expect(key.currentState!.isRenewing, isFalse);
    });

    testWidgets('el árbol se ve al menos el tiempo previsto', (tester) async {
      await open(tester);
      final future = key.currentState!.renew<String>(
        fetch: () async => _b,
        tokenOf: (t) => t,
      );
      var done = false;
      unawaited(future.then((_) => done = true));

      // Aunque el servidor responda al instante no se salta la animación.
      await _elapse(tester, 1500);
      expect(done, isFalse);
      expect(pieces(), findsOneWidget);

      await _elapse(tester, 3000);
      expect(done, isTrue);
      expect(pieces(), findsNothing);
    });

    testWidgets('si el servidor falla vuelve al QR anterior y avisa', (
      tester,
    ) async {
      await open(tester);
      Object? error;
      final future = key.currentState!.renew<String>(
        fetch: () async => throw StateError('sin red'),
        tokenOf: (t) => t,
      );
      unawaited(future.then((_) {}, onError: (Object e) => error = e));

      await _elapse(tester, 5000);

      expect(error, isA<StateError>());
      expect(pieces(), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(key.currentState!.isRenewing, isFalse);
    });

    testWidgets('un código que llega sin renovar se pone directo', (
      tester,
    ) async {
      await open(tester);

      await tester.pumpWidget(_host(SeasonQr(key: key, data: _c, size: 300)));
      await tester.pump();

      expect(pieces(), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('cerrar la pantalla a mitad de la animación no falla', (
      tester,
    ) async {
      await open(tester);
      unawaited(
        key.currentState!
            .renew<String>(fetch: () async => _b, tokenOf: (t) => t)
            .then((_) {}, onError: (_) {}),
      );
      await _elapse(tester, 300);
      await tester.pumpWidget(const SizedBox.shrink());
      await _elapse(tester, 5000);

      expect(tester.takeException(), isNull);
    });
  });
}
