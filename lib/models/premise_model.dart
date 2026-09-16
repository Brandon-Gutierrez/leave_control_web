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

class Premise {
  final int id;
  final String name;
  final List<Reason> reasonNames;

  Premise({
    required this.id,
    required this.name,
    required this.reasonNames,
  });

  factory Premise.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['reason_names'] as List? ?? [];
    return Premise(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      reasonNames: rawReasons.map((r) => Reason.fromJson(r)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'reason_names': reasonNames.map((r) => r.toJson()).toList(),
    };
  }
}