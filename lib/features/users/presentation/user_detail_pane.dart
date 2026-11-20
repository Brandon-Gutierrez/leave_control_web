import 'package:flutter/material.dart';

import '../../../core/constants/role_names.dart';
import '../../../core/format/date_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/master_detail.dart';
import '../../dashboard/presentation/user_profile_header.dart';
import '../models/managed_user.dart';

/// Detalle de la persona elegida en la lista: su rol, el predio (si es
/// responsable), su teléfono y su navegador vinculados, y el acceso de las
/// cuentas locales. Cada cambio pide confirmación en un cuadro aparte.
class UserDetailPane extends StatelessWidget {
  final ManagedUser user;

  /// Hay un cambio en curso para esta persona: los botones se deshabilitan.
  final bool busy;

  /// Quiere cambiar el rol: recibe el nombre del rol tocado (p. ej. `ADMIN`).
  final ValueChanged<String> onChangeRole;
  final VoidCallback onChangePremise;
  final ValueChanged<ClientPlatform> onResetDevice;
  final VoidCallback onChangePassword;

  /// Solo en pantallas angostas: volver a la lista.
  final VoidCallback? onBack;

  const UserDetailPane({
    super.key,
    required this.user,
    required this.busy,
    required this.onChangeRole,
    required this.onChangePremise,
    required this.onResetDevice,
    required this.onChangePassword,
    this.onBack,
  });

  /// Cuenta creada desde el sistema (con usuario y contraseña propios): solo
  /// puede ser responsable de predio.
  bool get _isLocalManager => user.username != null;

  String get _roleLabel =>
      user.role == null ? 'Sin rol' : RoleNames.label(user.role!.name);

  String get _subtitle {
    final parts = [
      if (user.item.isNotEmpty) 'Item ${user.item}',
      _roleLabel,
      _isLocalManager ? 'cuenta creada en el sistema' : 'cuenta de Comteco',
    ];
    return parts.join(' · ');
  }

  String get _roleHint {
    if (_isLocalManager) {
      return 'Esta cuenta se creó desde el sistema: solo puede ser '
          'responsable de predio.';
    }
    final base = switch (user.role?.name.toUpperCase()) {
      RoleNames.employee =>
        'Un empleado registra sus salidas desde la app móvil.',
      RoleNames.admin =>
        'Un administrador gestiona predios, usuarios y motivos desde el '
            'panel web, y también registra sus salidas.',
      RoleNames.managePremise => 'Un responsable muestra el código QR de su predio en una pantalla fija.',
      _ => 'Esta persona no tiene un rol asignado.',
    };
    return '$base Cambiar el rol pide confirmación.';
  }

  @override
  Widget build(BuildContext context) {
    final name = user.name.isEmpty ? 'Sin nombre' : user.name;
    final roles = _isLocalManager
        ? [(RoleNames.managePremise, RoleNames.label(RoleNames.managePremise))]
        : [
            (RoleNames.employee, RoleNames.label(RoleNames.employee)),
            (RoleNames.admin, RoleNames.label(RoleNames.admin)),
            (RoleNames.managePremise, RoleNames.label(RoleNames.managePremise)),
          ];
    final current = user.role?.name.toUpperCase() ?? '';

    return DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Volver a la lista'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.only(right: 12),
                ),
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primaryRed,
              ),
            ),
          DetailHeader(
            leading: UserAvatarLarge(name: name),
            title: name,
            subtitle: _subtitle,
          ),
          DetailSection(
            label: 'Rol en el sistema',
            children: [
              SegmentedChoice<String>(
                options: roles,
                selected: current,
                onChanged: busy || roles.length == 1
                    ? null
                    : (role) {
                        if (role != current) onChangeRole(role);
                      },
              ),
              DetailHint(_roleHint),
            ],
          ),
          if (user.managesPremise)
            DetailSection(
              label: 'Predio asignado',
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      user.premise?.name ?? 'Sin predio asignado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: user.premise == null
                            ? AppColors.danger
                            : AppColors.darkText,
                      ),
                    ),
                    AdminButton(
                      label: user.premise == null
                          ? 'Asignar predio'
                          : 'Cambiar predio',
                      onPressed: busy ? null : onChangePremise,
                    ),
                  ],
                ),
                const DetailHint(
                  'Cada predio tiene un solo responsable. Si el predio elegido '
                  'ya tiene uno, primero hay que cambiarlo desde Predios.',
                ),
              ],
            ),
          _DeviceSection(
            user: user,
            platform: ClientPlatform.mobile,
            busy: busy,
            onReset: onResetDevice,
          ),
          _DeviceSection(
            user: user,
            platform: ClientPlatform.web,
            busy: busy,
            onReset: onResetDevice,
          ),
          if (user.managesPremise && user.username != null)
            DetailSection(
              label: 'Acceso al panel',
              children: [
                Text(
                  'Usuario: ${user.username}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AdminButton(
                    label: 'Cambiar o regenerar contraseña',
                    onPressed: busy ? null : onChangePassword,
                  ),
                ),
                const DetailHint(
                  'Al cambiarla se cierran las sesiones abiertas de esta cuenta.',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Foto grande con las iniciales, a la izquierda del nombre.
class UserAvatarLarge extends StatelessWidget {
  final String name;

  const UserAvatarLarge({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return RowBadge(text: UserAvatar.initials(name), size: 72);
  }
}

/// El teléfono (app móvil) o el navegador (panel web) vinculados a la cuenta,
/// con su código y la fecha, y el botón para desvincularlo.
class _DeviceSection extends StatelessWidget {
  final ManagedUser user;
  final ClientPlatform platform;
  final bool busy;
  final ValueChanged<ClientPlatform> onReset;

  const _DeviceSection({
    required this.user,
    required this.platform,
    required this.busy,
    required this.onReset,
  });

  bool get _isMobile => platform == ClientPlatform.mobile;

  @override
  Widget build(BuildContext context) {
    final label = _isMobile ? 'Teléfono (app móvil)' : 'Panel web';

    if (!user.platforms.contains(platform)) {
      return DetailSection(
        label: label,
        children: [
          Text(
            _isMobile
                ? 'Este rol no usa la app móvil, no hay teléfono que vincular.'
                : 'Este rol no usa el panel web, no hay navegador que vincular.',
            style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
          ),
        ],
      );
    }

    final boundAt = user.devices[platform]?.toLocal();
    final code = user.deviceCodes[platform];
    final linked = boundAt != null;
    final noun = platform.deviceNoun;
    final icon = _isMobile ? Icons.smartphone_rounded : Icons.language_rounded;

    return DetailSection(
      label: label,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 30,
                    color: linked ? AppColors.success : AppColors.label,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          linked ? 'Vinculado' : 'Sin $noun vinculado',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          linked
                              ? 'Desde el ${DateText.dayMonthYear(boundAt)} '
                                    'a las ${DateText.hm(boundAt)}'
                              : _isMobile
                              ? 'Se vincula solo cuando inicia sesión en la app.'
                              : 'Se vincula solo cuando inicia sesión en el panel.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (linked && code != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CÓDIGO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: AppColors.label,
                    ),
                  ),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (linked) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: AdminButton.danger(
              label: 'Desvincular $noun',
              onPressed: busy ? null : () => onReset(platform),
            ),
          ),
          DetailHint(
            _isMobile
                ? 'La sesión de la app se cierra y la persona podrá vincular '
                      'otro teléfono.'
                : 'La sesión del panel se cierra y la persona podrá vincular '
                      'otro navegador.',
          ),
        ],
      ],
    );
  }
}
