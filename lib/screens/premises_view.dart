import 'package:flutter/material.dart';

import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_popup.dart';
import '../widgets/filter_sidebar.dart';
import 'premise_form_dialog.dart';

/// Sección "Predios" del panel de administración: búsqueda, listado con sus
/// motivos permitidos y creación y edición de predios (nombre, mapa, responsable y motivos).
/// Estado de un filtro que distingue "tiene / no tiene".
enum _Presence { any, with_, without }

class PremisesView extends StatefulWidget {
  /// Se llama cuando el token de sesión ya no es válido (401).
  final VoidCallback onUnauthorized;

  const PremisesView({super.key, required this.onUnauthorized});

  @override
  State<PremisesView> createState() => PremisesViewState();
}

class PremisesViewState extends State<PremisesView> {
  // Paleta de colores unificada
  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;

  // Separación entre tarjetas
  static const double _gap = 12;

  final _searchController = TextEditingController();
  final PremiseService _premiseService = PremiseService();

  List<Reason> _allReasons = [];
  List<Premise> _prediosList = [];
  String _searchQuery = '';
  _Presence _managerFilter = _Presence.any;
  _Presence _locationFilter = _Presence.any;
  _Presence _reasonsFilter = _Presence.any;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Recarga la lista de predios y el catálogo de motivos. Público para que
  /// otras secciones (p. ej. "Inicio") puedan refrescar estos datos.
  Future<void> refresh() => _fetchData();

  /// Abre el formulario de creación de predios. Público para que la sección
  /// "Inicio" pueda ofrecerlo como acceso directo.
  Future<void> openCreateDialog() => _openCreatePremiseDialog();

  /// Sincroniza el catálogo de motivos con el sistema externo, muestra el
  /// resultado y refresca los datos. Público para que "Inicio" lo use.
  Future<void> syncReasons() => _syncReasons();

  int get premiseCount => _prediosList.length;

  List<Premise> get _filteredPredios {
    final query = _searchQuery.toLowerCase().trim();
    return _prediosList.where((p) {
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_managerFilter == _Presence.with_ && p.manager == null) return false;
      if (_managerFilter == _Presence.without && p.manager != null) {
        return false;
      }
      if (_locationFilter == _Presence.with_ && !p.hasLocation) return false;
      if (_locationFilter == _Presence.without && p.hasLocation) return false;
      if (_reasonsFilter == _Presence.with_ && p.reasonNames.isEmpty) {
        return false;
      }
      if (_reasonsFilter == _Presence.without && p.reasonNames.isNotEmpty) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _activeFilters =>
      [
        _managerFilter,
        _locationFilter,
        _reasonsFilter,
      ].where((f) => f != _Presence.any).length +
      (_searchQuery.trim().isEmpty ? 0 : 1);

  void _clearFilters() => setState(() {
    _managerFilter = _Presence.any;
    _locationFilter = _Presence.any;
    _reasonsFilter = _Presence.any;
    _searchQuery = '';
    _searchController.clear();
  });

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _premiseService.getPremisesWithReasons(),
        _premiseService.getAllReasons(),
      ]);
      if (!mounted) return;
      setState(() {
        _prediosList = results[0] as List<Premise>;
        _allReasons = results[1] as List<Reason>;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } catch (_) {
      _showSnackBar('No se pudieron cargar los predios', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    showAppPopup(
      context,
      message,
      kind: color == Colors.red ? PopupKind.error : PopupKind.success,
    );
  }

  Future<void> _openCreatePremiseDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const PremiseFormDialog(),
    );
    if (created == true) {
      _showSnackBar('Predio creado correctamente', Colors.green);
      _fetchData();
    }
  }

