import 'package:flutter/material.dart';

import '../models/managed_user.dart';
import '../services/api_client.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'change_role_dialog.dart';

/// Sección "Usuarios" del panel de administración: busca usuarios y permite
/// otorgar o quitar el rol de administrador, siempre con una confirmación
/// explicada en palabras simples.
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

  List<ManagedUser> _users = [];
  List<AppRole> _roles = [];
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
    if (query.isEmpty) return _users;
    return _users
        .where((u) =>
            u.name.toLowerCase().contains(query) || u.item.contains(query))
        .toList();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userAdminService.getUsers(),
        _userAdminService.getRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<ManagedUser>;
        _roles = results[1] as List<AppRole>;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openChangeRoleDialog(ManagedUser user) async {
    if (_updatingUserIds.contains(user.id) || _roles.isEmpty) return;

    final newRole = await showDialog<AppRole>(
      context: context,
      builder: (context) => ChangeRoleDialog(user: user, roles: _roles),
    );
    if (newRole == null) return;
    await _changeRole(user, newRole);
  }

  Future<void> _changeRole(ManagedUser user, AppRole newRole) async {
    setState(() => _updatingUserIds.add(user.id));
    try {
      final updated = await _userAdminService.updateUserRole(user.id, newRole.id);
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) _users[index] = updated;
      });
      final displayName = user.name.isEmpty ? 'El usuario' : user.name;
      final roleLabel = newRole.name.toUpperCase() == 'ADMIN' ? 'Administrador' : 'Empleado';
      _showSnackBar('$displayName ahora es $roleLabel', Colors.green);
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

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: primaryRed))
        : LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontalPadding = width >= Breakpoints.tablet ? 32.0 : 16.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Toca a una persona para cambiar su rol.',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _buildSearchField()),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: darkText, size: AppDimens.iconSize),
                              tooltip: 'Actualizar',
                              onPressed: _isLoading ? null : _fetchData,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Expanded(
                          child: _filteredUsers.isEmpty
                              ? Center(
                                  child: Text(
                                    'No se encontraron usuarios.',
                                    style: AppText.body.copyWith(color: Colors.grey.shade600),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _fetchData,
                                  color: Colors.white,
                                  backgroundColor: primaryRed,
                                  child: ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: _filteredUsers.length,
                                    itemBuilder: (context, index) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildUserTile(_filteredUsers[index]),
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
        prefixIcon: const Icon(Icons.search_rounded, color: darkText, size: AppDimens.iconSize),
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
    final roleLabel = user.role == null
        ? 'Sin rol'
        : isAdmin
            ? 'Administrador'
            : 'Empleado';

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
                ],
              );
              final indicator = isUpdating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: primaryRed),
                    )
                  : _RoleBadge(label: roleLabel, isAdmin: isAdmin);

              // En pantallas muy angostas, la insignia de rol no cabe junto
              // al nombre: se acomoda debajo para que nada se recorte.
              if (constraints.maxWidth < 340) {
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
        color: isAdmin ? AppColors.primaryRed.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAdmin ? AppColors.primaryRed : Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_rounded, size: 15, color: color),
        ],
      ),
    );
  }
}
