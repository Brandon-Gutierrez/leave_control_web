// Funciones que dependen del navegador. En la VM (pruebas) se usa un stub.
export 'browser_http_stub.dart'
    if (dart.library.js_interop) 'browser_http_web.dart';
