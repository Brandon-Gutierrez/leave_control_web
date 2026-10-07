/// Código temporal que el responsable de un predio muestra para que el
/// personal lo escanee.
class QrToken {
  final String token;
  final int ttl;
  final DateTime expiresAt;

  /// Nombre del predio con el que el servidor generó el QR (puede cambiar si
  /// administración reasigna al responsable).
  final String? premiseName;

  QrToken({
    required this.token,
    required this.ttl,
    required this.expiresAt,
    this.premiseName,
  });
}
