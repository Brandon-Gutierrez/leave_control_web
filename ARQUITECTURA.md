# Guía del repositorio

Documento de orientación para `control_leaves_web`, una aplicación Flutter de administración de usuarios y predios, y generación de códigos QR para responsables. Describe el código mantenido en el repositorio, sus relaciones y una ruta de mejora. Las carpetas nativas corresponden principalmente al soporte de Flutter para compilar y ejecutar en cada plataforma.

## Mapa general

```text
main.dart → AuthGate / SessionController
              ├─ LoginAdminPage → AuthService → ApiClient → backend Laravel
              ├─ AdminDashboardPage → HomeView / UsersView / PremisesView
              └─ ManagerLockdown → QrPage → PremiseService

Views y diálogos → Services → ApiClient / modelos
LocationPicker → GeocodingService + flutter_map
ApiClient → ApiRoutes + ApiConfig + adaptadores web/stub
```

La estructura actual está organizada por tipo técnico (`screens`, `services`, `models`), no por dominio. Los widgets de pantalla realizan parte del trabajo de estado y coordinación de datos; los servicios encapsulan llamadas al backend Laravel y los modelos convierten respuestas JSON.

## Aplicación Flutter: `lib/`

### Arranque y sesión

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `lib/main.dart` | Punto de entrada, tema, restauración de sesión (`AuthGate`) y bloqueo global de la experiencia para `MANAGE_PREMISE`. Conecta `SessionController`, `AuthService` y pantallas raíz. | Mover tema y composición de dependencias a módulos dedicados. Sustituir construcción directa de servicios por inyección; modelar carga/error/sesión con un estado observable explícito. |
| `lib/session/session_controller.dart` | Estado observable de `AuthUser` compartido entre raíz, login, dashboard y cierre de sesión. | Definir transiciones de sesión y limpiar estado de forma centralizada al cerrar sesión o recibir 401. |

### Configuración de API

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `lib/config/api_config.dart` | Define `API_BASE_URL` mediante `dart-define`, con localhost como valor predeterminado. | Validar configuración por entorno, eliminar `debug()`/`print` de producción y evitar URLs sensibles codificadas. |
| `lib/config/api_routes.dart` | Centraliza rutas REST del backend para autenticación, usuarios, predios y ajustes QR. | Mantener rutas tipadas/agrupadas por dominio y documentar el contrato con el backend; evitar que cambios de endpoint se propaguen por las vistas. |
| `lib/services/api_client.dart` | Cliente Dio singleton; añade cabeceras, identificador de dispositivo y token CSRF; transforma errores en `ApiException`. Depende de rutas, configuración y adaptadores de plataforma. | Inyectar Dio/configuración y almacenamiento para aislar pruebas. Revisar política de reintentos, timeout, cancelación y exposición de mensajes; registrar errores con contexto sin datos sensibles. |

### Servicios

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `lib/services/auth_service.dart` | Login, restauración y cierre de sesión de Sanctum usando `ApiClient`; mapea `AuthUser`. | Separar DTO de autenticación del modelo de dominio, distinguir error de red de sesión ausente y probar los casos 401/servidor. |
| `lib/services/user_admin_service.dart` | Operaciones de administración de usuarios, roles, responsables, contraseñas, dispositivos y políticas de salida; mapea tipos de `managed_user.dart`. | Dividir por capacidades (`Users`, `Roles`, `Device`, `LeavePolicy`) al crecer. Definir interfaces en capa de dominio y validar respuestas/errores uniformemente. |
| `lib/services/premise_service.dart` | Consulta, creación y actualización de predios y motivos, sincronización y emisión de tokens QR; mapea `Premise` y define `QrToken`. | Extraer DTOs de API, validar campos obligatorios y separar gestión de predios de generación de QR si evolucionan independientemente. |
| `lib/services/settings_service.dart` | Obtiene y actualiza duración global del QR; incluye `QrSettings`. | Validar rangos y respuestas en un límite dedicado, y cubrir comportamiento ante configuración inválida. |
| `lib/services/geocoding_service.dart` | Busca lugares y ubicación actual; integra geocodificación y `geolocator`, devuelve `PlaceResult`/`LatLng`. Lo usa `LocationPicker`. | Inyectar cliente y permisos/ubicación para poder probarlo; representar fallos y límites del proveedor como resultados diferenciados. |

