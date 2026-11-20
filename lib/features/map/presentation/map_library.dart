import 'package:flutter/material.dart';

import '../../../core/widgets/deferred_widget.dart';
import '../constants/map_defaults.dart';
import '../models/lat_lng.dart';
import 'location_picker.dart' deferred as map;

/// Único punto por el que se usa el mapa. La biblioteca del mapa (y su
/// dependencia flutter_map) es pesada: se descarga la primera vez que alguna
/// pantalla necesita un mapa y no con el resto de la aplicación.

/// Selector de ubicación (ver `LocationPicker`), con el mapa cargándose
/// aparte.
Widget deferredLocationPicker({
  required LatLng? initial,
  required ValueChanged<LatLng?> onChanged,
  double radiusMeters = MapDefaults.premiseRadiusMeters,
}) => DeferredWidget(
  loadLibrary: map.loadLibrary,
  placeholderHeight: 320,
  builder: (context) => map.LocationPicker(
    initial: initial,
    onChanged: onChanged,
    radiusMeters: radiusMeters,
  ),
);

/// Mapa pequeño que solo muestra un punto (ver `LocationPreview`), con el
/// mapa cargándose aparte.
Widget deferredLocationPreview({
  required LatLng? position,
  double radiusMeters = MapDefaults.premiseRadiusMeters,
  double height = 150,
}) => DeferredWidget(
  loadLibrary: map.loadLibrary,
  placeholderHeight: height,
  builder: (context) => map.LocationPreview(
    position: position,
    radiusMeters: radiusMeters,
    height: height,
  ),
);
