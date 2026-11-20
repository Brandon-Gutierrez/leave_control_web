import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format/text_utils.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/admin_page.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/master_detail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../../premises/data/premise_service.dart';
import '../../premises/models/premise.dart';
import '../models/reason_catalog.dart';
import 'reason_detail_pane.dart';
import 'reason_sync_action.dart';

/// Qué motivos muestra la lista.
enum ReasonTab { all, active, retired }

/// Sección "Motivos de salida": el catálogo que viene de Comteco, el estado de
/// la última sincronización y, a la derecha de la lista, el detalle del motivo
/// elegido: en qué predios se ofrece, su límite por persona y su estado. La
/// sincronización también corre sola de lunes a viernes a las 00:00 (hora de
/// Bolivia), con reintentos a las 00:15 y 00:30.
class ReasonsView extends StatefulWidget {
  /// Lleva a Ajustes (donde se cambia el límite de salidas).
  final VoidCallback? onOpenSettings;

  const ReasonsView({super.key, this.onOpenSettings});

  @override
  State<ReasonsView> createState() => ReasonsViewState();
}

class ReasonsViewState extends State<ReasonsView> {
  final AdminDataStore _store = AdminDataStore.instance;
  final PremiseService _premiseService = PremiseService();
  final _searchController = TextEditingController();

  /// Llave del detalle abierto (para preguntarle si tiene cambios sin
  /// guardar); cambia con cada motivo elegido para que el borrador no pase de
  /// uno a otro.
  var _detailKey = GlobalKey<ReasonDetailPaneState>();

  String _query = '';
  ReasonTab _tab = ReasonTab.all;
  int? _selectedId;

  /// En pantallas angostas: se ve el detalle en lugar de la lista.
  bool _detailOpen = false;
  bool _syncing = false;

  StoreResource<ReasonCatalog> get _catalogData => _store.reasonCatalogData;
  ReasonCatalog get _catalog => _catalogData.value;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    unawaited(_catalogData.load());
    // Los predios (en cuáles se ofrece cada motivo) y el límite de salidas
    // se piden aparte, sin hacer esperar a la lista.
    unawaited(_store.premisesData.load());
    unawaited(_store.leaveLimitsData.load());
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

  Future<void> _reload() => Future.wait([
    _catalogData.load(force: true),
    _store.premisesData.load(force: true),
  ]);

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await runReasonSync(context);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // -------------------------------------------------------------------------
  // Lista
  // -------------------------------------------------------------------------

