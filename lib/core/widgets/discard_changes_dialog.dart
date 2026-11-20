import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_modal.dart';
import 'dialog_tone.dart';

/// Pregunta si se descartan los cambios sin guardar de un detalle (al elegir
/// otro elemento de la lista o al volver a ella). Devuelve true si se aceptó
/// perderlos.
Future<bool> confirmDiscardChanges(
  BuildContext context, {
  String? subtitle,
  required String description,
}) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AppModal(
      tone: DialogTone.caution,
      icon: Icons.edit_off_rounded,
      title: 'Cambios sin guardar',
      subtitle: subtitle,
      maxWidth: 460,
      actions: [
        ModalButton(
          label: 'Seguir editando',
          onPressed: () => Navigator.pop(context, false),
        ),
        ModalButton(
          label: 'Descartar',
          primary: true,
          color: AppColors.warning,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
      child: Text(
        '$description Si sigue, esos cambios se pierden.',
        style: AppText.body,
      ),
    ),
  );
  return discard == true;
}
