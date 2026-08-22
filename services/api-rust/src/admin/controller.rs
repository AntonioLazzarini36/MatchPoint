use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, patch},
    Json, Router,
};
use serde::Deserialize;
use serde_json::json;
use utoipa::{IntoParams, ToSchema};

#[allow(unused_imports)] // referenciado solo dentro de #[utoipa::path]
use crate::admin::service::ReportEntry;
use crate::admin::service::{self, AdminError};
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/admin/reports", get(list_reports))
        .route("/admin/reports/:reportId", patch(review_report))
}

/// Comprueba la clave de administración.
///
/// Devuelve **404 y no 401** cuando la clave falla o no está configurada: un
/// 401 confirmaría que la ruta existe, y eso es justo lo que no interesa
/// decirle a quien va probando URLs. Para un operador legítimo, que sabe que
/// existe, no cambia nada.
fn authorised(state: &AppState, headers: &HeaderMap) -> bool {
    let Some(expected) = &state.config.admin_api_key else {
        return false;
    };
    let Some(provided) = headers.get("x-admin-key").and_then(|v| v.to_str().ok()) else {
        return false;
    };
    // Comparación de longitud constante: comparar con `==` filtra por tiempo
    // cuántos caracteres iniciales ha acertado quien lo intenta.
    constant_time_eq(expected.as_bytes(), provided.as_bytes())
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

fn not_found() -> Response {
    (
        StatusCode::NOT_FOUND,
        Json(json!({ "message": "Not found" })),
    )
        .into_response()
}

#[derive(Debug, Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ListReportsQuery {
    /// Por defecto sólo lo pendiente, que es lo que hace falta a diario.
    #[serde(default)]
    pub include_reviewed: bool,
    #[serde(default = "default_limit")]
    pub limit: i64,
}

fn default_limit() -> i64 {
    50
}

/// La cola de moderación: reportes sin revisar, lo más viejo primero.
#[utoipa::path(
    get,
    path = "/admin/reports",
    tag = "admin",
    params(ListReportsQuery),
    responses(
        (status = 200, description = "Reportes de la cola", body = Vec<ReportEntry>),
        (status = 404, description = "Clave de administración ausente o incorrecta", body = ErrorResponse),
    )
)]
async fn list_reports(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListReportsQuery>,
) -> Response {
    if !authorised(&state, &headers) {
        return not_found();
    }
    match service::list_reports(&state, q.include_reviewed, q.limit).await {
        Ok(list) => Json(list).into_response(),
        Err(e) => error_response(e),
    }
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ReviewReportDto {
    /// Qué se decidió. Queda escrito en el reporte.
    pub note: Option<String>,
}

/// Cierra un reporte dejando constancia de qué se decidió.
#[utoipa::path(
    patch,
    path = "/admin/reports/{reportId}",
    tag = "admin",
    params(("reportId" = String, Path, description = "Id del reporte")),
    request_body = ReviewReportDto,
    responses(
        (status = 200, description = "Reporte marcado como revisado", body = ReportEntry),
        (status = 400, description = "Nota demasiado larga", body = ErrorResponse),
        (status = 404, description = "Reporte no encontrado, o clave incorrecta", body = ErrorResponse),
    )
)]
async fn review_report(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(report_id): Path<String>,
    Json(dto): Json<ReviewReportDto>,
) -> Response {
    if !authorised(&state, &headers) {
        return not_found();
    }
    match service::review_report(&state, &report_id, dto.note).await {
        Ok(entry) => Json(entry).into_response(),
        Err(e) => error_response(e),
    }
}

fn error_response(err: AdminError) -> Response {
    let status = match &err {
        AdminError::NotFound => StatusCode::NOT_FOUND,
        AdminError::InvalidInput(_) => StatusCode::BAD_REQUEST,
        AdminError::Db(_) | AdminError::Pool(_) => StatusCode::INTERNAL_SERVER_ERROR,
    };
    (status, Json(json!({ "message": err.to_string() }))).into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compara_en_tiempo_constante() {
        assert!(constant_time_eq(b"secreto", b"secreto"));
        assert!(!constant_time_eq(b"secreto", b"secretO"));
        assert!(!constant_time_eq(b"secreto", b"secret"));
        assert!(!constant_time_eq(b"", b"x"));
    }
}
