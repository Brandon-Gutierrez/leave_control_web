import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/platform/kiosk_lock.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'generator_qr_page.dart';

/// Única experiencia de una cuenta MANAGE_PREMISE.
///
/// La raíz de la app ([MaterialApp.builder]) muestra este widget en lugar de
/// todo el árbol de navegación mientras la sesión sea de un responsable, así
/// que ninguna ruta, enlace ni botón "atrás" puede llevarlo a otra pantalla.
/// Tiene su propio [Navigator] con una sola página que no se puede quitar.
class ManagerLockdown extends StatefulWidget {
  final AuthUser user;

  /// Pide de nuevo los datos de la cuenta (p. ej. si aún no tiene predio).
  final Future<void> Function()? onRetry;

  const ManagerLockdown({super.key, required this.user, this.onRetry});

  @override
  State<ManagerLockdown> createState() => _ManagerLockdownState();
}

class _ManagerLockdownState extends State<ManagerLockdown> {
  late final void Function() _disableBackLock;

  @override
  void initState() {
    super.initState();
    _disableBackLock = enableBrowserBackLock();
  }

  @override
  void dispose() {
    _disableBackLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premise = widget.user.premise;
    final hasPremise = premise != null && premise.id > 0;

    return Navigator(
      // Una sola página fija: no hay historial al que volver.
      pages: [
        MaterialPage<void>(
          key: ValueKey('manager-${widget.user.id}-${premise?.id}'),
          canPop: false,
          child: hasPremise
              ? QrPage.forPremiseManager(
                  premiseId: premise.id,
                  premiseName: premise.name,
                )
              : _NoPremiseScreen(onRetry: widget.onRetry),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}

/// Cuenta de responsable sin predio (p. ej. se eliminó el predio asignado).
class _NoPremiseScreen extends StatelessWidget {
  final Future<void> Function()? onRetry;

  const _NoPremiseScreen({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    size: 56,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Esta cuenta no tiene un predio asignado.',
                    textAlign: TextAlign.center,
                    style: AppText.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pida a administración que le asigne un predio.',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: Colors.grey.shade700),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Volver a comprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
