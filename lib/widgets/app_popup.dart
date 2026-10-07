import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Define los valores posibles.
enum PopupKind { success, error, warning }

/// Aviso flotante único de la app (éxito, error o advertencia). Se cierra
/// solo a los 7 segundos o con la (X). El color y el ícono dicen el resultado
/// sin necesidad de leer.
void showAppPopup(BuildContext context, String message, {PopupKind kind = PopupKind.success}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;

  /// Ejecuta la tarea.
  void remove() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _PopupCard(message: message, kind: kind, onClose: remove),
  );
  overlay.insert(entry);
}

/// Ejecuta la tarea.
void showSuccessPopup(BuildContext c, String m) => showAppPopup(c, m);
/// Ejecuta la tarea.
void showErrorPopup(BuildContext c, String m) => showAppPopup(c, m, kind: PopupKind.error);

/// Representa esta entidad.
class _PopupCard extends StatefulWidget {
  final String message;
  final PopupKind kind;
  final VoidCallback onClose;

  /// Ejecuta la tarea.
  const _PopupCard({required this.message, required this.kind, required this.onClose});

  /// Crea el estado del widget.
  @override
  State<_PopupCard> createState() => _PopupCardState();
}

/// Representa esta entidad.
class _PopupCardState extends State<_PopupCard> {
  // El temporizador vive con la tarjeta: se cancela solo si la pantalla se cierra.
  late final Timer _timer = Timer(const Duration(seconds: 7), widget.onClose);

  /// Inicializa el estado.
  @override
  void initState() {
    super.initState();
    _timer;
  }

  /// Libera los recursos.
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Construye la interfaz.
  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final kind = widget.kind;
    final onClose = widget.onClose;
    final (color, icon, title) = switch (kind) {
      PopupKind.success => (AppColors.success, Icons.check_circle_rounded, 'Listo'),
      PopupKind.error => (AppColors.danger, Icons.error_rounded, 'Algo salió mal'),
      PopupKind.warning => (AppColors.warning, Icons.warning_rounded, 'Atención'),
    };
    final width = MediaQuery.sizeOf(context).width;
    return Positioned(
      top: 16,
      right: width < 520 ? 12 : 24,
      left: width < 520 ? 12 : null,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: color, width: 8)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(message, style: const TextStyle(fontSize: 15, color: AppColors.darkText)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
