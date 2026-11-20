import 'package:flutter/material.dart';

import '../../../core/widgets/admin_page.dart';
import 'leave_limits_card.dart';
import 'qr_settings_card.dart';

/// Sección «Ajustes»: las reglas que aplican a todas las personas y predios.
/// Cada regla es una tarjeta con sus campos y sus propios botones para
/// guardar; guardar una no afecta a la otra.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Ajustes',
      subtitle: 'Reglas que aplican a todas las personas y predios.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LeaveLimitsCard(),
                SizedBox(height: 20),
                QrSettingsCard(),
              ],
            );
          }
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: LeaveLimitsCard()),
              SizedBox(width: 24),
              Expanded(flex: 4, child: QrSettingsCard()),
            ],
          );
        },
      ),
    );
  }
}
