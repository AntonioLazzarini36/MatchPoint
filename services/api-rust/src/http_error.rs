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

/// Un 5xx cuyo mensaje **sí** se enseña, porque no delata nada.
///
/// La regla de arriba existe contra los fallos internos: un error de Diesel
/// lleva dentro nombres de tablas y restricciones, y ésos no pueden salir.
/// Pero no todos los 5xx son eso. Un 503 de "esta instalación tiene el correo
/// apagado" es una decisión de configuración nuestra, dicha a propósito, y
/// esconderla no protege nada — sólo deja a quien lo lee con "inténtalo de
/// nuevo en unos segundos" delante de algo que no se va a arreglar solo por
/// esperar, porque no es un fallo pasajero.
///
/// **Sólo para mensajes constantes escritos por nosotros.** En cuanto el
/// texto venga de un error de una capa de abajo (base de datos, HTTP de un
/// tercero, sistema de ficheros), es `respond` y no esto: ahí es justo donde
/// se filtran las cosas. Si dudas, `respond`.
pub fn respond_public(status: StatusCode, message: impl std::fmt::Display) -> Response {
    if status.is_server_error() {
        // Se sigue registrando: que el cliente lo vea no quita que sea un
        // 5xx y que en el log haga falta para saber cuántos hay.
        tracing::warn!(%status, "{message}");
    }
    (status, Json(json!({ "message": message.to_string() }))).into_response()
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

    /// El caso del correo apagado: es un 503, pero el motivo se enseña. Con
    /// el genérico, quien lo lee entiende "vuelve a intentarlo" delante de
    /// algo que sólo se arregla encendiendo un flag en el servidor.
    #[tokio::test]
    async fn un_503_de_configuracion_si_explica_el_motivo() {
        let res = respond_public(
            StatusCode::SERVICE_UNAVAILABLE,
            "Ahora mismo no podemos enviar correos",
        );
        let body = body_of(res).await;
        assert!(body.contains("no podemos enviar correos"));
        assert!(!body.contains("Inténtalo de nuevo"));
    }

    /// Y la puerta que abre `respond_public` no toca la regla de `respond`:
    /// un fallo interno sigue sin salir por la vía normal.
    #[tokio::test]
    async fn respond_sigue_ocultando_los_5xx() {
        let res = respond(StatusCode::SERVICE_UNAVAILABLE, "Database error: boom");
        assert!(!body_of(res).await.contains("Database"));
    }
}
