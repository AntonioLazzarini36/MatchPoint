use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::schema::{matches, profiles, reports, users};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum AdminError {
    #[error("No encontramos ese reporte")]
    NotFound,
    #[error("{0}")]
    InvalidInput(String),
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

/// Un reporte con lo suficiente al lado para decidir sin abrir otra
/// pantalla: quién denuncia, a quién, y por qué.
///
/// El email va incluido porque en un caso serio hay que poder contactar con
/// las dos partes, y buscarlo a mano en la base es justo la fricción que hace
/// que la cola no se revise.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ReportEntry {
    pub id: String,
    pub reason: String,
    pub created_at: DateTime<Utc>,
    pub reviewed_at: Option<DateTime<Utc>>,
    pub review_note: Option<String>,

    pub reporter_user_id: String,
    pub reporter_email: String,
    pub reporter_name: Option<String>,

    pub reported_user_id: String,
    pub reported_email: String,
    pub reported_name: Option<String>,
    /// Cuántas veces ha sido denunciada esta persona **en total**. Una sola
    /// denuncia puede ser un roce; cinco de gente distinta es otra cosa, y
    /// sin este número cada reporte se juzga aislado.
    pub reported_total_reports: i64,
}

/// La cola. Por defecto sólo lo que falta por mirar, y lo más viejo primero:
/// una cola de moderación que empieza por lo nuevo deja lo antiguo sin
/// atender para siempre.
pub async fn list_reports(
    state: &AppState,
    include_reviewed: bool,
    limit: i64,
) -> Result<Vec<ReportEntry>, AdminError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AdminError::Pool(e.to_string()))?;

    let mut query = reports::table.into_boxed();
    if !include_reviewed {
        query = query.filter(reports::reviewed_at.is_null());
    }

    let rows = query
        .order(reports::created_at.asc())
        .limit(limit.clamp(1, 200))
        .load::<crate::models::Report>(&mut conn)
        .await?;

    let mut out = Vec::with_capacity(rows.len());
    for r in rows {
        let reporter = load_person(&mut conn, &r.reporter_user_id).await?;
        let reported = load_person(&mut conn, &r.reported_user_id).await?;

        let reported_total_reports: i64 = reports::table
            .filter(reports::reported_user_id.eq(&r.reported_user_id))
            .count()
            .get_result(&mut conn)
            .await?;

        out.push(ReportEntry {
            id: r.id,
            reason: r.reason,
            created_at: r.created_at,
            reviewed_at: r.reviewed_at,
            review_note: r.review_note,
            reporter_user_id: r.reporter_user_id,
            reporter_email: reporter.0,
            reporter_name: reporter.1,
            reported_user_id: r.reported_user_id,
            reported_email: reported.0,
            reported_name: reported.1,
            reported_total_reports,
        });
    }

    Ok(out)
}

/// Email y nombre visible. La cuenta puede haberse borrado entre el reporte y
/// la revisión (`DELETE /me` existe), así que no se puede dar por hecho que
/// esté — y perder el reporte por eso sería lo contrario de lo que se busca.
async fn load_person(
    conn: &mut diesel_async::AsyncPgConnection,
    user_id: &str,
) -> Result<(String, Option<String>), AdminError> {
    let email = users::table
        .filter(users::id.eq(user_id))
        .select(users::email)
        .first::<String>(conn)
        .await
        .optional()?
        .unwrap_or_else(|| "(cuenta borrada)".to_string());

    let name = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .select(profiles::display_name)
        .first::<String>(conn)
        .await
        .optional()?;

    Ok((email, name))
}

