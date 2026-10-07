/// Motivo de salida con el que una persona justifica su salida de un predio.
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
}
