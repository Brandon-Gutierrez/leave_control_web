import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo de la app: la C de Comteco en blanco, con la insignia de salida y
/// retorno, sobre un cuadro rojo redondeado (el diseño del ícono de la
/// aplicación móvil). Se genera con control_leaves_mobile/tool/generate_icons.ps1
/// usando el parámetro -Web.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'rsc/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Decorativo: las pantallas ya dicen el nombre de la app en texto.
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Icon(
        Icons.swap_horiz_rounded,
        size: size * 0.5,
        color: AppColors.primaryRed,
      ),
    );
  }
}
