import 'dart:convert';
import 'dart:typed_data';

import 'package:control_leaves_web/core/network/api_client.dart';
import 'package:dio/dio.dart';

/// Respuestas de ejemplo del panel, sin llamar al backend. Cada prueba puede
/// cambiar los datos antes de abrir la pantalla.
class FakeAdminBackend implements HttpClientAdapter {
  Map<String, dynamic> summary = {
    'premises': {
      'total': 6,
      'without_location': 0,
      'without_manager': 1,
      'without_reasons': 0,
    },
    'users': {
      'total': 248,
      'admins': 3,
      'managers_without_premise': 0,
      'employees_without_app': 12,
    },
  };

  List<Map<String, dynamic>> premises = [
    {
      'id': 1,
      'name': 'Central',
      'latitude': '-17.3935000',
      'longitude': '-66.1570000',
      'manager': {'user_id': 5, 'name': 'Marta Rojas'},
      'reason_names': ['Banco', 'Médico'],
    },
    {
      'id': 2,
      'name': 'Prado',
      'reason_names': ['Banco'],
    },
  ];

  List<Map<String, dynamic>> users = [
    {
      'user_id': 1,
      'name': 'Ana Flores',
      'item': 1488,
      'role_id': 1,
      'role': {'role_id': 1, 'name': 'EMPLOYEE'},
    },
  ];

  /// Cuántas veces se pidió «Sincronizar ahora».
  int syncCalls = 0;

  /// Desvinculaciones pedidas: `idDelUsuario:plataforma`.
  final List<String> deviceResets = [];

  /// Cambios de rol pedidos: `idDelUsuario:idDelRol`.
  final List<String> roleChanges = [];

  /// Actualizaciones de predios pedidas: el `id` y lo que viajó en la petición.
  final List<Map<String, dynamic>> premiseUpdates = [];

  /// Cada petición recibida: `METODO ruta`.
  final List<String> requests = [];

  /// Si se indica, guardar un predio (PUT) falla con este mensaje (422).
  String? premiseUpdateError;

  /// Catálogo de `/api/admin/reasons/catalog` (la cantidad de predios se
  /// calcula con los predios de este servidor) y su última sincronización.
  List<Map<String, dynamic>> catalogReasons = [];
  Map<String, dynamic>? sync;

  /// Lo que devuelve `POST /api/manager/qr-token` (con `qrError` falla con 500).
  String qrToken = 'Prado+123e4567-e89b-12d3-a456-426614174000';
  int qrTtl = 300;
  String qrPremiseName = 'Prado';
  String? qrError;

  /// Segundos que ya pasaron desde que el servidor emitió el código (el QR se
  /// pide antes de mostrarse, durante la animación).
  int qrIssuedAgo = 0;

  /// Ajustes: período y tope de salidas por persona, y vida del QR.
  String leavePeriod = 'day';
  int? maxExits = 3;
  int qrSeconds = 300;

  /// Cambios de ajustes pedidos (PUT): `path` y lo que viajó.
  final List<Map<String, dynamic>> settingsUpdates = [];

  /// Si se indica, guardar un ajuste (PUT) falla con este mensaje (422).
  String? settingsError;

  /// Límite por motivo de `/api/admin/settings/leave-limits`.
  Map<String, dynamic> reasonLimit = {
    'period': 'day',
    'mode': 'general',
    'general': 1,
    'custom': <Object>[],
  };

  /// Motivos del catálogo que devuelve `/api/admin/reasons`.
  List<String> reasons = ['Banco', 'Médico', 'Trámite'];

  static const _roleNames = {1: 'EMPLOYEE', 2: 'ADMIN', 3: 'MANAGE_PREMISE'};

