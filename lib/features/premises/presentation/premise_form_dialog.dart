import 'package:flutter/material.dart';

import '../../../core/constants/role_names.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/check_row.dart';
import '../../../core/widgets/dialog_tone.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../../map/models/lat_lng.dart';
import '../../map/presentation/map_library.dart';
import '../../users/data/user_admin_service.dart';
import '../../users/models/managed_user.dart';
import '../data/premise_service.dart';
import '../models/premise.dart';
import '../models/reason.dart';

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
      final List<Reason> reasons;
      final List<ManagedUser> users;
      if (widget.premiseService == null && widget.userService == null) {
        // Se usan los datos compartidos del panel: si Usuarios o Predios ya
        // los pidieron, no se vuelven a pedir; si no, se piden a la vez.
        final store = AdminDataStore.instance;
        await Future.wait([store.reasonsData.load(), store.usersData.load()]);
        final missing = [
          store.reasonsData,
          store.usersData,
        ].where((resource) => !resource.hasLoaded);
        if (missing.isNotEmpty) {
          throw ApiException(
            missing.first.error ?? 'No se pudieron cargar los datos.',
          );
        }
        reasons = store.reasons;
        users = store.users;
      } else {
        final results = await Future.wait([
          _premiseService.getAllReasons(),
          _userService.getUsers(),
        ]);
        reasons = results[0] as List<Reason>;
        users = results[1] as List<ManagedUser>;
      }
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

  InputDecoration _decoration(String label) =>
      InputDecoration(labelText: label);

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
        color: AppColors.label,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AppModal(
      tone: _isEditing ? DialogTone.configure : DialogTone.create,
      icon: _isEditing
          ? Icons.edit_location_alt_rounded
          : Icons.add_location_alt_rounded,
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
          onPressed: (_isSaving || _isLoading || _loadError != null)
              ? null
              : _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: primaryRed),
              ),
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
                border: Border(
                  left: BorderSide(color: AppColors.danger, width: 5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_rounded, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _submitError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
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
            // Tras el primer intento de guardar, el aviso se revisa al escribir
            // y desaparece en cuanto el nombre es válido.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
          ),
          _sectionTitle('Ubicación en el mapa'),
          // El mapa se descarga la primera vez que se abre este formulario.
          deferredLocationPicker(
            radiusMeters: AdminDataStore.instance.geofenceRadiusMeters,
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
            decoration: const InputDecoration(),
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
            onChanged: _isSaving ? null : (v) => setState(() => _managerId = v),
          ),
          if (_managers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Aún no hay usuarios con el rol '
                '${RoleNames.label(RoleNames.managePremise)}. '
                'Créalos en la sección Usuarios.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                warning,
                style: TextStyle(fontSize: 12, color: AppColors.warning),
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
            const gap = 18.0;
            final columns = constraints.maxWidth >= 480 ? 2 : 1;
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 2,
              children: [
                for (final reason in _availableReasons)
                  SizedBox(
                    width: tileWidth,
                    child: CheckRow(
                      label: reason.name,
                      checked: _selectedReasons.contains(reason.name),
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
