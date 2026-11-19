import 'managed_user.dart';

/// Cuenta a la que está vinculado el dispositivo con un código dado
/// (resultado de buscar por código de dispositivo).
class DeviceMatch {
  final int userId;
  final String name;
  final int? item;
  final String? role;
  final ClientPlatform platform;
  final DateTime? boundAt;
  final String code;

  const DeviceMatch({
    required this.userId,
    required this.name,
    required this.platform,
    required this.code,
    this.item,
    this.role,
    this.boundAt,
  });

  /// Devuelve null si la entrada no trae una cuenta o aplicación reconocible.
  static DeviceMatch? fromJson(Map<String, dynamic> json) {
    final platform = ClientPlatform.fromApi(json['platform']?.toString());
    final userId = (json['user_id'] as num?)?.toInt();
    if (platform == null || userId == null) return null;
    return DeviceMatch(
      userId: userId,
      name: (json['name'] ?? '').toString().trim(),
      item: (json['item'] as num?)?.toInt(),
      role: json['role']?.toString(),
      platform: platform,
      boundAt: DateTime.tryParse(json['bound_at']?.toString() ?? ''),
      code: (json['code'] ?? '').toString(),
    );
  }
}
