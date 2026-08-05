FROM rust:1-slim-bookworm AS builder
WORKDIR /app

# curl y ca-certificates no son opcionales: el build script de
# utoipa-swagger-ui descarga los assets de Swagger UI en tiempo de
# compilación usando el curl del sistema, y sin ellos `cargo build` falla.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev pkg-config libssl-dev ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock* ./
COPY src ./src
# Las migraciones se compilan dentro del binario (`embed_migrations!` en
# src/migrate.rs), así que tienen que estar presentes al compilar aunque
# la imagen final no las lleve.
COPY migrations ./migrations
RUN cargo build --release

FROM debian:bookworm-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/matchpoint_api ./matchpoint_api

# Existe para que el contenedor arranque aunque no se monte volumen. Sin
# volumen, lo que se suba aquí se pierde en cada despliegue: en producción
# hay que montar almacenamiento persistente en esta ruta y apuntar
# PHOTOS_DIR aquí (ver DEPLOY.md).
RUN mkdir -p /app/uploads

# Informativo: el puerto real lo decide la variable PORT, que las
# plataformas de hosting inyectan solas.
EXPOSE 3000
CMD ["./matchpoint_api"]
