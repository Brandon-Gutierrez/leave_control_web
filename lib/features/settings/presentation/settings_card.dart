import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_button.dart';

/// Tarjeta de una regla de Ajustes: un ícono, su título y su descripción,
/// luego sus campos y, al pie, los botones para guardar o descartar.
class SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Botones del pie (normalmente un [SettingsFooter]).
  final Widget? footer;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.panelLine),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 22, color: AppColors.info),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ...children,
          ?footer,
        ],
      ),
    );
  }
}

/// Un campo de la tarjeta: su rótulo, el control y una ayuda debajo.
class SettingsField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;

  const SettingsField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF444444),
              ),
            ),
          ),
          child,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                hint!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Título de un grupo de campos dentro de la tarjeta («Por persona»), con una
/// línea encima.
class SettingsGroup extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const SettingsGroup({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rowLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: AppColors.label,
            ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description!,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Pie de la tarjeta: «Cancelar» (descarta lo escrito) y «Guardar cambios».
/// Los dos esperan a que haya algo que guardar.
class SettingsFooter extends StatelessWidget {
  final bool dirty;
  final bool valid;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const SettingsFooter({
    super.key,
    required this.dirty,
    required this.valid,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(top: 20),
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
            onPressed: dirty && !saving ? onCancel : null,
          ),
          AdminButton.primary(
            label: saving ? 'Guardando...' : 'Guardar cambios',
            height: 46,
            onPressed: dirty && valid && !saving ? onSave : null,
          ),
        ],
      ),
    );
  }
}

/// Franja roja con el motivo por el que no se pudo guardar.
class SettingsErrorNote extends StatelessWidget {
  final String message;

  const SettingsErrorNote(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.dangerBg,
        border: Border(left: BorderSide(color: AppColors.danger, width: 5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
