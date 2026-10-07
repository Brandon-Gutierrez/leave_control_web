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

/// Límite de salidas general: cuántas veces puede salir cada persona (en total
/// y a un mismo predio) en el período elegido. Aplica igual a todo el personal.
class LeaveLimitsDialog extends StatefulWidget {
  final SettingsService? service;

  const LeaveLimitsDialog({super.key, this.service});

  @override
  State<LeaveLimitsDialog> createState() => _LeaveLimitsDialogState();
}

class _LeaveLimitsDialogState extends State<LeaveLimitsDialog> {
  late final SettingsService _service = widget.service ?? SettingsService();
  final _total = TextEditingController();
  final _perPremise = TextEditingController();
  String _period = 'day';
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
    _perPremise.dispose();
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
        _perPremise.text = limits.maxExitsPerPremise?.toString() ?? '';
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateLeaveLimits(
        LeaveLimits(
          period: _period,
          maxExits: int.tryParse(_total.text.trim()),
          maxExitsPerPremise: int.tryParse(_perPremise.text.trim()),
        ),
      );
      if (!mounted) return;
      showAppPopup(context, 'Límite de salidas actualizado para todo el personal');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  InputDecoration _decoration(String label, String helper) => InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimens.fieldRadius)),
  );

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AppModal(
      tone: DialogTone.configure,
      icon: Icons.rule_rounded,
      title: 'Límite de salidas',
      subtitle: 'Es el mismo para todo el personal',
      actions: [
        ModalButton(label: 'Cancelar', onPressed: _saving ? null : () => Navigator.pop(context)),
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
                  'Cuando alguien llega al límite, ya no puede registrar más salidas hasta que empiece el siguiente período.',
                  style: AppText.body,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: _decoration('El conteo se reinicia', 'Semana de lunes a domingo; mes calendario.'),
                  items: [
                    for (final p in LeaveLimits.periods)
                      DropdownMenuItem(value: p, child: Text(LeaveLimits.periodLabel(p))),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? _period),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _total,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: _decoration('Máximo de salidas por persona', 'Déjelo vacío para no poner tope.'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _perPremise,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: _decoration('Máximo de salidas al mismo predio', 'Déjelo vacío para no poner tope.'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerBg,
                      border: Border(left: BorderSide(color: AppColors.danger, width: 5)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
    );
  }
}
