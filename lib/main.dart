import 'package:flutter/material.dart';

import 'models/auth_user.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/login_admin_page.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control QR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Restaura la sesión del navegador (cookie de Sanctum) al recargar la página.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<AuthUser?> _currentUser = AuthService().currentUser();

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
        return user != null && user.isAdmin
            ? const AdminDashboardPage()
            : const LoginAdminPage();
      },
    );
  }
}
