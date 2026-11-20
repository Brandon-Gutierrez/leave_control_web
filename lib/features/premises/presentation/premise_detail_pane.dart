import 'package:flutter/material.dart';

import '../../../core/constants/role_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/admin_field.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/master_detail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../map/models/lat_lng.dart';
import '../../map/presentation/map_library.dart';
import '../../users/models/managed_user.dart';
import '../models/premise.dart';
import '../models/reason.dart';
import 'premise_location_dialog.dart';

/// Lo que se guarda con «Guardar cambios»: nombre, ubicación y motivos. El
/// responsable se cambia aparte, con «Asignar».
class PremiseChanges {
  final String name;

  /// Null solo si el predio todavía no tiene ubicación ni se fijó una.
  final LatLng? position;
  final List<String> reasonNames;

  const PremiseChanges({
    required this.name,
    required this.position,
    required this.reasonNames,
  });
}

/// Estado de un predio para la lista y el detalle: en rojo cuando le falta
/// algo que impide o limita su uso (ubicación, responsable o motivos).
class PremiseStatus {
  PremiseStatus._();

  static bool hasProblem(Premise p) =>
      !p.hasLocation || p.manager == null || p.reasonNames.isEmpty;

  /// Línea de apoyo del detalle: responsable, ubicación y motivos.
  static String summary(Premise p) {
    final manager = p.manager;
    final count = p.reasonNames.length;
    return [
      manager == null ? 'Sin responsable' : 'Responsable: ${manager.name}',
      if (!p.hasLocation) 'Sin ubicación',
      count == 0
          ? 'Sin motivos habilitados'
          : count == 1
          ? '1 motivo habilitado'
          : '$count motivos habilitados',
    ].join(' · ');
  }
}

/// Detalle del predio elegido en la lista. El nombre, la ubicación y los
/// motivos se editan sobre un borrador que se guarda (o se descarta) con los
/// botones del pie; el responsable se asigna aparte, con confirmación, porque
/// cierra sesiones.
class PremiseDetailPane extends StatefulWidget {
  final Premise premise;

  /// Motivos del catálogo, para marcar los que el predio ofrece.
  final List<Reason> catalog;
  final bool reasonsLoading;
  final String? reasonsError;
  final VoidCallback onRetryReasons;

  /// Personas con rol de responsable de predio.
  final List<ManagedUser> managers;
  final bool managersLoading;
  final String? managersError;
  final VoidCallback onRetryManagers;

  /// Radio (metros) donde se aceptan los escaneos; lo define el servidor.
  final double radiusMeters;

  /// Hay un cambio de responsable en curso: se bloquea ese bloque.
  final bool assigning;

  /// Guarda el borrador; devuelve si se guardó.
  final Future<bool> Function(PremiseChanges changes) onSave;

  /// Cambia al responsable (`null` lo quita). El cuadro de confirmación lo
  /// abre quien llama.
  final ValueChanged<int?> onAssignManager;

  /// Solo en pantallas angostas: volver a la lista.
  final VoidCallback? onBack;

  const PremiseDetailPane({
    super.key,
    required this.premise,
    required this.catalog,
    required this.reasonsLoading,
    required this.reasonsError,
    required this.onRetryReasons,
    required this.managers,
    required this.managersLoading,
    required this.managersError,
    required this.onRetryManagers,
    required this.radiusMeters,
    required this.assigning,
    required this.onSave,
    required this.onAssignManager,
    this.onBack,
  });

  @override
  State<PremiseDetailPane> createState() => PremiseDetailPaneState();
}

class PremiseDetailPaneState extends State<PremiseDetailPane> {
  /// Valor del desplegable que significa «dejar sin responsable».
  static const _removeManager = -1;

  late final TextEditingController _name = TextEditingController(
    text: widget.premise.name,
  );
  late LatLng? _position = _positionOf(widget.premise);
  late Set<String> _reasons = {
    for (final r in widget.premise.reasonNames) r.name,
  };
  late int? _managerChoice = widget.premise.manager?.userId;
  bool _nameTouched = false;
  bool _saving = false;

  static LatLng? _positionOf(Premise p) =>
      p.hasLocation ? LatLng(p.latitude!, p.longitude!) : null;

  /// Hay cambios sin guardar (la lista pregunta antes de descartarlos).
  bool get hasUnsavedChanges => _differsFrom(widget.premise);

  bool _differsFrom(Premise p) {
    final saved = {for (final r in p.reasonNames) r.name};
    return _name.text.trim() != p.name ||
        _position != _positionOf(p) ||
        _reasons.length != saved.length ||
        !_reasons.containsAll(saved);
  }

