/// Motivo que la persona ya usó tantas veces como permite el límite del
/// período: se muestra como no permitido.
class BlockedReason {
  final String name;
  final int limit;
  final String period;

  const BlockedReason({
    required this.name,
    required this.limit,
    required this.period,
  });

  factory BlockedReason.fromJson(Map<String, dynamic> json) => BlockedReason(
    name: json['name']?.toString() ?? '',
    limit: (json['limit'] as num?)?.toInt() ?? 0,
    period: json['period']?.toString() ?? 'day',
  );

  /// Ej.: "Límite alcanzado: 1 vez por día".
  String get note {
    final unit = switch (period) {
      'week' => 'semana',
      'month' => 'mes',
      _ => 'día',
    };
    return 'Límite alcanzado: $limit ${limit == 1 ? 'vez' : 'veces'} por $unit';
  }
}

/// Resultado de validar item y carnet en el ingreso manual: o la persona debe
/// elegir un motivo para su salida, o ya se registró su retorno.
class ManualEntryStep {
  /// `showReasons` (falta elegir el motivo) o `showHome` (retorno registrado).
  final String action;
  final String person;
  final String item;
  final String? premise;
  final List<String> reasons;

  /// Motivos de [reasons] que esta persona ya no puede elegir.
  final List<BlockedReason> blockedReasons;
  final String? leaveTicket;
  final DateTime? ticketExpiresAt;

  const ManualEntryStep({
    required this.action,
    required this.person,
    required this.item,
    this.premise,
    this.reasons = const [],
    this.blockedReasons = const [],
    this.leaveTicket,
    this.ticketExpiresAt,
  });

  bool get needsReason => action == 'showReasons';

  /// El bloqueo de [reason], o null si puede elegirlo.
  BlockedReason? blockFor(String reason) {
    for (final blocked in blockedReasons) {
      if (blocked.name == reason) return blocked;
    }
    return null;
  }

  factory ManualEntryStep.fromJson(Map<String, dynamic> json) {
    return ManualEntryStep(
      action: json['action']?.toString() ?? '',
      person: json['person']?.toString() ?? '',
      item: json['item']?.toString() ?? '',
      premise: json['premise']?.toString(),
      reasons: [
        for (final r in json['reasons'] as List? ?? const []) r.toString(),
      ],
      blockedReasons: [
        for (final r in json['blocked_reasons'] as List? ?? const [])
          if (r is Map<String, dynamic>) BlockedReason.fromJson(r),
      ],
      leaveTicket: json['leaveTicket']?.toString(),
      ticketExpiresAt: DateTime.tryParse(
        json['leaveTicketExpiresAt']?.toString() ?? '',
      ),
    );
  }
}
