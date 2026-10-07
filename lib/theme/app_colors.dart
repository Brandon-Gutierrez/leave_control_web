import 'package:flutter/material.dart';

/// Representa esta entidad.
class AppColors {
  static const primaryRed = Color(0xFFD32F2F);
  static const darkText = Color(0xFF111111);
  static const lightBg = Color(0xFFFAFAFA);
  static const loginBg = Color(0xFFF5F5F5);

  // Colores con significado: la gente se guía por el color antes de leer.
  static const success = Color(0xFF2E7D32);
  static const successBg = Color(0xFFE8F5E9);
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFFEBEE);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFFF4E0);
  static const info = Color(0xFF1565C0);
  static const infoBg = Color(0xFFE3F2FD);
  static const line = Color(0xFFDDDDDD);

  // Pantalla de QR
  static const qrBackground = Color.fromARGB(255, 223, 28, 14);
  static const qrText = Color.fromARGB(255, 160, 20, 10);
  static const qrShadow = Color.fromARGB(255, 70, 0, 0);
}

/// Puntos de quiebre para pantallas web.
class Breakpoints {
  static const double tablet = 760;
  static const double desktop = 1200;
}
