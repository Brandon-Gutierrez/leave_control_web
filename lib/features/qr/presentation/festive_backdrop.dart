import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Fondo de las fiestas: degradado verde oscuro, nieve que cae despacio y una
/// guirnalda de luces que parpadean arriba. Solo decora: no recibe toques.
class FestiveBackdrop extends StatefulWidget {
  final Widget child;

  const FestiveBackdrop({super.key, required this.child});

  @override
  State<FestiveBackdrop> createState() => _FestiveBackdropState();
}

class _FestiveBackdropState extends State<FestiveBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.35, -1),
          end: Alignment(0.35, 1),
          colors: [Color(0xFF0E1F17), Color(0xFF0A120E), Color(0xFF140A0A)],
          stops: [0, 0.6, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _DecorPainter(_seconds)),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Flake {
  final double x;
  final double size;
  final double opacity;
  final double period;
  final double offset;

  const _Flake(this.x, this.size, this.opacity, this.period, this.offset);
}

class _DecorPainter extends CustomPainter {
  static const _lights = [
    (Color(0xFFE53935), 0.0),
    (Color(0xFFFFB300), 0.4),
    (Color(0xFF43A047), 0.8),
    (Color(0xFFE53935), 1.2),
    (Color(0xFFFFB300), 0.2),
    (Color(0xFF43A047), 0.6),
  ];

  static final List<_Flake> _flakes = _makeFlakes();

  static List<_Flake> _makeFlakes() {
    var seed = 11;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    return [
      for (var i = 0; i < 28; i++)
        () {
          final size = 4 + (rnd() * 6).roundToDouble();
          final x = rnd();
          final opacity = 0.35 + rnd() * 0.5;
          final period = 7 + rnd() * 7;
          final offset = rnd() * 14;
          return _Flake(x, size, opacity, period, offset);
        }(),
    ];
  }

  final ValueListenable<double> seconds;

  _DecorPainter(this.seconds) : super(repaint: seconds);

  @override
  void paint(Canvas canvas, Size size) {
    final t = seconds.value;

    final snow = Paint();
    for (final f in _flakes) {
      final progress = ((t + f.offset) % f.period) / f.period;
      final y = -30 + progress * (size.height + 40);
      snow.color = Colors.white.withValues(alpha: f.opacity);
      canvas.drawCircle(Offset(f.x * size.width, y), f.size / 2, snow);
    }

    // Guirnalda: seis luces repartidas arriba, cada una con su propio ritmo.
    for (var i = 0; i < _lights.length; i++) {
      final (color, delay) = _lights[i];
      final x = (i + 0.5) / _lights.length * size.width;
      final pulse = 0.5 + 0.5 * math.cos(2 * math.pi * (t - delay) / 1.6);
      final opacity = 0.4 + 0.6 * pulse;
      canvas.drawCircle(
        Offset(x, 3),
        9,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        Offset(x, 3),
        5,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_DecorPainter old) => false;
}