  CatalogReason? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final reason in _catalog.reasons) {
      if (reason.id == id) return reason;
    }
    return null;
  }

  static bool _inTab(CatalogReason r, ReasonTab tab) => switch (tab) {
    ReasonTab.all => true,
    ReasonTab.active => r.active,
    ReasonTab.retired => !r.active,
  };

  int _count(ReasonTab tab) =>
      _catalog.reasons.where((r) => _inTab(r, tab)).length;

  /// Los de la pestaña y la búsqueda (nombre o código), ordenados por nombre
  /// sin mirar mayúsculas ni tildes.
  List<CatalogReason> get _visibleReasons {
    final query = foldText(_query).trim();
    final list = _catalog.reasons.where((r) {
      if (!_inTab(r, _tab)) return false;
      if (query.isEmpty) return true;
      return foldText(r.name).contains(query) ||
          foldText(r.code).contains(query);
    }).toList();
    list.sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));
    return list;
  }

  /// Línea bajo el nombre: el código y en cuántos predios se ofrece.
  String subtitleOf(CatalogReason r) {
    if (!r.active) return '${r.code} · ya no se ofrece';
    final premises = _store.premisesData;
    final total = premises.value.length;
    if (!premises.hasLoaded || total == 0) {
      return '${r.code} · ${r.premisesCount} '
          '${r.premisesCount == 1 ? 'predio' : 'predios'}';
    }
    return '${r.code} · ${r.premisesCount} de $total '
        '${total == 1 ? 'predio' : 'predios'}';
  }

  /// Elige un motivo; si el que estaba abierto tiene cambios sin guardar,
  /// pregunta antes de descartarlos.
  Future<void> _select(CatalogReason reason) async {
    if (reason.id == _selectedId) {
      setState(() => _detailOpen = true);
      return;
    }
    if (!await _confirmDiscard() || !mounted) return;
    setState(() {
      _selectedId = reason.id;
      _detailOpen = true;
      _detailKey = GlobalKey<ReasonDetailPaneState>();
    });
  }

  Future<void> _backToList() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _detailOpen = false);
  }

  Future<bool> _confirmDiscard() async {
    if (_detailKey.currentState?.hasUnsavedChanges != true) return true;
    return confirmDiscardChanges(
      context,
      subtitle: _selected?.name,
      description:
          'Cambió en qué predios se ofrece este motivo y todavía no guardó.',
    );
  }

  // -------------------------------------------------------------------------
  // Guardar
  // -------------------------------------------------------------------------

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    showAppPopup(
      context,
      message,
      kind: error ? PopupKind.error : PopupKind.success,
    );
  }

  /// Deja el motivo ofrecido solo en [wanted]: cambia únicamente los predios
  /// que difieren, conservando los demás motivos de cada uno. Devuelve si todo
  /// se guardó.
  Future<bool> _save(CatalogReason reason, Set<int> wanted) async {
    final changes = <Premise, List<String>>{};
    for (final premise in _store.premises) {
      final names = [for (final r in premise.reasonNames) r.name];
      final has = names.contains(reason.name);
      final want = wanted.contains(premise.id);
      if (has == want) continue;
      changes[premise] = want
          ? [...names, reason.name]
          : [
              for (final name in names)
                if (name != reason.name) name,
            ];
    }
    if (changes.isEmpty) return true;

    final failures = <(Premise, ApiException)>[];
    await Future.wait([
      for (final entry in changes.entries)
        () async {
          try {
            await _premiseService.setReasons(entry.key.id, entry.value);
          } on ApiException catch (e) {
            failures.add((entry.key, e));
          }
        }(),
    ]);

    // Se vuelve a leer lo que cambió: primero lo que este detalle muestra
    // (predios y catálogo) y en segundo plano lo demás.
    final all = _store.refreshQuietly();
    await Future.wait([_store.premisesData.load(), _catalogData.load()]);
    unawaited(all);

    if (failures.any((f) => f.$2.isUnauthorized)) {
      _store.sessionExpired();
      return false;
    }
    if (failures.isNotEmpty) {
      final names = failures.map((f) => f.$1.name).join(', ');
      _showMessage(
        'No se pudo guardar en $names: ${failures.first.$2.message}',
        error: true,
      );
      return false;
    }
    final n = changes.length;
    _showMessage(
      '${reason.name} se actualizó en $n ${n == 1 ? 'predio' : 'predios'}',
    );
    return true;
  }

  // -------------------------------------------------------------------------
  // Fecha y pantalla
  // -------------------------------------------------------------------------

  /// Fecha y hora de Bolivia (UTC−4, sin horario de verano): "11/11/2026 00:00".
  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    final bolivia = date.toUtc().subtract(const Duration(hours: 4));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(bolivia.day)}/${two(bolivia.month)}/${bolivia.year} '
        '${two(bolivia.hour)}:${two(bolivia.minute)}';
  }

  String? _limitTextFor(CatalogReason reason) {
    final data = _store.leaveLimitsData;
    final limits = data.value;
    if (limits == null) return data.hasFailed ? '—' : null;
    return limits.reasonLimit.describeCap(limits.reasonLimit.capFor(reason.id));
  }

  @override
  Widget build(BuildContext context) {
    final data = _catalogData;
    final visible = _visibleReasons;
    final selected = _selected;
    final premises = _store.premisesData;

    return AdminPage(
      title: 'Motivos de salida',
      subtitle:
          'El catálogo viene de Comteco. Elige un motivo de la lista para ver '
          'en qué predios se ofrece.',
      onRefresh: _reload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SyncBanner(
            loading: data.isInitialLoad,
            failedToLoad: data.hasFailed && !data.hasLoaded,
            sync: _catalog.sync,
            syncing: _syncing,
            onSync: _syncNow,
          ),
          const SizedBox(height: 22),
          MasterDetailLayout(
            showDetail: _detailOpen && selected != null,
            master: MasterList<CatalogReason>(
              // El aviso de sincronización ocupa parte de la pantalla.
              height: math.max(480, masterListHeight(context) - 110),
              searchHint: 'Buscar por nombre o código...',
              searchController: _searchController,
              onSearch: (value) => setState(() => _query = value),
              tabs: [
                ListTabSpec('Todos', _catalog.reasons.length),
                ListTabSpec('Activos', _count(ReasonTab.active)),
                ListTabSpec('Retirados', _count(ReasonTab.retired)),
              ],
              tabIndex: _tab.index,
              onTab: (i) => setState(() => _tab = ReasonTab.values[i]),
              items: visible,
              groupOf: (r) => groupLetterOf(r.name),
              loading: data.isInitialLoad,
              error: data.hasFailed && !data.hasLoaded
                  ? (data.error ?? 'No se pudo cargar el catálogo de motivos')
                  : null,
              onRetry: _reload,
              emptyText: _catalog.reasons.isEmpty
                  ? 'Todavía no hay motivos. Use «Sincronizar ahora» para '
                        'traerlos de Comteco.'
                  : 'No se encontraron motivos con esos filtros.',
              onTap: _select,
              rowBuilder: (context, r) => MasterRowTile(
                title: r.name,
                titleStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: r.active ? null : const Color(0xFF999999),
                  decoration: r.active ? null : TextDecoration.lineThrough,
                ),
                subtitle: subtitleOf(r),
                note: r.active ? 'Activo' : 'Retirado',
                noteColor: r.active ? AppColors.success : AppColors.warning,
                selected: r.id == _selectedId,
              ),
            ),
            detailBuilder: (narrow) => selected == null
                ? const DetailPlaceholder(
                    title: 'Elige un motivo de la lista',
                    hint: 'Aquí verás en qué predios se ofrece y su estado.',
                  )
                : ReasonDetailPane(
                    key: _detailKey,
                    reason: selected,
                    premises: _store.premises,
                    premisesLoading: premises.isInitialLoad,
                    premisesError: premises.hasFailed && !premises.hasLoaded
                        ? premises.error
                        : null,
                    onRetryPremises: () => premises.load(force: true),
                    limitText: _limitTextFor(selected),
                    onOpenSettings: widget.onOpenSettings ?? () {},
                    onSave: (ids) => _save(selected, ids),
                    onBack: narrow ? _backToList : null,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Estado de la última sincronización y el botón «Sincronizar ahora». Si la
/// última falló, el aviso va en ámbar.
class _SyncBanner extends StatelessWidget {
  final bool loading;
  final bool failedToLoad;
  final ReasonSyncStatus? sync;
  final bool syncing;
  final VoidCallback onSync;

  const _SyncBanner({
    required this.loading,
    required this.failedToLoad,
    required this.sync,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final status = sync;
    final failed = status?.failed ?? false;

    final title = failed
        ? 'La última sincronización con Comteco falló'
        : 'Sincronización con Comteco';
    final lines = <String>[];
    if (loading) {
      // Se muestra el esqueleto.
    } else if (failedToLoad) {
      lines.add('No se pudo leer el estado de la última sincronización.');
    } else if (status == null) {
      lines.add('Todavía no se ha sincronizado.');
    } else if (status.failed) {
      lines.add(
        'Fue el '
        '${ReasonsViewState.formatDate(status.at)} (${status.sourceLabel}).',
      );
      if (status.error != null) lines.add(status.error!);
      lines.add(
        status.lastSuccessAt != null
            ? 'Última correcta: '
                  '${ReasonsViewState.formatDate(status.lastSuccessAt)}. '
                  'Mientras tanto se usan los motivos ya guardados.'
            : 'Mientras tanto se usan los motivos ya guardados.',
      );
    } else {
      lines.add(
        'Última sincronización: ${ReasonsViewState.formatDate(status.at)} '
        '(${status.sourceLabel}).',
      );
      lines.add(status.changesSummary ?? 'Sin cambios.');
    }

    final titleColor = failed ? const Color(0xFF7A531A) : AppColors.darkText;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 2),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SkeletonPulse(child: SkeletonBox(width: 260, height: 14)),
          )
        else
          for (final line in lines)
            Text(
              line,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
            ),
        const SizedBox(height: 4),
        const Text(
          'Se sincroniza sola de lunes a viernes a las 00:00 (hora de '
          'Bolivia); si falla, se reintenta a las 00:15 y 00:30.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
    final button = AdminButton.dark(
      label: syncing ? 'Sincronizando...' : 'Sincronizar ahora',
      height: 44,
      onPressed: syncing ? null : onSync,
    );
    final icon = Icon(
      failed ? Icons.sync_problem_rounded : Icons.sync_rounded,
      size: 26,
      color: failed ? AppColors.warning : AppColors.muted,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFFBF6EA) : AppColors.lightBg,
        border: Border.all(
          color: failed ? const Color(0xFFE3D5B6) : AppColors.panelLine,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 640
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 16),
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: info),
                    ],
                  ),
                  const SizedBox(height: 12),
                  button,
                ],
              ),
      ),
    );
  }
}
