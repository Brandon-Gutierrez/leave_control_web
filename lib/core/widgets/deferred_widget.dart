import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Muestra un widget de una biblioteca con carga diferida (`import ... deferred
/// as x`): el código se descarga la primera vez que se necesita y no con el
/// resto de la aplicación.
///
/// ```dart
/// DeferredWidget(
///   loadLibrary: map.loadLibrary,
///   builder: (context) => map.LocationPicker(...),
/// )
/// ```
class DeferredWidget extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;

  /// Alto del hueco que se reserva mientras se descarga.
  final double placeholderHeight;

  const DeferredWidget({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.placeholderHeight = 120,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  late Future<void> _loading = widget.loadLibrary();

  void _retry() => setState(() => _loading = widget.loadLibrary());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        // Material: el aviso de error necesita un estilo de texto por defecto.
        return Material(
          type: MaterialType.transparency,
          child: SizedBox(
            height: widget.placeholderHeight,
            child: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No se pudo cargar esta parte.',
                          style: AppText.body,
                        ),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(
                      color: AppColors.primaryRed,
                    ),
            ),
          ),
        );
      },
    );
  }
}
