import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'home_view.dart';
import 'login_admin_page.dart';
import 'premises_view.dart';
import 'users_view.dart';

/// Estructura (shell) del panel de administración: navegación entre las
/// secciones "Inicio", "Predios" y "Usuarios", responsiva a teléfono, tablet
/// y escritorio. Pensada para ser fácil de usar por cualquier persona.
class AdminDashboardPage extends StatefulWidget {
  /// Nombre de la persona que inició sesión, para el saludo en "Inicio".
  final String adminName;

  const AdminDashboardPage({super.key, this.adminName = ''});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;
  static const lightBg = AppColors.lightBg;

  static const _titles = ['Inicio', 'Predios', 'Usuarios'];
  static const _destinationIcons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.apartment_outlined, Icons.apartment_rounded),
    (Icons.people_alt_outlined, Icons.people_alt_rounded),
  ];

  final AuthService _authService = AuthService();
  final _premisesKey = GlobalKey<PremisesViewState>();
  final _usersKey = GlobalKey<UsersViewState>();

  int _selectedIndex = 0;

  Future<void> _logout() async {
    await _authService.logout();
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginAdminPage()),
      (route) => false,
    );
  }

  void _selectSection(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _goToPremises({bool openCreateDialog = false}) {
    setState(() => _selectedIndex = 1);
    if (openCreateDialog) {
      // El estado de PremisesView ya existe (vive dentro de un IndexedStack),
      // así que se puede abrir el formulario de inmediato.
      _premisesKey.currentState?.openCreateDialog();
    }
  }

  void _goToUsers() => setState(() => _selectedIndex = 2);

  Future<void> _syncReasonsFromHome() async {
    await _premisesKey.currentState?.syncReasons();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.tablet;

        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            HomeView(
              adminName: widget.adminName,
              onAddPremise: () => _goToPremises(openCreateDialog: true),
              onSyncReasons: _syncReasonsFromHome,
              onOpenUsers: _goToUsers,
              onUnauthorized: _goToLogin,
            ),
            PremisesView(key: _premisesKey, onUnauthorized: _goToLogin),
            UsersView(key: _usersKey, onUnauthorized: _goToLogin),
          ],
        );

        return Scaffold(
          backgroundColor: lightBg,
          appBar: AppBar(
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'rsc/comteco.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.business_rounded,
                  color: darkText,
                ),
              ),
            ),
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_titles[_selectedIndex], style: AppText.sectionTitle),
            ),
            centerTitle: true,
            backgroundColor: lightBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: darkText, size: AppDimens.iconSize),
                tooltip: 'Cerrar sesión',
                onPressed: _logout,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: isWide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _selectSection,
                        backgroundColor: lightBg,
                        labelType: NavigationRailLabelType.all,
                        useIndicator: true,
                        indicatorColor: primaryRed.withValues(alpha: 0.12),
                        selectedIconTheme: const IconThemeData(color: primaryRed, size: 28),
                        selectedLabelTextStyle: const TextStyle(
                          color: primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600, size: 26),
                        unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        destinations: [
                          for (var i = 0; i < _titles.length; i++)
                            NavigationRailDestination(
                              icon: Icon(_destinationIcons[i].$1),
                              selectedIcon: Icon(_destinationIcons[i].$2),
                              label: Text(_titles[i]),
                            ),
                        ],
                      ),
                      VerticalDivider(width: 1, color: Colors.grey.shade300),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectSection,
                  backgroundColor: Colors.white,
                  indicatorColor: primaryRed.withValues(alpha: 0.12),
                  height: 68,
                  destinations: [
                    for (var i = 0; i < _titles.length; i++)
                      NavigationDestination(
                        icon: Icon(_destinationIcons[i].$1),
                        selectedIcon: Icon(_destinationIcons[i].$2, color: primaryRed),
                        label: _titles[i],
                      ),
                  ],
                ),
        );
      },
    );
  }
}
