import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/theme/app_colors.dart';
import '../constants/map_defaults.dart';
import '../data/geocoding_service.dart';
import '../models/lat_lng.dart';

/// Selector de ubicación solo por mapa (OpenStreetMap, sin API key).
///
/// - Un toque fija el marcador; el círculo rojo es la zona de 50 m donde se
///   aceptan los escaneos.
/// - Buscador de lugares por nombre y botón "Mi ubicación".
/// - Vista de calle o satélite, zoom grande y botón para volver al marcador.
/// - Mensaje de estado que indica si ya hay un punto fijado.
class LocationPicker extends StatefulWidget {
  /// Punto ya guardado; null cuando todavía no se eligió ninguno.
  final LatLng? initial;

  /// Recibe el punto elegido (o null si aún no hay).
  final ValueChanged<LatLng?> onChanged;

  final PlaceSearch? placeSearch;
  final LocateMe? locateMe;

  /// Proveedor de mosaicos alterno (solo pruebas, sin red).
  @visibleForTesting
  static TileProvider? tileProviderOverride;

  const LocationPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.placeSearch,
    this.locateMe,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  static const _street = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _satellite =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  final MapController _map = MapController();
  final TextEditingController _search = TextEditingController();

  LatLng? _picked;
  bool _satelliteView = false;
  bool _searching = false;
  bool _locating = false;
  String? _message;
  List<PlaceResult> _results = [];

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ll.LatLng _toLl(LatLng p) => ll.LatLng(p.latitude, p.longitude);

  ll.LatLng get _center =>
      _toLl(_picked ?? const LatLng(MapDefaults.latitude, MapDefaults.longitude));

  void _pick(LatLng p, {double? zoom}) {
    setState(() {
      _picked = p;
      _message = null;
      _results = [];
    });
    try {
      _map.move(_toLl(p), zoom ?? _map.camera.zoom);
    } catch (_) {
      // El mapa aún no está listo; se centra al construirse.
    }
    widget.onChanged(p);
  }

  void _zoom(double delta) {
    try {
      _map.move(
        _map.camera.center,
        (_map.camera.zoom + delta).clamp(3.0, 19.0),
      );
    } catch (_) {}
  }

  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.length < 3 || _searching) {
      setState(() => _message = 'Escribe al menos 3 letras para buscar.');
      return;
    }
    setState(() {
      _searching = true;
      _message = null;
      _results = [];
    });
    try {
      final results = await (widget.placeSearch ?? searchPlaces)(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _message =
              'No se encontró ese lugar. Prueba con otro nombre o toca el mapa.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'No se pudo buscar ahora. Toca el mapa para fijar el punto.',
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _message = null;
    });
    final p = await (widget.locateMe ?? currentLocation)();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      setState(
        () => _message =
            'No se pudo obtener tu ubicación. Permite el acceso a la ubicación en el navegador o toca el mapa.',
      );
      return;
    }
    _pick(p, zoom: 18);
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: AppColors.darkText),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildMap() {
    final picked = _picked;
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: picked == null ? 15 : 17,
            minZoom: 3,
            maxZoom: 19,
            onTap: (_, p) => _pick(LatLng(p.latitude, p.longitude)),
          ),
          children: [
            TileLayer(
              key: ValueKey(_satelliteView),
              urlTemplate: _satelliteView ? _satellite : _street,
              userAgentPackageName: 'com.controlsalida.web',
              tileProvider: LocationPicker.tileProviderOverride,
            ),
            if (picked != null) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _toLl(picked),
                    radius: MapDefaults.premiseRadiusMeters,
                    useRadiusInMeter: true,
                    color: AppColors.primaryRed.withValues(alpha: 0.2),
                    borderColor: AppColors.primaryRed,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _toLl(picked),
                    width: 52,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primaryRed,
                      size: 52,
                    ),
                  ),
                ],
              ),
            ],
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  _satelliteView
                      ? '© Esri, Maxar, Earthstar Geographics'
                      : '© OpenStreetMap contributors',
                ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Column(
            children: [
              _roundButton(Icons.add_rounded, 'Acercar', () => _zoom(1)),
              const SizedBox(height: 8),
              _roundButton(Icons.remove_rounded, 'Alejar', () => _zoom(-1)),
              const SizedBox(height: 8),
              _roundButton(
                _satelliteView
                    ? Icons.map_outlined
                    : Icons.satellite_alt_rounded,
                _satelliteView ? 'Ver mapa de calles' : 'Ver satélite',
                () => setState(() => _satelliteView = !_satelliteView),
              ),
              if (picked != null) ...[
                const SizedBox(height: 8),
                _roundButton(
                  Icons.center_focus_strong_rounded,
                  'Volver al marcador',
                  () => _map.move(_toLl(picked), 18),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatus() {
    final picked = _picked;
    final color = picked != null ? Colors.green.shade700 : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            picked != null ? Icons.check_circle_rounded : Icons.touch_app_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              picked != null
                  ? 'Ubicación fijada (${picked.latitude.toStringAsFixed(5)}, '
                        '${picked.longitude.toStringAsFixed(5)}). Se aceptan '
                        'escaneos a ${MapDefaults.premiseRadiusMeters.toInt()} m o menos. '
                        'Toca otro punto para moverla.'
                  : 'Toca en el mapa el lugar donde está el predio.',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: 'Buscar un lugar o dirección',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          tooltip: 'Buscar',
                          onPressed: _runSearch,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Mi ubicación'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: const BorderSide(color: AppColors.primaryRed),
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (final r in _results)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      r.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _pick(r.position, zoom: 18),
                  ),
              ],
            ),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _message!,
              style: const TextStyle(color: AppColors.primaryRed, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(height: 320, child: _buildMap()),
        ),
        const SizedBox(height: 10),
        _buildStatus(),
      ],
    );
  }
}
