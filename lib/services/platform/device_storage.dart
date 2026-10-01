// Identificador del navegador. En la VM (pruebas) se usa un stub en memoria.
export 'device_storage_stub.dart'
    if (dart.library.js_interop) 'device_storage_web.dart';
