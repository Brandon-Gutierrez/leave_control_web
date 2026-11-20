import 'package:flutter/material.dart';

/// Resalta lo que está bajo el puntero del ratón: oscurece un poco el fondo
/// (sea blanco, rosado o gris) y muestra la mano. Sirve para las filas de las
/// listas que se pueden tocar. En pantallas táctiles no hace nada.
class HoverHighlight extends StatefulWidget {
  final Widget child;

  /// Color translúcido que se pone encima al pasar el puntero.
  final Color color;

  const HoverHighlight({
    super.key,
    required this.child,
    this.color = const Color(0x0D000000),
  });

  @override
  State<HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<HoverHighlight> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                color: _hovered ? widget.color : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
