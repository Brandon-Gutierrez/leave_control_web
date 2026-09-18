import 'package:dio/browser.dart';
import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

/// Adaptador que envía las cookies del navegador (withCredentials).
HttpClientAdapter createHttpAdapter() =>
    BrowserHttpClientAdapter()..withCredentials = true;

/// Lee una cookie accesible desde JavaScript (p. ej. XSRF-TOKEN).
String? readCookie(String name) {
  for (final cookie in web.document.cookie.split(';')) {
    final parts = cookie.trim().split('=');
    if (parts.length >= 2 && parts[0] == name) {
      return parts.sublist(1).join('=');
    }
  }
  return null;
}
