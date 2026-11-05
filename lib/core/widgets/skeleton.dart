import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Hace "respirar" a todos los [SkeletonBox] que contiene con una sola
/// animación (en vez de una por caja).
class SkeletonPulse extends StatefulWidget {
  final Widget child;

  /// Anima solo mientras hay carga: una animación que nunca se detiene
  /// mantendría la pantalla redibujando para siempre.
  final bool active;

  const SkeletonPulse({super.key, required this.child, this.active = true});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SkeletonPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) =>
          _PulseScope(value: _controller.value, child: child!),
    );
  }
}

class _PulseScope extends InheritedWidget {
  final double value;

  const _PulseScope({required this.value, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PulseScope>()?.value ?? 0;

  @override
  bool updateShouldNotify(_PulseScope old) => old.value != value;
}

/// Caja gris que ocupa el lugar de un texto, número o imagen mientras llegan
/// los datos. Dentro de un [SkeletonPulse] cambia suavemente de tono.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 4});

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      AppColors.line,
      AppColors.infoBg,
      _PulseScope.of(context),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
