import 'package:flutter/material.dart';

class AppColors {
  static const primaryRed = Color(0xFFD32F2F);
  static const darkText = Color(0xFF111111);
  static const lightBg = Color(0xFFFAFAFA);
  static const loginBg = Color(0xFFF5F5F5);

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
