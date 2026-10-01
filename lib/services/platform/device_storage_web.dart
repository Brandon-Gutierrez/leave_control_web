import 'dart:math';

import 'package:web/web.dart' as web;

const _key = 'control_qr_device_id';

/// Identificador de este navegador, generado una vez y guardado en
/// localStorage. El servidor vincula cada cuenta a un único navegador: si se
/// borran los datos del sitio, cuenta como un dispositivo nuevo.
String readDeviceId() {
  final storage = web.window.localStorage;
  final existing = storage.getItem(_key);
  if (existing != null && existing.length >= 16) return existing;

  final random = Random.secure();
  final id = List.generate(32, (_) => random.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  storage.setItem(_key, id);
  return id;
}
