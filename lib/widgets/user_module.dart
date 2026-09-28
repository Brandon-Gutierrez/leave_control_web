import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Módulo de usuario: foto, nombre y cargo de quien inició sesión. Si la
/// persona no tiene foto se muestra una imagen predeterminada.
class UserModule extends StatelessWidget {
  final AuthUser? user;

  /// Versión pequeña (solo foto) para la barra superior.
  final bool compact;

  const UserModule({super.key, required this.user, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name.isNotEmpty ?? false) ? user!.name : 'Usuario';
    final cargo = user?.cargo ?? 'Administrador del sistema';

    if (compact) {
      return Tooltip(
        message: '$name · $cargo',
        child: UserAvatar(photoUrl: user?.photoUrl, radius: 18),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          UserAvatar(photoUrl: user?.photoUrl, radius: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading.copyWith(fontSize: 22),
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
                        cargo,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
