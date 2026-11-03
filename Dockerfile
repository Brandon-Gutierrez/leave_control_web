#
# Panel web (Flutter Web) servido por nginx. El contexto de build es la raíz de
# este repositorio.
#
#   docker build -t control-salidas-web --build-arg API_BASE_URL=https://mi-api .
#
# Por defecto la imagen sirve solo la web en el puerto 80. En el despliegue
# completo (repositorio de despliegue) se le monta una configuración de nginx que
# hace de puerta de entrada: web en "/" y /api, /sanctum hacia el backend.

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

# URL del backend que se incrusta al compilar. Vacía = mismo origen (la web
# llama a /api en el dominio desde el que se sirve).
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
# Si se monta /etc/nginx/certs sin certificado, genera uno autofirmado (ver el script).
COPY --chmod=755 docker/nginx/10-selfsigned-cert.sh /docker-entrypoint.d/10-selfsigned-cert.sh

EXPOSE 80 443
