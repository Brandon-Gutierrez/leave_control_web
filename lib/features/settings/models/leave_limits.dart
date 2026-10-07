/// Límite de salidas general: se aplica igual a todas las personas. `null` en
/// un tope significa "sin tope".
class LeaveLimits {
  final String period;
  final int? maxExits;
  final int? maxExitsPerPremise;

  const LeaveLimits({
    required this.period,
    this.maxExits,
    this.maxExitsPerPremise,
  });

  factory LeaveLimits.fromJson(Map<String, dynamic> json) => LeaveLimits(
    period: (json['period'] ?? 'day').toString(),
    maxExits: (json['max_exits'] as num?)?.toInt(),
    maxExitsPerPremise: (json['max_exits_per_premise'] as num?)?.toInt(),
  );

  static const periods = ['day', 'week', 'month'];

  static String periodLabel(String period) => switch (period) {
    'day' => 'Cada día',
    'week' => 'Cada semana',
    'month' => 'Cada mes',
    _ => period,
  };
}
