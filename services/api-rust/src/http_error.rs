//! Cómo se le cuenta un error a quien llama a la API.
//!
//! La regla, y es la única que hay que recordar al añadir un endpoint:
//!
//! - **4xx — culpa de la petición.** El mensaje va tal cual. Son textos
//!   escritos para leerse ("No se puede proponer una fecha que ya ha
//!   pasado"), y esconderlos sólo dejaría al usuario sin saber qué corregir.
//! - **5xx — culpa nuestra.** El detalle **nunca** sale. Se registra en el
//!   log del servidor y al cliente le llega una frase genérica.
//!
//! Por qué importa: todos los errores de dominio de este backend derivan de
//! `diesel::result::Error` con `#[error("Database error: {0}")]`, y los
//! controladores serializaban `err.to_string()` sin mirar el estado. El
//! resultado era que un fallo interno devolvía cosas como
//! `duplicate key value violates unique constraint "Swipe_fromUserId_toUserId_sport_key"`:
//! nombres de tablas, de columnas y de restricciones servidos a cualquiera
//! que provoque un 500. Un mapa del esquema, gratis.
//!
//! Tampoco es sólo seguridad. "Database error: ..." no le dice nada a nadie
//! que esté mirando la app.

use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

/// Lo que ve el cliente cuando el fallo es nuestro. Deliberadamente sin
/// detalle y sin disculpas: dice qué pasó y qué puede hacer.
const SERVER_FAILURE: &str =
    "No hemos podido completar la operación. Inténtalo de nuevo en unos segundos.";

/// Construye la respuesta de error, ocultando el detalle si el fallo es del
/// servidor.
pub fn respond(status: StatusCode, err: impl std::fmt::Display) -> Response {
    if status.is_server_error() {
        // Al log entero, que es donde sí hace falta: esconderlo del cliente
        // no puede significar perderlo.
        tracing::error!(%status, "fallo interno: {err}");
        return (status, Json(json!({ "message": SERVER_FAILURE }))).into_response();
    }

    (status, Json(json!({ "message": err.to_string() }))).into_response()
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::to_bytes;

    async fn body_of(res: Response) -> String {
        let bytes = to_bytes(res.into_body(), usize::MAX).await.unwrap();
        String::from_utf8(bytes.to_vec()).unwrap()
    }

    /// El caso que motiva todo esto: un error de base de datos no puede
    /// acabar en el cuerpo de la respuesta.
    #[tokio::test]
    async fn un_500_no_filtra_el_detalle() {
        let res = respond(
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database error: duplicate key value violates unique constraint \"Swipe_pkey\"",
        );
        let body = body_of(res).await;
        assert!(
            !body.contains("Swipe_pkey"),
            "no puede salir el nombre de la restriccion"
        );
        assert!(
            !body.contains("Database"),
            "ni la palabra que delata la capa"
        );
        assert!(body.contains("Inténtalo de nuevo"));
    }

    /// Y el contrario: un 400 tiene que seguir diciendo qué corregir.
    #[tokio::test]
    async fn un_400_conserva_el_mensaje() {
        let res = respond(
            StatusCode::BAD_REQUEST,
            "No se puede proponer una fecha que ya ha pasado",
        );
        assert!(body_of(res).await.contains("una fecha que ya ha pasado"));
    }

    #[tokio::test]
    async fn un_404_conserva_el_mensaje() {
        let res = respond(StatusCode::NOT_FOUND, "Perfil no encontrado");
        assert!(body_of(res).await.contains("Perfil no encontrado"));
    }
}
