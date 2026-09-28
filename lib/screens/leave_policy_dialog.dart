import 'package:flutter/material.dart';

import '../models/managed_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Formulario para definir cuántas veces puede salir un empleado (en total y
/// a un mismo predio) dentro de un período. Devuelve la política elegida, o
/// `null` para quitar el límite, o `false` si se canceló.
class LeavePolicyDialog extends StatefulWidget {
  final String userName;
  final LeavePolicy? initial;

  const LeavePolicyDialog({super.key, required this.userName, this.initial});

  @override
  State<LeavePolicyDialog> createState() => _LeavePolicyDialogState();
}

class _LeavePolicyDialogState extends State<LeavePolicyDialog> {
  static const primaryRed = AppColors.primaryRed;

  late String _period = widget.initial?.period ?? 'day';
  late final _maxExitsController = TextEditingController(
    text: widget.initial?.maxExits?.toString() ?? '',
  );
  late final _maxExitsPerPremiseController = TextEditingController(
    text: widget.initial?.maxExitsPerPremise?.toString() ?? '',
  );

  @override
  void dispose() {
    _maxExitsController.dispose();
    _maxExitsPerPremiseController.dispose();
    super.dispose();
  }

  void _save() {
    final maxExits = int.tryParse(_maxExitsController.text.trim());
    final maxExitsPerPremise = int.tryParse(
      _maxExitsPerPremiseController.text.trim(),
    );
    Navigator.pop(
      context,
      LeavePolicy(
        period: _period,
        maxExits: maxExits,
        maxExitsPerPremise: maxExitsPerPremise,
      ),
    );
  }

  InputDecoration _decoration(String label, String helper) => InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width < 480 ? width - 32 : 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Límite de salidas', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text(widget.userName, style: AppText.body),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _period,
                decoration: _decoration('Período', 'El contador se reinicia con cada período.'),
                items: [
                  for (final p in LeavePolicy.periods)
                    DropdownMenuItem(value: p, child: Text(LeavePolicy.periodLabel(p))),
                ],
                onChanged: (v) => setState(() => _period = v ?? _period),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _maxExitsController,
                keyboardType: TextInputType.number,
                decoration: _decoration(
                  'Máximo de salidas totales',
                  'Deje vacío para no limitar el total de salidas.',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _maxExitsPerPremiseController,
                keyboardType: TextInputType.number,
                decoration: _decoration(
                  'Máximo de salidas al mismo predio',
                  'Deje vacío para no limitar las salidas a un mismo lugar.',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
