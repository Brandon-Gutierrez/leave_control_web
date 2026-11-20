import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_popup.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../data/reason_catalog_service.dart';

/// «Sincronizar ahora»: pide a Comteco el catálogo de motivos y avisa del
/// resultado con un aviso verde (qué cambió) o rojo (por qué falló). Lo usan la
/// sección Motivos y el acceso directo de Inicio.
Future<void> runReasonSync(BuildContext context) async {
  final store = AdminDataStore.instance;
  try {
    final result = await ReasonCatalogService().syncNow();
    if (!context.mounted) return;
    final detail = result.summary;
    showAppPopup(
      context,
      detail == null ? result.message : '${result.message} ($detail)',
    );
  } on ApiException catch (e) {
    if (e.isUnauthorized) {
      store.sessionExpired();
      return;
    }
    if (context.mounted) {
      showAppPopup(context, e.message, kind: PopupKind.error);
    }
  }
  // Tanto si salió bien como si falló, el servidor guardó el resultado: se
  // vuelve a leer lo que ya estaba cargado (catálogo, resumen de Inicio...).
  unawaited(store.refreshQuietly());
}
