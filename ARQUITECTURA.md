# Guía del repositorio

Documento de orientación para `control_leaves_web`, una aplicación Flutter de administración de usuarios y predios, y generación de códigos QR para responsables. Describe el código mantenido en el repositorio, sus relaciones y una ruta de mejora. Las carpetas nativas corresponden principalmente al soporte de Flutter para compilar y ejecutar en cada plataforma.

## Mapa general

El código está organizado **por funcionalidad** (`features/`) con una capa de código compartido (`core/`):

```text
lib/
├── main.dart                     Punto de entrada
├── app/app.dart                  MaterialApp y guardia global del responsable de predio
├── core/                         Código compartido
│   ├── config/                   ApiConfig (URL) y ApiRoutes (rutas del backend)
│   ├── constants/role_names.dart Nombres de rol y su etiqueta
│   ├── network/                  ApiClient (Dio + cookies + CSRF) y ApiException
│   ├── platform/                 Adaptadores web/stub: HTTP del navegador, id de dispositivo, bloqueo "atrás"
│   ├── theme/                    Colores, textos, medidas y tema
│   └── widgets/                  AppModal, DialogTone, AppPopup, FilterSidebarLayout
└── features/
    ├── auth/                     Login, restauración de sesión y SessionController
    ├── dashboard/                Panel (barra lateral/navegación), Inicio y cabecera de usuario
    ├── users/                    Usuarios, roles, responsables, contraseñas y dispositivos
    ├── premises/                 Predios y motivos de salida
    ├── qr/                       Pantalla de QR y modo bloqueado del responsable
    ├── settings/                 Tiempo de vida del QR y límite de salidas
    └── map/                      Selector de ubicación (mapa, búsqueda, GPS)
```

Cada feature sigue la misma forma: `data/` (servicios que llaman al backend), `models/` (entidades y JSON), `presentation/` (pantallas, diálogos) y, cuando hace falta, `state/`.

```text
main.dart → ControlQrApp → AuthGate / SessionController
              ├─ AdminLoginPage → AuthService → ApiClient → backend Laravel
              ├─ AdminDashboardPage → HomeView / UsersView / PremisesView
              └─ ManagerLockdownPage → QrGeneratorPage → QrService

Views y diálogos → Services (data/) → ApiClient / modelos
LocationPicker → GeocodingService + flutter_map
ApiClient → ApiRoutes + ApiConfig + adaptadores web/stub
```

Los widgets de pantalla todavía realizan parte del estado y coordinación de datos; los servicios encapsulan las llamadas al backend Laravel y los modelos convierten respuestas JSON.

## Aplicación Flutter: `lib/`

### Arranque

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `main.dart` | Ejecuta `ControlQrApp`. | — |
| `app/app.dart` | `ControlQrApp`: tema, `AuthGate` como inicio y la guardia global que, si la sesión es de un responsable (`MANAGE_PREMISE`), muestra solo `ManagerLockdownPage` sin importar la ruta. | Sustituir la construcción directa de servicios por inyección. |

### `core/`

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `config/api_config.dart` | `ApiConfig.baseUrl`: URL del backend por `--dart-define=API_BASE_URL` (por defecto `http://localhost:8000`). | Validar configuración por entorno. |
| `config/api_routes.dart` | `ApiRoutes`: rutas REST agrupadas por dominio. | Documentar el contrato con el backend. |
| `constants/role_names.dart` | `RoleNames`: `admin`, `employee`, `managePremise`, `matches()` (comparación sin distinguir mayúsculas) y `label()`. Sustituye los textos de rol repetidos. | Convertir a enum cuando el backend exponga los roles tipados. |
| `network/api_client.dart` | `ApiClient`: Dio singleton con cabeceras, `DeviceId`, token CSRF y adaptador del navegador. | Inyectar Dio y almacenamiento para aislar pruebas; política de reintentos y cancelación. |
| `network/api_exception.dart` | `ApiException`: error con mensaje listo para mostrar (`isUnauthorized`). | Distinguir error de red, HTTP y parseo. |
| `platform/browser_http*.dart` | Adaptador Dio del navegador (cookies) o stub en VM. | Cubrir ambas variantes en CI. |
| `platform/device_storage*.dart` | Identificador persistente del navegador (localStorage) o stub en memoria. | Manejar errores de almacenamiento. |
| `platform/kiosk_lock*.dart` | Bloqueo del botón "atrás" del navegador para el responsable, o no-op en VM. | Gestionar alta/baja de listeners y probar su ciclo de vida. |
| `theme/` | `AppColors`, `Breakpoints`, `AppText`, `AppDimens` y `buildAppTheme()`. | Integrar los tokens en `ThemeData`/`ColorScheme`. |
| `widgets/app_modal.dart`, `dialog_tone.dart` | Carcasa común de los modales (cabecera de color según `DialogTone`) y sus botones. | — |
| `widgets/app_popup.dart` | `showAppPopup`: aviso flotante (éxito, error, advertencia) con autocierre de 7 s. | Evaluar `ScaffoldMessenger`. |
| `widgets/filter_sidebar.dart` | `FilterGroup` y `FilterSidebarLayout`: barra de filtros lateral o plegable. | Pruebas de teclado y tamaños estrechos. |

