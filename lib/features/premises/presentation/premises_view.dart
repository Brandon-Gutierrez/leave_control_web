import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/filter_sidebar.dart';
import '../../../core/widgets/lazy_card_grid.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../models/premise.dart';
import '../models/reason.dart';
import 'premise_form_dialog.dart';

/// Sección "Predios" del panel de administración: búsqueda, listado con sus
/// motivos permitidos y creación y edición de predios (nombre, mapa, responsable y motivos).
/// Estado de un filtro que distingue "tiene / no tiene".
enum _Presence { any, present, absent }

class PremisesView extends StatefulWidget {
  const PremisesView({super.key});

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
  final AdminDataStore _store = AdminDataStore.instance;

  String _searchQuery = '';
  int _page = 0;
  static const _pageSize = 15;
  _Presence _managerFilter = _Presence.any;
  _Presence _locationFilter = _Presence.any;
  _Presence _reasonsFilter = _Presence.any;

  List<Premise> get _premises => _store.premises;

  /// Total de motivos del catálogo (para "N de M motivos permitidos").
  List<Reason> get _allReasons => _store.reasons;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    unawaited(_store.premisesData.load());
    // El catálogo solo sirve para el total de cada tarjeta: se pide aparte, sin
    // hacer esperar a la lista.
    unawaited(_store.reasonsData.load());
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  /// Abre el formulario de creación de predios. Público para que la sección
  /// "Inicio" pueda ofrecerlo como acceso directo.
  Future<void> openCreateDialog() => _openCreatePremiseDialog();

  Future<void> _reload() => Future.wait([
    _store.premisesData.load(force: true),
    _store.reasonsData.load(force: true),
  ]);

  List<Premise> get _filteredPremises {
    final query = _searchQuery.toLowerCase().trim();
    return _premises.where((p) {
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_managerFilter == _Presence.present && p.manager == null) {
        return false;
      }
      if (_managerFilter == _Presence.absent && p.manager != null) {
        return false;
      }
      if (_locationFilter == _Presence.present && !p.hasLocation) return false;
      if (_locationFilter == _Presence.absent && p.hasLocation) return false;
      if (_reasonsFilter == _Presence.present && p.reasonNames.isEmpty) {
        return false;
      }
      if (_reasonsFilter == _Presence.absent && p.reasonNames.isNotEmpty) {
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
    _page = 0;
    _searchController.clear();
  });

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    showAppPopup(
      context,
      message,
      kind: color == AppColors.danger ? PopupKind.error : PopupKind.success,
    );
  }