  Future<void> _syncReasons() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final message = await _premiseService.syncReasons();
      _showSnackBar(message, Colors.green);
      await _fetchData();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _editPremise(Premise premise) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => PremiseFormDialog(premise: premise),
    );
    if (updated == true) {
      _showSnackBar('Predio actualizado correctamente', Colors.green);
      await _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryRed));
    }
    return FilterSidebarLayout(
      wideBreakpoint: 1100,
      search: _buildSearchField(),
      activeCount: _activeFilters,
      onClear: _clearFilters,
      filters: [
        FilterGroup<_Presence>(
          title: 'Responsable',
          value: _managerFilter,
          options: const {
            _Presence.any: 'Todos',
            _Presence.with_: 'Con responsable',
            _Presence.without: 'Sin responsable',
          },
          onChanged: (v) => setState(() => _managerFilter = v),
        ),
        FilterGroup<_Presence>(
          title: 'Ubicación en el mapa',
          value: _locationFilter,
          options: const {
            _Presence.any: 'Todos',
            _Presence.with_: 'Con ubicación',
            _Presence.without: 'Sin ubicación',
          },
          onChanged: (v) => setState(() => _locationFilter = v),
        ),
        FilterGroup<_Presence>(
          title: 'Motivos de salida',
          value: _reasonsFilter,
          options: const {
            _Presence.any: 'Todos',
            _Presence.with_: 'Con motivos',
            _Presence.without: 'Sin motivos',
          },
          onChanged: (v) => setState(() => _reasonsFilter = v),
        ),
      ],
      content: _buildContent(),
    );
  }

  Widget _buildContent() {
    final predios = _filteredPredios;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Tres columnas como mínimo cuando hay espacio; menos en pantallas
        // angostas para que las tarjetas sigan siendo legibles.
        final columns = width >= 1500
            ? 4
            : width >= 720
            ? 3
            : width >= 480
            ? 2
            : 1;
        final padding = width >= Breakpoints.tablet ? 24.0 : 16.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${predios.length} de ${_prediosList.length} predios',
                      style: AppText.caption,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: darkText),
                    tooltip: 'Actualizar',
                    onPressed: _isLoading ? null : _fetchData,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(width: 200, child: _buildAddButton()),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: predios.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron predios con esos filtros.',
                          style: AppText.body.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        color: Colors.white,
                        backgroundColor: primaryRed,
                        child: _buildGrid(columns, predios),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: AppDimens.smallButtonHeight,
      child: ElevatedButton.icon(
        onPressed: _openCreatePremiseDialog,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Agregar predio'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Buscar predio...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
        prefixIcon: const Icon(Icons.search_rounded, color: darkText),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: const BorderSide(color: primaryRed, width: 1.5),
        ),
      ),
    );
  }

  // Cuadrícula de tarjetas: cada fila reparte el ancho en partes iguales.
  Widget _buildGrid(int columns, List<Premise> predios) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _gap),
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final predio in predios)
                SizedBox(width: cardWidth, child: _buildPremiseCard(predio)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiseCard(Premise predio) {
    final manager = predio.manager;
    // El color de la franja resume el estado sin tener que leer nada.
    final statusColor = !predio.hasLocation
        ? AppColors.danger
        : (manager == null || predio.reasonNames.isEmpty)
        ? AppColors.warning
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: statusColor, width: 6),
          top: const BorderSide(color: AppColors.line),
          right: const BorderSide(color: AppColors.line),
          bottom: const BorderSide(color: AppColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            predio.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.person_outline_rounded,
            manager == null
                ? 'Sin responsable'
                : 'Responsable: ${manager.name}',
            alert: manager == null ? AppColors.warning : null,
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.location_on_outlined,
            predio.hasLocation
                ? '${predio.latitude!.toStringAsFixed(5)}, ${predio.longitude!.toStringAsFixed(5)}'
                : 'Sin ubicación: los escaneos no serán aceptados',
            alert: predio.hasLocation ? null : AppColors.danger,
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.checklist_rounded,
            '${predio.reasonNames.length} de ${_allReasons.length} motivos permitidos',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _editPremise(predio),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(AppDimens.smallButtonHeight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? alert}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: alert ?? darkText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: alert == null ? FontWeight.w400 : FontWeight.w700,
              color: alert ?? darkText,
            ),
          ),
        ),
      ],
    );
  }
}
