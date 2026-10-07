import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dialog_tone.dart';

/// Carcasa única de los modales del panel: cabecera de color sólido (el color
/// dice el propósito), cuerpo que se desplaza y un pie con los botones. Mismo
/// lenguaje visual que la barra lateral: esquinas rectas, líneas finas.
class AppModal extends StatelessWidget {
  final DialogTone tone;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  /// Botones del pie, de izquierda a derecha; el último es la acción principal.
  final List<Widget> actions;

  /// Si se muestra la (X) de la cabecera para cerrar.
  final VoidCallback? onClose;

  final double maxWidth;

  const AppModal({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onClose,
    this.maxWidth = 520,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: screen.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              tone: tone,
              icon: icon,
              title: title,
              subtitle: subtitle,
              onClose: onClose ?? () => Navigator.maybePop(context),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                child: child,
              ),
            ),
            if (actions.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF6F6F6),
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 10,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DialogTone tone;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  const _Header({
    required this.tone,
    required this.icon,
    required this.title,
    required this.onClose,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tone.color,
      padding: const EdgeInsets.fromLTRB(22, 16, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

/// Botones del pie con el mismo estilo en todos los modales.
class ModalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Color? color;
  final bool isLoading;

  const ModalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
    const size = Size(120, 48);
    if (!primary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          shape: shape,
          foregroundColor: AppColors.darkText,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFB0B0B0)),
        ),
        child: Text(label),
      );
    }
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: size,
        shape: shape,
        backgroundColor: color ?? AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}
