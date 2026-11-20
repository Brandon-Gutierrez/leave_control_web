import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

OutlineInputBorder _fieldBorder(Color color, double width) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// Tema global del panel: tipografía Manrope, paleta propia y campos y botones
/// redondeados, cómodos para tocar en cualquier edad.
ThemeData buildAppTheme() {
  return ThemeData(
    fontFamily: appFontFamily,
    // Esquema explícito: todo componente de Material (calendario, diálogos,
    // campos) usa solo la paleta de la app, sin tonos derivados del seed.
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryRed,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primaryRed,
          onPrimary: Colors.white,
          primaryContainer: AppColors.dangerBg,
          onPrimaryContainer: AppColors.danger,
          secondary: AppColors.info,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.infoBg,
          onSecondaryContainer: AppColors.darkText,
          surface: Colors.white,
          onSurface: AppColors.darkText,
          onSurfaceVariant: AppColors.info,
          surfaceTint: Colors.transparent,
          outline: AppColors.line,
          outlineVariant: AppColors.line,
          error: AppColors.danger,
        ),
    useMaterial3: true,
    visualDensity: VisualDensity.comfortable,
    scaffoldBackgroundColor: AppColors.lightBg,
    // Sin un color por defecto, todo texto que no lo indique se dibuja blanco.
    textTheme: Typography.englishLike2021.apply(
      fontSizeFactor: 1.08,
      fontFamily: appFontFamily,
      displayColor: AppColors.darkText,
      bodyColor: AppColors.darkText,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: const TextStyle(color: Color(0xFF777777), fontSize: 15),
      border: _fieldBorder(AppColors.buttonLine, 1),
      enabledBorder: _fieldBorder(AppColors.buttonLine, 1),
      disabledBorder: _fieldBorder(AppColors.buttonLine, 1),
      focusedBorder: _fieldBorder(AppColors.primaryRed, 2),
      errorBorder: _fieldBorder(AppColors.danger, 1.5),
      focusedErrorBorder: _fieldBorder(AppColors.danger, 2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      contentTextStyle: TextStyle(fontFamily: appFontFamily, fontSize: 15),
    ),
  );
}