#### Adaptadores de plataforma (`lib/services/platform/`)

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `browser_http.dart` | Export condicional de implementación web o stub para crear el adaptador Dio correcto. | Mantener la selección condicional encapsulada y cubrir ambas variantes en CI. |
| `browser_http_web.dart` | Implementación web con `BrowserHttpClientAdapter` de Dio y APIs web. | Revisar compatibilidad de cookies/CORS con backend y concentrar configuración específica del navegador en este adaptador. |
| `browser_http_stub.dart` | Adaptador no web usado en VM/pruebas. | Hacer que el stub falle con mensaje explícito si se invoca una operación no soportada. |
| `device_storage.dart` | Export condicional de almacenamiento de identificador de dispositivo. | Definir interfaz pequeña y documentar persistencia/privacidad del identificador. |
| `device_storage_web.dart` | Lee o crea el identificador persistente en navegador. | Manejar errores de almacenamiento y versionar el formato si cambia. |
| `device_storage_stub.dart` | Implementación de almacenamiento en memoria para VM/pruebas. | Permitir sustituirlo en pruebas para controlar estado y aislar casos. |
| `kiosk_lock.dart` | Export condicional para bloquear navegación atrás en modo responsable. | Nombrar la capacidad por comportamiento y definir semántica accesible para plataformas que no soporten bloqueo. |
| `kiosk_lock_web.dart` | Implementa el bloqueo mediante APIs del navegador. | Gestionar alta/baja de listeners explícitamente y probar ciclo de vida. |
| `kiosk_lock_stub.dart` | Implementación vacía de bloqueo para VM/pruebas. | Documentar que es intencionalmente no-op y mantener contrato idéntico al adaptador web. |

### Modelos

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `lib/models/auth_user.dart` | Usuario autenticado, rol y predio asignado; incluye interpretación de cargos y parsing JSON. Consumido por sesión, login y pantallas. | Usar parseo estricto/DTO y enums de rol, evitando valores por defecto silenciosos que oculten respuestas inválidas. |
| `lib/models/managed_user.dart` | Usuario administrativo, rol, predio, dispositivos/plataformas y política de salidas (`LeavePolicy`). | Separar entidades de dominio de serialización API; hacer inmutables también las colecciones y definir enums/valores de periodo centralizados. |
| `lib/models/premise_model.dart` | Predio, motivos, responsable y constantes de ubicación/radio; realiza parsing y serialización JSON. | Separar `Reason` y los DTOs del dominio; validar coordenadas/radio y usar tipos de valor para ubicación. |
| `lib/models/lat_lng.dart` | Coordenada geográfica liviana compartida por geocodificación y selector de mapa. | Validar latitud/longitud en construcción y considerar reutilizar un tipo único compatible con la librería geográfica. |

### Pantallas (`lib/screens/`)

