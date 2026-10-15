import 'package:control_leaves_web/core/widgets/pagination_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pageCount y pageSlice reparten en páginas', () {
    final items = List.generate(23, (i) => i);

    expect(pageCount(0, 10), 1);
    expect(pageCount(10, 10), 1);
    expect(pageCount(23, 10), 3);
    expect(pageSlice(items, 0, 10), items.sublist(0, 10));
    expect(pageSlice(items, 2, 10), [20, 21, 22]);
    // Una página fuera de rango se ajusta a la última.
    expect(pageSlice(items, 9, 10), [20, 21, 22]);
    expect(pageSlice(<int>[], 0, 10), isEmpty);
  });

  testWidgets('PaginationBar navega y se oculta con una sola página', (
    tester,
  ) async {
    var page = 0;
    Widget build() => MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PaginationBar(
            page: page,
            pageSize: 10,
            total: 23,
            onChanged: (p) => setState(() => page = p),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build());
    expect(find.text('1–10 de 23'), findsOneWidget);
    expect(find.text('Página 1 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.text('11–20 de 23'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    expect(find.text('21–23 de 23'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaginationBar(
            page: 0,
            pageSize: 10,
            total: 7,
            onChanged: _noop,
          ),
        ),
      ),
    );
    expect(find.textContaining('Página'), findsNothing);
  });
}

void _noop(int _) {}
