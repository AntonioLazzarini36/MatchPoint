//! Direct port of app.controller.ts.
//!
//! Nest wires `@Controller() -> @Get()` decorators; Axum wires plain
//! functions into a `Router`. `router()` here is the Rust equivalent of
//! the `@Controller()` class itself - every other module (auth, discover,
//! swipes...) will get its own `controller.rs` with the same shape, and
//! `app.rs` merges them the way `app.module.ts` lists them in `imports`.

use axum::{extract::State, http::StatusCode, response::IntoResponse, routing::get, Json, Router};
use diesel_async::RunQueryDsl;
use serde_json::json;

use crate::app::service;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::openapi::OkResponse;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(get_hello))
        .route("/health", get(health))
        .route("/app/config", get(app_config))
}

/// Lo que el cliente necesita saber **antes** de tener sesión.
///
/// De momento una sola cosa: si esta instalación puede mandar correos. Hace
/// falta en la pantalla de login, que es donde vive "he olvidado mi
/// contraseña" — y ese enlace, con el correo apagado, lleva a un 503. Un
/// enlace que siempre falla se lee como una app rota, así que el cliente lo
/// esconde; pero no puede preguntarlo por `/me`, que va autenticado y aquí
/// justamente no hay sesión.
///
/// No expone nada: es un booleano de configuración, no un dato de nadie.
#[derive(serde::Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct PublicConfig {
    /// Si es `false`, verificar el email y recuperar la contraseña devuelven
    /// 503 y el cliente debería esconder las dos cosas.
    pub email_enabled: bool,
}

#[utoipa::path(
    get,
    path = "/app/config",
    tag = "misc",
    responses((status = 200, description = "Configuración pública", body = PublicConfig))
)]
async fn app_config(State(state): State<AppState>) -> Json<PublicConfig> {
    Json(PublicConfig {
        email_enabled: state.config.email_verification_enabled,
    })
}

#[utoipa::path(
    get,
    path = "/",
    tag = "misc",
    responses((status = 200, description = "Saludo de prueba", body = String))
)]
async fn get_hello() -> &'static str {
    service::get_hello()
}

/// Healthcheck de verdad: toca la base de datos.
///
/// Antes devolvía `{ok:true}` fijo y la conectividad con Postgres sólo se
/// comprobaba una vez, al arrancar. Un balanceador o un `docker healthcheck`
/// apuntando aquí daría "sano" con la base caída, que es justo el momento
/// en que hace falta que diga lo contrario. Devuelve 503 si no puede
/// consultar, para que el orquestador pueda reiniciar o sacar la instancia
/// de rotación.
#[utoipa::path(
    get,
    path = "/health",
    tag = "misc",
    responses(
        (status = 200, description = "Servicio y base de datos OK", body = OkResponse),
        (status = 503, description = "La base de datos no responde", body = OkResponse),
    )
)]
async fn health(State(state): State<AppState>) -> impl IntoResponse {
    // Corto a propósito: un healthcheck que tarda 30s en fallar no sirve
    // para lo que existe. Si la base no contesta en 2s, no está sana.
    let probe = tokio::time::timeout(std::time::Duration::from_secs(2), async {
        let mut conn = state.db.get().await.map_err(|e| e.to_string())?;
        diesel::sql_query("SELECT 1")
            .execute(&mut conn)
            .await
            .map_err(|e| e.to_string())
    })
    .await;

    match probe {
        Ok(Ok(_)) => (StatusCode::OK, Json(json!({ "ok": true }))),
        Ok(Err(e)) => {
            tracing::error!("healthcheck: la base de datos falló: {e}");
            (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({ "ok": false, "database": "error" })),
            )
        }
        Err(_) => {
            tracing::error!("healthcheck: la base de datos no respondió en 2s");
            (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({ "ok": false, "database": "timeout" })),
            )
        }
    }
}
