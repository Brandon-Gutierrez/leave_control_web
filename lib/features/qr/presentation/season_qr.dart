import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Los módulos oscuros de un código QR (los mismos que dibuja `QrImageView`).
class QrMatrix {
  /// Módulos por lado.
  final int count;
  final List<({int row, int col})> dark;

  const QrMatrix._(this.count, this.dark);

  factory QrMatrix.fromData(String data) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    final image = QrImage(code);
    return QrMatrix._(code.moduleCount, [
      for (var r = 0; r < code.moduleCount; r++)
        for (var c = 0; c < code.moduleCount; c++)
          if (image.isDark(r, c)) (row: r, col: c),
    ]);
  }
}

/// Una celda del árbol: su lugar en la cuadrícula, su color y si titila.
class TreeCell {
  final int row;
  final int col;
  final Color color;
  final bool twinkle;

  const TreeCell(this.row, this.col, this.color, {this.twinkle = false});
}

/// El árbol de Navidad dibujado con celdas de una cuadrícula de 25 x 25, y la
/// nieve que sobra alrededor.
class TreeLayout {
  static const grid = 25;

  final List<TreeCell> cells;
  final List<({int row, int col})> snow;

  const TreeLayout._(this.cells, this.snow);

  static final TreeLayout instance = _build();

  static TreeLayout _build() {
    const greens = [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)];
    final map = <int, ({int row, int col, String kind, Color color})>{};
    void add(int r, int c, String kind, Color color) {
      if (r >= 0 && r < grid && c >= 0 && c < grid) {
        map[r * grid + c] = (row: r, col: c, kind: kind, color: color);
      }
    }

    // Tres pisos de copa: (fila inicial, filas, semiancho máximo).
    const mid = 12;
    for (final tier in const [(3, 7, 5), (8, 8, 8), (14, 8, 11)]) {
      for (var i = 0; i < tier.$2; i++) {
        final half = (1 + (tier.$3 - 1) * i / (tier.$2 - 1)).round();
        for (var c = mid - half; c <= mid + half; c++) {
          add(tier.$1 + i, c, 'g', greens[(tier.$1 + i + c) % 3]);
        }
      }
    }
    for (var r = 22; r < 25; r++) {
      for (var c = 11; c <= 13; c++) {
        add(r, c, 't', const Color(0xFF6D4C41));
      }
    }
    for (final p in const [(0, 12), (1, 11), (1, 12), (1, 13), (2, 12)]) {
      add(p.$1, p.$2, 's', const Color(0xFFFFC107));
    }

    final sorted = map.values.toList()
      ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    final cells = <TreeCell>[];
    for (var i = 0; i < sorted.length; i++) {
      final cell = sorted[i];
      if (cell.kind == 'g' && i % 9 == 4) {
        // Cada novena hoja es un adorno que titila.
        cells.add(
          TreeCell(
            cell.row,
            cell.col,
            i.isOdd ? const Color(0xFFE53935) : const Color(0xFFFFB300),
            twinkle: true,
          ),
        );
      } else {
        cells.add(
          TreeCell(cell.row, cell.col, cell.color, twinkle: cell.kind == 's'),
        );
      }
    }

    var seed = 7;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    final snow = <({int row, int col})>[];
    var guard = 0;
    while (snow.length < 160 && guard++ < 5000) {
      final r = (rnd() * grid).floor();
      final c = (rnd() * grid).floor();
      if (!map.containsKey(r * grid + c)) snow.add((row: r, col: c));
    }
    return TreeLayout._(cells, snow);
  }
}

/// Una pieza en un instante: posición y tamaño como fracción del lado del QR.
class _PieceState {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double opacity;
  final double rotation;

  /// 0 = cuadrado de esquinas casi rectas; 1 = círculo.
  final double round;
  final bool twinkle;

  /// Fila de la cuadrícula donde queda (marca cuándo empieza a moverse).
  final double gridRow;

  const _PieceState({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.opacity,
    required this.gridRow,
    this.rotation = 0,
    this.round = 0,
    this.twinkle = false,
  });
}

/// Dibujos de cada fase para [total] piezas (las que sobran se esconden).
class _Layouts {
  static List<_PieceState> qr(QrMatrix matrix, int total, Color ink) {
    final cell = 1 / matrix.count;
    final snow = TreeLayout.instance.snow;
    return [
      for (var k = 0; k < total; k++)
        if (k < matrix.dark.length)
          _PieceState(
            x: matrix.dark[k].col * cell,
            y: matrix.dark[k].row * cell,
            size: cell,
            color: ink,
            opacity: 1,
            gridRow: matrix.dark[k].row.toDouble(),
          )
        else
          // Sin módulo en este QR: espera arriba, escondida.
          _PieceState(
            x: snow[k % snow.length].col / TreeLayout.grid,
            y: -4 * cell,
            size: cell,
            color: ink,
            opacity: 0,
            gridRow: -4,
          ),
    ];
  }

