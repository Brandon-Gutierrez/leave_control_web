import 'dart:convert';

import 'package:control_leaves_web/features/map/presentation/location_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;

/// Mosaicos vacíos para las pruebas: los mapas no llaman a internet (donde las
/// peticiones fallan y se reintentan sin parar, y `pumpAndSettle` no termina).
class BlankTileProvider extends TileProvider {
  static final _transparentPixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPixel);

  /// Usa estos mosaicos en todos los mapas hasta que termine la prueba.
  static void install() {
    LocationPicker.tileProviderOverride = BlankTileProvider();
    addTearDown(() => LocationPicker.tileProviderOverride = null);
  }
}
