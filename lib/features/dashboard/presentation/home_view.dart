import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format/date_text.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/admin_page.dart';
import '../../auth/models/auth_user.dart';
import '../../reasons/presentation/reason_sync_action.dart';
import '../models/admin_summary.dart';
import '../state/admin_data_store.dart';
import 'home_parts.dart';

/// Sección "Inicio": un saludo, las cifras del sistema, una vista rápida de los
/// predios y, a un lado, lo que falta resolver y las reglas vigentes. Cada
/// pendiente lleva un botón directo para resolverlo.
class HomeView extends StatefulWidget {
  final AuthUser? user;
  final VoidCallback onAddPremise;
  final VoidCallback onOpenUsers;
  final VoidCallback? onOpenPremises;

  /// Abre Predios con ese predio elegido (el de la vista rápida).
  final ValueChanged<int>? onOpenPremise;

  /// Lleva a la sección "Motivos de salida" (p. ej. si falló la sincronización).
  final VoidCallback? onOpenReasons;

  /// Acceso directo para crear la cuenta de un responsable de predio.
  final VoidCallback? onAddManager;

  /// Acceso directo para buscar un teléfono por su código.
  final VoidCallback? onSearchDevice;

  /// Lleva a «Ajustes» (editar las reglas vigentes).
  final VoidCallback? onOpenSettings;

  /// Reloj de la pantalla (pruebas): fecha y saludo.
  final DateTime Function()? clock;

  const HomeView({
    super.key,
    required this.user,
    required this.onAddPremise,
    required this.onOpenUsers,
    this.onOpenPremises,
    this.onOpenPremise,
    this.onOpenReasons,
    this.onAddManager,
    this.onSearchDevice,
    this.onOpenSettings,
    this.clock,
  });

  @override
  State<HomeView> createState() => HomeViewState();
}

enum _Level { urgent, pending, info }

class _Issue {
  final _Level level;
  final int count;
  final String title;
  final String help;
  final String action;
  final VoidCallback onTap;

  /// Si el título empieza con la cantidad ("2 · Predios sin ubicación").
  final bool counted;

  const _Issue(
    this.level,
    this.count,
    this.title,
    this.help,
    this.action,
    this.onTap, {
    this.counted = true,
  });
}

class HomeViewState extends State<HomeView> {
  final AdminDataStore _store = AdminDataStore.instance;
  bool _syncing = false;

