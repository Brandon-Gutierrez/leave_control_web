import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'dialog_tone.dart';

/// Carcasa única de los modales del panel, con el mismo lenguaje que las
/// páginas: hoja blanca de borde fino y esquinas casi rectas, una franja fina
/// del color del propósito arriba (el color dice para qué es), el ícono en un
/// cuadro suave junto al título, el cuerpo que se desplaza y un pie separado
/// por una línea con los botones.
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
    // En pantallas angostas el contenido gana ancho: menos margen a los lados.
    final side = screen.width < 480 ? 18.0 : 28.0;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.panelLine),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: screen.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: tone.color),
            _Header(
              side: side,
              tone: tone,
              icon: icon,
              title: title,
              subtitle: subtitle,
              onClose: onClose ?? () => Navigator.maybePop(context),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(side, 6, side, 24),
                child: child,
              ),
            ),
            if (actions.isNotEmpty)
              Container(
                padding: EdgeInsets.fromLTRB(side, 16, side, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.rowLine)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
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
  final double side;
  final DialogTone tone;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  const _Header({
    required this.side,
    required this.tone,
    required this.icon,
    required this.title,
    required this.onClose,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 22, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tone.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: tone.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.15,
                      color: AppColors.darkText,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.muted,
              hoverColor: const Color(0x0D000000),
              minimumSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.close_rounded, size: 24),
          ),
        ],
      ),
    );
  }
}

/// Botones del pie con el mismo estilo en todos los modales: 46 px, esquinas
/// de 8 px y letra en negrita. El principal va relleno (de [color] o rojo); el
/// resto, blanco con borde.
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    const size = Size(110, 46);
    const text = TextStyle(
      fontFamily: appFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    if (!primary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          shape: shape,
          textStyle: text,
          foregroundColor: AppColors.darkText,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.buttonLine),
        ),
        child: Text(label),
      );
    }
    final fill = color ?? AppColors.primaryRed;
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: size,
        shape: shape,
        textStyle: text,
        backgroundColor: fill,
        foregroundColor: Colors.white,
        disabledBackgroundColor: fill.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
