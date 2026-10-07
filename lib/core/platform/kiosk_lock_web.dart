import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Impide salir de la página con el botón "atrás" (o Alt+←) del navegador:
/// cada vez que se intenta retroceder se vuelve a apilar la misma entrada del
/// historial. Devuelve la función que desactiva el bloqueo.
///
/// Un sitio web no puede impedir que se cierre la pestaña o se escriba otra
/// dirección en la barra del navegador; para eso se usa el modo quiosco del
/// navegador (p. ej. `chrome --kiosk`).
void Function() enableBrowserBackLock() {
  void pushEntry() =>
      web.window.history.pushState(null, '', web.window.location.href);

  pushEntry();
  final listener = ((web.Event _) => pushEntry()).toJS;
  web.window.addEventListener('popstate', listener);
  return () => web.window.removeEventListener('popstate', listener);
}
