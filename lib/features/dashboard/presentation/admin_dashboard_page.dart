import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/auth_user.dart';
import '../../auth/presentation/admin_login_page.dart';
import '../../auth/state/session_controller.dart';
import '../../premises/presentation/premises_view.dart';
import '../../reasons/presentation/reasons_view.dart';
import '../../settings/presentation/settings_view.dart';
import '../../users/presentation/users_view.dart';
import '../state/admin_data_store.dart';
import 'home_view.dart';
import 'user_profile_header.dart';

/// Estructura del panel: arriba el logo, las pestañas de las secciones y la
/// persona que inició sesión; en pantallas angostas, una barra superior con la
/// persona y la navegación abajo.
class AdminDashboardPage extends StatefulWidget {
  /// Persona que inició sesión (módulo de usuario). Si no se indica se toma de
  /// la sesión compartida.
  final AuthUser? user;

  const AdminDashboardPage({super.key, this.user});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const _titles = [
    'Inicio',
    'Predios',
    'Usuarios',
    'Motivos',
    'Ajustes',
  ];
  static const _destinationIcons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.place_outlined, Icons.place_rounded),
    (Icons.groups_outlined, Icons.groups_rounded),
    (Icons.format_list_bulleted_rounded, Icons.format_list_bulleted_rounded),
    (Icons.tune_rounded, Icons.tune_rounded),
  ];

  final AuthService _authService = AuthService();
  final _premisesKey = GlobalKey<PremisesViewState>();
  final _usersKey = GlobalKey<UsersViewState>();

  int _selectedIndex = 0;

  /// Secciones que ya se abrieron. Solo esas se construyen (y piden sus
  /// datos): al iniciar sesión se carga únicamente Inicio.
  final Set<int> _visited = {0};

  AuthUser? get _user => widget.user ?? SessionController.instance.user.value;

  @override
  void initState() {
    super.initState();
    // Una sesión caducada en cualquier petición lleva al inicio de sesión.
    AdminDataStore.instance.onUnauthorized = _goToLogin;
  }

  @override
  void dispose() {
    AdminDataStore.instance.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _logout() async {
    await _authService.logout();
    _goToLogin();
  }

  void _goToLogin() {
    SessionController.instance.clear();
    AdminDataStore.instance.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginPage()),
      (route) => false,
    );
  }

  /// Muestra una sección: la construye la primera vez y pide solo su dato, si
  /// no está al día (los que cargó hace poco se muestran al instante).
  void _showSection(int index) {
    final store = AdminDataStore.instance;
    setState(() {
      _visited.add(index);
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        unawaited(store.summaryData.load());
      case 1:
        unawaited(store.premisesData.load());
      case 2:
        unawaited(store.usersData.load());
      case 3:
        unawaited(store.reasonCatalogData.load());
    }
  }

  void _selectSection(int index) {
    if (index == _selectedIndex) return;
    _showSection(index);
  }

  void _goToPremises({bool openCreateDialog = false}) {
    _showSection(1);
    if (openCreateDialog) {
      // Si la sección se acaba de construir, su estado existe en el siguiente
      // cuadro.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _premisesKey.currentState?.openCreateDialog(),
      );
    }
  }

  void _goToUsers({
    bool openCreateManager = false,
    bool openDeviceSearch = false,
  }) {
    _showSection(2);
    if (openCreateManager) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _usersKey.currentState?.openCreateManagerDialog(),
      );
    }
    if (openDeviceSearch) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _usersKey.currentState?.openDeviceCodeSearch(),
      );
    }
  }

  void _goToReasons() => _showSection(3);

  void _goToSettings() => _showSection(4);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final topNav = constraints.maxWidth >= Breakpoints.topNav;

        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            HomeView(
              user: _user,
              onAddPremise: () => _goToPremises(openCreateDialog: true),
              onOpenPremises: _goToPremises,
              onOpenReasons: _goToReasons,
              onOpenUsers: _goToUsers,
              onAddManager: () => _goToUsers(openCreateManager: true),
              onSearchDevice: () => _goToUsers(openDeviceSearch: true),
              onOpenSettings: _goToSettings,
            ),
            if (_visited.contains(1))
              PremisesView(key: _premisesKey)
            else
              const SizedBox.shrink(),
            if (_visited.contains(2))
              UsersView(key: _usersKey)
            else
              const SizedBox.shrink(),
            if (_visited.contains(3))
              const ReasonsView()
            else
              const SizedBox.shrink(),
            if (_visited.contains(4))
              const SettingsView()
            else
              const SizedBox.shrink(),
          ],
        );

        if (topNav) {
          return Scaffold(
            backgroundColor: AppColors.lightBg,
            body: Column(
              children: [
                _TopBar(
                  user: _user,
                  titles: _titles,
                  icons: _destinationIcons,
                  selectedIndex: _selectedIndex,
                  onSelect: _selectSection,
                  onLogout: _logout,
                ),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 60,
            titleSpacing: 16,
            shape: const Border(bottom: BorderSide(color: Color(0xFFE0E0DC))),
            title: Row(
              children: [
                const AppLogo(size: 36),
                const Spacer(),
                UserChip(user: _user, onLogout: _logout, compact: true),
              ],
            ),
          ),
          body: SafeArea(child: content),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectSection,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primaryRed.withValues(alpha: 0.14),
            height: 72,
            destinations: [
              for (var i = 0; i < _titles.length; i++)
                NavigationDestination(
                  icon: Icon(_destinationIcons[i].$1),
                  selectedIcon: Icon(
                    _destinationIcons[i].$2,
                    color: AppColors.primaryRed,
                  ),
                  label: _titles[i],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Barra superior de pantallas anchas: logo, pestañas y la persona.
class _TopBar extends StatelessWidget {
  final AuthUser? user;
  final List<String> titles;
  final List<(IconData, IconData)> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _TopBar({
    required this.user,
    required this.titles,
    required this.icons,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    // La barra tiene un alto fijo: sus textos crecen hasta x1.3 y no más.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: _buildBar(),
    );
  }

  Widget _buildBar() {
    return Container(
      height: AppDimens.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0DC))),
      ),
      child: Row(
        children: [
          const AppLogo(size: 44),
          const SizedBox(width: 24),
          Expanded(
            // Si la ventana es justa, las pestañas se desplazan en vez de
            // desbordar.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < titles.length; i++)
                    _TopTab(
                      icon: selectedIndex == i ? icons[i].$2 : icons[i].$1,
                      label: titles[i],
                      selected: selectedIndex == i,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: UserChip(user: user, onLogout: onLogout),
          ),
        ],
      ),
    );
  }
}

/// Una pestaña de la barra superior: la activa va en rojo y subrayada.
class _TopTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryRed : const Color(0xFF555555);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: AppDimens.topBarHeight,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primaryRed : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