### `features/`

| Feature | Archivos | Función y relaciones |
|---|---|---|
| `auth` | `data/auth_service.dart`, `models/auth_user.dart`, `state/session_controller.dart`, `presentation/admin_login_page.dart`, `presentation/auth_gate.dart` | Login, restauración y cierre de sesión (Sanctum); `AuthUser` con rol y predio asignado; `SessionController` publica el usuario actual; `AuthGate` restaura la sesión al recargar. |
| `dashboard` | `presentation/admin_dashboard_page.dart`, `home_view.dart`, `user_profile_header.dart` | Estructura del panel (barra lateral en pantallas anchas, navegación inferior en teléfono), resumen de Inicio con accesos directos y cabecera con foto, nombre y cargo. |
| `users` | `data/user_admin_service.dart`, `models/managed_user.dart`, `presentation/users_view.dart`, `change_role_dialog.dart`, `create_manager_dialog.dart`, `manager_password_dialog.dart`, `devices_dialog.dart` | Listado y filtros de usuarios; cambio de rol y de predio; alta de responsables y contraseña generada; dispositivos vinculados por aplicación (`ClientPlatform`) y su desvinculación. |
| `premises` | `data/premise_service.dart`, `models/premise.dart`, `models/reason.dart`, `presentation/premises_view.dart`, `premise_form_dialog.dart` | Predios con ubicación, responsable y motivos; creación y edición; sincronización del catálogo de motivos. |
| `qr` | `data/qr_service.dart`, `models/qr_token.dart`, `presentation/qr_generator_page.dart`, `manager_lockdown_page.dart` | Genera y renueva el QR temporal; `ManagerLockdownPage` es la única pantalla de una cuenta `MANAGE_PREMISE`. |
| `settings` | `data/settings_service.dart`, `models/qr_settings.dart`, `models/leave_limits.dart`, `presentation/qr_settings_dialog.dart`, `leave_limits_dialog.dart` | Tiempo de vida del QR y límite general de salidas por período. |
| `map` | `data/geocoding_service.dart`, `models/lat_lng.dart`, `constants/map_defaults.dart`, `presentation/location_picker.dart` | Búsqueda de lugares (Nominatim), ubicación actual (GPS) y selector con mapa (`flutter_map`). |

Mejoras sugeridas: mover carga, filtros y mutaciones de `UsersView`, `PremisesView`, `HomeView` y `PremiseFormDialog` a controladores/ViewModels; usar enums de rol y período; extraer DTOs de API.

## Pruebas (`test/`)

| Archivo | Función y relaciones |
|---|---|
| `test/features/dashboard/admin_panel_test.dart` | Panel, login y QR con adaptador HTTP falso: navegación, Inicio, sincronización de motivos, cambio de rol, QR sin desbordes. |
| `test/features/premises/premise_form_dialog_test.dart` | Formulario de predio con servicios falsos y selección en el mapa. |
| `test/features/qr/manager_lockdown_test.dart` | Acceso y flujo restringido del responsable con backend simulado y control de sesión. |
| `test/features/users/devices_dialog_test.dart` | Diálogo de dispositivos y petición de desvinculación. |

