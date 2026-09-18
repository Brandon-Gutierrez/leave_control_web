import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Sección "Inicio": un resumen simple y los tres accesos directos más
/// usados, pensada como primera pantalla para alguien que recién entra al
/// panel y no sabe bien por dónde empezar.
class HomeView extends StatefulWidget {
  final String adminName;
  final VoidCallback onAddPremise;
  final Future<void> Function() onSyncReasons;
  final VoidCallback onOpenUsers;
  final VoidCallback onUnauthorized;

  const HomeView({
    super.key,
    required this.adminName,
    required this.onAddPremise,
    required this.onSyncReasons,
    required this.onOpenUsers,
    required this.onUnauthorized,
  });

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  final PremiseService _premiseService = PremiseService();
  final UserAdminService _userAdminService = UserAdminService();

  bool _isLoading = true;
  bool _isSyncing = false;
  int _premiseCount = 0;
  int _userCount = 0;
  int _adminCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  /// Vuelve a calcular los números del resumen. Público para que se pueda
  /// refrescar después de crear un predio o sincronizar motivos.
  Future<void> refresh() => _fetchSummary();

  Future<void> _fetchSummary() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _premiseService.getPremisesWithReasons(),
        _userAdminService.getUsers(),
      ]);
      if (!mounted) return;
      final users = results[1] as List;
      setState(() {
        _premiseCount = (results[0] as List).length;
        _userCount = users.length;
        _adminCount = users
            .cast<dynamic>()
            .where((u) => (u.isAdmin as bool) == true)
            .length;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
    } catch (_) {
      // El resumen es informativo: si falla, simplemente se muestran guiones.
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width >= Breakpoints.tablet ? 32.0 : 16.0;

        return RefreshIndicator(
          onRefresh: _fetchSummary,
          color: Colors.white,
          backgroundColor: AppColors.primaryRed,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '¡Hola${widget.adminName.isEmpty ? '' : ', ${widget.adminName}'}!',
                      style: AppText.heading,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Este es el resumen de hoy.',
                      style: AppText.body.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 24),

                    _buildStatsRow(width),
                    const SizedBox(height: 32),

                    const Text('¿Qué deseas hacer?', style: AppText.sectionTitle),
                    const SizedBox(height: 14),

                    _ActionRow(
                      icon: Icons.add_business_rounded,
                      title: 'Agregar un predio nuevo',
                      subtitle: 'Registra una nueva sede o sucursal del sistema.',
                      onTap: widget.onAddPremise,
                    ),
                    const SizedBox(height: 12),
                    _ActionRow(
                      icon: Icons.sync_rounded,
                      title: 'Actualizar motivos de salida',
                      subtitle: 'Trae los motivos más recientes desde el sistema.',
                      onTap: _handleSync,
                      isLoading: _isSyncing,
                    ),
                    const SizedBox(height: 12),
                    _ActionRow(
                      icon: Icons.people_alt_rounded,
                      title: 'Administrar usuarios',
                      subtitle: 'Otorga o quita permisos de administrador.',
                      onTap: widget.onOpenUsers,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(double width) {
    final isNarrow = width < 560;
    final cards = [
      _StatCard(
        icon: Icons.apartment_rounded,
        value: _premiseCount,
        label: 'Predios registrados',
        isLoading: _isLoading,
      ),
      _StatCard(
        icon: Icons.groups_rounded,
        value: _userCount,
        label: 'Personas registradas',
        isLoading: _isLoading,
      ),
      _StatCard(
        icon: Icons.shield_rounded,
        value: _adminCount,
        label: 'Administradores',
        isLoading: _isLoading,
      ),
    ];

    if (isNarrow) {
      return Column(
        children: [
          for (final card in cards) ...[
            card,
            if (card != cards.last) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (final card in cards) ...[
          Expanded(child: card),
          if (card != cards.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final bool isLoading;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryRed, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryRed),
                      )
                    : Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                const SizedBox(height: 2),
                Text(label, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryRed, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.cardTitle.copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryRed),
                )
              else
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
