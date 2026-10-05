import 'package:flutter/material.dart';

import '../models/auth_user.dart' show kManagePremiseRole;
import '../models/managed_user.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_modal.dart';
import '../widgets/app_popup.dart';
import '../widgets/dialog_header.dart';
import '../widgets/filter_sidebar.dart';
import 'manager_password_dialog.dart';
import 'change_role_dialog.dart';
import 'create_manager_dialog.dart';
import 'devices_dialog.dart';

/// Sección "Usuarios" del panel de administración: busca usuarios, gestiona
/// roles y asigna predios a los gestores, siempre con confirmación.
enum _RoleFilter { all, employee, admin, manager }

enum _PremiseFilter { any, with_, without }

class UsersView extends StatefulWidget {
  /// Se llama cuando el token de sesión ya no es válido (401).
  final VoidCallback onUnauthorized;

  const UsersView({super.key, required this.onUnauthorized});

  @override
  State<UsersView> createState() => UsersViewState();
}

class UsersViewState extends State<UsersView> {
  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;

  final _searchController = TextEditingController();
  final UserAdminService _userAdminService = UserAdminService();
  final PremiseService _premiseService = PremiseService();

  List<ManagedUser> _users = [];
  List<AppRole> _roles = [];
  List<UserPremise> _premises = [];
  final Set<int> _occupiedPremiseIds = {};
  _RoleFilter _roleFilter = _RoleFilter.all;
  _PremiseFilter _premiseFilter = _PremiseFilter.any;
  String _searchQuery = '';
  bool _isLoading = true;
  final Set<int> _updatingUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Recarga la lista de usuarios y roles. Público para que otras secciones
  /// (p. ej. "Inicio") puedan refrescar estos datos.
  Future<void> refresh() => _fetchData();

  int get adminCount => _users.where((u) => u.isAdmin).length;

