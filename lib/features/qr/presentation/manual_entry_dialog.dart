import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/dialog_tone.dart';
import '../data/qr_service.dart';
import '../models/manual_entry_step.dart';

/// Ingreso manual desde la pantalla del QR: la persona dicta su item y su
/// carnet, se validan en el sistema externo y luego elige el motivo de su
/// salida (o, si ya estaba fuera, se registra su retorno). Al terminar se
/// cierra solo y la pantalla vuelve al QR.
class ManualEntryDialog extends StatefulWidget {
  final QrService? service;

  /// Segundos que se muestra el resultado antes de volver al QR.
  final Duration resultDuration;

  const ManualEntryDialog({
    super.key,
    this.service,
    this.resultDuration = const Duration(seconds: 3),
  });

  @override
  State<ManualEntryDialog> createState() => _ManualEntryDialogState();
}

enum _Phase { form, reasons, done }

class _ManualEntryDialogState extends State<ManualEntryDialog> {
  late final QrService _service = widget.service ?? QrService();
  final _itemController = TextEditingController();
  final _carnetController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Phase _phase = _Phase.form;
  bool _busy = false;
  bool _hideCarnet = true;
  String? _error;
  ManualEntryStep? _step;
  String? _selectedReason;
  String _doneMessage = '';
  int _secondsLeft = 0;
  Timer? _ticker;
  Timer? _closeTimer;

  @override
  void dispose() {
    _ticker?.cancel();
    _closeTimer?.cancel();
    _itemController.dispose();
    _carnetController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final step = await _service.validateManualEntry(
        item: _itemController.text.trim(),
        carnet: _carnetController.text.trim(),
      );
      if (!mounted) return;
      if (step.needsReason) {
        setState(() {
          _step = step;
          _selectedReason = null;
          _phase = _Phase.reasons;
          _busy = false;
        });
        _startCountdown(step);
      } else {
        _finish('Retorno registrado. Bienvenido de regreso, ${step.person}.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  /// El comprobante dura pocos segundos: al vencer se vuelve al formulario.
  void _startCountdown(ManualEntryStep step) {
    _ticker?.cancel();
    final expires = step.ticketExpiresAt;
    if (expires == null) return;
    void tick() {
      final left = expires.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        _ticker?.cancel();
        if (!mounted || _phase != _Phase.reasons) return;
        setState(() {
          _phase = _Phase.form;
          _step = null;
          _error = 'Se agotó el tiempo para elegir el motivo. Ingrese sus datos de nuevo.';
        });
      } else if (mounted) {
        setState(() => _secondsLeft = left);
      }
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _confirm() async {
    final step = _step;
    final reason = _selectedReason;
    if (_busy || step == null || reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.confirmManualEntry(
        item: step.item,
        leaveTicket: step.leaveTicket ?? '',
        reason: reason,
      );
      if (!mounted) return;
      _finish('Salida registrada. Hasta pronto, ${step.person}.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  void _finish(String message) {
    _ticker?.cancel();
    setState(() {
      _doneMessage = message;
      _phase = _Phase.done;
      _busy = false;
    });
    _closeTimer = Timer(widget.resultDuration, () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.form => _buildForm(),
      _Phase.reasons => _buildReasons(),
      _Phase.done => _buildDone(),
    };
  }

  // ------------------------------------------------------------------ pasos

  Widget _buildForm() {
    return AppModal(
      tone: DialogTone.create,
      icon: Icons.badge_outlined,
      title: 'Ingreso manual',
      subtitle: 'Escriba su item y su carnet',
      maxWidth: 460,
      actions: [
        ModalButton(
          label: 'Cancelar',
          onPressed: _busy ? null : () => Navigator.pop(context, false),
        ),
        ModalButton(
          label: 'Validar',
          primary: true,
          color: AppColors.success,
          isLoading: _busy,
          onPressed: _validate,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _itemController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: AppText.body,
              decoration: _decoration('Item', Icons.numbers_rounded),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese su item' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _carnetController,
              obscureText: _hideCarnet,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _validate(),
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              style: AppText.body,
              decoration: _decoration('Carnet', Icons.credit_card_rounded)
                  .copyWith(
                    suffixIcon: IconButton(
                      tooltip: _hideCarnet ? 'Mostrar' : 'Ocultar',
                      icon: Icon(
                        _hideCarnet
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () =>
                          setState(() => _hideCarnet = !_hideCarnet),
                    ),
                  ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese su carnet' : null,
            ),
            if (_error != null) _ErrorNote(_error!),
          ],
        ),
      ),
    );
  }

  Widget _buildReasons() {
    final step = _step!;
    return AppModal(
      tone: DialogTone.create,
      icon: Icons.logout_rounded,
      title: 'Hola, ${step.person}',
      subtitle:
          'Elija el motivo de su salida de ${step.premise ?? 'este predio'}',
      maxWidth: 480,
      onClose: _busy ? () {} : () => Navigator.pop(context, false),
      actions: [
        ModalButton(
          label: 'Cancelar',
          onPressed: _busy ? null : () => Navigator.pop(context, false),
        ),
        ModalButton(
          label: 'Confirmar salida',
          primary: true,
          color: AppColors.success,
          isLoading: _busy,
          onPressed: _selectedReason == null ? null : _confirm,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tiene $_secondsLeft s para confirmar.', style: AppText.caption),
          const SizedBox(height: 10),
          if (step.reasons.isEmpty)
            const _ErrorNote(
              'Este predio no tiene motivos de salida habilitados.',
            )
          else
            for (final reason in step.reasons)
              _ReasonTile(
                label: reason,
                selected: reason == _selectedReason,
                onTap: _busy
                    ? null
                    : () => setState(() => _selectedReason = reason),
              ),
          if (_error != null) _ErrorNote(_error!),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return AppModal(
      tone: DialogTone.create,
      icon: Icons.check_circle_rounded,
      title: 'Listo',
      maxWidth: 440,
      onClose: () => Navigator.pop(context, true),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _doneMessage,
          textAlign: TextAlign.center,
          style: AppText.sectionTitle,
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.darkText),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  );
}

class _ErrorNote extends StatelessWidget {
  final String message;

  const _ErrorNote(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.dangerBg,
        border: Border(left: BorderSide(color: AppColors.danger, width: 5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.successBg : Colors.white,
            border: Border.all(
              color: selected ? AppColors.success : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.success : AppColors.info,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
