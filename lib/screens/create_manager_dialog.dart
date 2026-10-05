import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/managed_user.dart';
import '../services/api_client.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_popup.dart';
import '../widgets/app_modal.dart';
import '../widgets/dialog_header.dart';

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
    return AppModal(
      tone: DialogTone.create,
      icon: Icons.person_add_alt_1_rounded,
      title: 'Nuevo responsable de predio',
      subtitle: 'Solo verá el código QR de su predio y no podrá cerrar sesión',
      actions: [
        ModalButton(label: 'Cancelar', onPressed: _isSaving ? null : () => Navigator.pop(context)),
        ModalButton(
          label: 'Crear cuenta',
          primary: true,
          color: AppColors.success,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
      child: Form(
          key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              ],
            ),
      ),
    );
  }
}

/// Muestra las credenciales recién creadas. La contraseña generada solo se ve
/// aquí: el servidor no la guarda en claro ni la vuelve a entregar.
class ManagerCredentialsDialog extends StatelessWidget {
  final CreatedManager created;

  /// Título del diálogo ("Cuenta creada" o "Contraseña actualizada").
  final String title;

  /// Texto bajo el título; por defecto indica el predio del responsable.
  final String? message;

  const ManagerCredentialsDialog({
    super.key,
    required this.created,
    this.title = 'Cuenta creada',
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final username = created.user.username ?? '';
    final password = created.generatedPassword;

    return AppModal(
      tone: DialogTone.create,
      icon: Icons.check_circle_rounded,
      title: title,
      subtitle: message ??
          '${created.user.name} es responsable de ${created.user.premise?.name ?? 'su predio'}.',
      maxWidth: 480,
      onClose: () => Navigator.pop(context),
      actions: [
        ModalButton(
          label: password != null ? 'Ya la guardé' : 'Listo',
          primary: true,
          color: AppColors.success,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CredentialRow(label: 'Usuario', value: username),
          if (password != null) ...[
            const SizedBox(height: 10),
            _CredentialRow(label: 'Contraseña', value: password),
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
                      'Guárdela ahora y entréguela de forma segura: por seguridad no se volverá a mostrar.',
                      style: TextStyle(fontSize: 15),
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
              showAppPopup(context, '$label copiado');
            },
          ),
        ],
      ),
    );
  }
}
