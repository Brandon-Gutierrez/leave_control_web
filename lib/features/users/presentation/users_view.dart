import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/role_names.dart';
import '../../../core/format/text_utils.dart' as text_utils;
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/admin_page.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/dialog_tone.dart';
import '../../../core/widgets/master_detail.dart';
import '../../auth/state/session_controller.dart';
import '../../dashboard/presentation/user_profile_header.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../data/user_admin_service.dart';
import '../models/device_match.dart';
import '../models/managed_user.dart';
import 'change_role_dialog.dart';
import 'create_manager_dialog.dart';
import 'device_code_dialog.dart';
import 'manager_password_dialog.dart';
import 'user_detail_pane.dart';

/// Qué personas muestra la lista.
enum UserTab { all, employees, admins, managers }

/// Sección "Usuarios": a la izquierda la lista (con búsqueda, pestañas por
/// tipo y letras) y a la derecha el detalle de la persona elegida, donde se
/// cambia su rol y se desvincula su teléfono o navegador, siempre con
/// confirmación.
class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => UsersViewState();
}

class UsersViewState extends State<UsersView> {
  final _searchController = TextEditingController();
  final UserAdminService _userAdminService = UserAdminService();
  final AdminDataStore _store = AdminDataStore.instance;

  List<ManagedUser> _users = [];
  List<AppRole> _roles = [];
  List<UserPremise> _premises = [];
  final Set<int> _occupiedPremiseIds = {};
  UserTab _tab = UserTab.all;
  String _query = '';
  int? _selectedId;

  /// En pantallas angostas: se ve el detalle en lugar de la lista.
  bool _detailOpen = false;
  final Set<int> _updatingUserIds = {};

  @override
  void initState() {
    super.initState();
    _store.addListener(_applyStore);
    // Si los datos ya estaban cargados (otra sección los pidió) se ven al instante.
    _copyFromStore();
    // La sección solo pide la lista; los roles y predios se piden al abrir
    // los diálogos que los usan.
    unawaited(_store.usersData.load());
  }

