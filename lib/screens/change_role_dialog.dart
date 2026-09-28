import 'package:flutter/material.dart';

import '../models/auth_user.dart' show kManagePremiseRole;
import '../models/managed_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Diálogo con opciones grandes y explicadas para cambiar el rol de un
/// usuario. Se pide confirmar con un botón aparte para evitar cambios
/// accidentales. Devuelve el [AppRole] elegido, o `null` si se canceló.
class ChangeRoleDialog extends StatefulWidget {
  final ManagedUser user;
  final List<AppRole> roles;
  final List<UserPremise> premises;

  const ChangeRoleDialog({
    super.key,
    required this.user,
    required this.roles,
    required this.premises,
  });

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  late int? _selectedRoleId = widget.user.role?.id;
  late int? _selectedPremiseId = widget.user.premise?.id;

  bool _isAdminRole(AppRole role) => role.name.toUpperCase() == 'ADMIN';
  bool _isPremiseManagerRole(AppRole role) =>
      role.name.toUpperCase() == kManagePremiseRole;

  String _displayName(AppRole role) {
    if (_isAdminRole(role)) return 'Administrador';
    if (role.name.toUpperCase() == 'EMPLOYEE') return 'Empleado';
    if (_isPremiseManagerRole(role)) return 'Gestor de predio';
    return role.name;
  }

  String _describeRole(AppRole role) {
    if (_isAdminRole(role)) {
      return 'Puede crear predios, cambiar sus motivos de salida y decidir '
          'quién más es administrador.';
    }
    if (role.name.toUpperCase() == 'EMPLOYEE') {
      return 'Solo puede escanear el código QR y registrar sus propias salidas.';
    }
    if (_isPremiseManagerRole(role)) {
      return 'Puede generar el código QR del predio asignado.';
    }
    return 'Rol del sistema.';
  }

  IconData _iconForRole(AppRole role) => _isAdminRole(role)
      ? Icons.shield_rounded
      : _isPremiseManagerRole(role)
      ? Icons.apartment_rounded
      : Icons.badge_rounded;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth < 480 ? screenWidth - 32 : 460.0;
    final matchingRoles = widget.roles
        .where((role) => role.id == _selectedRoleId)
        .toList();
    final selectedRole = matchingRoles.isEmpty ? null : matchingRoles.first;
    final isPremiseManager =
        selectedRole != null && _isPremiseManagerRole(selectedRole);
    final hasChanged =
        _selectedRoleId != widget.user.role?.id ||
        _selectedPremiseId != widget.user.premise?.id;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Cambiar rol', style: AppText.sectionTitle),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.darkText,
                    ),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                widget.user.name.isEmpty
                    ? 'Usuario sin nombre'
                    : widget.user.name,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),

              for (final role in widget.roles) ...[
                _RoleOption(
                  title: _displayName(role),
                  icon: _iconForRole(role),
                  description: _describeRole(role),
                  selected: _selectedRoleId == role.id,
                  onTap: () => setState(() {
                    _selectedRoleId = role.id;
                    if (!_isPremiseManagerRole(role)) _selectedPremiseId = null;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              if (isPremiseManager) ...[
                DropdownButtonFormField<int>(
                  key: ValueKey(_selectedPremiseId),
                  initialValue: _selectedPremiseId,
                  decoration: const InputDecoration(
                    labelText: 'Predio asignado',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final premise in widget.premises)
                      DropdownMenuItem(
                        value: premise.id,
                        child: Text(premise.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedPremiseId = value),
                ),
                if (widget.premises.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Todos los predios ya tienen responsable. Solo puede haber uno por predio: cámbielo desde Editar predio.',
                      style: AppText.caption,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),

              SizedBox(
                height: AppDimens.buttonHeight,
                child: ElevatedButton(
                  onPressed:
                      hasChanged &&
                          (!isPremiseManager || _selectedPremiseId != null)
                      ? () {
                          final role = widget.roles.firstWhere(
                            (r) => r.id == _selectedRoleId,
                          );
                          Navigator.pop(
                            context,
                            RoleChangeSelection(
                              role: role,
                              premiseId: isPremiseManager
                                  ? _selectedPremiseId
                                  : null,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar cambio'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: AppDimens.smallButtonHeight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleChangeSelection {
  final AppRole role;
  final int? premiseId;

  const RoleChangeSelection({required this.role, required this.premiseId});
}

class _RoleOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.title,
    required this.icon,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryRed.withValues(alpha: 0.06)
          : Colors.white,
      borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
            border: Border.all(
              color: selected ? AppColors.primaryRed : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primaryRed : Colors.grey.shade500,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? AppColors.primaryRed
                            : AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primaryRed : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
