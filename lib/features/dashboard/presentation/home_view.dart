import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/models/auth_user.dart';
import '../models/admin_summary.dart';
import '../state/admin_data_store.dart';

/// Sección "Inicio": le dice a la persona qué falta resolver, con colores
/// (rojo = urgente, ámbar = pendiente, azul = informativo, verde = todo bien)
/// y un botón directo para resolverlo.
class HomeView extends StatefulWidget {
  final AuthUser? user;
  final VoidCallback onAddPremise;
  final VoidCallback onOpenUsers;
  final VoidCallback? onOpenPremises;

  /// Lleva a la sección "Motivos de salida" (p. ej. si falló la sincronización).
  final VoidCallback? onOpenReasons;

  /// Acceso directo para crear la cuenta de un responsable de predio.
  final VoidCallback? onAddManager;

  const HomeView({
    super.key,
    required this.user,
    required this.onAddPremise,
    required this.onOpenUsers,
    this.onOpenPremises,
    this.onOpenReasons,
    this.onAddManager,
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

  StoreResource<AdminSummary?> get _summary => _store.summaryData;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    // Inicio solo necesita los contadores, no las listas completas.
    unawaited(_summary.load());
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() => _summary.load(force: true);

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
          'Se conserva el catálogo anterior. ${summary.reasonsSync!.error ?? 'Reintente la sincronización.'}',
          'Ver motivos',
          widget.onOpenReasons ?? () {},
          counted: false,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final pad = constraints.maxWidth >= Breakpoints.tablet ? 32.0 : 16.0;

        final attention = _buildAttention();
        final actions = _buildActions();

        return RefreshIndicator(
          onRefresh: _reload,
          color: Colors.white,
          backgroundColor: AppColors.primaryRed,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTotals(),
                    const SizedBox(height: 28),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: attention),
                          const SizedBox(width: 32),
                          Expanded(flex: 2, child: actions),
                        ],
                      )
                    else ...[
                      attention,
                      const SizedBox(height: 28),
                      actions,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Números en una franja simple separada por líneas, no en tarjetas.
  Widget _buildTotals() {
    final summary = _summary.value;
    final loading = _summary.isInitialLoad;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    Widget item(IconData icon, int? value, String label) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (!narrow) ...[
              Icon(icon, size: 30, color: Colors.grey.shade700),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loading)
                    const SkeletonBox(width: 48, height: 28)
                  else
                    Text(
                      value == null ? '–' : '$value',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(label, style: AppText.caption, maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.line)),
      ),
      child: SkeletonPulse(
        active: loading,
        child: Row(
          children: [
            item(
              Icons.apartment_rounded,
              summary?.premises,
              'Predios registrados',
            ),
            item(Icons.groups_rounded, summary?.users, 'Personas registradas'),
            item(Icons.shield_rounded, summary?.admins, 'Administradores'),
          ],
        ),
      ),
    );
  }

  Widget _buildAttention() {
    final Widget body;
    if (_summary.isInitialLoad) {
      body = const SkeletonPulse(
        child: Column(
          children: [
            _SkeletonBanner(),
            SizedBox(height: 10),
            _SkeletonBanner(),
          ],
        ),
      );
    } else if (_summary.hasFailed && _summary.value == null) {
      body = LoadErrorNotice(
        message: _summary.error ?? 'No se pudo cargar el resumen',
        onRetry: _reload,
      );
    } else if (_issues.isEmpty) {
      body = const _Banner(
        color: AppColors.success,
        background: AppColors.successBg,
        icon: Icons.check_circle_rounded,
        title: 'Todo está en orden',
        help: 'Todos los predios tienen ubicación, motivos y responsable.',
      );
    } else {
      body = Column(
        children: [
          for (final issue in _issues) ...[
            _IssueRow(issue: issue),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Requiere su atención', style: AppText.sectionTitle),
        const SizedBox(height: 4),
        Text('Lo más urgente aparece primero.', style: AppText.caption),
        const SizedBox(height: 14),
        body,
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Acciones rápidas', style: AppText.sectionTitle),
        const SizedBox(height: 14),
        _QuickAction(
          icon: Icons.add_location_alt_rounded,
          label: 'Agregar un predio nuevo',
          onTap: widget.onAddPremise,
        ),
        if (widget.onAddManager != null)
          _QuickAction(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Crear responsable de predio',
            onTap: widget.onAddManager!,
          ),
        _QuickAction(
          icon: Icons.people_alt_rounded,
          label: 'Administrar usuarios',
          onTap: widget.onOpenUsers,
        ),
      ],
    );
  }
}

/// Hueco con la forma de una franja de aviso mientras llega el resumen.
class _SkeletonBanner extends StatelessWidget {
  const _SkeletonBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.line, width: 6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 220, height: 18),
          SizedBox(height: 8),
          SkeletonBox(height: 14),
          SizedBox(height: 12),
          SkeletonBox(width: 130, height: 36, radius: 6),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final _Issue issue;

  const _IssueRow({required this.issue});

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (issue.level) {
      _Level.urgent => (
        AppColors.danger,
        AppColors.dangerBg,
        Icons.error_rounded,
      ),
      _Level.pending => (
        AppColors.warning,
        AppColors.warningBg,
        Icons.warning_rounded,
      ),
      _Level.info => (AppColors.info, AppColors.infoBg, Icons.info_rounded),
    };
    return _Banner(
      color: color,
      background: bg,
      icon: icon,
      title: issue.counted ? '${issue.count} · ${issue.title}' : issue.title,
      help: issue.help,
      action: issue.action,
      onTap: issue.onTap,
    );
  }
}

/// Franja de color con ícono, mensaje y un botón de acción opcional.
class _Banner extends StatelessWidget {
  final Color color;
  final Color background;
  final IconData icon;
  final String title;
  final String help;
  final String? action;
  final VoidCallback? onTap;

  const _Banner({
    required this.color,
    required this.background,
    required this.icon,
    required this.title,
    required this.help,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(left: BorderSide(color: color, width: 6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(help, style: AppText.body.copyWith(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(action!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppColors.darkText,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryRed, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