Cada pantalla presenta una tarea de usuario; los diálogos asociados hacen parte del flujo de administración. En general, las vistas usan `ApiClient`/servicios y estilos compartidos. Para reducir acoplamiento, mover carga, filtros y mutaciones a controladores/ViewModels y dejar los widgets enfocados en presentación.

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `admin_dashboard_page.dart` | Contenedor del panel, navegación y acceso a inicio, usuarios, predios y ajustes. Integra usuario y sesión. | Separar navegación de layout; usar rutas nombradas/declarativas si crecen los flujos y controlar permisos por capacidad. |
| `login_admin_page.dart` | Formulario de acceso administrativo; usa `AuthService`, `ApiClient`, `SessionController` y abre dashboard. | Extraer validación/estado de formulario; manejar estados accesibles de error/carga y proteger navegación ante respuestas tardías. |
| `home_view.dart` | Resumen inicial con datos/acciones administrativas y tarjetas de estadísticas. | Extraer consulta a un modelo de estado y separar widgets de presentación; paginar o agregar datos en backend a escala. |
| `users_view.dart` | Tabla/lista administrativa de usuarios, filtros y acciones; coordina servicios y diálogos de roles, predios, dispositivos y políticas. | Archivo de alta responsabilidad: dividir filtros, listado y acciones por caso de uso, y trasladar estado/consultas a ViewModel. |
| `premises_view.dart` | Lista y filtros de predios; abre formulario de creación/edición. | Trasladar carga/filtros a estado dedicado y separar componentes de lista. |
| `generator_qr_page.dart` | Genera y presenta QR temporal para el usuario autenticado y predio correspondiente; usa `PremiseService`, temporizador, sesión y vista de login. | Separar ciclo de vida/renovación QR de presentación; cancelar temporizadores y solicitudes al disponer; modelar estados de expiración y error. |
| `manager_lockdown.dart` | Vista restringida para responsables; aplica el bloqueo de navegación y muestra QR o aviso si falta predio. | Convertir el rol y acceso a un guard declarativo y cubrir cambios de sesión durante la pantalla. |
| `premise_form_dialog.dart` | Formulario amplio de alta/edición de predios; relaciona motivos, responsables, `PremiseService`, `UserAdminService` y mapa. | Extraer secciones/campos y coordinador de formulario; aislar validación y guardado como caso de uso. |
| `change_role_dialog.dart` | Selección de rol y datos relacionados para cambio de permisos; usa modelos de rol/usuario. | Representar selección con tipos explícitos y validar combinaciones según reglas de negocio, idealmente compartidas con backend. |
| `create_manager_dialog.dart` | Alta de cuenta de responsable y presentación de credenciales generadas. | Evitar mantener credenciales más de lo necesario; extraer creación como flujo de aplicación y diseñar estado explícito de resultado. |
| `manager_password_dialog.dart` | Permite elegir contraseña o solicitar una generada para responsable. | Mover reglas de contraseña a validador reutilizable y cubrir errores de servidor. |
| `devices_dialog.dart` | Muestra dispositivos vinculados por plataforma y permite iniciar desvinculación desde la vista de usuarios. | Extraer acción a controlador y explicitar confirmación/estado de operación; probar permisos y fallos. |
| `leave_policy_dialog.dart` | Consulta/configura límites de salidas por periodo para empleado. | Usar enum de periodos y validación de dominio compartida; separar formulario y persistencia. |
| `qr_settings_dialog.dart` | Consulta/edita duración global de QR desde ajustes. | Limitar valores desde el modelo/servicio y comunicar claramente errores de persistencia. |

### Widgets reutilizables (`lib/widgets/`)

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `user_module.dart` | Presentación reutilizable de identidad del usuario y avatar; usada en navegación/cabeceras. | Recibir datos ya preparados y añadir semántica para lectores de pantalla e imágenes con error. |
| `filter_sidebar.dart` | Componentes genéricos de grupos de filtros y layout lateral; compartidos por vistas de usuarios/predios. | Mantener genérico el widget, pero dejar definición/aplicación de filtros en cada dominio; probar navegación por teclado y tamaños estrechos. |
| `location_picker.dart` | Selector de mapa, búsqueda, ubicación actual y selección de coordenadas; integra `flutter_map`, `GeocodingService` y modelos de predio. | Separar mapa, búsqueda y permisos en componentes/controladores; aplicar debounce y cancelación de búsquedas. |

### Tema (`lib/theme/`)

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `app_colors.dart` | Paleta de color y breakpoints usados por pantallas y widgets. | Integrar tokens en `ThemeData`/`ColorScheme` y comprobar contraste/accesibilidad en claro/oscuro. |
| `app_text_styles.dart` | Estilos tipográficos y dimensiones compartidas. | Centralizar tokens en tema tipado, evitar estilos duplicados y contemplar escalado de texto. |