/// Cierra un reporte dejando escrito qué se decidió.
///
/// No borra nada ni actúa sobre la cuenta: eso es una decisión aparte y con
/// más consecuencias. Esto sólo saca el reporte de la cola dejando constancia,
/// que es lo que convierte la tabla en un registro auditable.
pub async fn review_report(
    state: &AppState,
    report_id: &str,
    note: Option<String>,
) -> Result<ReportEntry, AdminError> {
    if let Some(n) = &note {
        if n.chars().count() > 1000 {
            return Err(AdminError::InvalidInput(
                "La nota de revisión es demasiado larga".into(),
            ));
        }
    }

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AdminError::Pool(e.to_string()))?;

    let updated = diesel::update(reports::table.filter(reports::id.eq(report_id)))
        .set((
            reports::reviewed_at.eq(Utc::now()),
            reports::review_note.eq(note),
        ))
        .get_result::<crate::models::Report>(&mut conn)
        .await
        .optional()?
        .ok_or(AdminError::NotFound)?;

    let reporter = load_person(&mut conn, &updated.reporter_user_id).await?;
    let reported = load_person(&mut conn, &updated.reported_user_id).await?;
    let reported_total_reports: i64 = reports::table
        .filter(reports::reported_user_id.eq(&updated.reported_user_id))
        .count()
        .get_result(&mut conn)
        .await?;

    Ok(ReportEntry {
        id: updated.id,
        reason: updated.reason,
        created_at: updated.created_at,
        reviewed_at: updated.reviewed_at,
        review_note: updated.review_note,
        reporter_user_id: updated.reporter_user_id,
        reporter_email: reporter.0,
        reporter_name: reporter.1,
        reported_user_id: updated.reported_user_id,
        reported_email: reported.0,
        reported_name: reported.1,
        reported_total_reports,
    })
}

/// Cuentas a medio crear: sin perfil, o con perfil pero sin ninguna foto.
///
/// Ensucian de verdad: `/discover` ya las esconde (exige foto y coordenadas),
/// pero siguen ocupando la base, apareciendo en cualquier listado y
/// contando como usuarios que no son.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct IncompleteAccount {
    pub user_id: String,
    pub email: String,
    pub display_name: Option<String>,
    pub created_at: DateTime<Utc>,
    /// Qué le falta, para poder revisar la lista antes de borrar nada.
    pub reason: String,
}

/// Encuentra las cuentas incompletas.
///
/// **Nunca** incluye a quien tenga algún match: aunque su perfil esté a
/// medias, ahí hay una conversación de otra persona al otro lado, y borrar la
/// cuenta se la llevaría por delante.
pub async fn find_incomplete(state: &AppState) -> Result<Vec<IncompleteAccount>, AdminError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AdminError::Pool(e.to_string()))?;

    let rows = users::table
        .left_join(profiles::table.on(profiles::user_id.eq(users::id)))
        .select((
            users::id,
            users::email,
            users::created_at,
            profiles::display_name.nullable(),
            profiles::photos.nullable(),
        ))
        .load::<(
            String,
            String,
            DateTime<Utc>,
            Option<String>,
            Option<Vec<String>>,
        )>(&mut conn)
        .await?;

    let mut out = Vec::new();
    for (user_id, email, created_at, display_name, photos) in rows {
        let reason = match &photos {
            None => "sin perfil",
            Some(p) if p.is_empty() => "sin fotos",
            Some(_) => continue,
        };

        // Con matches no se toca, aunque el perfil este a medias.
        let has_match: i64 = matches::table
            .filter(
                matches::user_a_id
                    .eq(&user_id)
                    .or(matches::user_b_id.eq(&user_id)),
            )
            .count()
            .get_result(&mut conn)
            .await?;
        if has_match > 0 {
            continue;
        }

        out.push(IncompleteAccount {
            user_id,
            email,
            display_name,
            created_at,
            reason: reason.to_string(),
        });
    }

    Ok(out)
}

/// Borra las cuentas que devuelve `find_incomplete`.
///
/// Todo lo demás cae por `ON DELETE CASCADE`. Los ficheros de las fotos no
/// hace falta limpiarlos aquí: por definición, estas cuentas no tienen.
pub async fn delete_incomplete(state: &AppState) -> Result<usize, AdminError> {
    let victims = find_incomplete(state).await?;
    if victims.is_empty() {
        return Ok(0);
    }

    let ids: Vec<String> = victims.into_iter().map(|a| a.user_id).collect();
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AdminError::Pool(e.to_string()))?;

    let deleted = diesel::delete(users::table.filter(users::id.eq_any(&ids)))
        .execute(&mut conn)
        .await?;

    tracing::warn!("admin: borradas {deleted} cuentas incompletas");
    Ok(deleted)
}
