/// "2 nuevos · 1 retirado", o null si no hubo cambios.
String? describeReasonChanges({
  int added = 0,
  int updated = 0,
  int reactivated = 0,
  int deactivated = 0,
}) {
  final parts = [
    if (added > 0) '$added ${added == 1 ? 'nuevo' : 'nuevos'}',
    if (updated > 0) '$updated ${updated == 1 ? 'actualizado' : 'actualizados'}',
    if (reactivated > 0)
      '$reactivated ${reactivated == 1 ? 'reactivado' : 'reactivados'}',
    if (deactivated > 0)
      '$deactivated ${deactivated == 1 ? 'retirado' : 'retirados'}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Motivo del catálogo con su estado y uso. Un motivo retirado ([active] falso)
/// es uno que Comteco ya no ofrece: no se elige en nuevas salidas, pero el
/// historial lo sigue mostrando.
class CatalogReason {
  final int id;
  final String name;
  final String code;
  final bool active;

  /// En cuántos predios está habilitado.
  final int premisesCount;

  const CatalogReason({
    required this.id,
    required this.name,
    required this.code,
    required this.active,
    required this.premisesCount,
  });

  factory CatalogReason.fromJson(Map<String, dynamic> json) => CatalogReason(
    id: (json['reason_id'] as num?)?.toInt() ?? 0,
    name: (json['name'] ?? '').toString(),
    code: (json['code'] ?? '').toString(),
    active: json['active'] != false,
    premisesCount: (json['premises_count'] as num?)?.toInt() ?? 0,
  );
}

/// Resultado de la última sincronización de motivos con Comteco.
class ReasonSyncStatus {
  /// `manual` (botón del panel), `scheduled` (00:00, lunes a viernes) o
  /// `console` (comando).
  static const manual = 'manual';
  static const scheduled = 'scheduled';

  final bool failed;
  final String source;

  /// Cuándo se intentó.
  final DateTime? at;
  final String? actor;
  final int? added;
  final int? updated;
  final int? reactivated;
  final int? deactivated;
  final String? error;

  /// Última vez que terminó bien (se conserva aunque después falle una).
  final DateTime? lastSuccessAt;

  const ReasonSyncStatus({
    required this.failed,
    required this.source,
    this.at,
    this.actor,
    this.added,
    this.updated,
    this.reactivated,
    this.deactivated,
    this.error,
    this.lastSuccessAt,
  });

  factory ReasonSyncStatus.fromJson(Map<String, dynamic> json) {
    int? count(String key) => (json[key] as num?)?.toInt();
    DateTime? date(String key) => DateTime.tryParse('${json[key] ?? ''}');
    return ReasonSyncStatus(
      failed: json['status'] == 'failed',
      source: (json['source'] ?? manual).toString(),
      at: date('at'),
      actor: json['actor'] as String?,
      added: count('added'),
      updated: count('updated'),
      reactivated: count('reactivated'),
      deactivated: count('deactivated'),
      error: json['error'] as String?,
      lastSuccessAt: date('last_success_at'),
    );
  }

  /// Qué cambió en esa sincronización (null si no hubo cambios o falló).
  String? get changesSummary => failed
      ? null
      : describeReasonChanges(
          added: added ?? 0,
          updated: updated ?? 0,
          reactivated: reactivated ?? 0,
          deactivated: deactivated ?? 0,
        );

  String get sourceLabel => switch (source) {
    scheduled => 'automática',
    manual => 'manual',
    _ => 'por consola',
  };
}

/// Catálogo completo de motivos y su última sincronización.
class ReasonCatalog {
  final List<CatalogReason> reasons;

  /// Null si nunca se sincronizó.
  final ReasonSyncStatus? sync;

  const ReasonCatalog({this.reasons = const [], this.sync});

  factory ReasonCatalog.fromJson(Map<String, dynamic> json) {
    final sync = json['sync'];
    return ReasonCatalog(
      reasons: [
        for (final row in json['reasons'] as List? ?? const [])
          if (row is Map<String, dynamic>) CatalogReason.fromJson(row),
      ],
      sync: sync is Map<String, dynamic>
          ? ReasonSyncStatus.fromJson(sync)
          : null,
    );
  }
}

/// Respuesta de "Sincronizar ahora".
class ReasonSyncResult {
  final String message;
  final int added;
  final int updated;
  final int reactivated;
  final int deactivated;

  const ReasonSyncResult({
    required this.message,
    this.added = 0,
    this.updated = 0,
    this.reactivated = 0,
    this.deactivated = 0,
  });

  factory ReasonSyncResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    int count(String key) =>
        result is Map ? (result[key] as num?)?.toInt() ?? 0 : 0;
    return ReasonSyncResult(
      message: (json['message'] ?? 'Motivos sincronizados correctamente.')
          .toString(),
      added: count('added'),
      updated: count('updated'),
      reactivated: count('reactivated'),
      deactivated: count('deactivated'),
    );
  }

  /// "2 nuevos · 1 retirado", o null si no hubo cambios.
  String? get summary => describeReasonChanges(
    added: added,
    updated: updated,
    reactivated: reactivated,
    deactivated: deactivated,
  );
}
