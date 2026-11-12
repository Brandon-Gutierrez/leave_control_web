import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/filter_sidebar.dart';
import '../../../core/widgets/lazy_card_grid.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/skeleton.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../data/reason_catalog_service.dart';
import '../models/reason_catalog.dart';

enum _Status { all, active, retired }

/// Sección "Motivos de salida": el catálogo que viene de Comteco, el estado de
/// la última sincronización y el botón para sincronizar a mano. La sincronización
/// también corre sola de lunes a viernes a las 00:00 (hora de Bolivia).
class ReasonsView extends StatefulWidget {
  const ReasonsView({super.key});

  @override
  State<ReasonsView> createState() => ReasonsViewState();
}

class ReasonsViewState extends State<ReasonsView> {
  final AdminDataStore _store = AdminDataStore.instance;
  final ReasonCatalogService _service = ReasonCatalogService();
  final _searchController = TextEditingController();

  String _query = '';
  _Status _status = _Status.all;
  bool _syncing = false;

  StoreResource<ReasonCatalog> get _catalogData => _store.reasonCatalogData;
  ReasonCatalog get _catalog => _catalogData.value;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    unawaited(_catalogData.load());
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

  Future<void> _reload() => _catalogData.load(force: true);

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await _service.syncNow();
      if (!mounted) return;
      final detail = result.summary;
      showAppPopup(
        context,
        detail == null ? result.message : '${result.message} ($detail)',
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _store.sessionExpired();
        return;
      }
      if (mounted) showAppPopup(context, e.message, kind: PopupKind.error);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
    // Tanto si salió bien como si falló, el servidor guardó el resultado: se
    // vuelve a leer lo que ya estaba cargado (catálogo, resumen de Inicio...).
    unawaited(_store.refreshQuietly());
  }

  List<CatalogReason> get _filtered {
    final query = _query.toLowerCase().trim();
    return _catalog.reasons.where((r) {
      if (query.isNotEmpty &&
          !r.name.toLowerCase().contains(query) &&
          !r.code.toLowerCase().contains(query)) {
        return false;
      }
      return switch (_status) {
        _Status.all => true,
        _Status.active => r.active,
        _Status.retired => !r.active,
      };
    }).toList();
  }

  int get _activeFilters =>
      (_status == _Status.all ? 0 : 1) + (_query.trim().isEmpty ? 0 : 1);

  void _clearFilters() => setState(() {
    _status = _Status.all;
    _query = '';
    _searchController.clear();
  });

  /// Fecha y hora de Bolivia (UTC−4, sin horario de verano): "11/11/2026 00:00".
  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    final bolivia = date.toUtc().subtract(const Duration(hours: 4));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(bolivia.day)}/${two(bolivia.month)}/${bolivia.year} '
        '${two(bolivia.hour)}:${two(bolivia.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return FilterSidebarLayout(
      wideBreakpoint: 1100,
      search: _buildSearchField(),
      activeCount: _activeFilters,
      onClear: _clearFilters,
      filters: [
        FilterGroup<_Status>(
          title: 'Estado',
          value: _status,
          options: const {
            _Status.all: 'Todos',
            _Status.active: 'Activos',
            _Status.retired: 'Retirados por Comteco',
          },
          onChanged: (v) => setState(() => _status = v),
        ),
      ],
      content: _buildContent(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o código...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.darkText,
          size: AppDimens.iconSize,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = width >= Breakpoints.tablet ? 24.0 : 16.0;
        final columns = width >= 760 ? 2 : 1;
        final data = _catalogData;
        final reasons = _filtered;

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SyncCard(
                loading: data.isInitialLoad,
                failedToLoad: data.hasFailed && !data.hasLoaded,
                sync: _catalog.sync,
                syncing: _syncing,
                onSync: _syncNow,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: data.isInitialLoad
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SkeletonPulse(
                              child: SkeletonBox(width: 150, height: 14),
                            ),
                          )
                        : Text(
                            '${reasons.length} de ${_catalog.reasons.length} motivos',
                            style: AppText.caption,
                          ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.darkText,
                    ),
                    tooltip: 'Actualizar',
                    onPressed: data.isLoading ? null : _reload,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(columns, reasons)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(int columns, List<CatalogReason> reasons) {
    final data = _catalogData;
    if (data.isInitialLoad) {
      return SkeletonPulse(
        child: LazyCardGrid<int>(
          items: List.generate(columns * 3, (i) => i),
          columns: columns,
          itemBuilder: (context, _) => const _SkeletonReasonTile(),
        ),
      );
    }
    if (data.hasFailed && !data.hasLoaded) {
      return Align(
        alignment: Alignment.topCenter,
        child: LoadErrorNotice(
          message: data.error ?? 'No se pudo cargar el catálogo de motivos',
          onRetry: _reload,
        ),
      );
    }
    if (reasons.isEmpty) {
      return Center(
        child: Text(
          _catalog.reasons.isEmpty
              ? 'Todavía no hay motivos. Use «Sincronizar ahora» para traerlos de Comteco.'
              : 'No se encontraron motivos con esos filtros.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: Colors.grey.shade600),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      color: Colors.white,
      backgroundColor: AppColors.primaryRed,
      child: LazyCardGrid<CatalogReason>(
        key: ValueKey('$_query|${_status.index}'),
        items: reasons,
        columns: columns,
        itemBuilder: (context, reason) => _ReasonTile(reason: reason),
      ),
    );
  }
}

/// Estado de la última sincronización y el botón "Sincronizar ahora".
class _SyncCard extends StatelessWidget {
  final bool loading;
  final bool failedToLoad;
  final ReasonSyncStatus? sync;
  final bool syncing;
  final VoidCallback onSync;

  const _SyncCard({
    required this.loading,
    required this.failedToLoad,
    required this.sync,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final status = sync;
    final color = status == null
        ? AppColors.info
        : status.failed
        ? AppColors.danger
        : AppColors.success;

    final lines = <String>[];
    if (loading) {
      // Se muestra el esqueleto.
    } else if (failedToLoad) {
      lines.add('No se pudo leer el estado de la última sincronización.');
    } else if (status == null) {
      lines.add('Todavía no se ha sincronizado.');
    } else if (status.failed) {
      lines.add(
        'La última sincronización falló el '
        '${ReasonsViewState.formatDate(status.at)} (${status.sourceLabel}).',
      );
      if (status.error != null) lines.add(status.error!);
      if (status.lastSuccessAt != null) {
        lines.add(
          'Última correcta: ${ReasonsViewState.formatDate(status.lastSuccessAt)}. '
          'Se conserva el catálogo de esa fecha.',
        );
      }
    } else {
      lines.add(
        'Última sincronización: ${ReasonsViewState.formatDate(status.at)} '
        '(${status.sourceLabel}).',
      );
      lines.add(status.changesSummary ?? 'Sin cambios.');
    }

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sincronización con Comteco', style: AppText.cardTitle),
        const SizedBox(height: 6),
        if (loading)
          const SkeletonPulse(child: SkeletonBox(width: 260, height: 14))
        else
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: AppText.body),
            ),
        const SizedBox(height: 4),
        Text(
          'Se sincroniza sola de lunes a viernes a las 00:00 (hora de Bolivia).',
          style: AppText.caption,
        ),
      ],
    );

    final button = FilledButton.icon(
      onPressed: syncing ? null : onSync,
      icon: syncing
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.sync_rounded, size: 22),
      label: Text(syncing ? 'Sincronizando...' : 'Sincronizar ahora'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        minimumSize: const Size(190, AppDimens.smallButtonHeight),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: color, width: 6),
          top: const BorderSide(color: AppColors.line),
          right: const BorderSide(color: AppColors.line),
          bottom: const BorderSide(color: AppColors.line),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 640
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 12), button],
              ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final CatalogReason reason;

  const _ReasonTile({required this.reason});

  @override
  Widget build(BuildContext context) {
    final color = reason.active ? AppColors.success : AppColors.warning;
    final uses = reason.premisesCount == 1
        ? 'Habilitado en 1 predio'
        : 'Habilitado en ${reason.premisesCount} predios';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: reason.active ? Colors.white : AppColors.infoBg,
        border: Border(
          left: BorderSide(color: color, width: 6),
          top: const BorderSide(color: AppColors.line),
          right: const BorderSide(color: AppColors.line),
          bottom: const BorderSide(color: AppColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  reason.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(
                    color: reason.active ? null : AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Badge(
                label: reason.active ? 'Activo' : 'Retirado por Comteco',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Código: ${reason.code}', style: AppText.caption),
          const SizedBox(height: 2),
          Text(
            reason.active
                ? uses
                : 'Ya no se ofrece, pero se conserva en el historial',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Hueco con la forma de un motivo mientras llega el catálogo.
class _SkeletonReasonTile extends StatelessWidget {
  const _SkeletonReasonTile();

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
          SkeletonBox(width: 180, height: 18),
          SizedBox(height: 10),
          SkeletonBox(width: 100, height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 150, height: 12),
        ],
      ),
    );
  }
}
