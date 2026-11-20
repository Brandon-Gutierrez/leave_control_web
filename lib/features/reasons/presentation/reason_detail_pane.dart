import 'package:flutter/material.dart';

import '../../../core/format/text_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_button.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/master_detail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../premises/models/premise.dart';
import '../models/reason_catalog.dart';

/// Detalle del motivo elegido en la lista: en qué predios se ofrece (cada uno
/// con su interruptor), su límite por persona y su estado en Comteco. Los
/// interruptores editan un borrador que se guarda (o se descarta) con los
/// botones del pie. Un motivo retirado por Comteco no se puede editar.
class ReasonDetailPane extends StatefulWidget {
  final CatalogReason reason;

  /// Todos los predios, para mostrar en cuáles se ofrece el motivo.
  final List<Premise> premises;
  final bool premisesLoading;
  final String? premisesError;
  final VoidCallback onRetryPremises;

  /// «1 vez por día», «Sin tope»…; null mientras se carga el límite.
  final String? limitText;

  /// Lleva a Ajustes, donde se cambia el límite.
  final VoidCallback onOpenSettings;

  /// Guarda el borrador (los predios donde debe ofrecerse); devuelve si se
  /// guardó todo.
  final Future<bool> Function(Set<int> premiseIds) onSave;

  /// Solo en pantallas angostas: volver a la lista.
  final VoidCallback? onBack;

  const ReasonDetailPane({
    super.key,
    required this.reason,
    required this.premises,
    required this.premisesLoading,
    required this.premisesError,
    required this.onRetryPremises,
    required this.limitText,
    required this.onOpenSettings,
    required this.onSave,
    this.onBack,
  });

  @override
  State<ReasonDetailPane> createState() => ReasonDetailPaneState();
}

class ReasonDetailPaneState extends State<ReasonDetailPane> {
  late Set<int> _offered = _savedOffered(widget.premises);
  bool _saving = false;

  /// Predios donde el motivo ya se ofrece (lo guardado en el servidor).
  Set<int> _savedOffered(List<Premise> premises) => {
    for (final p in premises)
      if (p.reasonNames.any((r) => r.name == widget.reason.name)) p.id,
  };

  /// Hay cambios sin guardar (la lista pregunta antes de descartarlos).
  bool get hasUnsavedChanges => _differsFrom(widget.premises);

  bool _differsFrom(List<Premise> premises) {
    final saved = _savedOffered(premises);
    return saved.length != _offered.length || !saved.containsAll(_offered);
  }

  @override
  void didUpdateWidget(ReasonDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si los predios cambiaron en el servidor y no había nada sin guardar, el
    // borrador pasa a reflejarlo; con cambios a medias se respetan.
    final cleanBefore =
        _offered.length == _savedOffered(oldWidget.premises).length &&
        _savedOffered(oldWidget.premises).containsAll(_offered);
    if (cleanBefore) _offered = _savedOffered(widget.premises);
  }

  void _cancel() => setState(() => _offered = _savedOffered(widget.premises));

  void _toggle(int premiseId) => setState(() {
    if (!_offered.remove(premiseId)) _offered.add(premiseId);
  });

  Future<void> _save() async {
    if (_saving || !hasUnsavedChanges) return;
    setState(() => _saving = true);
    await widget.onSave(Set.of(_offered));
    if (mounted) setState(() => _saving = false);
  }

  List<Premise> get _sortedPremises {
    final list = List.of(widget.premises);
    list.sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reason;
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
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primaryRed,
              ),
            ),
          _header(r),
          if (r.active) ...[
            _buildPremises(),
            DetailSection(
              label: 'Límite por persona',
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.limitText == null)
                          const SkeletonPulse(
                            child: SkeletonBox(width: 120, height: 18),
                          )
                        else
                          Text(
                            widget.limitText!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const SizedBox(height: 2),
                        const Text(
                          'Se define en Ajustes, en «Límite de salidas».',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    AdminButton(
                      label: 'Cambiar en Ajustes',
                      onPressed: widget.onOpenSettings,
                    ),
                  ],
                ),
              ],
            ),
          ] else
            DetailSection(
              label: 'Predios donde se ofrece',
              children: const [
                Text(
                  'Ya no se ofrece en ningún predio: Comteco lo retiró del '
                  'catálogo. Las salidas que ya se registraron con este '
                  'motivo se conservan en el historial.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF555555)),
                ),
              ],
            ),
          DetailSection(
            label: 'Estado en Comteco',
            children: [
              Text(
                r.active
                    ? 'Activo. Si Comteco lo retira del catálogo, deja de '
                          'ofrecerse en todos los predios y el historial se '
                          'conserva.'
                    : 'Retirado. Si Comteco lo vuelve a incluir en su '
                          'catálogo, se reactiva en la próxima sincronización.',
                style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
              ),
            ],
          ),
          if (r.active)
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
                    onPressed: dirty && !_saving ? _save : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(CatalogReason r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
              children: [
                TextSpan(text: 'Código ${r.code} · '),
                TextSpan(
                  text: r.active ? 'Activo' : 'Retirado',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: r.active ? AppColors.success : AppColors.warning,
                  ),
                ),
                const TextSpan(text: ' · viene de Comteco'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremises() {
    final premises = _sortedPremises;
    final loading = widget.premisesLoading && premises.isEmpty;
    final failed = widget.premisesError != null && premises.isEmpty;

    final Widget body;
    if (loading) {
      body = const SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 18),
            SizedBox(height: 18),
            SkeletonBox(height: 18),
            SizedBox(height: 18),
            SkeletonBox(height: 18),
          ],
        ),
      );
    } else if (failed) {
      body = LoadErrorNotice(
        message: widget.premisesError!,
        onRetry: widget.onRetryPremises,
      );
    } else if (premises.isEmpty) {
      body = const Text(
        'Todavía no hay predios. Créalos en la sección Predios.',
        style: TextStyle(fontSize: 14, color: AppColors.muted),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in premises)
            _PremiseSwitchRow(
              premise: p,
              on: _offered.contains(p.id),
              onTap: _saving ? null : () => _toggle(p.id),
            ),
        ],
      );
    }

    return DetailSection(
      label: 'Predios donde se ofrece',
      trailing: premises.isEmpty
          ? null
          : '${_offered.length} de ${premises.length}',
      children: [
        body,
        if (premises.isNotEmpty)
          const DetailHint(
            'Si lo quitas de un predio, la gente de ese predio ya no lo ve al '
            'salir. El historial de salidas se conserva.',
          ),
      ],
    );
  }
}

/// Un predio con su interruptor «Se ofrece / No se ofrece».
class _PremiseSwitchRow extends StatelessWidget {
  final Premise premise;
  final bool on;
  final VoidCallback? onTap;

  const _PremiseSwitchRow({
    required this.premise,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final manager = premise.manager;
    return Semantics(
      toggled: on,
      label: premise.name,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFEFEFEA))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      premise.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      manager == null
                          ? 'Sin responsable'
                          : 'Responsable: ${manager.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _Track(on: on),
              const SizedBox(width: 14),
              SizedBox(
                width: 92,
                child: Text(
                  on ? 'Se ofrece' : 'No se ofrece',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on ? AppColors.success : AppColors.label,
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

/// Interruptor: verde con la perilla a la derecha cuando está encendido.
class _Track extends StatelessWidget {
  final bool on;

  const _Track({required this.on});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        color: on ? AppColors.success : AppColors.buttonLine,
        borderRadius: BorderRadius.circular(13),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 120),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
