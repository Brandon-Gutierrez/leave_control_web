import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Aspecto de los campos de texto de los detalles y formularios del panel:
/// borde fino de 8 px, rojo al enfocar y en rojo oscuro si hay un error.
InputDecoration adminFieldDecoration({
  String? errorText,
  String? hintText,
  String? suffixText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    isDense: true,
    errorText: errorText,
    errorMaxLines: 2,
    hintText: hintText,
    hintStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: Color(0xFF999999),
    ),
    suffixText: suffixText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border(AppColors.buttonLine),
    disabledBorder: border(AppColors.buttonLine),
    border: border(AppColors.buttonLine),
    focusedBorder: border(AppColors.primaryRed, 2),
    errorBorder: border(AppColors.danger, 1.5),
    focusedErrorBorder: border(AppColors.danger, 2),
  );
}
