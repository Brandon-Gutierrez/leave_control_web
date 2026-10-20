/// Resultado de validar item y carnet en el ingreso manual: o la persona debe
/// elegir un motivo para su salida, o ya se registró su retorno.
class ManualEntryStep {
  /// `showReasons` (falta elegir el motivo) o `showHome` (retorno registrado).
  final String action;
  final String person;
  final String item;
  final String? premise;
  final List<String> reasons;
  final String? leaveTicket;
  final DateTime? ticketExpiresAt;

  const ManualEntryStep({
    required this.action,
    required this.person,
    required this.item,
    this.premise,
    this.reasons = const [],
    this.leaveTicket,
    this.ticketExpiresAt,
  });

  bool get needsReason => action == 'showReasons';

  factory ManualEntryStep.fromJson(Map<String, dynamic> json) {
    return ManualEntryStep(
      action: json['action']?.toString() ?? '',
      person: json['person']?.toString() ?? '',
      item: json['item']?.toString() ?? '',
      premise: json['premise']?.toString(),
      reasons: [
        for (final r in json['reasons'] as List? ?? const []) r.toString(),
      ],
      leaveTicket: json['leaveTicket']?.toString(),
      ticketExpiresAt: DateTime.tryParse(
        json['leaveTicketExpiresAt']?.toString() ?? '',
      ),
    );
  }
}