## Pruebas (`test/`)

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `test/widget_test.dart` | Pruebas de widgets y flujos principales, con adaptador HTTP falso; cubre dashboard, login y generación QR según sus casos. | Dividir por feature, usar fakes tipados y añadir casos de estados vacíos, error y accesibilidad. |
| `test/premise_form_test.dart` | Prueba del formulario de predio con servicios falsos y selección en mapa. | Mantener pruebas de validación y mutaciones aisladas; evitar depender de detalles de layout cuando no sean parte del contrato. |
| `test/manager_lockdown_test.dart` | Comprueba acceso/flujo restringido de responsables usando backend simulado y control de sesión. | Añadir casos de cambio de rol, logout y fallo de generación del QR. |
| `test/devices_test.dart` | Comprueba la interacción del diálogo de dispositivos y petición de desvinculación con adaptador HTTP de registro. | Afirmar estados de error y accesibilidad, además del endpoint enviado. |

## Archivos raíz y recursos web

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `README.md` | Introducción actual de plantilla Flutter. | Sustituir por descripción funcional, requisitos, configuración `API_BASE_URL`, ejecución, compilación, pruebas y arquitectura. |
| `pubspec.yaml` | Identidad del paquete, SDK, dependencias, material design y recurso `rsc/`. | Documentar versiones de runtime, retirar comentarios de plantilla y evaluar actualización de dependencias como cambio controlado. |
| `pubspec.lock` | Versiones exactas resueltas para reproducibilidad de la aplicación. | Mantener versionado para la app y actualizar junto con validación de compatibilidad. |
| `analysis_options.yaml` | Activa reglas `flutter_lints`; excluye carpetas nativas y web del análisis Dart. | Activar reglas adicionales con migración incremental y evitar excluir código Dart mantenido sin motivo. |
| `.gitignore` | Reglas raíz para omitir artefactos locales y de compilación de Git. | Comprobar que cubra logs, secretos, configuraciones locales y salidas de todos los targets sin excluir fuentes necesarias. |
| `.metadata` | Metadatos que Flutter usa para conocer la plataforma y versión de migración del proyecto. | Mantener mediante las herramientas Flutter; no editar a mano salvo migración documentada. |
| `control_leaves_web.iml`, `android/control_leaves_web_android.iml` | Metadatos de módulos del IDE (IntelliJ/Android Studio). | Son específicos del IDE; mantener solo si el equipo realmente los comparte y no almacenan rutas locales. |
| `android/local.properties` | Rutas locales de SDK/Flutter para Gradle. | Es configuración de máquina; normalmente debe quedar fuera de control de versiones para evitar rutas personales. |
| `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/gradle-wrapper.jar` | Wrapper de Gradle para ejecutar builds con la versión acordada, sin depender de una instalación global. | Mantener wrapper consistente con `gradle-wrapper.properties` y revisar procedencia al actualizar. |
| `.flutter-plugins-dependencies` | Índice generado por Flutter de plugins y sus dependencias por plataforma. | Artefacto generado; no editar manualmente. Confirmar si está versionado y excluirlo si el flujo del proyecto no requiere conservarlo. |
| `flutter_01.log`, `flutter_02.log`, `flutter_03.log` | Registros de ejecución/build de Flutter encontrados en la raíz. | Son salida temporal: evitar versionarlos, añadir patrón adecuado a `.gitignore` y conservar solo si sirven como evidencia deliberada. |
| `flutter_01.png` | Imagen de referencia en raíz; no aparece declarada como asset en `pubspec.yaml`. | Determinar si es documentación o recurso usado; mover a carpeta con nombre claro o eliminarla si ya no se utiliza. |
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

1. **Organizar por funcionalidad**: agrupar `auth`, `users`, `premises`, `qr` y `settings` con presentación, aplicación, dominio y datos propios. Evita que un cambio funcional requiera navegar carpetas transversales grandes.
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
