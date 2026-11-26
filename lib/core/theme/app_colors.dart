import 'package:flutter/material.dart';

/// Paleta del sistema: rojo como color de marca sobre neutros. Los colores de
/// estado son versiones apagadas (poca saturación) para que no compitan con el
/// rojo: el estado se distingue por el matiz sutil, el ícono y el texto.
abstract final class AppColors {
  static const primaryRed = Color(0xFFD32F2F);
  static const darkText = Color(0xFF111111);

  /// Fondo de la página, detrás del panel blanco de cada sección.
  static const lightBg = Color(0xFFF6F6F3);

  /// Fondo de la pantalla de inicio de sesión.
  static const loginBg = Color(0xFFF7F7F8);

  // Estados
  static const success = Color(0xFF3F7D4E);
  static const successBg = Color(0xFFEEF5EF);
  static const danger = Color(0xFFB71C1C);
  static const dangerBg = Color(0xFFFBEBEB);
  static const warning = Color(0xFF9A6A1F);
  static const warningBg = Color(0xFFFAF3E6);

  /// Información y acciones neutras: gris, no azul.
  static const info = Color(0xFF4A4A4A);
  static const infoBg = Color(0xFFF0F0F0);
  static const line = Color(0xFFDDDDDD);

  /// Texto secundario (subtítulos, ayudas).
  static const muted = Color(0xFF666666);

  /// Rótulos pequeños en mayúsculas.
  static const label = Color(0xFF888888);

  /// Borde de los paneles y las listas.
  static const panelLine = Color(0xFFDEDED9);

  /// Separador entre filas de una lista.
  static const rowLine = Color(0xFFE6E6E1);

  /// Borde de los botones y campos de la barra de herramientas.
  static const buttonLine = Color(0xFFCFCFCA);
}

/// Puntos de quiebre para pantallas web.
abstract final class Breakpoints {
  static const double tablet = 760;

  /// Desde este ancho la navegación va en pestañas arriba; por debajo, en una
  /// barra inferior.
  static const double topNav = 1000;
}
