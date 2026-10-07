import 'package:flutter/material.dart';

import '../models/managed_user.dart';
import '../theme/app_colors.dart';
import '../widgets/app_modal.dart';
import '../widgets/dialog_header.dart';
import '../theme/app_text_styles.dart';

/// Muestra el dispositivo autorizado de una cuenta en cada aplicación que su
/// rol puede usar. Devuelve la aplicación cuyo dispositivo se quiere
/// desvincular, o `null` si se cerró sin elegir.
class DevicesDialog extends StatelessWidget {
  final ManagedUser user;

  /// Ejecuta la tarea.
  const DevicesDialog({super.key, required this.user});

  /// Ejecuta la tarea.
  static String _formatDate(DateTime date) {
    final d = date.toLocal();
    /// Ejecuta la tarea.
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    return AppModal(
      tone: DialogTone.caution,
      icon: Icons.devices_rounded,
      title: 'Dispositivos autorizados',
      subtitle: user.name,
      actions: [ModalButton(label: 'Cerrar', onPressed: () => Navigator.pop(context))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cada cuenta usa un solo dispositivo por aplicación. Si la persona '
            'cambió de equipo, desvincule el anterior: el próximo inicio de '
            'sesión quedará vinculado al nuevo.',
            style: AppText.body,
          ),
          const SizedBox(height: 16),
          for (final platform in user.platforms) ...[
            _PlatformRow(
              platform: platform,
              boundAt: user.devices[platform],
              formatDate: _formatDate,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Representa esta entidad.
class _PlatformRow extends StatelessWidget {
  final ClientPlatform platform;
  final DateTime? boundAt;
  final String Function(DateTime) formatDate;

  /// Ejecuta la tarea.
  const _PlatformRow({
    required this.platform,
    required this.boundAt,
    required this.formatDate,
  });

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    final bound = boundAt != null;
    final color = bound ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: bound ? AppColors.successBg : AppColors.warningBg,
        border: Border(left: BorderSide(color: color, width: 6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
            children: [
              Icon(
                platform == ClientPlatform.web ? Icons.computer_rounded : Icons.smartphone_rounded,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(platform.label, style: AppText.cardTitle),
                  Text(
                    bound
                        ? 'Vinculado desde ${formatDate(boundAt!)}'
                        : 'Sin ${platform.deviceNoun} vinculado',
                    style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              )),
            ],
          ),
          ),
          if (bound) ...[
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => Navigator.pop(context, platform),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Desvincular'),
            ),
          ],
        ],
      ),
    );
  }
}
