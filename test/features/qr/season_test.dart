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

/// Un cambio de código con el reloj de la prueba.
class _Swap extends StatefulWidget {
  final bool festive;
  final int treeEvery;
  const _Swap({super.key, this.festive = true, this.treeEvery = 3});

  @override
  State<_Swap> createState() => _SwapState();
}

class _SwapState extends State<_Swap> {
  String data = 'Prado+primero-1234567890123456789012345678901234';

  void change(String value) => setState(() => data = value);

  @override
  Widget build(BuildContext context) => SeasonQr(
    data: data,
    size: 300,
    festive: widget.festive,
    treeEvery: widget.treeEvery,
  );
}

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

    /// El código que se ve: hay un QR quieto y es el de la pantalla.
    String shown(WidgetTester t) {
      expect(find.byType(QrImageView), findsOneWidget);
      return t.widget<SeasonQr>(find.byType(SeasonQr)).data;
    }

    testWidgets('sin temporada el código nuevo se pone al instante', (
      tester,
    ) async {
      final key = GlobalKey<_SwapState>();
      await tester.pumpWidget(_host(_Swap(key: key, festive: false)));
      expect(shown(tester), _a);

      key.currentState!.change(_b);
      await tester.pump();

      expect(pieces(), findsNothing);
      expect(shown(tester), _b);
    });

    testWidgets('en temporada el código se reacomoda y vuelve a ser el QR', (
      tester,
    ) async {
      final key = GlobalKey<_SwapState>();
      await tester.pumpWidget(_host(_Swap(key: key)));

      key.currentState!.change(_b);
      await tester.pump();
      await _elapse(tester, 200);
      // Mientras se mueve no hay QR legible, solo piezas.
      expect(pieces(), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await _elapse(tester, 1500);
      expect(pieces(), findsNothing);
      expect(shown(tester), _b);
    });

    testWidgets('cada tercer cambio forma el árbol antes del código nuevo', (
      tester,
    ) async {
      final key = GlobalKey<_SwapState>();
      await tester.pumpWidget(_host(_Swap(key: key, treeEvery: 2)));

      // Primer cambio: solo se reacomoda (rápido).
      key.currentState!.change(_b);
      await tester.pump();
      await _elapse(tester, 1500);
      expect(pieces(), findsNothing);
      expect(shown(tester), _b);

      // Segundo: pasa por el árbol y tarda más.
      key.currentState!.change(_c);
      await tester.pump();
      await _elapse(tester, 800);
      expect(pieces(), findsOneWidget); // el árbol a la vista
      await _elapse(tester, 200);
      expect(pieces(), findsOneWidget);

      await _elapse(tester, 4 * 1000);
      expect(pieces(), findsNothing);
      expect(shown(tester), _c);
    });

    testWidgets('un cambio en pleno movimiento pone el último código', (
      tester,
    ) async {
      final key = GlobalKey<_SwapState>();
      await tester.pumpWidget(_host(_Swap(key: key)));

      key.currentState!.change(_b);
      await tester.pump();
      await _elapse(tester, 150);
      key.currentState!.change(_c);
      await tester.pump();

      expect(pieces(), findsNothing);
      expect(shown(tester), _c);
      await _elapse(tester, 3 * 1000);
      expect(shown(tester), _c);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cerrar la pantalla a mitad de la animación no falla', (
      tester,
    ) async {
      final key = GlobalKey<_SwapState>();
      await tester.pumpWidget(_host(_Swap(key: key, treeEvery: 1)));

      key.currentState!.change(_b);
      await tester.pump();
      await _elapse(tester, 300);
      await tester.pumpWidget(const SizedBox.shrink());
      await _elapse(tester, 5 * 1000);

      expect(tester.takeException(), isNull);
    });

    testWidgets('el mismo código no anima nada', (tester) async {
      final key = GlobalKey<_SwapState>();
      await tester.pumpWidget(_host(_Swap(key: key)));

      key.currentState!.change(_a);
      await tester.pump();

      expect(pieces(), findsNothing);
      expect(shown(tester), _a);
    });
  });
}
