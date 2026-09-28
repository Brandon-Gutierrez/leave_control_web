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
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
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

/// Barra lateral de filtros. En pantallas anchas es un panel fijo a la
/// izquierda del contenido; en pantallas angostas se despliega arriba con un
/// botón "Filtros".
class FilterSidebarLayout extends StatefulWidget {
  /// Búsqueda por texto, siempre visible en la barra.
  final Widget search;

  /// Grupos de filtros (normalmente [FilterGroup]).
  final List<Widget> filters;

  /// Cantidad de filtros activos (se muestra en el botón en pantallas angostas).
  final int activeCount;

  final VoidCallback onClear;
  final Widget content;

  /// Ancho a partir del cual la barra queda fija al costado.
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

  List<Widget> _spaced(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const SizedBox(height: 18),
      items[i],
    ],
  ];

  Widget _clearButton() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: widget.activeCount == 0 ? null : widget.onClear,
      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
      label: const Text('Limpiar filtros'),
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= widget.wideBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 270,
                margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('Filtros', style: AppText.cardTitle),
                        ],
                      ),
                      const SizedBox(height: 14),
                      widget.search,
                      const SizedBox(height: 18),
                      ..._spaced(widget.filters),
                      const SizedBox(height: 10),
                      _clearButton(),
                    ],
                  ),
                ),
              ),
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
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: Text(
                      widget.activeCount == 0
                          ? 'Filtros'
                          : 'Filtros (${widget.activeCount})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(color: AppColors.primaryRed),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [..._spaced(widget.filters), _clearButton()],
                    ),
                  ),
                ),
              ),
            Expanded(child: widget.content),
          ],
        );
      },
    );
  }
}
