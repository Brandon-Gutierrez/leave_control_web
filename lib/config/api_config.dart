class ApiConfig {
  /// URL del backend Laravel. Se puede sobrescribir al compilar:
  /// flutter run -d chrome --web-port 65085 --dart-define=API_BASE_URL=https://mi-api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
