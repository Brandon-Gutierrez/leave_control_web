import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Cantidad de páginas para [total] elementos (mínimo 1).
int pageCount(int total, int pageSize) =>
    total <= 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

/// Los elementos de la página [page] (empezando en 0); la página se ajusta
/// si quedó fuera de rango (p. ej. tras filtrar).
List<T> pageSlice<T>(List<T> items, int page, int pageSize) {
  final safe = page.clamp(0, pageCount(items.length, pageSize) - 1);
  final start = safe * pageSize;
  final end = start + pageSize > items.length ? items.length : start + pageSize;
  return items.sublist(start, end);
}

/// Barra de paginación: "1–10 de 37" con botones anterior/siguiente. No se
/// muestra si todo cabe en una sola página.
class PaginationBar extends StatelessWidget {
  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onChanged;

  const PaginationBar({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pages = pageCount(total, pageSize);
    if (pages <= 1) return const SizedBox.shrink();

    final current = page.clamp(0, pages - 1);
    final from = current * pageSize + 1;
    final to = (current + 1) * pageSize > total
        ? total
        : (current + 1) * pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('$from–$to de $total', style: AppText.caption)),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: current > 0 ? () => onChanged(current - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: AppColors.darkText,
          ),
          Text(
            'Página ${current + 1} de $pages',
            style: AppText.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: current < pages - 1
                ? () => onChanged(current + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: AppColors.darkText,
          ),
        ],
      ),
    );
  }
}
