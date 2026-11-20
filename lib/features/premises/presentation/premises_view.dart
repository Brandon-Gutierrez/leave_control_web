import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format/text_utils.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/admin_page.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/dialog_tone.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/master_detail.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../../users/models/managed_user.dart';
import '../data/premise_service.dart';
import '../models/premise.dart';
import 'premise_detail_pane.dart';
import 'premise_form_dialog.dart';

/// Qué predios muestra la lista.
/// [incomplete]: sin ubicación en el mapa o sin motivos habilitados.
enum PremiseTab { all, withoutManager, incomplete }

/// Sección "Predios": a la izquierda la lista (con búsqueda, pestañas por lo
/// que les falta y letras) y a la derecha el detalle del predio elegido, donde
/// se cambian su nombre, su ubicación en el mapa, su responsable y los motivos
/// de salida que ofrece.
class PremisesView extends StatefulWidget {
  const PremisesView({super.key});

  @override
  State<PremisesView> createState() => PremisesViewState();
}

class PremisesViewState extends State<PremisesView> {
  final _searchController = TextEditingController();

  /// Llave del detalle abierto: sirve para preguntarle si tiene cambios sin
  /// guardar. Cambia con cada predio elegido para que el borrador no pase de
  /// un predio a otro.
  var _detailKey = GlobalKey<PremiseDetailPaneState>();
  final PremiseService _service = PremiseService();
  final AdminDataStore _store = AdminDataStore.instance;

  PremiseTab _tab = PremiseTab.all;
  String _query = '';
  int? _selectedId;

  /// En pantallas angostas: se ve el detalle en lugar de la lista.
  bool _detailOpen = false;

  /// Se está cambiando el responsable del predio elegido.
  bool _assigning = false;

  List<Premise> get _premises => _store.premises;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    unawaited(_store.premisesData.load());
    // Los motivos del catálogo hacen falta para el detalle; se piden aparte,
    // sin hacer esperar a la lista.
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

  Future<void> _reload() => Future.wait([
    _store.premisesData.load(force: true),
    _store.reasonsData.load(force: true),
  ]);

  // -------------------------------------------------------------------------
  // Lista
  // -------------------------------------------------------------------------

