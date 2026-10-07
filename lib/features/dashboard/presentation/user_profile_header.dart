import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/auth_user.dart';

/// Módulo de usuario: foto, nombre y roleTitle de quien inició sesión. Si la
/// persona no tiene foto se muestra una imagen predeterminada.
class UserProfileHeader extends StatelessWidget {
  final AuthUser? user;

  /// Versión pequeña (solo foto) para la barra superior.
  final bool compact;

  const UserProfileHeader({super.key, required this.user, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name.isNotEmpty ?? false) ? user!.name : 'Usuario';
    final roleTitle = user?.roleTitle ?? 'Administrador del sistema';

    if (compact) {
      return Row(
        children: [
          UserAvatar(photoUrl: user?.photoUrl, radius: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  roleTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          UserAvatar(photoUrl: user?.photoUrl, radius: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: AppColors.primaryRed,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        roleTitle,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (user?.jobTitle != null && user!.jobTitle!.isNotEmpty)
                  Text(
                    user!.jobTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto de perfil circular con imagen predeterminada.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;

  const UserAvatar({super.key, required this.photoUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryRed.withValues(alpha: 0.12),
      child: Icon(
        Icons.person_rounded,
        size: radius * 1.3,
        color: AppColors.primaryRed,
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
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        // Si la foto no carga, se usa la predeterminada.
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}