  static List<_PieceState> tree(int total, Color snowColor) {
    final layout = TreeLayout.instance;
    const cell = 1 / TreeLayout.grid;
    const piece = cell * 0.9;
    const offset = (cell - piece) / 2;
    return [
      for (var k = 0; k < total; k++)
        if (k < layout.cells.length)
          _PieceState(
            x: layout.cells[k].col * cell + offset,
            y: layout.cells[k].row * cell + offset,
            size: piece,
            color: layout.cells[k].color,
            opacity: 1,
            gridRow: layout.cells[k].row.toDouble(),
            twinkle: layout.cells[k].twinkle,
          )
        else
          () {
            final s =
                layout.snow[(k - layout.cells.length) % layout.snow.length];
            return _PieceState(
              x: s.col * cell + offset,
              y: s.row * cell + offset,
              size: piece,
              color: snowColor,
              opacity: 0.95,
              gridRow: s.row.toDouble(),
              rotation: k.isOdd ? 0.7 : -0.7,
              round: 1,
            );
          }(),
    ];
  }
}

/// El paso de un dibujo a otro: cada pieza sale en su momento, de arriba abajo.
class _Transition {
  static const moveMs = 360;
  static const colorMs = 220;

  final List<_PieceState> from;
  final List<_PieceState> to;
  final List<int> delays;
  final int totalMs;

  _Transition._(this.from, this.to, this.delays, this.totalMs);

  factory _Transition.between(List<_PieceState> from, List<_PieceState> to) {
    final delays = [
      for (var k = 0; k < to.length; k++)
        (math.max(0.0, to[k].gridRow + 4) * 4 + (k % 7) * 3).round(),
    ];
    return _Transition._(
      from,
      to,
      delays,
      moveMs + delays.fold<int>(0, math.max),
    );
  }

  /// El mismo dibujo quieto (para que los adornos titilen).
  /// Su progreso queda al final (1), así los adornos ya brillan.
  factory _Transition.still(List<_PieceState> state) =>
      _Transition._(state, state, List.filled(state.length, 0), moveMs);
}

class _PiecesPainter extends CustomPainter {
  static const _move = Cubic(0.3, 0.1, 0.3, 1.1);

  final _Transition transition;
  final Animation<double> progress;
  final Animation<double> twinkle;

  _PiecesPainter(this.transition, this.progress, this.twinkle)
    : super(repaint: Listenable.merge([progress, twinkle]));

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    final elapsed = progress.value * transition.totalMs;
    final paint = Paint();
    for (var k = 0; k < transition.to.length; k++) {
      final a = transition.from[k];
      final b = transition.to[k];
      final delay = transition.delays[k];
      final tMove = ((elapsed - delay) / _Transition.moveMs).clamp(0.0, 1.0);
      final tColor = ((elapsed - delay) / _Transition.colorMs).clamp(0.0, 1.0);
      final e = _move.transform(tMove);

      final x = ui.lerpDouble(a.x, b.x, e)!;
      final y = ui.lerpDouble(a.y, b.y, e)!;
      final s = ui.lerpDouble(a.size, b.size, e)!;
      final opacity = ui.lerpDouble(a.opacity, b.opacity, tColor)!;
      if (opacity <= 0.01 || s <= 0) continue;

      var color = Color.lerp(a.color, b.color, tColor)!;
      if (b.twinkle && tMove >= 1) {
        // Los adornos y la estrella brillan por turnos.
        final phase = (twinkle.value + (k % 5) * 0.2) % 1;
        final glow = 0.5 - 0.5 * math.cos(2 * math.pi * phase);
        color = Color.lerp(color, Colors.white, 0.45 * glow)!;
      }
      paint.color = color.withValues(alpha: opacity);

      final px = s * side;
      // Un poco más grande: sin rendijas entre módulos vecinos.
      final rect = Rect.fromLTWH(x * side, y * side, px, px).inflate(0.3);
      final round = ui.lerpDouble(a.round, b.round, tColor)!;
      final radius = ui.lerpDouble(math.min(2, px * 0.12), px / 2, round)!;
      final rotation = ui.lerpDouble(a.rotation, b.rotation, e)!;
      if (rotation == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          paint,
        );
      } else {
        canvas.save();
        canvas.translate(rect.center.dx, rect.center.dy);
        canvas.rotate(rotation);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: rect.width,
              height: rect.height,
            ),
            Radius.circular(radius),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PiecesPainter old) => old.transition != transition;
}

