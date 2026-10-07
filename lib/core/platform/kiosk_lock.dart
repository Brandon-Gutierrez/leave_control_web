// Bloqueo del botón "atrás" del navegador para la pantalla del responsable.
// En pruebas (VM) se usa una versión vacía.
export 'kiosk_lock_stub.dart' if (dart.library.js_interop) 'kiosk_lock_web.dart';
