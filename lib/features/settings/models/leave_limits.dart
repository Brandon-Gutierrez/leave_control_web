/// Tope de salidas de un motivo (modo personalizado). `null` = sin tope.
class ReasonCap {
  final int reasonId;
  final String name;
  final int? max;

  const ReasonCap({required this.reasonId, required this.name, this.max});

  factory ReasonCap.fromJson(Map<String, dynamic> json) => ReasonCap(
    reasonId: (json['reason_id'] as num).toInt(),
    name: (json['name'] ?? '').toString(),
    max: (json['max'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {'reason_id': reasonId, 'max': max};
}

/// Cuántas veces puede una persona elegir un mismo motivo en el período.
/// General: el mismo tope para cada motivo. Personalizado: un tope por motivo.
class ReasonLimit {
  static const general = 'general';
  static const custom = 'custom';

  final String period;
  final String mode;
  final int? maxGeneral;
  final List<ReasonCap> caps;

  const ReasonLimit({
    this.period = 'day',
    this.mode = general,
    this.maxGeneral,
    this.caps = const [],
  });

  factory ReasonLimit.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReasonLimit();
    return ReasonLimit(
      period: (json['period'] ?? 'day').toString(),
      mode: json['mode'] == custom ? custom : general,
      maxGeneral: (json['general'] as num?)?.toInt(),
      caps: [
        for (final row in (json['custom'] as List? ?? const []))
          if (row is Map<String, dynamic>) ReasonCap.fromJson(row),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'period': period,
    'mode': mode,
    'general': maxGeneral,
    'custom': [for (final cap in caps) cap.toJson()],
  };

  /// Tope de veces para el motivo [reasonId]; null si no tiene tope.
  int? capFor(int reasonId) {
    if (mode == general) return maxGeneral;
    for (final cap in caps) {
      if (cap.reasonId == reasonId) return cap.max;
    }
    return null;
  }

  /// «1 vez por día», «3 veces por semana» o «Sin tope».
  String describeCap(int? max) {
    if (max == null) return 'Sin tope';
    final unit = switch (period) {
      'week' => 'semana',
      'month' => 'mes',
      _ => 'día',
    };
    return '$max ${max == 1 ? 'vez' : 'veces'} por $unit';
  }
}

/// Límites de salidas, iguales para todas las personas: por persona y por
/// motivo. `null` en un tope significa "sin tope".
class LeaveLimits {
  final String period;
  final int? maxExits;
  final ReasonLimit reasonLimit;

  const LeaveLimits({
    required this.period,
    this.maxExits,
    this.reasonLimit = const ReasonLimit(),
  });

  factory LeaveLimits.fromJson(Map<String, dynamic> json) => LeaveLimits(
    period: (json['period'] ?? 'day').toString(),
    maxExits: (json['max_exits'] as num?)?.toInt(),
    reasonLimit: ReasonLimit.fromJson(
      json['reason_limit'] as Map<String, dynamic>?,
    ),
  );

  Map<String, dynamic> toJson() => {
    'period': period,
    'max_exits': maxExits,
    'reason_limit': reasonLimit.toJson(),
  };

  static const periods = ['day', 'week', 'month'];

  static String periodLabel(String period) => switch (period) {
    'day' => 'Cada día',
    'week' => 'Cada semana',
    'month' => 'Cada mes',
    _ => period,
  };
}