  Future<void> _openCreatePremiseDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const PremiseFormDialog(),
    );
    if (created == true) {
      _showSnackBar('Predio creado correctamente', AppColors.success);
      unawaited(_store.refreshQuietly());
    }
  }

  Future<void> _editPremise(Premise premise) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => PremiseFormDialog(premise: premise),
    );
    if (updated == true) {
      _showSnackBar('Predio actualizado correctamente', AppColors.success);
      unawaited(_store.refreshQuietly());
    }
  }

  /// Cambia de lista (filtro, búsqueda o página): la lista vuelve al inicio.
  Key get _listKey => ValueKey(
    '$_page|$_searchQuery|${_managerFilter.index}|${_locationFilter.index}|${_reasonsFilter.index}',
  );

  @override
  Widget build(BuildContext context) {
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
            _Presence.present: 'Con responsable',
            _Presence.absent: 'Sin responsable',
          },
          onChanged: (v) => setState(() {
            _managerFilter = v;
            _page = 0;
          }),
        ),
        FilterGroup<_Presence>(
          title: 'Ubicación en el mapa',
          value: _locationFilter,
          options: const {
            _Presence.any: 'Todos',
            _Presence.present: 'Con ubicación',
            _Presence.absent: 'Sin ubicación',
          },
          onChanged: (v) => setState(() {
            _locationFilter = v;
            _page = 0;
          }),
        ),
        FilterGroup<_Presence>(
          title: 'Motivos de salida',
          value: _reasonsFilter,
          options: const {
            _Presence.any: 'Todos',
            _Presence.present: 'Con motivos',
            _Presence.absent: 'Sin motivos',
          },
          onChanged: (v) => setState(() {
            _reasonsFilter = v;
            _page = 0;
          }),
        ),
      ],
      content: _buildContent(),
    );
  }

  Widget _buildContent() {
    final data = _store.premisesData;
    final visiblePremises = _filteredPremises;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Las tarjetas de predio contienen varias líneas descriptivas; se
        // mantienen cerca de 320 px y se agregan columnas según el espacio.
        const minCardWidth = 320.0;
        final columns = ((width + _gap) / (minCardWidth + _gap))
            .floor()
            .clamp(1, 4)
            .toInt();
        final padding = width >= Breakpoints.tablet ? 24.0 : 16.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: data.isInitialLoad
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SkeletonPulse(
                              child: SkeletonBox(width: 120, height: 14),
                            ),
                          )
                        : Text(
                            '${visiblePremises.length} de ${_premises.length} predios',
                            style: AppText.caption,
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: darkText),
                    tooltip: 'Actualizar',
                    onPressed: data.isLoading ? null : _reload,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(width: 200, child: _buildAddButton()),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(columns, visiblePremises)),
              PaginationBar(
                page: _page,
                pageSize: _pageSize,
                total: visiblePremises.length,
                onChanged: (p) => setState(() => _page = p),
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
      onChanged: (value) => setState(() {
        _searchQuery = value;
        _page = 0;
      }),
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

  /// Lo que hay bajo el encabezado: esqueletos mientras llegan los predios, un
  /// aviso con "Reintentar" si no se pudieron cargar, o la lista.
  Widget _buildBody(int columns, List<Premise> visiblePremises) {
    final data = _store.premisesData;
    // Con la lista vacía, una recarga (p. ej. justo tras crear un predio) no
    // debe mostrar "sin resultados": todavía no se sabe qué hay.
    if (data.isInitialLoad || (data.isLoading && _premises.isEmpty)) {
      return SkeletonPulse(
        child: LazyCardGrid<int>(
          items: List.generate(columns * 3, (i) => i),
          columns: columns,
          gap: _gap,
          itemBuilder: (context, _) => const _SkeletonPremiseCard(),
        ),
      );
    }
    if (data.hasFailed && !data.hasLoaded) {
      return Align(
        alignment: Alignment.topCenter,
        child: LoadErrorNotice(
          message: data.error ?? 'No se pudieron cargar los predios',
          onRetry: _reload,
        ),
      );
    }
    if (visiblePremises.isEmpty) {
      return Center(
        child: Text(
          _premises.isEmpty
              ? 'Aún no hay predios. Use «Agregar predio» para crear el primero.'
              : 'No se encontraron predios con esos filtros.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: Colors.grey.shade600),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      color: Colors.white,
      backgroundColor: primaryRed,
      // Las tarjetas se construyen por filas, solo cuando se acercan a la pantalla.
      child: LazyCardGrid<Premise>(
        key: _listKey,
        items: pageSlice(visiblePremises, _page, _pageSize),
        columns: columns,
        gap: _gap,
        itemBuilder: (context, premise) => _buildPremiseCard(premise),
      ),
    );
  }

  Widget _buildPremiseCard(Premise premise) {
    final manager = premise.manager;
    // El color de la franja resume el estado sin tener que leer nada.
    final statusColor = !premise.hasLocation
        ? AppColors.danger
        : (manager == null || premise.reasonNames.isEmpty)
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
            premise.name,
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
            premise.hasLocation
                ? '${premise.latitude!.toStringAsFixed(5)}, ${premise.longitude!.toStringAsFixed(5)}'
                : 'Sin ubicación: los escaneos no serán aceptados',
            alert: premise.hasLocation ? null : AppColors.danger,
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.checklist_rounded,
            _store.reasonsData.hasLoaded
                ? '${premise.reasonNames.length} de ${_allReasons.length} motivos permitidos'
                : '${premise.reasonNames.length} motivos permitidos',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _editPremise(premise),
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

/// Hueco con la forma de una tarjeta de predio mientras llegan los datos.
class _SkeletonPremiseCard extends StatelessWidget {
  const _SkeletonPremiseCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: AppColors.line, width: 6),
          top: BorderSide(color: AppColors.line),
          right: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 160, height: 20),
          SizedBox(height: 14),
          SkeletonBox(height: 14),
          SizedBox(height: 10),
          SkeletonBox(height: 14),
          SizedBox(height: 10),
          SkeletonBox(width: 120, height: 14),
          SizedBox(height: 18),
          SkeletonBox(height: AppDimens.smallButtonHeight, radius: 6),
        ],
      ),
    );
  }
}
