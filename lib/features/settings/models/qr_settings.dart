/// Tiempo de vida del código QR y los límites que acepta el servidor.
class QrSettings {
  final int ttlSeconds;
  final int minSeconds;
  final int maxSeconds;

  const QrSettings({
    required this.ttlSeconds,
    required this.minSeconds,
    required this.maxSeconds,
  });

  factory QrSettings.fromJson(Map<String, dynamic> json) => QrSettings(
    ttlSeconds: (json['qr_ttl_seconds'] as num?)?.toInt() ?? 300,
    minSeconds: (json['qr_ttl_seconds_min'] as num?)?.toInt() ?? 30,
    maxSeconds: (json['qr_ttl_seconds_max'] as num?)?.toInt() ?? 3600,
  );
}
