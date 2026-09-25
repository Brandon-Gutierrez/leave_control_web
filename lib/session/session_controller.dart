import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';

/// Usuario de la sesión actual, compartido por toda la app.
///
/// La raíz de la app lo escucha: mientras haya un [AuthUser] con rol
/// MANAGE_PREMISE, se muestra únicamente su pantalla de QR (sin importar en
/// qué ruta, enlace o botón "atrás" se intente salir de ella).
class SessionController {
  SessionController._();

  static final SessionController instance = SessionController._();

  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);

  void set(AuthUser? value) => user.value = value;

  void clear() => user.value = null;
}
