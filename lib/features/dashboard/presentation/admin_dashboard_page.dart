import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../session/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/user_module.dart';
import 'home_view.dart';
import 'login_admin_page.dart';
import 'premises_view.dart';
import 'leave_limits_dialog.dart';
import 'qr_settings_dialog.dart';
import 'users_view.dart';

/// Estructura del panel: en pantallas anchas una barra lateral fija con la
/// persona que inició sesión, las secciones y los ajustes; en teléfono, una
/// barra superior con la persona y navegación abajo.
class AdminDashboardPage extends StatefulWidget {
  /// Persona que inició sesión (módulo de usuario). Si no se indica se toma de
  /// la sesión compartida.
  final AuthUser? user;

  /// Ejecuta la tarea.
  const AdminDashboardPage({super.key, this.user});

  /// Crea el estado del widget.
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

/// Representa esta entidad.
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

  AuthUser? get _user => widget.user ?? SessionController.instance.user.value;

  /// Ejecuta la tarea.
  Future<void> _logout() async {
    await _authService.logout();
    _goToLogin();
  }

  /// Ejecuta la tarea.
  void _goToLogin() {
    SessionController.instance.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginAdminPage()),
      (route) => false,
    );
  }

  /// Ejecuta la tarea.
  void _selectSection(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  /// Ejecuta la tarea.
  void _goToPremises({bool openCreateDialog = false}) {
    setState(() => _selectedIndex = 1);
    if (openCreateDialog) {
      // El estado de PremisesView ya existe (vive dentro de un IndexedStack),
      // así que se puede abrir el formulario de inmediato.
      _premisesKey.currentState?.openCreateDialog();
    }
  }

  /// Ejecuta la tarea.
  void _goToUsers({bool openCreateManager = false}) {
    setState(() => _selectedIndex = 2);
    if (openCreateManager) {
      _usersKey.currentState?.openCreateManagerDialog();
    }
  }

  /// Ejecuta la tarea.
  Future<void> _syncReasonsFromHome() async {
    await _premisesKey.currentState?.syncReasons();
  }

  /// Ejecuta la tarea.
  Future<void> _openQrSettings() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => const QrSettingsDialog(),
    );
  }

  /// Ejecuta la tarea.
  Future<void> _openLeaveLimits() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => const LeaveLimitsDialog(),
    );
  }

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.tablet;

        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            HomeView(
              user: _user,
              onAddPremise: () => _goToPremises(openCreateDialog: true),
              onOpenPremises: _goToPremises,
              onSyncReasons: _syncReasonsFromHome,
              onOpenUsers: _goToUsers,
              onAddManager: () => _goToUsers(openCreateManager: true),
              onUnauthorized: _goToLogin,
            ),
            PremisesView(key: _premisesKey, onUnauthorized: _goToLogin),
            UsersView(key: _usersKey, onUnauthorized: _goToLogin),
          ],
        );

        if (isWide) {
          return Scaffold(
            backgroundColor: lightBg,
            body: Row(
              children: [
                _Sidebar(
                  user: _user,
                  selectedIndex: _selectedIndex,
                  titles: _titles,
                  icons: _destinationIcons,
                  onSelect: _selectSection,
                  onQrSettings: _openQrSettings,
                  onLeaveLimits: _openLeaveLimits,
                  onLogout: _logout,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _SectionHeader(title: _titles[_selectedIndex]),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: lightBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 64,
            shape: const Border(bottom: BorderSide(color: AppColors.line)),
            title: UserModule(user: _user, compact: true),
            actions: [
              IconButton(
                icon: const Icon(Icons.rule_rounded, color: darkText, size: AppDimens.iconSize),
                tooltip: 'Límite de salidas',
                onPressed: _openLeaveLimits,
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded, color: darkText, size: AppDimens.iconSize),
                tooltip: 'Tiempo de vida del QR',
                onPressed: _openQrSettings,
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.danger, size: AppDimens.iconSize),
                tooltip: 'Cerrar sesión',
                onPressed: _logout,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(child: content),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectSection,
            backgroundColor: Colors.white,
            indicatorColor: primaryRed.withValues(alpha: 0.14),
            height: 72,
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

/// Representa esta entidad.
class _SectionHeader extends StatelessWidget {
  final String title;

  /// Ejecuta la tarea.
  const _SectionHeader({required this.title});

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Text(title, style: AppText.heading.copyWith(fontSize: 24)),
    );
  }
}

/// Representa esta entidad.
class _Sidebar extends StatelessWidget {
  final AuthUser? user;
  final int selectedIndex;
  final List<String> titles;
  final List<(IconData, IconData)> icons;
  final ValueChanged<int> onSelect;
  final VoidCallback onQrSettings;
  final VoidCallback onLeaveLimits;
  final VoidCallback onLogout;

  /// Ejecuta la tarea.
  const _Sidebar({
    required this.user,
    required this.selectedIndex,
    required this.titles,
    required this.icons,
    required this.onSelect,
    required this.onQrSettings,
    required this.onLeaveLimits,
    required this.onLogout,
  });

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Image.asset(
                'rsc/comteco.png',
                height: 38,
                alignment: Alignment.centerLeft,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.business_rounded, color: AppColors.darkText),
              ),
            ),
            UserModule(user: user),
            const Divider(height: 28, color: AppColors.line),
            for (var i = 0; i < titles.length; i++)
              _NavItem(
                icon: selectedIndex == i ? icons[i].$2 : icons[i].$1,
                label: titles[i],
                selected: selectedIndex == i,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.line),
            _NavItem(
              icon: Icons.rule_rounded,
              label: 'Límite de salidas',
              selected: false,
              onTap: onLeaveLimits,
            ),
            _NavItem(
              icon: Icons.qr_code_2_rounded,
              label: 'Tiempo de vida del QR',
              selected: false,
              onTap: onQrSettings,
            ),
            _NavItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              selected: false,
              color: AppColors.danger,
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Representa esta entidad.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  /// Ejecuta la tarea.
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primaryRed : (color ?? AppColors.darkText);
    return Tooltip(
      message: label,
      child: InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryRed.withValues(alpha: 0.08) : null,
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.primaryRed : Colors.transparent,
              width: 5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