## Archivos raíz y recursos web

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `README.md` | Propósito, requisitos, configuración `API_BASE_URL`, ejecución, pruebas y estructura. | Añadir despliegue y variables por entorno. |
| `pubspec.yaml` | Identidad del paquete, SDK, dependencias, material design y recurso `rsc/`. | Evaluar la actualización de dependencias como cambio controlado. |
| `pubspec.lock` | Versiones exactas resueltas para reproducibilidad de la aplicación. | Mantener versionado para la app y actualizar junto con validación de compatibilidad. |
| `analysis_options.yaml` | Activa `flutter_lints` y reglas extra (`directives_ordering`, `prefer_single_quotes`, `prefer_final_locals`, `unawaited_futures`, `avoid_print`); excluye carpetas nativas y web del análisis Dart. | Ejecutar `flutter analyze` como puerta de CI. |
| `.gitignore` | Reglas raíz para omitir artefactos locales y de compilación de Git. | Comprobar que cubra logs, secretos, configuraciones locales y salidas de todos los targets sin excluir fuentes necesarias. |
| `.metadata` | Metadatos que Flutter usa para conocer la plataforma y versión de migración del proyecto. | Mantener mediante las herramientas Flutter; no editar a mano salvo migración documentada. |
| `control_leaves_web.iml`, `android/control_leaves_web_android.iml` | Metadatos de módulos del IDE (IntelliJ/Android Studio). | Son específicos del IDE; mantener solo si el equipo realmente los comparte y no almacenan rutas locales. |
| `android/local.properties` | Rutas locales de SDK/Flutter para Gradle. | Es configuración de máquina; normalmente debe quedar fuera de control de versiones para evitar rutas personales. |
| `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/gradle-wrapper.jar` | Wrapper de Gradle para ejecutar builds con la versión acordada, sin depender de una instalación global. | Mantener wrapper consistente con `gradle-wrapper.properties` y revisar procedencia al actualizar. |
| `.flutter-plugins-dependencies` | Índice generado por Flutter de plugins y sus dependencias por plataforma. | Artefacto generado; no editar manualmente. Confirmar si está versionado y excluirlo si el flujo del proyecto no requiere conservarlo. |
| `flutter_01.log`, `flutter_02.log`, `flutter_03.log` | Registros de ejecución/build de Flutter encontrados en la raíz. | Son salida temporal: evitar versionarlos, añadir patrón adecuado a `.gitignore` y conservar solo si sirven como evidencia deliberada. |
| `flutter_01.png` | Captura suelta en la raíz; no está declarada como asset ni se referencia. | Eliminarla del repositorio (`git rm flutter_01.png`). |
| `rsc/comteco.png` | Marca/imagen de recursos incluida mediante `rsc/` en pubspec. | Referenciarla mediante una constante de assets y revisar variantes/resolución y licencias. |
| `web/index.html` | Documento HTML anfitrión de Flutter Web. | Revisar título, metadatos, accesibilidad y configuración de carga según despliegue. |
| `web/manifest.json` | Nombre, colores e iconos de la PWA. | Mantener metadatos alineados con identidad y probar instalación/actualización PWA. |
| `web/favicon.png` | Icono del navegador. | Mantener derivado del icono de marca y validar dimensiones. |
| `web/icons/Icon-192.png`, `web/icons/Icon-512.png` | Iconos PWA de tamaños estándar. | Regenerar desde fuente de marca y comprobar legibilidad a tamaño real. |
| `web/icons/Icon-maskable-192.png`, `web/icons/Icon-maskable-512.png` | Variantes seguras para recorte de icono instalado. | Respetar zona segura de máscara y validar en lanzadores. |

## Soporte nativo y archivos de plataforma

Las carpetas siguientes permiten ejecutar/build de Flutter en móvil y escritorio. Los archivos `generated_*`, `GeneratedPluginRegistrant*` y registradores de plugins son salidas generadas; se regeneran con Flutter y no deberían recibir lógica de negocio. Recursos `.png`, `.ico` y `.xcassets` son iconos/launch images. Los manifiestos, proyectos y configuración restante contienen la integración específica de cada sistema.

### Android (`android/`)

