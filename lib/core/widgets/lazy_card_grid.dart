import 'package:flutter/material.dart';

/// Tarjetas en [columns] columnas que se construyen por filas y solo cuando
/// la fila se acerca a la pantalla (`ListView.builder`): una lista larga no
/// crea todos sus widgets a la vez. Cada fila toma la altura de su tarjeta
/// más alta y las tarjetas se alinean arriba.
///
/// Para volver al inicio de la lista (p. ej. al cambiar un filtro) basta con
/// darle otra `key`.
class LazyCardGrid<T> extends StatelessWidget {
  final List<T> items;
  final int columns;
  final double gap;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const LazyCardGrid({
    super.key,
    required this.items,
    required this.columns,
    required this.itemBuilder,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    final perRow = columns < 1 ? 1 : columns;
    final rows = (items.length + perRow - 1) ~/ perRow;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: gap),
      itemCount: rows,
      itemBuilder: (context, row) {
        return Padding(
          padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < perRow; column++) ...[
                if (column > 0) SizedBox(width: gap),
                Expanded(
                  child: row * perRow + column < items.length
                      ? itemBuilder(context, items[row * perRow + column])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
