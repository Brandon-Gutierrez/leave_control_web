import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AdminButtonKind { primary, secondary, dark, danger }

/// Botón de las barras de herramientas y de los formularios del panel: 42 px de
/// alto, esquinas de 8 px y el texto en negrita. El principal es rojo; el
/// secundario, blanco con borde; el oscuro, negro; y el de peligro, blanco con
/// borde y texto rojos (desvincular, quitar…).
class AdminButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AdminButtonKind kind;
  final IconData? icon;

  /// Alto del botón; 42 por defecto, 46 en los pies de formulario.
  final double height;

  const AdminButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AdminButtonKind.secondary,
    this.icon,
    this.height = 42,
  });

  const AdminButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 42,
  }) : kind = AdminButtonKind.primary;

  const AdminButton.dark({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 42,
  }) : kind = AdminButtonKind.dark;

  const AdminButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 42,
  }) : kind = AdminButtonKind.danger;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (kind) {
      AdminButtonKind.primary => (
        AppColors.primaryRed,
        Colors.white,
        AppColors.primaryRed,
      ),
      AdminButtonKind.dark => (
        AppColors.darkText,
        Colors.white,
        AppColors.darkText,
      ),
      AdminButtonKind.danger => (
        Colors.white,
        AppColors.danger,
        AppColors.danger,
      ),
      AdminButtonKind.secondary => (
        Colors.white,
        AppColors.darkText,
        AppColors.buttonLine,
      ),
    };
    final enabled = onPressed != null;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.5),
        disabledForegroundColor: fg.withValues(alpha: 0.5),
        // Mide exactamente [height]: sin el margen táctil de 48 px ni el ajuste
        // de la densidad cómoda del tema.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: Size(0, height),
        fixedSize: Size.fromHeight(height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(
          color: enabled ? border : border.withValues(alpha: 0.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