  /// Instala este adaptador en el cliente HTTP compartido.
  FakeAdminBackend install() {
    ApiClient().dio.httpClientAdapter = this;
    return this;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();
    requests.add('$method $path');
    final Object body;
    var statusCode = 200;
    if (path == '/api/admin/summary' && method == 'GET') {
      body = {'status': 0, 'data': summary};
    } else if (path == '/api/admin/premises' && method == 'GET') {
      body = {'status': 0, 'data': premises};
    } else if (path == '/api/admin/reasons' && method == 'GET') {
      body = {'status': 0, 'reasons': reasons};
    } else if (path == '/api/admin/users' && method == 'GET') {
      body = {'status': 0, 'data': users};
    } else if (path == '/api/admin/roles' && method == 'GET') {
      body = {
        'status': 0,
        'data': [
          {'role_id': 1, 'name': 'EMPLOYEE'},
          {'role_id': 2, 'name': 'ADMIN'},
          {'role_id': 3, 'name': 'MANAGE_PREMISE'},
        ],
      };
    } else if (RegExp(r'^/api/admin/users/(\d+)/device/reset$').firstMatch(path)
        case final match? when method == 'POST') {
      final id = int.parse(match.group(1)!);
      final platform = (options.data as Map)['platform'];
      deviceResets.add('$id:$platform');
      for (final user in users) {
        if (user['user_id'] == id) {
          (user['devices'] as List?)?.removeWhere(
            (d) => (d as Map)['platform'] == platform,
          );
        }
      }
      body = {'status': 0};
    } else if (RegExp(r'^/api/admin/users/(\d+)/role$').firstMatch(path)
        case final match? when method == 'PUT') {
      final id = int.parse(match.group(1)!);
      final roleId = (options.data as Map)['role_id'] as int;
      roleChanges.add('$id:$roleId');
      final user = users.firstWhere((u) => u['user_id'] == id);
      user['role_id'] = roleId;
      user['role'] = {'role_id': roleId, 'name': _roleNames[roleId]};
      body = {'status': 0, 'data': user};
    } else if (RegExp(r'^/api/admin/premises/(\d+)$').firstMatch(path)
        case final match? when method == 'PUT') {
      final id = int.parse(match.group(1)!);
      final data = Map<String, dynamic>.from(options.data as Map);
      premiseUpdates.add({'id': id, ...data});
      final premise = premises.firstWhere((p) => p['id'] == id);
      if (premiseUpdateError != null) {
        statusCode = 422;
        body = {'status': 'ERROR', 'message': premiseUpdateError};
        return _respond(body, statusCode);
      }
      if (data.containsKey('name')) premise['name'] = data['name'];
      if (data.containsKey('latitude')) {
        premise['latitude'] = '${data['latitude']}';
        premise['longitude'] = '${data['longitude']}';
      }
      if (data.containsKey('reasons')) {
        premise['reason_names'] = data['reasons'];
      }
      if (data.containsKey('manager_user_id')) {
        final managerId = data['manager_user_id'] as int?;
        if (managerId == null) {
          premise.remove('manager');
        } else {
          final user = users.firstWhere((u) => u['user_id'] == managerId);
          premise['manager'] = {'user_id': managerId, 'name': user['name']};
        }
      }
      body = {'status': 0, 'data': premise};
    } else if (path == '/api/admin/premises' && method == 'POST') {
      final data = Map<String, dynamic>.from(options.data as Map);
      final premise = <String, dynamic>{
        'id': 100 + premises.length,
        'name': data['name'],
        'latitude': '${data['latitude']}',
        'longitude': '${data['longitude']}',
        'reason_names': data['reasons'] ?? <String>[],
      };
      premises.add(premise);
      statusCode = 201;
      body = {'status': 0, 'data': premise};
    } else if (path == '/api/manager/qr-token' && method == 'POST') {
      if (qrError != null) {
        return _respond({'status': 'ERROR', 'message': qrError}, 500);
      }
      body = {
        'status': 0,
        'token': qrToken,
        'TTL': qrTtl,
        'expires_at': DateTime.now()
            .add(Duration(seconds: qrTtl - qrIssuedAgo))
            .toUtc()
            .toIso8601String(),
        'premise': {'premise_id': 7, 'name': qrPremiseName},
      };
    } else if (path == '/api/admin/reasons/sync' && method == 'POST') {
      syncCalls++;
      body = {
        'status': 0,
        'message': 'Motivos de salida actualizados correctamente',
        'result': {
          'added': 1,
          'updated': 0,
          'reactivated': 0,
          'deactivated': 0,
        },
      };
    } else if (path == '/api/admin/settings/leave-limits' &&
        (method == 'GET' || method == 'PUT')) {
      if (method == 'PUT') {
        settingsUpdates.add({'path': path, ...options.data as Map});
        if (settingsError != null) {
          return _respond({'status': 'ERROR', 'message': settingsError}, 422);
        }
        final data = Map<String, dynamic>.from(options.data as Map);
        leavePeriod = data['period'] as String;
        maxExits = data['max_exits'] as int?;
        reasonLimit = Map<String, dynamic>.from(data['reason_limit'] as Map);
      }
      body = {
        'status': 0,
        'data': {
          'period': leavePeriod,
          'max_exits': maxExits,
          'reason_limit': reasonLimit,
        },
      };
    } else if (path == '/api/admin/settings/qr' &&
        (method == 'GET' || method == 'PUT')) {
      if (method == 'PUT') {
        settingsUpdates.add({'path': path, ...options.data as Map});
        if (settingsError != null) {
          return _respond({'status': 'ERROR', 'message': settingsError}, 422);
        }
        qrSeconds = (options.data as Map)['qr_ttl_seconds'] as int;
      }
      body = {
        'status': 0,
        'data': {'qr_ttl_seconds': qrSeconds},
      };
    } else if (path == '/api/admin/reasons/catalog' && method == 'GET') {
      body = {
        'status': 0,
        'data': {
          'reasons': [
            for (final reason in catalogReasons)
              {
                ...reason,
                'premises_count': premises
                    .where(
                      (p) =>
                          (p['reason_names'] as List).contains(reason['name']),
                    )
                    .length,
              },
          ],
          'sync': sync,
        },
      };
    } else {
      body = {'status': 0};
    }
    return _respond(body, statusCode);
  }

  ResponseBody _respond(Object body, int statusCode) => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
