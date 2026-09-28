class Reason {
  final String name;

  Reason({required this.name});

  factory Reason.fromJson(dynamic value) {
    // Si viene como String directo dentro del array
    if (value is String) {
      return Reason(name: value);
    }
    // Si en alguna otra ruta viniera como Map
    return Reason(name: value['name'] ?? value['reasons'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}

/// Ubicación por defecto del mapa: El Prado, Cochabamba.
const double kDefaultLatitude = -17.3935;
const double kDefaultLongitude = -66.1570;

/// Radio (metros) dentro del cual se aceptan los escaneos de un predio.
const double kPremiseRadiusMeters = 30;

/// Responsable (rol MANAGE_PREMISE) asignado a un predio.
class PremiseManager {
  final int userId;
  final String name;

  const PremiseManager({required this.userId, required this.name});
}

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'reason_names': reasonNames.map((r) => r.toJson()).toList(),
    };
  }
}
