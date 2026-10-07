import 'reason.dart';

/// Responsable (rol MANAGE_PREMISE) asignado a un predio.
class PremiseManager {
  final int userId;
  final String name;

  const PremiseManager({required this.userId, required this.name});
}

/// Predio con su ubicación, responsable y motivos de salida permitidos.
class Premise {
  final int id;
  final String name;
  final List<Reason> reasonNames;
  final double? latitude;
  final double? longitude;
  final PremiseManager? manager;

  Premise({
    required this.id,
    required this.name,
    required this.reasonNames,
    this.latitude,
    this.longitude,
    this.manager,
  });

  /// Indica si el predio tiene coordenadas.
  bool get hasLocation => latitude != null && longitude != null;

  static double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  factory Premise.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['reason_names'] as List? ?? [];
    final rawManager = json['manager'];
    return Premise(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      reasonNames: rawReasons.map((r) => Reason.fromJson(r)).toList(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      manager: rawManager is Map
          ? PremiseManager(
              userId: int.tryParse('${rawManager['user_id']}') ?? 0,
              name: (rawManager['name'] ?? '').toString().trim(),
            )
          : null,
    );
  }
}
