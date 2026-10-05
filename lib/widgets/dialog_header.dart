import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Propósito de un modal; define su color para que se entienda sin leer:
/// azul = configurar, verde = crear, ámbar = cambia un acceso, rojo = corta un acceso.
enum DialogTone {
  configure(AppColors.info, AppColors.infoBg),
  create(AppColors.success, AppColors.successBg),
  caution(AppColors.warning, AppColors.warningBg),
  danger(AppColors.danger, AppColors.dangerBg);

  const DialogTone(this.color, this.background);
  final Color color;
  final Color background;
}

/// Franja superior de color con ícono y título; el subtítulo explica en una
/// frase qué va a pasar.
class DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final DialogTone tone;

  const DialogHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.tone,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tone.background,
        border: Border(left: BorderSide(color: tone.color, width: 6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone.color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: tone.color),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: const TextStyle(fontSize: 15, color: AppColors.darkText)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
