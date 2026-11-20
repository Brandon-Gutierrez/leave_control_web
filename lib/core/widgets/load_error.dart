import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Aviso de que una parte no se pudo cargar, con botón para reintentar solo
/// esa parte. Mismo estilo que las franjas de aviso del panel.
class LoadErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LoadErrorNotice({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.danger,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Revise su conexión e intente de nuevo.',
          style: AppText.body.copyWith(fontSize: 15),
        ),
      ],
    );
    final button = FilledButton(
      onPressed: onRetry,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: const Text('Reintentar'),
    );
    const icon = Icon(
      Icons.cloud_off_rounded,
      color: AppColors.danger,
      size: 30,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.dangerBg,
        border: Border(left: BorderSide(color: AppColors.danger, width: 6)),
      ),
      // En un espacio angosto (p. ej. la lista de una sección) el botón pasa
      // debajo del texto.
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 440
            ? Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  const SizedBox(width: 12),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: 12),
                  button,
                ],
              ),
      ),
    );
  }
}
