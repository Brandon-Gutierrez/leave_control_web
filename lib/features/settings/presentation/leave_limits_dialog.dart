import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/dialog_tone.dart';
import '../data/settings_service.dart';
import '../models/leave_limits.dart';

/// Límites de salidas, iguales para todo el personal:
/// - por persona: cuántas salidas en total en el período;
/// - por motivo: cuántas veces puede elegir un mismo motivo, con un tope
///   general (el mismo para cada motivo) o uno personalizado por motivo.
class LeaveLimitsDialog extends StatefulWidget {
  final SettingsService? service;

  const LeaveLimitsDialog({super.key, this.service});

  @override
  State<LeaveLimitsDialog> createState() => _LeaveLimitsDialogState();
}

class _LeaveLimitsDialogState extends State<LeaveLimitsDialog> {
  late final SettingsService _service = widget.service ?? SettingsService();
  final _total = TextEditingController();
  final _reasonGeneral = TextEditingController();
  final Map<int, TextEditingController> _reasonCaps = {};
  List<ReasonCap> _reasons = [];
  String _period = 'day';
  String _reasonPeriod = 'day';
  String _reasonMode = ReasonLimit.general;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _total.dispose();
    _reasonGeneral.dispose();
    for (final c in _reasonCaps.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final limits = await _service.getLeaveLimits();
      if (!mounted) return;
      setState(() {
        _period = limits.period;
        _total.text = limits.maxExits?.toString() ?? '';
        final reasonLimit = limits.reasonLimit;
        _reasonPeriod = reasonLimit.period;
        _reasonMode = reasonLimit.mode;
        _reasonGeneral.text = reasonLimit.maxGeneral?.toString() ?? '';
        _reasons = reasonLimit.caps;
        for (final c in _reasonCaps.values) {
          c.dispose();
        }
        _reasonCaps
          ..clear()
          ..addEntries([
            for (final cap in _reasons)
              MapEntry(
                cap.reasonId,
                TextEditingController(text: cap.max?.toString() ?? ''),
              ),
          ]);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Vacío = sin tope; 0 no es un tope válido.
  ({bool valid, int? value}) _parse(String text) {
    final value = int.tryParse(text.trim());
    return (valid: value == null || value >= 1, value: value);
  }

  Future<void> _save() async {
    final total = _parse(_total.text);
    final general = _parse(_reasonGeneral.text);
    final caps = [
      for (final cap in _reasons)
        (cap: cap, parsed: _parse(_reasonCaps[cap.reasonId]!.text)),
    ];
    final invalid =
        !total.valid ||
        (_reasonMode == ReasonLimit.general && !general.valid) ||
        (_reasonMode == ReasonLimit.custom && caps.any((c) => !c.parsed.valid));
    if (invalid) {
      setState(
        () => _error =
            'Los topes deben ser 1 o más. Déjelo vacío para no poner tope.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateLeaveLimits(
        LeaveLimits(
          period: _period,
          maxExits: total.value,
          reasonLimit: ReasonLimit(
            period: _reasonPeriod,
            mode: _reasonMode,
            maxGeneral: general.value,
            caps: [
              for (final c in caps)
                ReasonCap(
                  reasonId: c.cap.reasonId,
                  name: c.cap.name,
                  max: c.parsed.value,
                ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      showAppPopup(
        context,
        'Límites de salidas actualizados para todo el personal',
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  InputDecoration _decoration(String label, [String? helper, String? hint]) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        hintText: hint,
        helperMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        ),
      );

  Widget _periodField(String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: _decoration(
          'El conteo se reinicia',
          'Semana de lunes a domingo; mes calendario.',
        ),
        items: [
          for (final p in LeaveLimits.periods)
            DropdownMenuItem(value: p, child: Text(LeaveLimits.periodLabel(p))),
        ],
        onChanged: (v) => onChanged(v ?? value),
      );

  @override
  Widget build(BuildContext context) {
    return AppModal(
      tone: DialogTone.configure,
      icon: Icons.rule_rounded,
      title: 'Límite de salidas',
      subtitle: 'Es el mismo para todo el personal',
      maxWidth: 580,
      actions: [
        ModalButton(
          label: 'Cancelar',
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        ModalButton(
          label: 'Guardar',
          primary: true,
          color: AppColors.info,
          isLoading: _saving,
          onPressed: _loading ? null : _save,
        ),
      ],
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.info),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cuando alguien llega a un límite, ya no puede registrar más '
                  'salidas hasta que empiece el siguiente período.',
                  style: AppText.body,
                ),
                const SizedBox(height: 20),
                ..._personSection(),
                const SizedBox(height: 26),
                ..._reasonSection(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorNote(_error!),
                ],
              ],
            ),
    );
  }

  List<Widget> _personSection() => [
    const _SectionTitle(
      'Por persona',
      'Cuántas salidas puede hacer cada persona en total, sin importar el motivo.',
    ),
    const SizedBox(height: 14),
    _periodField(_period, (v) => setState(() => _period = v)),
    const SizedBox(height: 16),
    TextField(
      key: const ValueKey('limit-person'),
      controller: _total,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(
        'Máximo de salidas por persona',
        'Déjelo vacío para no poner tope.',
      ),
    ),
  ];

  List<Widget> _reasonSection() => [
    const _SectionTitle(
      'Por motivo',
      'Cuántas veces puede cada persona elegir un mismo motivo. Al llegar al '
          'tope, ese motivo aparece como no permitido.',
    ),
    const SizedBox(height: 14),
    _periodField(_reasonPeriod, (v) => setState(() => _reasonPeriod = v)),
    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: _ModeOption(
            key: const ValueKey('mode-general'),
            title: 'General',
            description: 'El mismo tope para todos los motivos.',
            selected: _reasonMode == ReasonLimit.general,
            onTap: () => setState(() => _reasonMode = ReasonLimit.general),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeOption(
            key: const ValueKey('mode-custom'),
            title: 'Personalizado',
            description: 'Un tope distinto por cada motivo.',
            selected: _reasonMode == ReasonLimit.custom,
            onTap: () => setState(() => _reasonMode = ReasonLimit.custom),
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),
    if (_reasonMode == ReasonLimit.general)
      TextField(
        key: const ValueKey('limit-reason-general'),
        controller: _reasonGeneral,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _decoration(
          'Máximo de veces por motivo',
          'Se aplica a cada motivo por separado. Déjelo vacío para no poner tope.',
        ),
      )
    else
      ..._customList(),
  ];

  List<Widget> _customList() {
    if (_reasons.isEmpty) {
      return [
        Text(
          'Todavía no hay motivos de salida. Sincronícelos desde Inicio.',
          style: AppText.caption,
        ),
      ];
    }
    return [
      Text(
        'Escriba el máximo de veces para cada motivo. Los que deje vacíos no '
        'tienen tope.',
        style: AppText.caption,
      ),
      const SizedBox(height: 10),
      for (final cap in _reasons)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cap.name,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TextField(
                  key: ValueKey('limit-reason-${cap.reasonId}'),
                  controller: _reasonCaps[cap.reasonId],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Sin tope',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String description;

  const _SectionTitle(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.sectionTitle),
        const SizedBox(height: 2),
        Text(description, style: AppText.caption),
        const Divider(height: 16, color: AppColors.line),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.info : AppColors.darkText;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.infoBg : Colors.white,
          border: Border.all(
            color: selected ? AppColors.info : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.info : AppColors.line,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  final String message;

  const _ErrorNote(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.dangerBg,
        border: Border(left: BorderSide(color: AppColors.danger, width: 5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