  @override
  void didUpdateWidget(PremiseDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el predio cambió en el servidor y no había nada sin guardar, el
    // borrador pasa a reflejarlo; con cambios a medias se respetan.
    final cleanBefore = !_differsFrom(oldWidget.premise);
    if (cleanBefore && _differsFrom(widget.premise)) _resetDraft();
    if (oldWidget.premise.manager?.userId != widget.premise.manager?.userId) {
      _managerChoice = widget.premise.manager?.userId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _resetDraft() {
    final p = widget.premise;
    _name.text = p.name;
    _position = _positionOf(p);
    _reasons = {for (final r in p.reasonNames) r.name};
    _nameTouched = false;
  }

  void _cancel() => setState(_resetDraft);

  bool get _nameValid => _name.text.trim().isNotEmpty;

  /// Los motivos que se pueden marcar: el catálogo y, al final, los que el
  /// predio ya tenía aunque ya no estén en él (para poder quitarlos).
  List<String> get _reasonOptions {
    final names = [for (final r in widget.catalog) r.name];
    for (final r in widget.premise.reasonNames) {
      if (!names.contains(r.name)) names.add(r.name);
    }
    return names;
  }

  Future<void> _save() async {
    if (_saving || !_nameValid || !hasUnsavedChanges) return;
    setState(() => _saving = true);
    final options = _reasonOptions;
    final ok = await widget.onSave(
      PremiseChanges(
        name: _name.text.trim(),
        position: _position,
        reasonNames: [
          for (final name in options)
            if (_reasons.contains(name)) name,
          for (final name in _reasons)
            if (!options.contains(name)) name,
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    // Si no se pudo guardar, el borrador queda como estaba para reintentar.
    if (ok) setState(() => _nameTouched = false);
  }

  Future<void> _pickLocation() async {
    final picked = await showDialog<LatLng>(
      context: context,
      builder: (context) => PremiseLocationDialog(
        premiseName: _name.text.trim().isEmpty
            ? widget.premise.name
            : _name.text.trim(),
        initial: _position,
      ),
    );
    if (picked != null && mounted) setState(() => _position = picked);
  }

  void _toggleReason(String name) => setState(() {
    if (!_reasons.remove(name)) _reasons.add(name);
  });

  @override
  Widget build(BuildContext context) {
    final p = widget.premise;
    final problem = PremiseStatus.hasProblem(p);
    final dirty = hasUnsavedChanges;

    return DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Volver a la lista'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.only(right: 12),
                ),
              ),
            ),
          if (_saving || widget.assigning)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primaryRed,
              ),
            ),
          DetailHeader(
            leading: RowBadge(
              icon: Icons.place_outlined,
              size: 72,
              background: problem
                  ? const Color(0xFFFBEFEE)
                  : const Color(0xFFE4E4DF),
              foreground: problem ? AppColors.danger : const Color(0xFF444444),
            ),
            title: p.name,
            subtitle: PremiseStatus.summary(p),
            subtitleColor: problem ? AppColors.danger : AppColors.muted,
            subtitleWeight: problem ? FontWeight.w700 : null,
          ),
          DetailSection(
            label: 'Nombre del predio',
            children: [
              TextField(
                key: const ValueKey('premise-name'),
                controller: _name,
                enabled: !_saving,
                onChanged: (_) => setState(() => _nameTouched = true),
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                decoration: adminFieldDecoration(
                  errorText: _nameTouched && !_nameValid
                      ? 'Campo requerido'
                      : null,
                ),
              ),
            ],
          ),
          _buildLocation(),
          _buildManager(),
          _buildReasons(),
          Container(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.rowLine)),
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                AdminButton(
                  label: 'Cancelar',
                  height: 46,
                  onPressed: dirty && !_saving ? _cancel : null,
                ),
                AdminButton.primary(
                  label: _saving ? 'Guardando...' : 'Guardar cambios',
                  height: 46,
                  onPressed: dirty && _nameValid && !_saving ? _save : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Ubicación
  // -------------------------------------------------------------------------

  Widget _buildLocation() {
    final position = _position;
    final moved = position != _positionOf(widget.premise);
    final radius = widget.radiusMeters.round();

    final preview = deferredLocationPreview(
      position: position,
      radiusMeters: widget.radiusMeters,
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          position == null
              ? 'Sin ubicación'
              : '${position.latitude.toStringAsFixed(4)}, '
                    '${position.longitude.toStringAsFixed(4)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: position == null ? AppColors.danger : AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          position == null
              ? 'Mientras no tenga ubicación, los escaneos de este predio no '
                    'serán aceptados.'
              : 'El círculo marca los $radius m dentro de los que la persona '
                    'puede escanear el QR de este predio.',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        if (moved) ...[
          const SizedBox(height: 8),
          const Text(
            'Ubicación cambiada: se guarda con «Guardar cambios».',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ],
        const SizedBox(height: 12),
        AdminButton(
          label: position == null ? 'Fijar en el mapa' : 'Cambiar en el mapa',
          onPressed: _saving ? null : _pickLocation,
        ),
      ],
    );

    return DetailSection(
      label: 'Ubicación',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [preview, const SizedBox(height: 14), info],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: preview),
                const SizedBox(width: 18),
                Expanded(child: info),
              ],
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Responsable
  // -------------------------------------------------------------------------

  String _managerLabel(ManagedUser m) {
    final premise = m.premise;
    return premise == null || premise.id == widget.premise.id
        ? m.name
        : '${m.name} (${premise.name})';
  }

  Widget _buildManager() {
    final current = widget.premise.manager;
    final loading = widget.managersLoading && widget.managers.isEmpty;
    final failed = widget.managersError != null && widget.managers.isEmpty;

    Widget body;
    if (loading) {
      body = const SkeletonPulse(child: SkeletonBox(height: 46, radius: 8));
    } else if (failed) {
      body = LoadErrorNotice(
        message: widget.managersError!,
        onRetry: widget.onRetryManagers,
      );
    } else if (widget.managers.isEmpty && current == null) {
      body = Text(
        'Aún no hay usuarios con el rol '
        '${RoleNames.label(RoleNames.managePremise)}. '
        'Créalos en la sección Usuarios.',
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      );
    } else {
      body = _managerPicker(current);
    }

    return DetailSection(
      label: 'Responsable del predio',
      children: [
        body,
        const DetailHint(
          'El responsable muestra el QR de este predio en una pantalla fija. '
          'Si ya era responsable de otro predio, pasa a este y su sesión se '
          'cierra. Este cambio se aplica al momento, sin «Guardar cambios».',
        ),
      ],
    );
  }

  Widget _managerPicker(PremiseManager? current) {
    final items = <DropdownMenuItem<int>>[
      for (final m in widget.managers)
        DropdownMenuItem(
          value: m.id,
          child: Text(_managerLabel(m), overflow: TextOverflow.ellipsis),
        ),
      // El responsable actual puede no estar en la lista (p. ej. ya cambió de
      // rol): se ofrece igual para que el desplegable muestre quién es.
      if (current != null &&
          !widget.managers.any((m) => m.id == current.userId))
        DropdownMenuItem(
          value: current.userId,
          child: Text(current.name, overflow: TextOverflow.ellipsis),
        ),
      if (current != null)
        const DropdownMenuItem(
          value: _removeManager,
          child: Text('Sin responsable (quitar)'),
        ),
    ];
    final choice = _managerChoice;
    final unchanged = choice == null || choice == current?.userId;
    final removing = choice == _removeManager;
    final alert = current == null && choice == null;
    final busy = widget.assigning;

    final field = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: alert ? const Color(0xFFFDF6F5) : Colors.white,
        border: Border.all(
          color: alert ? AppColors.danger : AppColors.buttonLine,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: choice,
          isExpanded: true,
          hint: const Text(
            'Elegir responsable...',
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          style: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: items,
          onChanged: busy ? null : (v) => setState(() => _managerChoice = v),
        ),
      ),
    );
    final button = AdminButton.dark(
      label: removing ? 'Quitar' : 'Asignar',
      height: 46,
      onPressed: busy || unchanged
          ? null
          : () => widget.onAssignManager(removing ? null : choice),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: button),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Motivos
  // -------------------------------------------------------------------------

  /// Enlaces de texto alineados con la columna de casillas (sin sangría).
  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, 40),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(
      fontFamily: appFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _buildReasons() {
    final options = _reasonOptions;
    final loading = widget.reasonsLoading && options.isEmpty;
    final failed = widget.reasonsError != null && options.isEmpty;

    final Widget body;
    if (loading) {
      body = const SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 16),
            SizedBox(height: 14),
            SkeletonBox(height: 16),
            SizedBox(height: 14),
            SkeletonBox(height: 16),
          ],
        ),
      );
    } else if (failed) {
      body = LoadErrorNotice(
        message: widget.reasonsError!,
        onRetry: widget.onRetryReasons,
      );
    } else if (options.isEmpty) {
      body = const Text(
        'No hay motivos en el catálogo todavía.',
        style: TextStyle(fontSize: 14, color: AppColors.muted),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 18.0;
              const minWidth = 230.0;
              final columns = ((constraints.maxWidth + gap) / (minWidth + gap))
                  .floor()
                  .clamp(1, 4);
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 2,
                children: [
                  for (final name in options)
                    SizedBox(
                      width: width,
                      child: _ReasonCheck(
                        label: name,
                        checked: _reasons.contains(name),
                        onTap: _saving ? null : () => _toggleReason(name),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 20,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _reasons.addAll(options)),
                  style: _linkStyle,
                  child: const Text('Marcar todos'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => setState(_reasons.clear),
                  style: _linkStyle,
                  child: const Text('Quitar todos'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return DetailSection(
      label: 'Motivos de salida que se ofrecen',
      trailing: options.isEmpty
          ? null
          : '${options.where(_reasons.contains).length} de ${options.length}',
      children: [body],
    );
  }
}

/// Un motivo con su casilla: marcado va en negro y en negrita.
class _ReasonCheck extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback? onTap;

  const _ReasonCheck({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: checked ? AppColors.darkText : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: checked
                        ? null
                        : Border.all(
                            color: const Color(0xFFBDBDB8),
                            width: 1.5,
                          ),
                  ),
                  child: checked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                      color: checked ? AppColors.darkText : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
