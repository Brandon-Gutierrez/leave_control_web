import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../models/lat_lng.dart';

/// Lugar encontrado por el buscador del mapa.
class PlaceResult {
  final String name;
  final LatLng position;

  const PlaceResult({required this.name, required this.position});
}

typedef PlaceSearch = Future<List<PlaceResult>> Function(String query);
typedef LocateMe = Future<LatLng?> Function();

/// Búsqueda de lugares por nombre (OpenStreetMap Nominatim, sin API key).
Future<List<PlaceResult>> searchPlaces(String query) async {
  final response = await Dio().get<List<dynamic>>(
    'https://nominatim.openstreetmap.org/search',
    queryParameters: {
      'q': query,
      'format': 'jsonv2',
      'limit': 5,
      'accept-language': 'es',
    },
  );
  final results = <PlaceResult>[];
  for (final item in response.data ?? const []) {
    final lat = double.tryParse('${item['lat']}');
    final lng = double.tryParse('${item['lon']}');
    if (lat == null || lng == null) continue;
    results.add(
      PlaceResult(
        name: (item['display_name'] ?? '').toString(),
        position: LatLng(lat, lng),
      ),
    );
  }
  return results;
}

/// Ubicación actual del administrador según el navegador. Devuelve null si
/// no hay permiso o el GPS/ubicación no está disponible.
Future<LatLng?> currentLocation() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LatLng(p.latitude, p.longitude);
  } catch (_) {
    return null;
  }
}
