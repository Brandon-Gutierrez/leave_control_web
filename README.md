# Panel web de administración

Aplicación Flutter Web con dos usos:

- **Administración**: gestiona usuarios y roles, predios (ubicación, responsable y motivos de salida), dispositivos vinculados, tiempo de vida del QR y límite de salidas.
- **Responsable de predio** (rol `MANAGE_PREMISE`): su cuenta solo muestra el QR de su predio, que se renueva sola.

El backend es el proyecto Laravel `control_salida`; la app de los empleados es `control_leaves_mobile`.

## Requisitos

- Flutter con Dart `^3.13`.
- Backend accesible (por defecto `http://localhost:8000`).

## Ejecutar

```bash
flutter pub get
flutter run -d chrome --web-port 65085 --dart-define=API_BASE_URL=https://mi-api
```

## Pruebas y análisis

```bash
flutter analyze
flutter test
```

## Estructura

El código está organizado por funcionalidad:

```text
lib/
├── main.dart
├── app/            MaterialApp y guardia del responsable de predio
├── core/           config, network, platform (web/stub), theme, widgets compartidos
└── features/       auth, dashboard, users, premises, qr, settings, map
                    (cada una con data/, models/ y presentation/)
```

El detalle de cada archivo está en [ARQUITECTURA.md](ARQUITECTURA.md).
