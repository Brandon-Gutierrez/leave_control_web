import 'package:flutter/material.dart';

import '../models/managed_user.dart';
import '../theme/app_colors.dart';
import '../widgets/app_modal.dart';
import '../widgets/dialog_header.dart';
import '../theme/app_text_styles.dart';

/// Resultado del diálogo: [password] null significa "generar una automática".
class PasswordChoice {
  final String? password;

  /// Ejecuta la tarea.
  const PasswordChoice(this.password);
}

/// Permite a administración regenerar o escribir una nueva contraseña para la
/// cuenta de un responsable de predio.
class ManagerPasswordDialog extends StatefulWidget {
  final ManagedUser user;

  /// Ejecuta la tarea.
  const ManagerPasswordDialog({super.key, required this.user});

  /// Crea el estado del widget.
  @override
  State<ManagerPasswordDialog> createState() => _ManagerPasswordDialogState();
}

/// Representa esta entidad.
class _ManagerPasswordDialogState extends State<ManagerPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _generate = true;
  bool _obscure = true;

  /// Libera los recursos.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ejecuta la tarea.
  void _confirm() {
    if (!_generate && !_formKey.currentState!.validate()) return;
    Navigator.pop(context, PasswordChoice(_generate ? null : _controller.text));
  }

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    return AppModal(
      tone: DialogTone.caution,
      icon: Icons.key_rounded,
      title: 'Cambiar contraseña',
      subtitle: '${widget.user.name} (${widget.user.username ?? 'sin usuario'})',
      maxWidth: 480,
      actions: [
        ModalButton(label: 'Cancelar', onPressed: () => Navigator.pop(context)),
        ModalButton(
          label: 'Cambiar',
          primary: true,
          color: AppColors.warning,
          onPressed: _confirm,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<bool>(
              groupValue: _generate,
              onChanged: (v) => setState(() => _generate = v ?? true),
              child: const Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.warning,
                    title: Text('Generar una contraseña nueva'),
                    subtitle: Text('Recomendado: es larga y difícil de adivinar.'),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.warning,
                    title: Text('Escribir una contraseña'),
                  ),
                ],
              ),
            ),
            if (!_generate) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _controller,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña (mínimo 10 caracteres)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 10)
                    ? 'Debe tener al menos 10 caracteres'
                    : null,
                onFieldSubmitted: (_) => _confirm(),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.warningBg,
                border: Border(left: BorderSide(color: AppColors.warning, width: 5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: AppColors.warning),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'La contraseña anterior deja de servir y se cierran las sesiones abiertas de esta cuenta.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