  List<ManagedUser> get _filteredUsers {
    final query = _searchQuery.toLowerCase().trim();
    return _users.where((u) {
      if (query.isNotEmpty &&
          !u.name.toLowerCase().contains(query) &&
          !u.item.contains(query)) {
        return false;
      }
      switch (_roleFilter) {
        case _RoleFilter.all:
          break;
        case _RoleFilter.employee:
          if (u.role?.name.toUpperCase() != 'EMPLOYEE') return false;
        case _RoleFilter.admin:
          if (!u.isAdmin) return false;
        case _RoleFilter.manager:
          if (!u.managesPremise) return false;
      }
      if (_premiseFilter == _PremiseFilter.with_ && u.premise == null) {
        return false;
      }
      if (_premiseFilter == _PremiseFilter.without && u.premise != null) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _activeFilters =>
      (_roleFilter == _RoleFilter.all ? 0 : 1) +
      (_premiseFilter == _PremiseFilter.any ? 0 : 1) +
      (_searchQuery.trim().isEmpty ? 0 : 1);

  void _clearFilters() => setState(() {
    _roleFilter = _RoleFilter.all;
    _premiseFilter = _PremiseFilter.any;
    _searchQuery = '';
    _searchController.clear();
  });

  /// Predios que todavía no tienen responsable (solo puede haber uno por
  /// predio), más el predio actual de [user] si ya es su responsable.
  List<UserPremise> _availablePremises([ManagedUser? user]) => _premises
      .where(
        (p) => !_occupiedPremiseIds.contains(p.id) || p.id == user?.premise?.id,
      )
      .toList();

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userAdminService.getUsers(),
        _userAdminService.getRoles(),
        _premiseService.getPremisesWithReasons(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<ManagedUser>;
        _roles = results[1] as List<AppRole>;
        _premises = (results[2] as List)
            .map((premise) => UserPremise(id: premise.id, name: premise.name))
            .toList();
        _occupiedPremiseIds
          ..clear()
          ..addAll(
            (results[2] as List)
                .where((premise) => premise.manager != null)
                .map<int>((premise) => premise.id as int),
          );
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } catch (_) {
      _showSnackBar('No se pudo cargar la lista de usuarios', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    showAppPopup(
      context,
      message,
      kind: color == Colors.red ? PopupKind.error : PopupKind.success,
    );
  }

  /// Abre el formulario para crear un responsable de predio. Público para que
  /// "Inicio" pueda ofrecerlo como acceso directo.
  Future<void> openCreateManagerDialog() async {
    final free = _availablePremises();
    if (free.isEmpty) {
      _showSnackBar(
        _premises.isEmpty
            ? 'Primero cree un predio para poder asignárselo a un responsable.'
            : 'Todos los predios ya tienen responsable. Cambie el responsable desde Editar predio.',
        Colors.red,
      );
      return;
    }
    final created = await showDialog<CreatedManager>(
      context: context,
      builder: (context) => CreateManagerDialog(premises: free),
    );
    if (created == null || !mounted) return;
    setState(
      () =>
          _users = [..._users, created.user]
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManagerCredentialsDialog(created: created),
    );
  }

  Future<void> _openChangeRoleDialog(ManagedUser user) async {
    if (_updatingUserIds.contains(user.id) || _roles.isEmpty) return;

    final selection = await showDialog<RoleChangeSelection>(
      context: context,
      builder: (context) => ChangeRoleDialog(
        user: user,
        roles: _roles,
        premises: _availablePremises(user),
      ),
    );
    if (selection == null) return;
    await _changeUser(user, selection);
  }

  Future<void> _openDevicesDialog(ManagedUser user) async {
    if (_updatingUserIds.contains(user.id)) return;
    final platform = await showDialog<ClientPlatform>(
      context: context,
      builder: (context) => DevicesDialog(user: user),
    );
    if (platform == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppModal(
        tone: DialogTone.danger,
        icon: Icons.link_off_rounded,
        title: 'Desvincular ${platform.deviceNoun}',
        subtitle: user.name,
        maxWidth: 460,
        actions: [
          ModalButton(label: 'Cancelar', onPressed: () => Navigator.pop(context, false)),
          ModalButton(
            label: 'Desvincular',
            primary: true,
            color: AppColors.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(
          'El ${platform.deviceNoun} actual de ${user.name} dejará de '
          'funcionar en ${platform.label.toLowerCase()} y su sesión ahí se '
          'cerrará. El próximo inicio de sesión quedará vinculado al nuevo '
          '${platform.deviceNoun}.',
          style: AppText.body,
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingUserIds.add(user.id));
    try {
      await _userAdminService.resetUserDevice(user.id, platform);
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          final devices = Map.of(_users[index].devices)..remove(platform);
          _users[index] = _users[index].copyWith(devices: devices);
        }
      });
      _showSnackBar(
        '${platform.label}: ${platform.deviceNoun} de ${user.name} '
        'desvinculado. Ya puede entrar desde uno nuevo.',
        Colors.green,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _updatingUserIds.remove(user.id));
    }
  }

  Future<void> _openPasswordDialog(ManagedUser user) async {
    if (_updatingUserIds.contains(user.id)) return;
    final choice = await showDialog<PasswordChoice>(
      context: context,
      builder: (context) => ManagerPasswordDialog(user: user),
    );
    if (choice == null || !mounted) return;

    setState(() => _updatingUserIds.add(user.id));
    try {
      final generated = await _userAdminService.resetManagerPassword(
        user.id,
        password: choice.password,
      );
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(user.id));
      if (generated == null) {
        _showSnackBar('Contraseña de ${user.name} actualizada', Colors.green);
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ManagerCredentialsDialog(
            created: CreatedManager(user: user, generatedPassword: generated),
            title: 'Contraseña actualizada',
            message:
                'Nueva contraseña de ${user.name}. Las sesiones abiertas '
                'de esta cuenta se cerraron.',
          ),
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _updatingUserIds.remove(user.id));
    }
  }

  Future<void> _changeUser(
    ManagedUser user,
    RoleChangeSelection selection,
  ) async {
    setState(() => _updatingUserIds.add(user.id));
    try {
      // Rol y predio viajan en una sola petición: el servidor exige que un
      // gestor tenga predio y cierra las sesiones cuando cambian los permisos.
      final ManagedUser updated;
      if (selection.role.id != user.role?.id) {
        updated = await _userAdminService.updateUserRole(
          user.id,
          selection.role.id,
          premiseId: selection.premiseId,
        );
      } else if (selection.premiseId != null &&
          selection.premiseId != user.premise?.id) {
        updated = await _userAdminService.assignUserPremise(
          user.id,
          selection.premiseId!,
        );
      } else {
        return;
      }
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) _users[index] = updated;
      });
      final displayName = user.name.isEmpty ? 'El usuario' : user.name;
      final roleLabel = _roleLabel(selection.role);
      final premiseLabel = selection.premiseId == null
          ? ''
          : ' en ${_premises.firstWhere((p) => p.id == selection.premiseId).name}';
      _showSnackBar(
        '$displayName ahora es $roleLabel$premiseLabel',
        Colors.green,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _updatingUserIds.remove(user.id));
    }
  }

  String _roleLabel(AppRole role) {
    switch (role.name.toUpperCase()) {
      case 'ADMIN':
        return 'Administrador';
      case kManagePremiseRole:
        return 'Gestor de predio';
      case 'EMPLOYEE':
        return 'Empleado';
      default:
        return role.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryRed));
    }
    return FilterSidebarLayout(
      wideBreakpoint: 1000,
      search: _buildSearchField(),
      activeCount: _activeFilters,
      onClear: _clearFilters,
      filters: [
        FilterGroup<_RoleFilter>(
          title: 'Tipo de usuario',
          value: _roleFilter,
          options: const {
            _RoleFilter.all: 'Todos',
            _RoleFilter.employee: 'Empleados',
            _RoleFilter.admin: 'Administradores',
            _RoleFilter.manager: 'Responsables de predio',
          },
          onChanged: (v) => setState(() => _roleFilter = v),
        ),
        FilterGroup<_PremiseFilter>(
          title: 'Predio asignado',
          value: _premiseFilter,
          options: const {
            _PremiseFilter.any: 'Todos',
            _PremiseFilter.with_: 'Con predio',
            _PremiseFilter.without: 'Sin predio',
          },
          onChanged: (v) => setState(() => _premiseFilter = v),
        ),
      ],
      content: _buildContent(),
    );
  }

  Widget _buildContent() {
    final users = _filteredUsers;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= Breakpoints.tablet
            ? 24.0
            : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: AppDimens.buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: openCreateManagerDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Nuevo responsable de predio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${users.length} de ${_users.length} usuarios · '
                          'Toca a una persona para cambiar su rol.',
                          style: AppText.caption,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: darkText,
                          size: AppDimens.iconSize,
                        ),
                        tooltip: 'Actualizar',
                        onPressed: _isLoading ? null : _fetchData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: users.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron usuarios con esos filtros.',
                              style: AppText.body.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchData,
                            color: Colors.white,
                            backgroundColor: primaryRed,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: users.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildUserTile(users[index]),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o item...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: darkText,
          size: AppDimens.iconSize,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: const BorderSide(color: primaryRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildUserTile(ManagedUser user) {
    final isUpdating = _updatingUserIds.contains(user.id);
    final isAdmin = user.isAdmin;
    final roleLabel = user.role == null ? 'Sin rol' : _roleLabel(user.role!);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        onTap: isUpdating ? null : () => _openChangeRoleDialog(user),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final avatar = CircleAvatar(
                radius: 22,
                backgroundColor: isAdmin
                    ? primaryRed.withValues(alpha: 0.12)
                    : Colors.grey.shade200,
                child: Icon(
                  isAdmin ? Icons.shield_rounded : Icons.badge_rounded,
                  color: isAdmin ? primaryRed : Colors.grey.shade600,
                ),
              );
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name.isEmpty ? 'Sin nombre' : user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle,
                  ),
                  const SizedBox(height: 3),
                  Text('Item: ${user.item}', style: AppText.caption),
                  if (user.managesPremise && user.premise != null)
                    Text(
                      'Predio: ${user.premise!.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  if (user.platforms.isNotEmpty)
                    Text(
                      user.platforms
                          .map(
                            (p) =>
                                '${p.label}: ${user.devices.containsKey(p) ? 'vinculado' : 'sin vincular'}',
                          )
                          .join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                ],
              );
              final indicator = isUpdating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: primaryRed,
                      ),
                    )
                  : Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (user.managesPremise && user.username != null)
                          IconButton(
                            icon: const Icon(
                              Icons.key_rounded,
                              color: darkText,
                            ),
                            tooltip: 'Cambiar o regenerar contraseña',
                            onPressed: () => _openPasswordDialog(user),
                          ),
                        if (user.platforms.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.devices_rounded,
                              color: darkText,
                            ),
                            tooltip: 'Dispositivos',
                            onPressed: () => _openDevicesDialog(user),
                          ),
                        _RoleBadge(label: roleLabel, isAdmin: isAdmin),
                      ],
                    );

              // En pantallas muy angostas, la insignia de rol no cabe junto
              // al nombre: se acomoda debajo para que nada se recorte.
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const SizedBox(width: 14),
                        Expanded(child: info),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: indicator),
                  ],
                );
              }

              return Row(
                children: [
                  avatar,
                  const SizedBox(width: 14),
                  Expanded(child: info),
                  const SizedBox(width: 8),
                  indicator,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool isAdmin;

  const _RoleBadge({required this.label, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? AppColors.primaryRed : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primaryRed.withValues(alpha: 0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAdmin ? AppColors.primaryRed : Colors.grey.shade400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_rounded, size: 15, color: color),
        ],
      ),
    );
  }
}
