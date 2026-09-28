import 'package:flutter/material.dart';

import '../models/managed_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Resultado del diálogo: [password] null significa "generar una automática".
class PasswordChoice {
  final String? password;

  const PasswordChoice(this.password);
}

/// Permite a administración regenerar o escribir una nueva contraseña para la
/// cuenta de un responsable de predio.
class ManagerPasswordDialog extends StatefulWidget {
  final ManagedUser user;

  const ManagerPasswordDialog({super.key, required this.user});

  @override
  State<ManagerPasswordDialog> createState() => _ManagerPasswordDialogState();
}

class _ManagerPasswordDialogState extends State<ManagerPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _generate = true;
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_generate && !_formKey.currentState!.validate()) return;
    Navigator.pop(context, PasswordChoice(_generate ? null : _controller.text));
  }

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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Cambiar contraseña', style: AppText.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  '${widget.user.name} (${widget.user.username ?? 'sin usuario'})',
                  style: AppText.body,
                ),
                const SizedBox(height: 16),
                RadioGroup<bool>(
                  groupValue: _generate,
                  onChanged: (v) => setState(() => _generate = v ?? true),
                  child: const Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primaryRed,
                        title: Text('Generar una contraseña nueva'),
                        subtitle: Text('Recomendado: es larga y difícil de adivinar.'),
                      ),
                      RadioListTile<bool>(
                        value: false,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primaryRed,
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
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 10)
                        ? 'Debe tener al menos 10 caracteres'
                        : null,
                    onFieldSubmitted: (_) => _confirm(),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'La contraseña anterior deja de servir y se cierran las '
                  'sesiones abiertas de esta cuenta.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                        ),
                        child: const Text('Cambiar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
