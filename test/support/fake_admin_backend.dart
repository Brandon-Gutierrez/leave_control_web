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
    final Object body;
    if (path == '/api/admin/summary' && method == 'GET') {
      body = {'status': 0, 'data': summary};
    } else if (path == '/api/admin/premises' && method == 'GET') {
      body = {'status': 0, 'data': premises};
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
    } else if (path == '/api/admin/settings/leave-limits' && method == 'GET') {
      body = {
        'status': 0,
        'data': {
          'period': 'day',
          'max_exits': 3,
          'reason_limit': {
            'period': 'day',
            'mode': 'general',
            'general': 1,
            'custom': <Object>[],
          },
        },
      };
    } else if (path == '/api/admin/settings/qr' && method == 'GET') {
      body = {
        'status': 0,
        'data': {'qr_ttl_seconds': 300},
      };
    } else if (path == '/api/admin/reasons/catalog' && method == 'GET') {
      body = {
        'status': 0,
        'data': {'reasons': <Object>[], 'sync': null},
      };
    } else {
      body = {'status': 0};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
