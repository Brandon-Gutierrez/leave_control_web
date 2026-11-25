import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// «08:15:30» (hora de este equipo).
String formatFullTime(DateTime time) {
  final local = time.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
}

/// Cuánto tiempo estuvo fuera: «45 s», «26 min 5 s», «2 h 0 min 9 s» o, si
/// pasó de un día, «1 d 3 h 10 min 0 s».
String formatTimeAway(Duration away) {
  final total = away.isNegative ? 0 : away.inSeconds;
  final days = total ~/ 86400;
  final hours = total ~/ 3600 % 24;
  final minutes = total ~/ 60 % 60;
  return [
    if (days > 0) '$days d',
    if (total >= 3600) '$hours h',
    if (total >= 60) '$minutes min',
    '${total % 60} s',
  ].join(' ');
}

/// Resumen de lo que se registró en el registro manual: la hora de salida y,
/// en un retorno, la de regreso y el tiempo que la persona estuvo fuera.
class ManualEntrySummary extends StatelessWidget {
  final DateTime? leftAt;

  /// Solo en un retorno.
  final DateTime? returnedAt;

  const ManualEntrySummary({super.key, this.leftAt, this.returnedAt});

  /// La salida de otro día lleva su fecha («01/03 23:50:00»).
  String _departure(DateTime left) {
    final back = returnedAt?.toLocal();
    final local = left.toLocal();
    final otherDay =
        back != null &&
        (back.year != local.year ||
            back.month != local.month ||
            back.day != local.day);
    return otherDay
        ? '${_two(local.day)}/${_two(local.month)} ${formatFullTime(left)}'
        : formatFullTime(left);
  }

  @override
  Widget build(BuildContext context) {
    final left = leftAt;
    final back = returnedAt;
    final rows = <Widget>[
      if (left != null) _Row('Hora de salida', _departure(left)),
      if (back != null) _Row('Hora de retorno', formatFullTime(back)),
      if (left != null && back != null)
        _Row('Tiempo fuera', formatTimeAway(back.difference(left)), big: true),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.panelLine),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: AppColors.rowLine)),
              ),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool big;

  const _Row(this.label, this.value, {this.big = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      // Si no caben en una línea (letra grande), el valor baja.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 24 : 20,
              fontWeight: FontWeight.w800,
              color: big ? AppColors.success : AppColors.darkText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
