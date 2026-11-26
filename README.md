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

## Despliegue con Docker (producción)

Este repositorio despliega **solo la web**, sin necesitar archivos del backend. Corre un contenedor, `web`: nginx sirve Flutter con HTTPS y reenvía `/api`, `/sanctum` y `/up` a la API, que se despliega aparte. El navegador ve una sola dirección, así que el inicio de sesión no necesita CORS.

Requisitos en el servidor: Docker con Compose v2. Si vienes de la instalación anterior (un solo compose en el backend), sigue antes la sección «Desde la instalación anterior» del README del backend.

### Primer despliegue

La API y la web comparten una red de Docker que se crea **una sola vez** en el servidor (si ya se creó para el backend, omite ese paso). Después, desde la carpeta `docker/`:

```bash
docker network create --subnet 172.30.0.0/24 control-salidas
cp .env.example .env    # completar PUBLIC_HOST (el mismo que en el .env del backend)
docker compose up -d --build
curl -k https://localhost/api/health    # con la API arriba: {"status":"OK"}
```

El orden entre los dos despliegues no importa: sin la API, la web carga y `/api` responde 502.

### Actualizar

Después de `git pull`, desde `docker/`: `docker compose up -d --build`. No toca la API.

### Dirección de la API

`BACKEND_URL` (en `docker/.env`) es `http(s)://host[:puerto]`, sin barra final. Si no es válida, el contenedor no arranca y lo explica en `docker compose logs web`.

| Dónde está la API | `BACKEND_URL` |
|---|---|
| En el mismo servidor | `http://control-salidas-api` (valor por defecto; HTTP dentro de la red de Docker) |
| En otro servidor | `https://IP-o-nombre:8443`. En el `.env` del backend, `TRUSTED_PROXY` pasa a ser la IP de este servidor. El tráfico va cifrado, pero no se verifica el certificado de la API. |

Cambiarla no exige recompilar: basta `docker compose up -d`.

### HTTPS y certificado

El puerto 80 redirige a HTTPS. El certificado se lee de `docker/certs/`: `fullchain.pem` (el certificado seguido de los intermedios) y `privkey.pem` (la clave, sin contraseña). Si faltan, se genera uno autofirmado para probar. Después de reemplazarlos: `docker compose restart web`. El README del backend explica cómo comprobar los archivos; la API necesita su propia copia.

Si Comteco pone **su propio proxy** delante, indica su IP en `TRUSTED_PROXY`. Si el proxy habla con este servidor por HTTPS, la configuración sirve como está. Si le habla por **HTTP (80)**, hay que cambiar `docker/nginx/default.conf.template`: tal como está, produce un bucle de redirecciones.

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