/// El código QR de la pantalla del responsable. En temporada festiva, cada
/// vez que se renueva el código sus módulos se reacomodan y, de cada
/// [treeEvery] renovaciones, forman un árbol de Navidad por un instante antes
/// de volver a ser el QR nuevo. Fuera de temporada, o sin cambios, es un
/// `QrImageView` quieto.
///
/// El QR solo es ilegible mientras dura la animación (poco más de un
/// segundo); el resto del tiempo es el código real, sin adornos.
class SeasonQr extends StatefulWidget {
  /// Lo que codifica el QR (el token del predio).
  final String data;
  final double size;

  /// Anima los cambios de código (temporada festiva).
  final bool festive;

  /// De cada cuántos cambios de código, uno forma el árbol.
  final int treeEvery;

  /// Cuánto se ve el árbol (incluye el tiempo en que se arma).
  final Duration dwell;

  final Color snowColor;

  const SeasonQr({
    super.key,
    required this.data,
    required this.size,
    this.festive = false,
    this.treeEvery = 3,
    this.dwell = const Duration(milliseconds: 750),
    this.snowColor = const Color(0xFF9CC3E4),
  });

  @override
  State<SeasonQr> createState() => _SeasonQrState();
}

class _SeasonQrState extends State<SeasonQr> with TickerProviderStateMixin {
  static const _ink = Color(0xFF000000);

  late final AnimationController _progress = AnimationController(vsync: this);
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  late QrMatrix _matrix = QrMatrix.fromData(widget.data);
  _Transition? _active;
  int _epoch = 0;
  int _renewals = 0;

  @override
  void didUpdateWidget(SeasonQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data == oldWidget.data) return;
    final next = QrMatrix.fromData(widget.data);
    if (!widget.festive || _active != null) {
      // Sin temporada (o si ya se estaba animando) el código nuevo se pone
      // directo.
      _epoch++;
      _twinkle.stop();
      setState(() {
        _active = null;
        _matrix = next;
      });
      return;
    }
    _renewals++;
    unawaited(_animate(next, tree: _renewals % widget.treeEvery == 0));
  }

  @override
  void dispose() {
    _epoch++;
    _progress.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  Future<void> _animate(QrMatrix next, {required bool tree}) async {
    final epoch = ++_epoch;
    final layout = TreeLayout.instance;
    final total = math.max(
      math.max(_matrix.dark.length, next.dark.length),
      tree ? layout.cells.length + 100 : 0,
    );
    final before = _Layouts.qr(_matrix, total, _ink);
    final after = _Layouts.qr(next, total, _ink);

    bool alive() => mounted && epoch == _epoch;

    if (tree) {
      final shape = _Layouts.tree(total, widget.snowColor);
      final up = _Transition.between(before, shape);
      if (!await _play(up, epoch)) return;
      // El árbol queda un instante a la vista, con los adornos brillando.
      final held = widget.dwell.inMilliseconds - up.totalMs;
      setState(() => _active = _Transition.still(shape));
      _twinkle.repeat();
      await Future<void>.delayed(Duration(milliseconds: math.max(200, held)));
      if (!alive()) return;
      _twinkle.stop();
      if (!await _play(_Transition.between(shape, after), epoch)) return;
    } else if (!await _play(_Transition.between(before, after), epoch)) {
      return;
    }
    if (!alive()) return;
    setState(() {
      _matrix = next;
      _active = null;
    });
  }

  /// Anima una transición; false si se canceló o la pantalla se cerró.
  Future<bool> _play(_Transition transition, int epoch) async {
    if (!mounted || epoch != _epoch) return false;
    setState(() => _active = transition);
    _progress.duration = Duration(milliseconds: transition.totalMs);
    await _progress.forward(from: 0);
    return mounted && epoch == _epoch;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return SizedBox.square(
      dimension: widget.size,
      child: active == null
          ? QrImageView(
              data: widget.data,
              size: widget.size,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            )
          : CustomPaint(
              key: const ValueKey('season-qr-pieces'),
              painter: _PiecesPainter(active, _progress, _twinkle),
            ),
    );
  }
}
