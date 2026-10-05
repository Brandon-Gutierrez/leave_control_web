import 'package:flutter/material.dart';

import '../models/lat_lng.dart';

import '../models/managed_user.dart';
import '../models/premise_model.dart';
import '../services/api_client.dart';
import '../services/premise_service.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_modal.dart';
import '../widgets/dialog_header.dart';
import '../widgets/location_picker.dart';

/// Formulario para crear o editar un predio: nombre, ubicación en el mapa,
/// responsable y motivos de salida. Devuelve `true` si se guardó.
class PremiseFormDialog extends StatefulWidget {
  /// Predio a editar; null crea uno nuevo.
  final Premise? premise;

  final PremiseService? premiseService;
  final UserAdminService? userService;

  const PremiseFormDialog({
    super.key,
    this.premise,
    this.premiseService,
    this.userService,
  });

  @override
  State<PremiseFormDialog> createState() => _PremiseFormDialogState();
}

class _PremiseFormDialogState extends State<PremiseFormDialog> {
  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.premise?.name ?? '',
  );
  late final PremiseService _premiseService =
      widget.premiseService ?? PremiseService();
  late final UserAdminService _userService =
      widget.userService ?? UserAdminService();

  bool get _isEditing => widget.premise != null;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _submitError;
  List<Reason> _availableReasons = [];
  List<ManagedUser> _managers = [];
  late final Set<String> _selectedReasons = {
    ...?widget.premise?.reasonNames.map((r) => r.name),
  };
  late int? _managerId = widget.premise?.manager?.userId;
  late LatLng? _position = widget.premise?.hasLocation == true
      ? LatLng(widget.premise!.latitude!, widget.premise!.longitude!)
      : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final reasons = await _premiseService.getAllReasons();
      final users = await _userService.getUsers();
      if (!mounted) return;
      setState(() {
        _availableReasons = reasons;
        _managers = users.where((u) => u.managesPremise).toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  ManagedUser? get _selectedManager {
    for (final m in _managers) {
      if (m.id == _managerId) return m;
    }
    return null;
  }

  /// Aviso cuando el cambio de responsable afecta a otra cuenta o predio.
  String? get _managerWarning {
    final original = widget.premise?.manager;
    final selected = _selectedManager;
    final notes = <String>[];
    if (original != null && original.userId != _managerId) {
      notes.add(
        '${original.name} dejará de ser responsable y su sesión se cerrará.',
      );
    }
    if (selected != null &&
        selected.premise != null &&
        selected.premise!.id != widget.premise?.id) {
      notes.add(
        '${selected.name} pasará de "${selected.premise!.name}" a este predio.',
      );
    }
    return notes.isEmpty ? null : notes.join(' ');
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final position = _position;
    if (position == null) {
      setState(
        () => _submitError = 'Toca el mapa para fijar la ubicación del predio.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _submitError = null;
    });

    try {
      final name = _nameController.text.trim();
      final reasons = _selectedReasons.toList();
      if (_isEditing) {
        await _premiseService.updatePremise(
          widget.premise!.id,
          name: name,
          latitude: position.latitude,
          longitude: position.longitude,
          reasonNames: reasons,
          managerUserId: _managerId,
        );
      } else {
        await _premiseService.createPremise(
          name: name,
          latitude: position.latitude,
          longitude: position.longitude,
          reasonNames: reasons,
          managerUserId: _managerId,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _isSaving = false;
      });
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: primaryRed, width: 1.5),
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: darkText,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AppModal(
      tone: _isEditing ? DialogTone.configure : DialogTone.create,
      icon: _isEditing ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
      title: _isEditing ? 'Editar predio' : 'Nuevo predio',
      subtitle: _isEditing
          ? widget.premise!.name
          : 'Nombre, ubicación en el mapa, responsable y motivos',
      maxWidth: 760,
      onClose: _isSaving ? () {} : () => Navigator.pop(context, false),
      actions: [
        ModalButton(
          label: 'Cancelar',
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
        ),
        ModalButton(
          label: _isEditing ? 'Guardar cambios' : 'Crear predio',
          primary: true,
          color: _isEditing ? AppColors.info : AppColors.success,
          isLoading: _isSaving,
          onPressed: (_isSaving || _isLoading || _loadError != null) ? null : _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(color: primaryRed)),
            )
          else if (_loadError != null)
            _buildLoadError()
          else
            _buildForm(),
          if (_submitError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.dangerBg,
                border: Border(left: BorderSide(color: AppColors.danger, width: 5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_rounded, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _submitError!,
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final warning = _managerWarning;
    return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: darkText, fontSize: 15),
              decoration: _decoration('Nombre del predio'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            _sectionTitle('Ubicación en el mapa'),
            LocationPicker(
              initial: _position,
              onChanged: (p) => setState(() {
                _position = p;
                _submitError = null;
              }),
            ),
            _sectionTitle('Responsable del predio'),
            DropdownButtonFormField<int?>(
              key: ValueKey('manager-$_managerId'),
              initialValue: _managerId,
              isExpanded: true,
              decoration: _decoration('Responsable'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin responsable'),
                ),
                for (final m in _managers)
                  DropdownMenuItem<int?>(
                    value: m.id,
                    child: Text(
                      m.premise == null
                          ? m.name
                          : '${m.name} (${m.premise!.name})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _isSaving
                  ? null
                  : (v) => setState(() => _managerId = v),
            ),
            if (_managers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Aún no hay usuarios con el rol MANAGE_PREMISE. Créalos en la sección Usuarios.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            if (warning != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  warning,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ),
            _sectionTitle('Motivos de salida permitidos'),
            _buildReasonsPicker(),
          ],
      ),
    );
  }

  /// Motivos en dos columnas: cada uno es un botón grande que se marca al
  /// tocarlo, con contador y atajos "Todos" / "Ninguno".
  Widget _buildReasonsPicker() {
    if (_availableReasons.isEmpty) {
      return Text(
        'No hay motivos en el catálogo todavía.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );
    }
    final total = _availableReasons.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_selectedReasons.length} de $total seleccionados',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
            TextButton(
              onPressed: () => setState(
                () => _selectedReasons.addAll(
                  _availableReasons.map((r) => r.name),
                ),
              ),
              child: const Text('Todos'),
            ),
            TextButton(
              onPressed: () => setState(_selectedReasons.clear),
              child: const Text('Ninguno'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final tileWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final reason in _availableReasons)
                  SizedBox(
                    width: tileWidth,
                    child: _ReasonTile(
                      label: reason.name,
                      selected: _selectedReasons.contains(reason.name),
                      onTap: () => setState(() {
                        if (!_selectedReasons.remove(reason.name)) {
                          _selectedReasons.add(reason.name);
                        }
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const red = AppColors.primaryRed;
    return Material(
      color: selected ? red.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? red : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? red : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.darkText,
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
