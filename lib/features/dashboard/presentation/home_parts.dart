import 'package:flutter/material.dart';

import '../../../core/format/date_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hover_highlight.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/skeleton.dart';
import '../../premises/models/premise.dart';
import '../../settings/models/leave_limits.dart';
import '../../settings/models/qr_settings.dart';
import '../models/admin_summary.dart';
import 'user_profile_header.dart';

/// Texto de enlace rojo con flecha («Ver todos →»).
class ArrowLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const ArrowLink({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.primaryRed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$label →',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Franja de cifras
// ---------------------------------------------------------------------------

/// Cuatro cifras grandes en una franja con una línea gruesa arriba: predios,
/// usuarios, responsables y motivos activos, cada una con una nota.
class HomeStats extends StatelessWidget {
  final AdminSummary? summary;

  /// Primera carga: todavía no hay cifras que mostrar.
  final bool loading;

  /// Ahora (para decir «hoy a las 00:00» de la última sincronización).
  final DateTime now;

  const HomeStats({
    super.key,
    required this.summary,
    required this.loading,
    required this.now,
  });

  static const _gray = Color(0xFF9A9A94);

  List<_Stat> _stats() {
    final s = summary;
    if (s == null) {
      return const [
        _Stat('Predios', null, null, _gray),
        _Stat('Usuarios', null, null, _gray),
        _Stat('Responsables', null, null, _gray),
        _Stat('Motivos activos', null, null, _gray),
      ];
    }

    final (String, Color) premises = s.premises == 0
        ? ('Aún no hay predios', _gray)
        : s.premisesWithoutLocation > 0
        ? ('${s.premisesWithoutLocation} sin ubicación', AppColors.danger)
        : s.premisesWithoutManager > 0
        ? ('${s.premisesWithoutManager} sin responsable', AppColors.warning)
        : ('Todos con ubicación y responsable', AppColors.success);

    final (String, Color) managers = s.managers == 0
        ? ('Ninguno todavía', _gray)
        : s.managersWithoutPremise > 0
        ? ('${s.managersWithoutPremise} sin predio asignado', AppColors.warning)
        : ('Todos con predio asignado', AppColors.success);

    final sync = s.reasonsSync;
    final (String, Color) reasons = sync == null
        ? ('Aún sin sincronizar', _gray)
        : sync.failed
        ? ('Sincronización con error', AppColors.warning)
        : sync.at == null
        ? ('Sincronizado', AppColors.success)
        : (
            'Sincronizado ${DateText.whenText(sync.at!.toLocal(), now)}',
            AppColors.success,
          );

    return [
      _Stat('Predios', s.premises, premises.$1, premises.$2),
      _Stat(
        'Usuarios',
        s.users,
        '${s.admins} ${s.admins == 1 ? 'administrador' : 'administradores'}',
        _gray,
      ),
      _Stat('Responsables', s.managers, managers.$1, managers.$2),
      _Stat('Motivos activos', s.activeReasons, reasons.$1, reasons.$2),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    return SkeletonPulse(
      active: loading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 880 ? 4 : 2;
          final rows = [
            for (var i = 0; i < stats.length; i += columns)
              stats.sublist(i, (i + columns).clamp(0, stats.length)),
          ];
          return Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.darkText, width: 3),
                bottom: BorderSide(color: Color(0xFFD9D9D4)),
              ),
            ),
            child: Column(
              children: [
                for (var r = 0; r < rows.length; r++)
                  Container(
                    decoration: BoxDecoration(
                      border: r == 0
                          ? null
                          : const Border(
                              top: BorderSide(color: AppColors.rowLine),
                            ),
                    ),
                    child: Row(
                      children: [
                        for (var c = 0; c < columns; c++)
                          Expanded(
                            child: c < rows[r].length
                                ? _StatCell(
                                    stat: rows[r][c],
                                    loading: loading,
                                    first: c == 0,
                                  )
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat {
  final String label;
  final int? value;
  final String? note;
  final Color noteColor;

  const _Stat(this.label, this.value, this.note, this.noteColor);
}

class _StatCell extends StatelessWidget {
  final _Stat stat;
  final bool loading;
  final bool first;

  const _StatCell({
    required this.stat,
    required this.loading,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(first ? 0 : 24, 20, 12, 20),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(left: BorderSide(color: Color(0xFFD9D9D4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const SkeletonBox(width: 80, height: 48)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                stat.value == null ? '–' : '${stat.value}',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (loading)
            const SkeletonBox(width: 110, height: 14)
          else if (stat.note != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: stat.noteColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stat.note!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vista rápida de predios
// ---------------------------------------------------------------------------

/// Los primeros predios con su responsable y cuántos motivos tienen. Los que
/// tienen algo pendiente (sin ubicación, sin responsable, sin motivos) van
/// primero y resaltados, con el botón para resolverlo.
class PremisesGlance extends StatelessWidget {
  final List<Premise> premises;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;

  const PremisesGlance({
    super.key,
    required this.premises,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSeeAll,
  });

  /// Cuántos predios caben en la vista rápida.
  static const limit = 6;

  static int _priority(Premise p) {
    if (!p.hasLocation) return 0;
    if (p.manager == null) return 1;
    if (p.reasonNames.isEmpty) return 2;
    return 3;
  }

  /// Los de la lista: primero los que tienen algo pendiente; dentro de cada
  /// grupo, por nombre.
  static List<Premise> pick(List<Premise> all) {
    final sorted = [...all]
      ..sort((a, b) {
        final byPriority = _priority(a).compareTo(_priority(b));
        if (byPriority != 0) return byPriority;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shown = pick(premises);

    final Widget body;
    if (loading) {
      body = const SkeletonPulse(
        child: Column(
          children: [_SkeletonRow(), _SkeletonRow(), _SkeletonRow()],
        ),
      );
    } else if (error != null && premises.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: LoadErrorNotice(message: error!, onRetry: onRetry),
      );
    } else if (premises.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Aún no hay predios registrados.',
          style: TextStyle(fontSize: 15, color: AppColors.muted),
        ),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          return Column(
            children: [
              if (wide) const _HeaderRow(),
              for (final premise in shown)
                _PremiseRow(
                  premise: premise,
                  wide: wide,
                  first: false,
                  onTap: onSeeAll,
                ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Expanded(
              child: Text(
                'Vista rápida de predios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            ArrowLink(label: 'Ver todos', onTap: onSeeAll),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.panelLine),
            borderRadius: BorderRadius.circular(6),
          ),
          child: body,
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: AppColors.label,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          SizedBox(width: 34),
          Expanded(flex: 9, child: Text('PREDIO', style: style)),
          Expanded(flex: 16, child: Text('RESPONSABLE', style: style)),
          SizedBox(width: 124, child: Text('MOTIVOS', style: style)),
          SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _PremiseRow extends StatelessWidget {
  final Premise premise;
  final bool wide;
  final bool first;
  final VoidCallback onTap;

  const _PremiseRow({
    required this.premise,
    required this.wide,
    required this.first,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = premise;
    final manager = p.manager;
    final reasons = p.reasonNames.length;

    // Qué le pasa al predio (null = nada pendiente).
    final (String, String, Color)? alert = !p.hasLocation
        ? ('Sin ubicación · nadie puede escanear', 'Marcar', AppColors.danger)
        : manager == null
        ? ('Sin responsable · nadie muestra el QR', 'Asignar', AppColors.danger)
        : reasons == 0
        ? ('Sin motivos habilitados', 'Elegir', AppColors.warning)
        : null;
    final urgent = alert != null && alert.$3 == AppColors.danger;
    final dot = alert?.$3 ?? AppColors.success;
    final motives = '$reasons ${reasons == 1 ? 'habilitado' : 'habilitados'}';

    final name = Text(
      p.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );

    final Widget responsible = alert != null
        ? Text(
            alert.$1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: alert.$3,
            ),
          )
        : manager == null
        ? const SizedBox.shrink()
        : Row(
            children: [
              UserAvatar(name: manager.name, photoUrl: null, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  manager.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          );

    final Widget row = wide
        ? Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 25),
              Expanded(flex: 9, child: name),
              Expanded(flex: 16, child: responsible),
              SizedBox(
                width: 124,
                child: alert != null
                    ? Text(
                        '${alert.$2} →',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: alert.$3,
                        ),
                      )
                    : Text(
                        motives,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF555555),
                        ),
                      ),
              ),
              SizedBox(
                width: 24,
                child: alert != null
                    ? null
                    : const Text(
                        '›',
                        style: TextStyle(
                          fontSize: 20,
                          color: Color(0xFFBBBBBB),
                        ),
                      ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: name),
                  Text(
                    alert != null ? '${alert.$2} →' : motives,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: alert != null
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: alert?.$3 ?? const Color(0xFF555555),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 21, top: 6),
                child: responsible,
              ),
            ],
          );

    return HoverHighlight(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: urgent ? const Color(0xFFFDF1EF) : null,
            border: const Border(top: BorderSide(color: AppColors.rowLine)),
          ),
          child: row,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rowLine)),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 9, height: 9, radius: 5),
          SizedBox(width: 20),
          SkeletonBox(width: 120, height: 16),
          SizedBox(width: 40),
          Expanded(child: SkeletonBox(height: 14)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pendientes
// ---------------------------------------------------------------------------

/// Una cosa por resolver, con su acción.
class PendingItem {
  final String title;
  final String help;
  final String action;
  final VoidCallback onTap;

  /// Lo informativo (no urgente) lleva su enlace en gris.
  final bool neutral;

  const PendingItem({
    required this.title,
    required this.help,
    required this.action,
    required this.onTap,
    this.neutral = false,
  });
}

/// Lista numerada de lo que falta resolver; si no hay nada, lo dice.
class PendingList extends StatelessWidget {
  final List<PendingItem> items;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const PendingList({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (loading) {
      body = const SkeletonPulse(
        child: Column(children: [_SkeletonTodo(), _SkeletonTodo()]),
      );
    } else if (error != null) {
      body = LoadErrorNotice(message: error!, onRetry: onRetry);
    } else if (items.isEmpty) {
      body = Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rowLine)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 30,
              color: AppColors.success,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Todo está en orden',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Todos los predios tienen ubicación, motivos y responsable.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _Todo(number: i + 1, item: items[i]),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Pendientes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        body,
      ],
    );
  }
}

class _Todo extends StatelessWidget {
  final int number;
  final PendingItem item;

  const _Todo({required this.number, required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.neutral ? const Color(0xFF555555) : AppColors.primaryRed;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rowLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1,
                color: AppColors.primaryRed,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
                  child: Text(
                    item.help,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                InkWell(
                  onTap: item.onTap,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 1),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: item.neutral
                              ? const Color(0xFF999999)
                              : AppColors.primaryRed,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      item.action,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
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

class _SkeletonTodo extends StatelessWidget {
  const _SkeletonTodo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rowLine)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 26, height: 34),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 220, height: 16),
                SizedBox(height: 8),
                SkeletonBox(height: 13),
                SizedBox(height: 10),
                SkeletonBox(width: 110, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Configuración vigente
// ---------------------------------------------------------------------------

/// Las reglas que están en uso, con puntos guía entre el nombre y el valor.
class CurrentRules extends StatelessWidget {
  final QrSettings? qr;
  final LeaveLimits? limits;
  final double radiusMeters;
  final VoidCallback? onEdit;

  const CurrentRules({
    super.key,
    required this.qr,
    required this.limits,
    required this.radiusMeters,
    required this.onEdit,
  });

  static String limitText(LeaveLimits limits) {
    final max = limits.maxExits;
    if (max == null) return 'Sin tope';
    final period = switch (limits.period) {
      'week' => 'semana',
      'month' => 'mes',
      _ => 'día',
    };
    return '$max por $period';
  }

  @override
  Widget build(BuildContext context) {
    final qrSettings = qr;
    final leaveLimits = limits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Expanded(
              child: Text(
                'Configuración vigente',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            ArrowLink(label: 'Editar', onTap: onEdit),
          ],
        ),
        const SizedBox(height: 4),
        _Rule(
          'Vida del código QR',
          qrSettings == null ? '—' : DateText.seconds(qrSettings.ttlSeconds),
        ),
        _Rule(
          'Salidas por persona',
          leaveLimits == null ? '—' : limitText(leaveLimits),
        ),
        _Rule('Distancia al predio', '${radiusMeters.round()} metros'),
        const _Rule('Sincronización de motivos', 'Lun a vie, 00:00'),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  final String label;
  final String value;

  const _Rule(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: LayoutBuilder(
        // El nombre ocupa solo lo que mide y el valor tambiÃ©n (cada uno hasta la mitad de la fila), los
        // puntos rellenan el resto y el valor queda pegado al borde derecho:
        // así todas las filas terminan en la misma línea.
        builder: (context, box) => Row(
          // Los puntos van abajo, a la altura de la base del texto.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5),
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
            const Expanded(child: _DottedLeader()),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Línea de puntos entre el nombre de una regla y su valor.
class _DottedLeader extends StatelessWidget {
  const _DottedLeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 5),
      child: SizedBox(height: 1, child: CustomPaint(painter: _DotsPainter())),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB5B5AF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x + 1.5, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}
