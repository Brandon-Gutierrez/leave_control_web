import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_user.dart';

/// Quién tiene la sesión abierta, en la barra superior: nombre, «Cerrar
/// sesión» y su foto (o sus iniciales).
class UserChip extends StatelessWidget {
  final AuthUser? user;
  final VoidCallback onLogout;

  /// Versión pequeña para pantallas angostas: solo la foto y un botón de salir.
  final bool compact;

  const UserChip({
    super.key,
    required this.user,
    required this.onLogout,
    this.compact = false,
  });

  String get _name => (user?.name.isNotEmpty ?? false) ? user!.name : 'Usuario';

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(name: _name, photoUrl: user?.photoUrl, size: 36),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
              size: 22,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        UserAvatar(name: _name, photoUrl: user?.photoUrl, size: 40),
      ],
    );
  }
}

/// Foto de perfil circular; si no hay o no carga, un círculo negro con las
/// iniciales de la persona.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;

  const UserAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  /// «Ana Pérez» → «AP»; con una sola palabra, su inicial.
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.darkText,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.33,
        ),
      ),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        // La foto es de otro dominio sin CORS: en web se dibuja como <img> del
        // navegador, que no lo exige.
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Si la foto no carga, se usan las iniciales.
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}
