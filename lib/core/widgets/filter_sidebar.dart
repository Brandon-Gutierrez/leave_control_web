import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Un grupo de opciones excluyentes dentro de la barra de filtros.
class FilterGroup<T> extends StatelessWidget {
  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const FilterGroup({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == value,
                showCheckmark: false,
                selectedColor: AppColors.primaryRed,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: entry.key == value
                      ? AppColors.primaryRed
                      : AppColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: entry.key == value ? Colors.white : AppColors.darkText,
                ),
                onSelected: (_) => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// Barra lateral vertical en escritorio y panel desplegable en pantallas
/// estrechas, con la búsqueda y los filtros junto al contenido que refinan.
class FilterSidebarLayout extends StatefulWidget {
  /// Búsqueda por texto.
  final Widget search;

  /// Grupos de filtros (normalmente [FilterGroup]).
  final List<Widget> filters;

  /// Cantidad de filtros activos, incluida la búsqueda.
  final int activeCount;

  final VoidCallback onClear;
  final Widget content;

  /// Ancho a partir del cual los filtros pasan a una barra lateral vertical.
  final double wideBreakpoint;

  const FilterSidebarLayout({
    super.key,
    required this.search,
    required this.filters,
    required this.activeCount,
    required this.onClear,
    required this.content,
    this.wideBreakpoint = 900,
  });

  @override
  State<FilterSidebarLayout> createState() => _FilterSidebarLayoutState();
}

class _FilterSidebarLayoutState extends State<FilterSidebarLayout> {
  bool _expanded = false;

  Widget _filterToggle() {
    final label = widget.activeCount == 0
        ? 'Filtros'
        : 'Filtros (${widget.activeCount})';
    return OutlinedButton.icon(
      onPressed: () => setState(() => _expanded = !_expanded),
      icon: const Icon(Icons.tune_rounded, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryRed,
        side: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.55)),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _clearButton() => TextButton.icon(
    onPressed: widget.activeCount == 0 ? null : widget.onClear,
    icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
    label: const Text('Limpiar todo'),
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primaryRed,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
  );

  Widget _activeCount() {
    if (widget.activeCount == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${widget.activeCount}',
        style: const TextStyle(
          color: AppColors.primaryRed,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _filterList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < widget.filters.length; index++) ...[
        if (index > 0) const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: widget.filters[index],
        ),
      ],
    ],
  );

  Widget _desktopSidebar() => Container(
    width: 300,
    margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 20, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(child: Text('Filtros', style: AppText.cardTitle)),
            _activeCount(),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: AppColors.line),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.search,
                const SizedBox(height: 18),
                Text('Refinar resultados', style: AppText.caption),
                const SizedBox(height: 10),
                _filterList(),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Divider(height: 1, color: AppColors.line),
        ),
        Align(alignment: Alignment.centerLeft, child: _clearButton()),
      ],
    ),
  );

  Widget _mobileFilters(double availableHeight) => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Refinar resultados',
                style: AppText.cardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _activeCount(),
          ],
        ),
        Align(alignment: Alignment.centerRight, child: _clearButton()),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: availableHeight * 0.42),
          child: SingleChildScrollView(child: _filterList()),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= widget.wideBreakpoint;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 760.0;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _desktopSidebar(),
              Expanded(child: widget.content),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(child: widget.search),
                  const SizedBox(width: 10),
                  _filterToggle(),
                ],
              ),
            ),
            if (_expanded) _mobileFilters(availableHeight),
            Expanded(child: widget.content),
          ],
        );
      },
    );
  }
}
