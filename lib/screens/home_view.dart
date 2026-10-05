import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/managed_user.dart';
import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Sección "Inicio": le dice a la persona qué falta resolver, con colores
/// (rojo = urgente, ámbar = pendiente, azul = informativo, verde = todo bien)
/// y un botón directo para resolverlo.
class HomeView extends StatefulWidget {
  final AuthUser? user;
  final VoidCallback onAddPremise;
  final Future<void> Function() onSyncReasons;
  final VoidCallback onOpenUsers;
  final VoidCallback onUnauthorized;
  final VoidCallback? onOpenPremises;

  /// Acceso directo para crear la cuenta de un responsable de predio.
  final VoidCallback? onAddManager;

  const HomeView({
    super.key,
    required this.user,
    required this.onAddPremise,
    required this.onSyncReasons,
    required this.onOpenUsers,
    required this.onUnauthorized,
    this.onOpenPremises,
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

  const _Issue(this.level, this.count, this.title, this.help, this.action, this.onTap);
}

class HomeViewState extends State<HomeView> {
  final PremiseService _premiseService = PremiseService();
  final UserAdminService _userAdminService = UserAdminService();

  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isSyncing = false;
  List<Premise> _premises = [];
  List<ManagedUser> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  /// Vuelve a calcular el resumen. Público para refrescarlo desde fuera.
  Future<void> refresh() => _fetchSummary();

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait([
        _premiseService.getPremisesWithReasons(),
        _userAdminService.getUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _premises = results[0] as List<Premise>;
        _users = results[1] as List<ManagedUser>;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      if (mounted) setState(() => _loadFailed = true);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    await widget.onSyncReasons();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    _fetchSummary();
  }

  void _openPremises() => (widget.onOpenPremises ?? widget.onAddPremise).call();

  List<_Issue> get _issues {
    final noLocation = _premises.where((p) => !p.hasLocation).length;
    final noManager = _premises.where((p) => p.manager == null).length;
    final noReasons = _premises.where((p) => p.reasonNames.isEmpty).length;
    final managersWithoutPremise =
        _users.where((u) => u.managesPremise && u.premise == null).length;
    final employeesUnbound = _users
        .where((u) => u.isEmployee && !u.devices.containsKey(ClientPlatform.mobile))
        .length;

    return [
      if (noLocation > 0)
        _Issue(
          _Level.urgent,
          noLocation,
          noLocation == 1 ? 'Predio sin ubicación en el mapa' : 'Predios sin ubicación en el mapa',
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
          noReasons == 1 ? 'Predio sin motivos de salida' : 'Predios sin motivos de salida',
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
          onRefresh: _fetchSummary,
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
    final admins = _users.where((u) => u.isAdmin).length;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    Widget item(IconData icon, int value, String label) => Expanded(
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
                  Text(
                    _isLoading ? '–' : '$value',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1),
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
      child: Row(
        children: [
          item(Icons.apartment_rounded, _premises.length, 'Predios registrados'),
          item(Icons.groups_rounded, _users.length, 'Personas registradas'),
          item(Icons.shield_rounded, admins, 'Administradores'),
        ],
      ),
    );
  }

  Widget _buildAttention() {
    final Widget body;
    if (_isLoading && _premises.isEmpty && _users.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
      );
    } else if (_loadFailed) {
      body = _Banner(
        color: AppColors.danger,
        background: AppColors.dangerBg,
        icon: Icons.cloud_off_rounded,
        title: 'No se pudo cargar el resumen',
        help: 'Revise su conexión e intente de nuevo.',
        action: 'Reintentar',
        onTap: _fetchSummary,
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
          icon: Icons.sync_rounded,
          label: 'Actualizar motivos de salida',
          onTap: _handleSync,
          isLoading: _isSyncing,
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

class _IssueRow extends StatelessWidget {
  final _Issue issue;

  const _IssueRow({required this.issue});

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (issue.level) {
      _Level.urgent => (AppColors.danger, AppColors.dangerBg, Icons.error_rounded),
      _Level.pending => (AppColors.warning, AppColors.warningBg, Icons.warning_rounded),
      _Level.info => (AppColors.info, AppColors.infoBg, Icons.info_rounded),
    };
    return _Banner(
      color: color,
      background: bg,
      icon: icon,
      title: '${issue.count} · ${issue.title}',
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
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
  final bool isLoading;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
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
            isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryRed),
                  )
                : Icon(icon, color: AppColors.primaryRed, size: 26),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}
