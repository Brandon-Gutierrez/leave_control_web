import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'load_error.dart';
import 'skeleton.dart';

/// Una pestaña de la lista, con la cantidad que muestra («Admin 3»).
class ListTabSpec {
  final String label;
  final int? count;

  const ListTabSpec(this.label, [this.count]);
}

/// Lista a la izquierda y detalle a la derecha. En pantallas anchas van lado a
/// lado; en angostas se ve solo la lista, o solo el detalle (con [showDetail]).
class MasterDetailLayout extends StatelessWidget {
  final Widget master;

  /// Construye el detalle; `narrow` indica la vista de una sola columna (ahí
  /// conviene ofrecer un botón para volver a la lista).
  final Widget Function(bool narrow) detailBuilder;

  /// En pantallas angostas: mostrar el detalle en lugar de la lista.
  final bool showDetail;

  /// Ancho desde el que van lado a lado.
  final double breakpoint;

  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detailBuilder,
    required this.showDetail,
    this.breakpoint = 900,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return showDetail ? detailBuilder(true) : master;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: master,
              ),
            ),
            const SizedBox(width: 28),
            Expanded(flex: 2, child: detailBuilder(false)),
          ],
        );
      },
    );
  }
}

/// Altura de la lista: ocupa la pantalla (menos el encabezado y el título),
/// con un mínimo para que siempre se pueda usar.
double masterListHeight(BuildContext context) {
  final screen = MediaQuery.sizeOf(context).height;
  final height = screen - 340;
  return height < 480 ? 480 : height;
}

/// Panel con búsqueda, pestañas y una lista agrupada por letra que solo
/// construye las filas cercanas a la pantalla. [items] ya viene filtrada y
/// ordenada; las letras se ponen cuando cambia [groupOf].
class MasterList<T> extends StatelessWidget {
  final double height;
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final List<ListTabSpec> tabs;
  final int tabIndex;
  final ValueChanged<int> onTab;
  final List<T> items;
  final String Function(T) groupOf;
  final Widget Function(BuildContext, T) rowBuilder;
  final ValueChanged<T> onTap;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final String emptyText;

  const MasterList({
    super.key,
    required this.height,
    required this.searchHint,
    required this.searchController,
    required this.onSearch,
    required this.tabs,
    required this.tabIndex,
    required this.onTab,
    required this.items,
    required this.groupOf,
    required this.rowBuilder,
    required this.onTap,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.panelLine),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _SearchField(
              controller: searchController,
              hint: searchHint,
              onChanged: onSearch,
            ),
          ),
          _Tabs(tabs: tabs, index: tabIndex, onTap: onTab),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const SkeletonPulse(
        child: Column(
          children: [_SkeletonRow(), _SkeletonRow(), _SkeletonRow()],
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: LoadErrorNotice(message: error!, onRetry: onRetry),
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
        ),
      );
    }

    // Las letras y las filas van en una sola lista para construirlas por
    // demanda.
    final entries = <Object?>[];
    String? current;
    for (final item in items) {
      final group = groupOf(item);
      if (group != current) {
        current = group;
        entries.add(group);
      }
      entries.add(item);
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is String) return _GroupHeader(letter: entry);
        final item = entry as T;
        return InkWell(
          onTap: () => onTap(item),
          child: rowBuilder(context, item),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF777777)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 17,
            color: Color(0xFF777777),
          ),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.buttonLine),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.buttonLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final List<ListTabSpec> tabs;
  final int index;
  final ValueChanged<int> onTap;

  const _Tabs({required this.tabs, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.rowLine)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 20),
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: i == index
                                ? AppColors.primaryRed
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        tabs[i].count == null
                            ? tabs[i].label
                            : '${tabs[i].label} ${tabs[i].count}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: i == index
                              ? AppColors.darkText
                              : const Color(0xFF777777),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String letter;

  const _GroupHeader({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.lightBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppColors.label,
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEFEFEA))),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 36, height: 36, radius: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 15),
                SizedBox(height: 6),
                SkeletonBox(width: 100, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de la lista: figura a la izquierda, nombre y detalle, y una nota
/// corta a la derecha. La elegida lleva fondo rosado y una barra roja.
class MasterRowTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final String? note;
  final Color noteColor;
  final bool selected;

  const MasterRowTile({
    super.key,
    this.leading,
    required this.title,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.note,
    this.noteColor = AppColors.muted,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(selected ? 12 : 16, 12, 16, 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFBEFEE) : null,
        border: Border(
          top: const BorderSide(color: Color(0xFFEFEFEA)),
          left: selected
              ? const BorderSide(color: AppColors.primaryRed, width: 4)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        subtitleStyle ??
                        const TextStyle(fontSize: 12, color: Color(0xFF777777)),
                  ),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Text(
              note!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: noteColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Círculo con las iniciales o un ícono, a la izquierda de una fila.
class RowBadge extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final double size;
  final Color background;
  final Color foreground;

  const RowBadge({
    super.key,
    this.text,
    this.icon,
    this.size = 36,
    this.background = const Color(0xFFE4E4DF),
    this.foreground = const Color(0xFF444444),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: foreground)
          : Text(
              text ?? '',
              style: TextStyle(
                fontSize: size / 3,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
    );
  }
}

/// Panel blanco del detalle de lo elegido.
class DetailPanel extends StatelessWidget {
  final Widget child;

  const DetailPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.panelLine),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

/// Cabecera del detalle: figura grande, título y una línea de apoyo.
class DetailHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final FontWeight? subtitleWeight;

  const DetailHeader({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.subtitleWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: subtitleColor ?? AppColors.muted,
                        fontWeight: subtitleWeight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un bloque del detalle: un rótulo pequeño y su contenido, con una línea
/// arriba.
class DetailSection extends StatelessWidget {
  final String label;

  /// Texto a la derecha del rótulo (p. ej. «7 de 14»).
  final String? trailing;
  final List<Widget> children;

  const DetailSection({
    super.key,
    required this.label,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rowLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: AppColors.label,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          for (final child in children) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

/// Texto de ayuda pequeño bajo un control.
class DetailHint extends StatelessWidget {
  final String text;

  const DetailHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.muted),
    );
  }
}

/// Selector de una opción entre pocas, en una barra con borde (el elegido va
/// en negro). Con [onChanged] nulo queda deshabilitado.
class SegmentedChoice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T>? onChanged;

  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.buttonLine),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          // Si no caben en una línea, bajan a la siguiente.
          children: [
            for (var i = 0; i < options.length; i++)
              Semantics(
                button: true,
                selected: options[i].$1 == selected,
                child: InkWell(
                  onTap: onChanged == null
                      ? null
                      : () => onChanged!(options[i].$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: options[i].$1 == selected
                          ? AppColors.darkText
                          : Colors.white,
                      border: i == 0
                          ? null
                          : const Border(
                              left: BorderSide(color: AppColors.buttonLine),
                            ),
                    ),
                    child: Text(
                      options[i].$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: options[i].$1 == selected
                            ? Colors.white
                            : (onChanged == null
                                  ? const Color(0xFF999999)
                                  : const Color(0xFF555555)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
