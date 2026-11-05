import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador HTTP de prueba que cuenta cuántas veces se pidió cada ruta y
/// permite simular demoras (`gate`) y errores (`failStatus`).
class CountingAdapter implements HttpClientAdapter {
  /// Respuesta por ruta (`/api/admin/users`...). Si falta, `{'status': 0}`.
  final Map<String, Object> bodies;

  /// Peticiones recibidas por ruta.
  final Map<String, int> hits = {};

  /// Rutas que responden con este código de error en vez de 200.
  final Map<String, int> failStatus = {};

  /// Mientras exista, las peticiones esperan a que se complete.
  Completer<void>? gate;

  CountingAdapter(this.bodies);

  int hitsOf(String path) => hits[path] ?? 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    hits[path] = hitsOf(path) + 1;
    final wait = gate;
    if (wait != null) await wait.future;

    final status = failStatus[path] ?? 200;
    final body = status == 200
        ? (bodies[path] ?? {'status': 0})
        : {'status': 'ERROR', 'message': 'Fallo $status en $path'};
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