- `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`: configuración Gradle global y plugins.
- `gradle/wrapper/gradle-wrapper.properties`: versión de Gradle usada por el wrapper.
- `app/build.gradle.kts`: módulo Android, SDK, dependencias y variantes de compilación Flutter.
- `app/src/main/AndroidManifest.xml`: permisos, actividad y metadatos de la app.
- `app/src/debug/AndroidManifest.xml`, `app/src/profile/AndroidManifest.xml`: manifiestos para debug y profile.
- `app/src/main/kotlin/com/example/control_leaves_web/MainActivity.kt`: actividad anfitriona Android.
- `app/src/main/res/values/styles.xml`, `values-night/styles.xml`: estilos de ventana claro/oscuro.
- `app/src/main/res/drawable/launch_background.xml`, `drawable-v21/launch_background.xml`: fondo de inicio según versión Android.
- `app/src/main/res/mipmap-*/ic_launcher.png` (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`): iconos de launcher por densidad.

Mejora: cambiar el identificador de paquete `com.example` antes de publicar, revisar permisos y secretos de firma fuera del repositorio, y mantener configuración de SDK alineada con dependencias.

### iOS (`ios/`)

- `Runner/AppDelegate.swift`, `Runner/SceneDelegate.swift`: ciclo de vida de aplicación/escena y arranque de Flutter.
- `Runner/Info.plist`: metadatos, permisos y configuración de la app.
- `Runner/Runner-Bridging-Header.h`: puente entre Swift y código Objective-C/Flutter si se requiere.
- `Runner/Base.lproj/Main.storyboard`: storyboard principal.
- `Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` y `Icon-App-*.png`: catálogo y tamaños de icono iOS.
- `Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`, `LaunchImage.png`, `LaunchImage@2x.png`, `LaunchImage@3x.png`, `README.md`: recurso y documentación de launch image.
- `Runner.xcodeproj/project.pbxproj`: configuración del proyecto Xcode.
- `Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`: esquema compartido de compilación/ejecución.
- `Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`, `.../xcshareddata/IDEWorkspaceChecks.plist`, `.../xcshareddata/WorkspaceSettings.xcsettings`: workspace y preferencias de Xcode.
- `Runner.xcworkspace/contents.xcworkspacedata`, `Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`, `Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`: workspace usado para abrir el proyecto.
- `Flutter/Debug.xcconfig`, `Flutter/Release.xcconfig`, `Flutter/AppFrameworkInfo.plist`: configuración Flutter por build y metadatos del framework.
- `RunnerTests/RunnerTests.swift`: pruebas del target nativo iOS.

Mejora: revisar identificadores, permisos y capacidades antes de publicar; mantener secretos/certificados en el sistema de CI y no en el repositorio.

### macOS (`macos/`)

- `Runner/AppDelegate.swift`, `Runner/MainFlutterWindow.swift`: arranque y ventana anfitriona Flutter.
- `Runner/Info.plist`: metadatos de la aplicación.
- `Runner/DebugProfile.entitlements`, `Runner/Release.entitlements`: capacidades por configuración.
- `Runner/Configs/AppInfo.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Warnings.xcconfig`: identidad, ajustes de build y warnings.
- `Runner/Base.lproj/MainMenu.xib`: menú y ventana inicial.
- `Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, `app_icon_16.png`, `app_icon_32.png`, `app_icon_64.png`, `app_icon_128.png`, `app_icon_256.png`, `app_icon_512.png`, `app_icon_1024.png`: catálogo e iconos.
- `Runner.xcodeproj/project.pbxproj`, `Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`: proyecto y esquema Xcode.
- `Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`, `.../xcshareddata/IDEWorkspaceChecks.plist`: workspace del proyecto.
- `Runner.xcworkspace/contents.xcworkspacedata`, `Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`: workspace de ejecución.
- `Flutter/Flutter-Debug.xcconfig`, `Flutter/Flutter-Release.xcconfig`, `Flutter/GeneratedPluginRegistrant.swift`: configuración Flutter y registrador de plugins generado.
- `macos/RunnerTests/RunnerTests.swift`: pruebas del target nativo macOS.

Mejora: verificar entitlements mínimos necesarios y gestionar firma/notarización desde CI.

### Windows (`windows/`)

- `CMakeLists.txt`, `runner/CMakeLists.txt`, `flutter/CMakeLists.txt`: configuración CMake raíz, runner y motor Flutter.
- `runner/main.cpp`, `runner/flutter_window.cpp`, `runner/flutter_window.h`: entrada de aplicación y ventana Flutter.
- `runner/win32_window.cpp`, `runner/win32_window.h`: creación y manejo de ventana Win32.
- `runner/utils.cpp`, `runner/utils.h`: utilidades del runner.
- `runner/Runner.rc`, `runner/resource.h`, `runner/resources/app_icon.ico`, `runner/runner.exe.manifest`: recursos, identificadores e identidad de ejecución de Windows.
- `flutter/generated_plugin_registrant.cc`, `flutter/generated_plugin_registrant.h`, `flutter/generated_plugins.cmake`: registro generado de plugins.

Mejora: sustituir metadatos de plantilla, definir identidad/producto/versionado y firmar artefactos desde CI.

### Linux (`linux/`)

- `CMakeLists.txt`, `flutter/CMakeLists.txt`, `runner/CMakeLists.txt`: configuración de compilación CMake.
- `runner/main.cc`, `runner/my_application.cc`, `runner/my_application.h`: punto de entrada y aplicación GTK/Flutter.
- `runner/generated_plugin_registrant.cc`, `runner/generated_plugin_registrant.h`, `flutter/generated_plugins.cmake`: registro generado de plugins.

Mejora: definir metadatos de paquete/distribución, estrategia de instalación y automatizar builds reproducibles.

## Recomendaciones de arquitectura

La aplicación ya separa modelos, servicios y presentación, lo que ofrece un punto de partida razonable. Para acercarla a Clean Architecture y facilitar crecimiento:

1. **Organizar por funcionalidad** (hecho): `features/auth`, `users`, `premises`, `qr`, `settings`, `dashboard` y `map` con `data`, `models` y `presentation` propios, y `core/` para lo compartido. Siguiente paso: añadir una capa de aplicación (controladores/casos de uso).
2. **Definir dependencias hacia dentro**: casos de uso/controladores dependen de contratos de repositorio; implementaciones Dio dependen de esos contratos. El dominio no debe importar Flutter, Dio ni JSON.
3. **Separar modelos de API y dominio**: convertir JSON en DTOs estrictos y mapearlos a entidades. Evitar `dynamic`, casts implícitos y valores sustitutos que escondan respuestas incompatibles.
4. **Inyectar dependencias**: crear `ApiClient`, servicios y repositorios en el composition root. Evitar singleton global para permitir pruebas deterministas y configuración por entorno.
5. **Estados explícitos y UI pequeña**: representar carga, éxito, vacío y error con estados; trasladar consultas, filtros y mutaciones fuera de widgets grandes como `UsersView`.
6. **Errores y seguridad**: normalizar errores HTTP, conservar códigos para decisiones de UI, no mostrar detalles internos del backend y no registrar credenciales, cookies, tokens ni datos personales.
7. **Calidad verificable**: ampliar pruebas unitarias para mapeadores/casos de uso, pruebas de widgets para flujos, y análisis/lints en CI. Añadir integración contra contrato de API cuando backend lo permita.
8. **Accesibilidad y mantenibilidad visual**: centralizar tema/tokens, respetar escalado de texto, contraste, foco y navegación por teclado; evitar estilos dispersos.
9. **Documentación y operación**: completar README con setup, entornos, despliegue, configuración y convenciones. Mantener decisiones arquitectónicas importantes en ADR breves.

## Límites de este inventario

El inventario cubre archivos de aplicación, pruebas, configuración, recursos y soporte nativo presentes al documentar. Los binarios de iconos/imagenes se describen por su papel, no por su contenido visual. Archivos generados por Flutter o herramientas nativas deben tratarse como artefactos de integración, salvo que una personalización concreta esté documentada.

Las carpetas de caché (`.gradle/`, `Flutter/ephemeral/`) y registros detectados localmente son temporales y no forman parte de la arquitectura funcional. No se detallan archivo por archivo porque Flutter, Gradle o Xcode pueden regenerarlos; deben excluirse del control de versiones salvo una necesidad explícita del equipo.
