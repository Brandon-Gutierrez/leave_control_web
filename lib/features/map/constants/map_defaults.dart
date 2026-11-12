/// Valores por defecto del selector de ubicación.
abstract final class MapDefaults {
  /// Ubicación inicial del mapa: El Prado, Cochabamba.
  static const double latitude = -17.3935;
  static const double longitude = -66.1570;

  /// Radio (metros) por defecto de la geocerca. El valor real lo define el
  /// servidor (`GEOFENCE_RADIUS_METERS`) y llega en la lista de predios; esta
  /// constante solo se usa mientras no ha llegado.
  static const double premiseRadiusMeters = 50;
}
