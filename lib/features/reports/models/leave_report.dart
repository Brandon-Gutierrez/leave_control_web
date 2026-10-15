int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Totales del periodo.
class ReportSummary {
  final int exits;
  final int minutes;
  final int averageMinutes;
  final int people;
  final int outsideNow;
  final int unreturned;

  const ReportSummary({
    required this.exits,
    required this.minutes,
    required this.averageMinutes,
    required this.people,
    required this.outsideNow,
    required this.unreturned,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    exits: _int(json['exits']),
    minutes: _int(json['minutes']),
    averageMinutes: _int(json['average_minutes']),
    people: _int(json['people']),
    outsideNow: _int(json['outside_now']),
    unreturned: _int(json['unreturned']),
  );
}

/// Salidas y tiempo agrupados por predio o por motivo.
class ReportGroup {
  final String name;
  final int exits;
  final int minutes;
  final int averageMinutes;
  final int people;

  const ReportGroup({
    required this.name,
    required this.exits,
    required this.minutes,
    required this.averageMinutes,
    required this.people,
  });

  factory ReportGroup.fromJson(Map<String, dynamic> json) => ReportGroup(
    name: json['name']?.toString() ?? '',
    exits: _int(json['exits']),
    minutes: _int(json['minutes']),
    averageMinutes: _int(json['average_minutes']),
    people: _int(json['people']),
  );
}

/// Resumen de una persona en el periodo.
class ReportPerson {
  final int userId;
  final String name;
  final String? item;
  final int exits;
  final int minutes;
  final int averageMinutes;
  final int longestMinutes;
  final int unreturned;

  const ReportPerson({
    required this.userId,
    required this.name,
    required this.item,
    required this.exits,
    required this.minutes,
    required this.averageMinutes,
    required this.longestMinutes,
    required this.unreturned,
  });

  factory ReportPerson.fromJson(Map<String, dynamic> json) => ReportPerson(
    userId: _int(json['user_id']),
    name: json['name']?.toString() ?? '',
    item: json['item']?.toString(),
    exits: _int(json['exits']),
    minutes: _int(json['minutes']),
    averageMinutes: _int(json['average_minutes']),
    longestMinutes: _int(json['longest_minutes']),
    unreturned: _int(json['unreturned']),
  );
}

/// Una salida que merece atención: sin retorno, o persona fuera ahora.
class ReportWarning {
  final String name;
  final String? item;
  final String? premise;
  final String? reason;
  final DateTime leftAt;
  final int minutes;

  const ReportWarning({
    required this.name,
    required this.item,
    required this.premise,
    required this.reason,
    required this.leftAt,
    required this.minutes,
  });

  factory ReportWarning.fromJson(Map<String, dynamic> json) => ReportWarning(
    name: json['name']?.toString() ?? '',
    item: json['item']?.toString(),
    premise: json['premise']?.toString(),
    reason: json['reason']?.toString(),
    leftAt:
        DateTime.tryParse(json['left_at']?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    minutes: _int(json['minutes']),
  );
}

/// Reporte de salidas del periodo, tal como lo entrega el backend.
class LeaveReport {
  final ReportSummary summary;
  final List<ReportGroup> byPremise;
  final List<ReportGroup> byReason;
  final List<ReportPerson> byUser;
  final List<ReportWarning> unreturned;
  final List<ReportWarning> outsideNow;

  const LeaveReport({
    required this.summary,
    required this.byPremise,
    required this.byReason,
    required this.byUser,
    required this.unreturned,
    required this.outsideNow,
  });

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) map) =>
      [
        for (final item in raw as List? ?? const [])
          if (item is Map) map(Map<String, dynamic>.from(item)),
      ];

  factory LeaveReport.fromJson(Map<String, dynamic> json) => LeaveReport(
    summary: ReportSummary.fromJson(
      Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
    ),
    byPremise: _list(json['by_premise'], ReportGroup.fromJson),
    byReason: _list(json['by_reason'], ReportGroup.fromJson),
    byUser: _list(json['by_user'], ReportPerson.fromJson),
    unreturned: _list(json['unreturned'], ReportWarning.fromJson),
    outsideNow: _list(json['outside_now'], ReportWarning.fromJson),
  );
}