  StoreResource<AdminSummary?> get _summary => _store.summaryData;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    // Inicio pide los contadores, los predios (para la vista rápida y la
    // distancia) y las dos reglas que muestra; no las listas de usuarios.
    unawaited(_load());
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool force = false}) => Future.wait([
    _summary.load(force: force),
    _store.premisesData.load(force: force),
    _store.qrSettingsData.load(force: force),
    _store.leaveLimitsData.load(force: force),
  ]);

  Future<void> _reload() => _load(force: true);

  Future<void> _syncReasons() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await runReasonSync(context);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _openPremises() => (widget.onOpenPremises ?? widget.onAddPremise).call();

  List<_Issue> get _issues {
    final summary = _summary.value;
    if (summary == null) return const [];
    final noLocation = summary.premisesWithoutLocation;
    final noManager = summary.premisesWithoutManager;
    final noReasons = summary.premisesWithoutReasons;
    final managersWithoutPremise = summary.managersWithoutPremise;
    final employeesUnbound = summary.employeesWithoutApp;

    return [
      // Sin predios no hay nada que revisar: lo primero es crear el primero.
      if (summary.premises == 0)
        _Issue(
          _Level.urgent,
          0,
          'Aún no hay predios registrados',
          'Nadie puede registrar salidas hasta que agregue el primer predio.',
          'Agregar predio',
          widget.onAddPremise,
          counted: false,
        ),
      if (noLocation > 0)
        _Issue(
          _Level.urgent,
          noLocation,
          noLocation == 1
              ? 'Predio sin ubicación en el mapa'
              : 'Predios sin ubicación en el mapa',
          'Nadie puede registrar salidas ahí hasta que se marque su ubicación.',
          'Marcar ubicación',
          _openPremises,
        ),
      if (managersWithoutPremise > 0)
        _Issue(
          _Level.urgent,
          managersWithoutPremise,
          managersWithoutPremise == 1
              ? 'Responsable sin predio asignado'
              : 'Responsables sin predio asignado',
          'No pueden iniciar sesión hasta que se les asigne un predio.',
          'Asignar predio',
          widget.onOpenUsers,
        ),
      if (noReasons > 0)
        _Issue(
          _Level.pending,
          noReasons,
          noReasons == 1
              ? 'Predio sin motivos de salida'
              : 'Predios sin motivos de salida',
          'Los empleados no tendrán opciones para elegir al salir.',
          'Elegir motivos',
          _openPremises,
        ),
      if (noManager > 0)
        _Issue(
          _Level.pending,
          noManager,
          noManager == 1 ? 'Predio sin responsable' : 'Predios sin responsable',
          'Nadie podrá mostrar el código QR de ese predio.',
          'Asignar responsable',
          _openPremises,
        ),
      if (employeesUnbound > 0)
        _Issue(
          _Level.info,
          employeesUnbound,
          employeesUnbound == 1
              ? 'Empleado que aún no usa la app'
              : 'Empleados que aún no usan la app',
          'Su teléfono se vincula solo la primera vez que inician sesión.',
          'Ver usuarios',
          widget.onOpenUsers,
        ),
      if (summary.reasonsSync?.failed == true)
        _Issue(
          _Level.pending,
          1,
          'No se pudieron sincronizar los motivos con Comteco',
          'Se conserva el catálogo anterior. '
              '${_sentence(summary.reasonsSync!.error ?? 'Reintente la sincronización')} '
              'Se reintenta solo en el próximo horario programado.',
          'Ver motivos',
          widget.onOpenReasons ?? () {},
          counted: false,
        ),
    ];
  }

  /// El texto con un punto final (sin duplicarlo si ya lo trae).
  static String _sentence(String text) {
    final trimmed = text.trim();
    return RegExp(r'[.!?]$').hasMatch(trimmed) ? trimmed : '$trimmed.';
  }

  /// Cada pendiente ya va numerado (1, 2, 3...): la cantidad solo se escribe
  /// cuando es más de una («3 predios sin ubicación en el mapa»).
  static String _titleOf(_Issue issue) {
    if (!issue.counted || issue.count <= 1) return issue.title;
    final title = issue.title;
    return '${issue.count} ${title[0].toLowerCase()}${title.substring(1)}';
  }

  List<PendingItem> get _pending => [
    for (final issue in _issues)
      PendingItem(
        title: _titleOf(issue),
        help: issue.help,
        action: issue.action,
        onTap: issue.onTap,
        neutral: issue.level == _Level.info,
      ),
  ];

  String get _greeting {
    final name = (widget.user?.name.isNotEmpty ?? false)
        ? widget.user!.name
        : 'Administrador';
    return '${DateText.greeting(_now())}, $name';
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final premises = _store.premisesData;
    final summaryLoading = _summary.isInitialLoad;
    final summaryFailed = _summary.hasFailed && _summary.value == null;

    return AdminPage(
      eyebrow: DateText.longDate(now),
      title: _greeting,
      onRefresh: _reload,
      actions: [
        AdminButton.primary(
          label: '+ Nuevo predio',
          onPressed: widget.onAddPremise,
        ),
        if (widget.onAddManager != null)
          AdminButton(
            label: 'Crear responsable',
            onPressed: widget.onAddManager,
          ),
        if (widget.onSearchDevice != null)
          AdminButton(
            label: 'Código de dispositivo',
            onPressed: widget.onSearchDevice,
          ),
        AdminButton(
          label: _syncing ? 'Sincronizando…' : 'Sincronizar motivos',
          onPressed: _syncing ? null : _syncReasons,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeStats(summary: _summary.value, loading: summaryLoading, now: now),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              final glance = PremisesGlance(
                premises: premises.value,
                loading: premises.isInitialLoad,
                error: premises.hasFailed ? premises.error : null,
                onRetry: () => premises.load(force: true),
                onSeeAll: _openPremises,
                onOpenPremise: widget.onOpenPremise,
              );
              final aside = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PendingList(
                    items: _pending,
                    loading: summaryLoading,
                    error: summaryFailed
                        ? (_summary.error ?? 'No se pudo cargar el resumen')
                        : null,
                    onRetry: _reload,
                  ),
                  const SizedBox(height: 30),
                  CurrentRules(
                    qr: _store.qrSettingsData.value,
                    limits: _store.leaveLimitsData.value,
                    onEdit: widget.onOpenSettings,
                  ),
                ],
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [aside, const SizedBox(height: 30), glance],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: glance),
                  const SizedBox(width: 36),
                  Expanded(flex: 2, child: aside),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
