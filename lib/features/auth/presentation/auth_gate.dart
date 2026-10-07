import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/admin_dashboard_page.dart';
import '../data/auth_service.dart';
import '../models/auth_user.dart';
import '../state/session_controller.dart';
import 'admin_login_page.dart';

/// Restaura la sesión del navegador (cookie de Sanctum) al recargar la página.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Al restaurar la sesión se publica el usuario: si es un responsable de
  // predio, la raíz de la app pasa a mostrar solo su pantalla de QR.
  late final Future<AuthUser?> _currentUser = AuthService().currentUser().then((
    user,
  ) {
    SessionController.instance.set(user);
    return user;
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthUser?>(
      future: _currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.loginBg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
          );
        }
        final user = snapshot.data;
        return user?.isAdmin == true
            ? AdminDashboardPage(user: user)
            : const AdminLoginPage();
      },
    );
  }
}