  @override
  void dispose() {
    _store.removeListener(_applyStore);
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Datos
  // -------------------------------------------------------------------------

  /// Copia los datos compartidos cada vez que cualquier sección los actualiza.
  void _applyStore() {
    if (!mounted) return;
    setState(_copyFromStore);
  }

  void _copyFromStore() {
    _users = List.of(_store.users);
    _roles = List.of(_store.roles);
    _premises = _store.premises
        .map((premise) => UserPremise(id: premise.id, name: premise.name))
        .toList();
    _occupiedPremiseIds
      ..clear()
      ..addAll(
        _store.premises
            .where((premise) => premise.manager != null)
            .map((premise) => premise.id),
      );
  }

  /// Vuelve a pedir la lista de usuarios.
  Future<void> _reload() => _store.usersData.load(force: true);

  ManagedUser? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  static bool _inTab(ManagedUser u, UserTab tab) => switch (tab) {
    UserTab.all => true,
    UserTab.employees => u.isEmployee,
    UserTab.admins => u.isAdmin,
    UserTab.managers => u.managesPremise,
  };

  /// Los de la pestaña y la búsqueda, ordenados por nombre sin mirar
  /// mayúsculas ni tildes.
  List<ManagedUser> get _visibleUsers {
    final query = foldText(_query).trim();
    final list = _users.where((u) {
      if (!_inTab(u, _tab)) return false;
      if (query.isEmpty) return true;
      return foldText(u.name).contains(query) || u.item.contains(query);
    }).toList();
    list.sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));
    return list;
  }

  /// Predios que todavía no tienen responsable (solo puede haber uno por
  /// predio), más el predio actual de [user] si ya es su responsable.
  List<UserPremise> _availablePremises([ManagedUser? user]) => _premises
      .where(
        (p) => !_occupiedPremiseIds.contains(p.id) || p.id == user?.premise?.id,
      )
      .toList();

  /// Pide lo que un diálogo necesita (roles, predios...) solo cuando se abre.
  /// Devuelve false —y avisa— si alguno no se pudo cargar.
  Future<bool> _ensureLoaded(List<StoreResource<Object?>> needed) async {
    await Future.wait([for (final resource in needed) resource.load()]);
    final failed = needed.where((r) => !r.hasLoaded).toList();
    if (failed.isEmpty) return true;
    _showSnackBar(
      failed.first.error ?? 'No se pudieron cargar los datos.',
      AppColors.danger,
    );
    return false;
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    showAppPopup(
      context,
      message,
      kind: color == AppColors.danger ? PopupKind.error : PopupKind.success,
    );
  }

  // -------------------------------------------------------------------------
  // Texto de la lista
  // -------------------------------------------------------------------------

  /// Línea bajo el nombre: item y rol, o el predio si es responsable.
  static String subtitleOf(ManagedUser u) {
    if (u.managesPremise) {
      final premise = u.premise?.name;
      return premise == null
          ? 'Responsable sin predio asignado'
          : 'Responsable de $premise';
    }
    final role = u.role == null ? 'Sin rol' : RoleNames.label(u.role!.name);
    return u.item.isEmpty ? role : 'Item ${u.item} · $role';
  }

  /// Nota a la derecha: qué dispositivos tiene vinculados. En ámbar si le
  /// falta alguno que su rol usa.
  static (String, Color) deviceNote(ManagedUser u) {
    final mobile = u.devices.containsKey(ClientPlatform.mobile);
    final web = u.devices.containsKey(ClientPlatform.web);
    final usesMobile = u.platforms.contains(ClientPlatform.mobile);
    final usesWeb = u.platforms.contains(ClientPlatform.web);
    if (!usesMobile && !usesWeb) return ('', AppColors.muted);

    final linked = [if (mobile) 'teléfono', if (web) 'web'];
    if (linked.isEmpty) {
      final text = usesMobile && usesWeb
          ? 'sin vincular'
          : usesMobile
          ? 'sin teléfono'
          : 'sin navegador';
      return (text, AppColors.warning);
    }
    if (mobile && web) return ('teléfono + web', AppColors.success);
    if (web && !usesMobile) return ('navegador', AppColors.success);
    return (linked.join(' + '), AppColors.success);
  }

  // -------------------------------------------------------------------------
  // Acciones
  // -------------------------------------------------------------------------

  /// Abre el formulario para crear un responsable de predio. Público para que
  /// "Inicio" pueda ofrecerlo como acceso directo.
  Future<void> openCreateManagerDialog() async {
    // Los predios solo hacen falta aquí, para elegir el predio del responsable.
    if (!await _ensureLoaded([_store.premisesData]) || !mounted) return;
    final free = _availablePremises();
    if (free.isEmpty) {
      _showSnackBar(
        _premises.isEmpty
            ? 'Primero cree un predio para poder asignárselo a un responsable.'
            : 'Todos los predios ya tienen responsable. Cambie el responsable en la sección Predios.',
        AppColors.danger,
      );
      return;
    }
    final created = await showDialog<CreatedManager>(
      context: context,
      builder: (context) => CreateManagerDialog(premises: free),
    );
    if (created == null || !mounted) return;
    unawaited(_store.refreshQuietly());
    setState(() {
      _users = [..._users, created.user];
      // La nueva cuenta queda elegida en el detalle.
      _selectedId = created.user.id;
      _detailOpen = true;
      _tab = UserTab.all;
      _query = '';
      _searchController.clear();
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManagerCredentialsDialog(created: created),
    );
  }

  /// Busca por el código que la persona ve en su app (y dicta a RR. HH.) a
  /// quién está vinculado ese teléfono y permite desvincularlo.
  Future<void> openDeviceCodeSearch() async {
    final match = await showDialog<DeviceMatch>(
      context: context,
      builder: (context) => const DeviceCodeDialog(),
    );
    if (match == null || !mounted) return;
    await _confirmAndResetDevice(match.userId, match.name, match.platform);
  }

  /// Abre el cuadro de cambio de rol (y de predio, si es responsable). Con
  /// [roleName] sale elegido ese rol; sin él, el actual (para cambiar solo el
  /// predio).
  Future<void> _openChangeRoleDialog(
    ManagedUser user, {
    String? roleName,
  }) async {
    if (_updatingUserIds.contains(user.id)) return;

    // Un administrador no se cambia su propio rol: otro administrador lo hace.
    if (SessionController.instance.user.value?.id == user.id) {
      _showSnackBar(
        'No puede cambiar su propio rol. Pídalo a otro administrador.',
        AppColors.warning,
      );
      return;
    }

    // Los roles y los predios se piden la primera vez que se abre este diálogo.
    setState(() => _updatingUserIds.add(user.id));
    final ready = await _ensureLoaded([_store.rolesData, _store.premisesData]);
    if (!mounted) return;
    setState(() => _updatingUserIds.remove(user.id));
    if (!ready) return;

    // Las cuentas creadas desde el sistema (con usuario y contraseña propios)
    // solo pueden ser responsables de predio: no se les ofrece otro rol.
    final roles = user.username == null
        ? _roles
        : _roles
              .where((r) => RoleNames.matches(r.name, RoleNames.managePremise))
              .toList();
    if (roles.isEmpty) return;

    int? initial;
    if (roleName != null) {
      for (final role in roles) {
        if (RoleNames.matches(role.name, roleName)) initial = role.id;
      }
    }

    final selection = await showDialog<RoleChangeSelection>(
      context: context,
      builder: (context) => ChangeRoleDialog(
        user: user,
        roles: roles,
        premises: _availablePremises(user),
        initialRoleId: initial,
      ),
    );
    if (selection == null) return;
    await _changeUser(user, selection);
  }

  /// Pide confirmación y desvincula el dispositivo de la cuenta en [platform].
  Future<void> _confirmAndResetDevice(
    int userId,
    String userName,
    ClientPlatform platform,
  ) async {
    if (_updatingUserIds.contains(userId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppModal(
        tone: DialogTone.danger,
        icon: Icons.link_off_rounded,
        title: 'Desvincular ${platform.deviceNoun}',
        subtitle: userName,
        maxWidth: 460,
        actions: [
          ModalButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(context, false),
          ),
          ModalButton(
            label: 'Desvincular',
            primary: true,
            color: AppColors.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(
          'El ${platform.deviceNoun} actual de $userName dejará de '
          'funcionar en ${platform.label.toLowerCase()} y su sesión ahí se '
          'cerrará. El próximo inicio de sesión quedará vinculado al nuevo '
          '${platform.deviceNoun}.',
          style: AppText.body,
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingUserIds.add(userId));
    try {
      await _userAdminService.resetUserDevice(userId, platform);
      unawaited(_store.refreshQuietly());
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == userId);
        if (index != -1) {
          final devices = Map.of(_users[index].devices)..remove(platform);
          final codes = Map.of(_users[index].deviceCodes)..remove(platform);
          _users[index] = _users[index].copyWith(
            devices: devices,
            deviceCodes: codes,
          );
        }
      });
      _showSnackBar(
        '${platform.label}: ${platform.deviceNoun} de $userName '
        'desvinculado. Ya puede entrar desde uno nuevo.',
        AppColors.success,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _store.sessionExpired();
        return;
      }
      _showSnackBar(e.message, AppColors.danger);
    } finally {
      if (mounted) setState(() => _updatingUserIds.remove(userId));
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
      unawaited(_store.refreshQuietly());
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(user.id));
      if (generated == null) {
        _showSnackBar(
          'Contraseña de ${user.name} actualizada',
          AppColors.success,
        );
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
        _store.sessionExpired();
        return;
      }
      _showSnackBar(e.message, AppColors.danger);
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
      unawaited(_store.refreshQuietly());
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) _users[index] = updated;
      });
      final displayName = user.name.isEmpty ? 'El usuario' : user.name;
      final roleLabel = RoleNames.label(selection.role.name);
      final premiseLabel = selection.premiseId == null
          ? ''
          : ' en ${_premises.firstWhere((p) => p.id == selection.premiseId).name}';
      _showSnackBar(
        '$displayName ahora es $roleLabel$premiseLabel',
        AppColors.success,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _store.sessionExpired();
        return;
      }
      _showSnackBar(e.message, AppColors.danger);
    } finally {
      if (mounted) setState(() => _updatingUserIds.remove(user.id));
    }
  }

  // -------------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = _store.usersData;
    final visible = _visibleUsers;
    final selected = _selected;

    return AdminPage(
      title: 'Usuarios',
      subtitle: 'Elige a una persona de la lista para ver y cambiar su rol y su teléfono.',
      onRefresh: _reload,
      actions: [
        AdminButton(
          label: 'Buscar por código de dispositivo',
          onPressed: openDeviceCodeSearch,
        ),
        AdminButton.primary(
          label: '+ Nuevo responsable de predio',
          onPressed: openCreateManagerDialog,
        ),
      ],
      child: MasterDetailLayout(
        showDetail: _detailOpen && selected != null,
        master: MasterList<ManagedUser>(
          searchHint: 'Buscar por nombre o item...',
          searchController: _searchController,
          onSearch: (value) => setState(() => _query = value),
          tabs: [
            ListTabSpec('Todos', _users.length),
            ListTabSpec(
              'Empleados',
              _users.where((u) => _inTab(u, UserTab.employees)).length,
            ),
            ListTabSpec(
              'Admin',
              _users.where((u) => _inTab(u, UserTab.admins)).length,
            ),
            ListTabSpec(
              'Responsables',
              _users.where((u) => _inTab(u, UserTab.managers)).length,
            ),
          ],
          tabIndex: _tab.index,
          onTab: (i) => setState(() => _tab = UserTab.values[i]),
          items: visible,
          groupOf: (u) => groupLetterOf(u.name),
          loading: data.isInitialLoad,
          error: data.hasFailed && !data.hasLoaded
              ? (data.error ?? 'No se pudo cargar la lista de usuarios')
              : null,
          onRetry: _reload,
          emptyText: 'No se encontraron usuarios con esos filtros.',
          onTap: (u) => setState(() {
            _selectedId = u.id;
            _detailOpen = true;
          }),
          rowBuilder: (context, u) {
            final (note, color) = deviceNote(u);
            return MasterRowTile(
              leading: RowBadge(text: UserAvatar.initials(u.name)),
              title: u.name.isEmpty ? 'Sin nombre' : u.name,
              subtitle: subtitleOf(u),
              note: note.isEmpty ? null : note,
              noteColor: color,
              selected: u.id == _selectedId,
            );
          },
        ),
        detailBuilder: (narrow) => selected == null
            ? const DetailPlaceholder(
                title: 'Elige a una persona de la lista',
                hint: 'Aquí verás su rol, su teléfono y su navegador.',
              )
            : UserDetailPane(
                key: ValueKey(selected.id),
                user: selected,
                busy: _updatingUserIds.contains(selected.id),
                onChangeRole: (role) =>
                    _openChangeRoleDialog(selected, roleName: role),
                onChangePremise: () => _openChangeRoleDialog(selected),
                onResetDevice: (platform) => _confirmAndResetDevice(
                  selected.id,
                  selected.name,
                  platform,
                ),
                onChangePassword: () => _openPasswordDialog(selected),
                onBack: narrow
                    ? () => setState(() => _detailOpen = false)
                    : null,
              ),
      ),
    );
  }

  /// La inicial para agrupar la lista (ver [groupLetterOf]).
  static String groupLetterOf(String name) => text_utils.groupLetterOf(name);

  /// El texto en minúsculas y sin tildes (ver [foldText]).
  static String foldText(String text) => text_utils.foldText(text);
}