  Premise? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final premise in _premises) {
      if (premise.id == id) return premise;
    }
    return null;
  }

  static bool _inTab(Premise p, PremiseTab tab) => switch (tab) {
    PremiseTab.all => true,
    PremiseTab.withoutManager => p.manager == null,
    PremiseTab.incomplete => !p.hasLocation || p.reasonNames.isEmpty,
  };

  int _count(PremiseTab tab) => _premises.where((p) => _inTab(p, tab)).length;

  /// Los de la pestaña y la búsqueda, ordenados por nombre sin mirar
  /// mayúsculas ni tildes.
  List<Premise> get _visiblePremises {
    final query = foldText(_query).trim();
    final list = _premises.where((p) {
      if (!_inTab(p, _tab)) return false;
      if (query.isEmpty) return true;
      return foldText(p.name).contains(query) ||
          foldText(p.manager?.name ?? '').contains(query);
    }).toList();
    list.sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));
    return list;
  }

  /// Línea bajo el nombre y si va resaltada: lo más grave que le falta.
  static (String, bool) subtitleOf(Premise p) {
    if (!p.hasLocation) return ('Sin ubicación en el mapa', true);
    final manager = p.manager;
    if (manager == null) return ('Sin responsable', true);
    return ('Responsable: ${manager.name}', false);
  }

  static String noteOf(Premise p) {
    final count = p.reasonNames.length;
    if (count == 0) return 'Sin motivos';
    return count == 1 ? '1 motivo' : '$count motivos';
  }

  /// Elige un predio; si el que estaba abierto tiene cambios sin guardar,
  /// pregunta antes de descartarlos.
  Future<void> _select(Premise premise) async {
    if (premise.id == _selectedId) {
      setState(() => _detailOpen = true);
      return;
    }
    if (!await _confirmDiscard() || !mounted) return;
    setState(() {
      _selectedId = premise.id;
      _detailOpen = true;
      _detailKey = GlobalKey<PremiseDetailPaneState>();
    });
    // Los responsables solo hacen falta al elegir un predio: se piden entonces.
    unawaited(_store.usersData.load());
  }

  Future<void> _backToList() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _detailOpen = false);
  }

  /// true si no había cambios sin guardar o si se aceptó descartarlos.
  Future<bool> _confirmDiscard() async {
    if (_detailKey.currentState?.hasUnsavedChanges != true) return true;
    return confirmDiscardChanges(
      context,
      subtitle: _selected?.name,
      description:
          'Cambió el nombre, la ubicación o los motivos y todavía no guardó.',
    );
  }

  // -------------------------------------------------------------------------
  // Acciones
  // -------------------------------------------------------------------------

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    showAppPopup(
      context,
      message,
      kind: color == AppColors.danger ? PopupKind.error : PopupKind.success,
    );
  }

  /// Vuelve a pedir lo que cambió con un predio: primero la lista de predios
  /// (el detalle la espera) y en segundo plano lo demás que ya estaba cargado.
  Future<void> _refreshAfterChange() async {
    final all = _store.refreshQuietly();
    await _store.premisesData.load();
    unawaited(all);
  }

  /// Abre el formulario de creación de predios. Público para que la sección
  /// "Inicio" pueda ofrecerlo como acceso directo.
  Future<void> openCreateDialog() async {
    final before = {for (final p in _premises) p.id};
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const PremiseFormDialog(),
    );
    if (created != true || !mounted) return;
    _showSnackBar('Predio creado correctamente', AppColors.success);
    await _store.premisesData.load(force: true);
    unawaited(_store.refreshQuietly());
    if (!mounted) return;
    // El predio nuevo queda elegido en el detalle.
    final fresh = _premises.where((p) => !before.contains(p.id));
    if (fresh.isEmpty) return;
    setState(() {
      _selectedId = fresh.first.id;
      _detailOpen = true;
      _detailKey = GlobalKey<PremiseDetailPaneState>();
      _tab = PremiseTab.all;
      _query = '';
      _searchController.clear();
    });
    unawaited(_store.usersData.load());
  }

  Future<bool> _save(Premise premise, PremiseChanges changes) async {
    try {
      await _service.updateDetails(
        premise.id,
        name: changes.name,
        latitude: changes.position?.latitude,
        longitude: changes.position?.longitude,
        reasonNames: changes.reasonNames,
      );
      await _refreshAfterChange();
      _showSnackBar('Predio actualizado correctamente', AppColors.success);
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _store.sessionExpired();
        return false;
      }
      _showSnackBar(e.message, AppColors.danger);
      return false;
    }
  }

  /// Pide confirmación y cambia al responsable (`userId` null lo quita): el
  /// anterior pierde su acceso y su sesión se cierra.
  Future<void> _assignManager(Premise premise, int? userId) async {
    if (_assigning) return;
    ManagedUser? chosen;
    if (userId != null) {
      for (final user in _store.users) {
        if (user.id == userId) chosen = user;
      }
    }
    final current = premise.manager;
    final notes = <String>[
      if (userId == null)
        'El predio quedará sin responsable y no tendrá quién muestre su QR.'
      else
        '${chosen?.name ?? 'La persona elegida'} será el responsable de '
            '${premise.name}.',
      if (current != null && current.userId != userId)
        '${current.name} dejará de ser responsable y su sesión se cerrará.',
      if (chosen?.premise != null && chosen!.premise!.id != premise.id)
        '${chosen.name} pasará de «${chosen.premise!.name}» a este predio.',
    ];
    final removing = userId == null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppModal(
        tone: removing ? DialogTone.danger : DialogTone.caution,
        icon: removing ? Icons.person_remove_rounded : Icons.badge_rounded,
        title: removing ? 'Quitar responsable' : 'Asignar responsable',
        subtitle: premise.name,
        maxWidth: 480,
        actions: [
          ModalButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(context, false),
          ),
          ModalButton(
            label: removing ? 'Quitar' : 'Asignar',
            primary: true,
            color: removing ? AppColors.danger : AppColors.warning,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < notes.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Text(notes[i], style: AppText.body),
            ],
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _assigning = true);
    try {
      await _service.assignManager(premise.id, userId);
      await _refreshAfterChange();
      _showSnackBar(
        removing
            ? '${premise.name} quedó sin responsable'
            : '${chosen?.name ?? 'El responsable'} ahora es responsable de '
                  '${premise.name}',
        AppColors.success,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _store.sessionExpired();
        return;
      }
      _showSnackBar(e.message, AppColors.danger);
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  // -------------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------------

  List<ManagedUser> get _managers {
    final list = _store.users.where((u) => u.managesPremise).toList();
    list.sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final data = _store.premisesData;
    final visible = _visiblePremises;
    final selected = _selected;
    final users = _store.usersData;
    final reasons = _store.reasonsData;

    return AdminPage(
      title: 'Predios',
      subtitle:
          'Elige un predio de la lista para ver y cambiar su ubicación, su '
          'responsable y sus motivos.',
      onRefresh: _reload,
      actions: [
        AdminButton.primary(
          label: '+ Nuevo predio',
          onPressed: openCreateDialog,
        ),
      ],
      child: MasterDetailLayout(
        showDetail: _detailOpen && selected != null,
        master: MasterList<Premise>(
          height: masterListHeight(context),
          searchHint: 'Buscar predio...',
          searchController: _searchController,
          onSearch: (value) => setState(() => _query = value),
          tabs: [
            ListTabSpec('Todos', _premises.length),
            ListTabSpec('Sin responsable', _count(PremiseTab.withoutManager)),
            ListTabSpec('Incompletos', _count(PremiseTab.incomplete)),
          ],
          tabIndex: _tab.index,
          onTab: (i) => setState(() => _tab = PremiseTab.values[i]),
          items: visible,
          groupOf: (p) => groupLetterOf(p.name),
          // Con la lista vacía, una recarga (p. ej. justo tras crear un
          // predio) no debe mostrar «sin resultados»: todavía no se sabe qué
          // hay.
          loading: data.isInitialLoad || (data.isLoading && _premises.isEmpty),
          error: data.hasFailed && !data.hasLoaded
              ? (data.error ?? 'No se pudieron cargar los predios')
              : null,
          onRetry: _reload,
          emptyText: _premises.isEmpty
              ? 'Aún no hay predios. Use «+ Nuevo predio» para crear el '
                    'primero.'
              : 'No se encontraron predios con esos filtros.',
          onTap: _select,
          rowBuilder: (context, p) {
            final (subtitle, alert) = subtitleOf(p);
            final problem = PremiseStatus.hasProblem(p);
            return MasterRowTile(
              leading: RowBadge(
                icon: Icons.place_outlined,
                background: problem
                    ? const Color(0xFFF6DADA)
                    : const Color(0xFFE4E4DF),
                foreground: problem
                    ? AppColors.danger
                    : const Color(0xFF555555),
              ),
              title: p.name,
              subtitle: subtitle,
              subtitleStyle: TextStyle(
                fontSize: 12,
                fontWeight: alert ? FontWeight.w800 : FontWeight.w500,
                color: alert ? AppColors.danger : const Color(0xFF777777),
              ),
              note: noteOf(p),
              noteColor: p.reasonNames.isEmpty
                  ? AppColors.warning
                  : AppColors.muted,
              selected: p.id == _selectedId,
            );
          },
        ),
        detailBuilder: (narrow) => selected == null
            ? const DetailPlaceholder(
                title: 'Elige un predio de la lista',
                hint: 'Aquí verás su ubicación, su responsable y sus motivos.',
              )
            : PremiseDetailPane(
                key: _detailKey,
                premise: selected,
                catalog: _store.reasons,
                reasonsLoading: reasons.isInitialLoad,
                reasonsError: reasons.hasFailed && !reasons.hasLoaded
                    ? reasons.error
                    : null,
                onRetryReasons: () => reasons.load(force: true),
                managers: _managers,
                managersLoading: users.isInitialLoad,
                managersError: users.hasFailed && !users.hasLoaded
                    ? users.error
                    : null,
                onRetryManagers: () => users.load(force: true),
                radiusMeters: _store.geofenceRadiusMeters,
                assigning: _assigning,
                onSave: (changes) => _save(selected, changes),
                onAssignManager: (userId) => _assignManager(selected, userId),
                onBack: narrow ? _backToList : null,
              ),
      ),
    );
  }
}
