import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Nombre de la tipografía del panel (declarada en pubspec.yaml). Los estilos
/// de botón reemplazan —no mezclan— la fuente del tema: deben indicarla ellos.
const appFontFamily = 'Manrope';

/// Tamaños de texto pensados para que se lean cómodamente incluso personas
/// mayores o que no usan aplicaciones seguido: nada por debajo de 14px, y
/// el texto importante siempre en 16px o más.
abstract final class AppText {
  /// Título grande de una página (p. ej. «Usuarios»).
  static const TextStyle pageTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
    letterSpacing: -1,
    height: 1.15,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.darkText,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.darkText,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.darkText,
  );

  static final TextStyle caption = TextStyle(
    fontSize: 14,
    color: Colors.grey.shade600,
  );
}

/// Medidas mínimas para que los botones y filas sean fáciles de tocar.
abstract final class AppDimens {
  static const double smallButtonHeight = 48.0;
  static const double fieldRadius = 8.0;

  /// Alto de la barra superior con las pestañas.
  static const double topBarHeight = 68.0;

  /// Ancho máximo del panel blanco de cada sección.
  static const double pageMaxWidth = 1240.0;

  /// Botón principal del inicio de sesión y de los formularios.
  static const double primaryButtonHeight = 56.0;
  static const double radiusButton = 12.0;
}
