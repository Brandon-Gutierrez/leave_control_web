import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Propósito de un modal; define su color para que se entienda sin leer:
/// azul = configurar, verde = crear, ámbar = cambia un acceso, rojo = corta un acceso.
enum DialogTone {
  configure(AppColors.info),
  create(AppColors.success),
  caution(AppColors.warning),
  danger(AppColors.danger);

  const DialogTone(this.color);
  final Color color;
}
