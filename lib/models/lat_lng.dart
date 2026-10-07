/// Coordenada geográfica (grados).
class LatLng {
  final double latitude;
  final double longitude;

  /// Ejecuta la tarea.
  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
