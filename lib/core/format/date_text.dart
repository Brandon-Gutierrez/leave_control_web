/// Fechas, horas y cifras escritas en español para las pantallas del panel.
/// No usa `intl`: son pocas frases y así no depende de la configuración regional.
abstract final class DateText {
  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// «Jueves 19 de noviembre»
  static String longDate(DateTime d) {
    final day = _weekdays[d.weekday - 1];
    return '${day[0].toUpperCase()}${day.substring(1)} ${d.day} de '
        '${_months[d.month - 1]}';
  }

  /// «19/11/2026»
  static String dayMonthYear(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';

  /// «08:05»
  static String hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// «Buenos días», «Buenas tardes» o «Buenas noches» según la hora.
  static String greeting(DateTime d) {
    if (d.hour < 12) return 'Buenos días';
    if (d.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// «hoy a las 00:00», «ayer a las 00:00» o «19/11/2026 a las 00:00».
  static String whenText(DateTime moment, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(moment.year, moment.month, moment.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'hoy'
        : diff == 1
        ? 'ayer'
        : dayMonthYear(moment);
    return '$label a las ${hm(moment)}';
  }

  /// «45 segundos», «1 minuto», «5 minutos», «1 min 30 s».
  static String seconds(int total) {
    if (total < 60) return '$total ${total == 1 ? 'segundo' : 'segundos'}';
    final minutes = total ~/ 60;
    final rest = total % 60;
    if (rest == 0) return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    return '$minutes min $rest s';
  }
}
