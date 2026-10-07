import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_service.dart';
import '../features/auth/models/auth_user.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/auth/state/session_controller.dart';
import '../features/qr/presentation/manager_lockdown_page.dart';

/// Aplicación web del panel de administración y del QR de los responsables.
class ControlQrApp extends StatelessWidget {
  const ControlQrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control QR',
      theme: buildAppTheme(),
      // Guardia global: si la sesión es de un responsable de predio (rol
      // MANAGE_PREMISE) se muestra solo su pantalla de QR, sin importar la ruta.
      builder: (context, child) => ValueListenableBuilder<AuthUser?>(
        valueListenable: SessionController.instance.user,
        builder: (context, user, _) {
          if (user != null && user.isPremiseManager) {
            return ManagerLockdownPage(
              user: user,
              onRetry: () async => SessionController.instance.set(
                await AuthService().currentUser(),
              ),
            );
          }
          return child ?? const SizedBox.shrink();
        },
      ),
      home: const AuthGate(),
    );
  }
}
