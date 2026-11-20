import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/admin_page.dart';
import '../../dashboard/state/admin_data_store.dart';
import 'leave_limits_dialog.dart';
import 'qr_settings_dialog.dart';

/// Sección «Ajustes»: las reglas que aplican a todas las personas y predios.
/// Cada una se cambia en su propio cuadro de diálogo.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _openLeaveLimits(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const LeaveLimitsDialog(),
    );
    // Inicio muestra estas reglas: si cambiaron, se vuelven a leer.
    if (saved == true) unawaited(AdminDataStore.instance.refreshQuietly());
  }

  Future<void> _openQrSettings(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const QrSettingsDialog(),
    );
    if (saved == true) unawaited(AdminDataStore.instance.refreshQuietly());
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Ajustes',
      subtitle: 'Reglas que aplican a todas las personas y predios.',
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          _SettingCard(
            icon: Icons.schedule_rounded,
            title: 'Límite de salidas',
            subtitle: 'Cuántas veces puede salir cada persona',
            action: AdminButton(
              label: 'Cambiar',
              onPressed: () => _openLeaveLimits(context),
            ),
          ),
          _SettingCard(
            icon: Icons.qr_code_2_rounded,
            title: 'Vida del código QR',
            subtitle: 'Cada cuánto cambia el QR del predio',
            action: AdminButton(
              label: 'Cambiar',
              onPressed: () => _openQrSettings(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: AppColors.info),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          action,
        ],
      ),
    );
  }
}
