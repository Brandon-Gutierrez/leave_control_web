import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/managed_user.dart';
import '../services/api_client.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Formulario para crear la cuenta de un responsable de predio: una persona que
/// solo verá el código QR del predio que se le asigne aquí.
/// Devuelve el [CreatedManager] creado, o `null` si se canceló.
class CreateManagerDialog extends StatefulWidget {
  final List<UserPremise> premises;
  final UserAdminService? service;

  const CreateManagerDialog({super.key, required this.premises, this.service});

  @override
  State<CreateManagerDialog> createState() => _CreateManagerDialogState();
}

class _CreateManagerDialogState extends State<CreateManagerDialog> {
  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9_-]+$');

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final UserAdminService _service = widget.service ?? UserAdminService();

  int? _premiseId;
  bool _isSaving = false;
  bool _obscure = true;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _submitError = null;
    });
    try {
      final created = await _service.createPremiseManager(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        premiseId: _premiseId!,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _isSaving = false;
      });
    }
  }

  InputDecoration _decoration(String label, {String? helper, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth < 480 ? screenWidth - 32 : 460.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nuevo responsable de predio',
                        style: AppText.sectionTitle,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  'Solo podrá ver el código QR de su predio. No podrá cerrar '
                  'sesión ni entrar a otras secciones.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Nombre completo'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Campo requerido'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: _decoration(
                    'Usuario para iniciar sesión',
                    helper: 'Solo letras, números, guion (-) o guion bajo (_).',
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Campo requerido';
                    if (!_usernamePattern.hasMatch(value)) {
                      return 'Use solo letras, números, - o _ (sin espacios)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _premiseId,
                  isExpanded: true,
                  decoration: _decoration('Predio del que será responsable'),
                  items: [
                    for (final premise in widget.premises)
                      DropdownMenuItem(
                        value: premise.id,
                        child: Text(premise.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _premiseId = value),
                  validator: (v) => v == null ? 'Elija un predio' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: _decoration(
                    'Contraseña (opcional)',
                    helper: 'Si la deja vacía, el sistema crea una segura y se '
                        'la muestra una sola vez.',
                    suffix: IconButton(
                      tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (value.isNotEmpty && value.length < 10) {
                      return 'Debe tener al menos 10 caracteres';
                    }
                    return null;
                  },
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submitError!,
                    style: const TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: AppDimens.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Crear cuenta'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: AppDimens.smallButtonHeight,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
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

/// Muestra las credenciales recién creadas. La contraseña generada solo se ve
/// aquí: el servidor no la guarda en claro ni la vuelve a entregar.
class ManagerCredentialsDialog extends StatelessWidget {
  final CreatedManager created;

  const ManagerCredentialsDialog({super.key, required this.created});

  @override
  Widget build(BuildContext context) {
    final username = created.user.username ?? '';
    final password = created.generatedPassword;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth < 480 ? screenWidth - 32 : 460,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Cuenta creada', style: AppText.sectionTitle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${created.user.name} es responsable de '
                '${created.user.premise?.name ?? 'su predio'}.',
                style: AppText.body,
              ),
              const SizedBox(height: 16),
              _CredentialRow(label: 'Usuario', value: username),
              if (password != null) ...[
                const SizedBox(height: 10),
                _CredentialRow(label: 'Contraseña', value: password),
                const SizedBox(height: 12),
                Text(
                  'Guárdela ahora y entréguela de forma segura: por seguridad '
                  'no se volverá a mostrar.',
                  style: AppText.caption.copyWith(color: AppColors.primaryRed),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: AppDimens.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(password != null ? 'Ya la guardé' : 'Listo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption),
                SelectableText(
                  value,
                  style: AppText.cardTitle.copyWith(letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar $label',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copiado')),
              );
            },
          ),
        ],
      ),
    );
  }
}
