import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Hoja blanca centrada de cada sección del panel, con su título, un texto
/// de ayuda y las acciones principales a la derecha. El contenido se desplaza
/// dentro de la hoja; sobre pantallas altas la hoja llega hasta abajo.
class AdminPage extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Botones de la sección (p. ej. «+ Nuevo predio»).
  final List<Widget> actions;

  final Widget child;

  const AdminPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < Breakpoints.tablet;
        final padX = narrow ? 16.0 : 32.0;

        final header = Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 14,
          spacing: 16,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.pageTitle.copyWith(
                      fontSize: narrow ? 28 : 34,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        );

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppDimens.pageMaxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padX, 28, padX, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header, const SizedBox(height: 22), child],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
