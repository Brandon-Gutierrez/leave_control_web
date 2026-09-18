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
        // Botones y filas más grandes, cómodos para tocar en cualquier edad.
        visualDensity: VisualDensity.comfortable,
        textTheme: Typography.englishLike2021.apply(fontSizeFactor: 1.08),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          contentTextStyle: TextStyle(fontSize: 15),
        ),
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
            ? AdminDashboardPage(adminName: user.name)
            : const LoginAdminPage();
      },
    );
  }
}
