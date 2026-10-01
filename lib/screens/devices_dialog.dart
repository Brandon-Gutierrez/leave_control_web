import 'package:flutter/material.dart';

import '../models/managed_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Muestra el dispositivo autorizado de una cuenta en cada aplicación que su
/// rol puede usar. Devuelve la aplicación cuyo dispositivo se quiere
/// desvincular, o `null` si se cerró sin elegir.
class DevicesDialog extends StatelessWidget {
  final ManagedUser user;

  const DevicesDialog({super.key, required this.user});

  static String _formatDate(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width < 480 ? width - 32 : 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Dispositivos autorizados', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text(user.name, style: AppText.body),
              const SizedBox(height: 4),
              Text(
                'Cada cuenta puede usar un solo dispositivo por aplicación. '
                'Si la persona cambió de equipo, desvincule el anterior y '
                'el próximo inicio de sesión quedará vinculado al nuevo.',
                style: AppText.caption,
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
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  final ClientPlatform platform;
  final DateTime? boundAt;
  final String Function(DateTime) formatDate;

  const _PlatformRow({
    required this.platform,
    required this.boundAt,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final bound = boundAt != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            platform == ClientPlatform.web
                ? Icons.computer_rounded
                : Icons.smartphone_rounded,
            color: AppColors.darkText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(platform.label, style: AppText.cardTitle),
                Text(
                  bound
                      ? 'Vinculado desde ${formatDate(boundAt!)}'
                      : 'Sin ${platform.deviceNoun} vinculado',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          if (bound)
            TextButton(
              onPressed: () => Navigator.pop(context, platform),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
              child: const Text('Desvincular'),
            ),
        ],
      ),
    );
  }
}
