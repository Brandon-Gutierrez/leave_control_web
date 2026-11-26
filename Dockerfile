#
# Panel web (Flutter Web) servido por nginx, con HTTPS y reenvío a la API. El
# contexto de build es la raíz de este repositorio; el despliegue está en
# docker/docker-compose.yml (ver README.md).
#
# Al ejecutar la imagen hay que indicar BACKEND_URL, la dirección de la API:
# nginx le reenvía /api, /sanctum y /up, y el resto lo sirve Flutter.

# ---------------------------------------------------------------- Flutter SDK
FROM debian:bookworm-slim AS flutter-sdk

ARG FLUTTER_VERSION=3.47.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

# ---------------------------------------------------------------- compilación
FROM flutter-sdk AS build

# URL del backend que se incrusta al compilar. Debe quedar vacía: la web llama a
# /api en la dirección desde la que se sirve y nginx lo reenvía a la API.
ARG API_BASE_URL=""

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"

# ---------------------------------------------------------------- nginx
FROM nginx:1.27-alpine AS prod

RUN apk add --no-cache openssl

COPY --from=build /app/build/web /usr/share/nginx/html
COPY docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY docker/nginx/api-proxy.conf /etc/nginx/api-proxy.conf
# Al arrancar: valida BACKEND_URL y, si falta el certificado, genera uno autofirmado.
COPY --chmod=755 docker/nginx/05-check-backend-url.sh /docker-entrypoint.d/05-check-backend-url.sh
COPY --chmod=755 docker/nginx/10-selfsigned-cert.sh /docker-entrypoint.d/10-selfsigned-cert.sh

# Valores por defecto de la configuración de nginx. BACKEND_URL no tiene: es obligatorio.
ENV PUBLIC_HTTPS_PORT=443 \
    TRUSTED_PROXY=127.0.0.1/32

EXPOSE 80 443
