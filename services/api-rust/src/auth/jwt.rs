use axum::{
    async_trait,
    extract::{FromRef, FromRequestParts},
    http::{request::Parts, StatusCode},
    RequestPartsExt,
};
use axum_extra::headers::{authorization::Bearer, Authorization};
use axum_extra::TypedHeader;
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

use crate::state::AppState;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String,
    pub email: String,
    pub exp: usize,
}

pub fn sign(claims: &Claims, secret: &str) -> String {
    encode(
        &Header::default(),
        claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .expect("jwt signing should not fail")
}

pub fn verify(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )?;
    Ok(data.claims)
}

/// Equivalente de lo que `jwt.strategy.ts`'s `validate()` deja en `req.user`.
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: String,
    pub email: String,
}

/// Equivalente de `@UseGuards(JwtAuthGuard)`. Cualquier ruta que necesite
/// auth simplemente añade `user: AuthUser` como parámetro del handler
/// (discover, me, swipes, matches, chats, users lo usarán así).
#[async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    /// Se responde con el mismo `{ "message": ... }` que el resto de la API:
    /// devolver texto plano aqui obligaba al cliente a tratar este error
    /// distinto de todos los demas.
    ///
    /// Y con el **mismo texto** tanto si falta el token como si es invalido o
    /// ha caducado: la salida para quien llama es identica —volver a iniciar
    /// sesion— y distinguirlos solo le dice a quien prueba tokens en que ha
    /// fallado.
    type Rejection = axum::response::Response;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let TypedHeader(Authorization(bearer)) = parts
            .extract::<TypedHeader<Authorization<Bearer>>>()
            .await
            .map_err(|_| unauthorized())?;

        let app_state = AppState::from_ref(state);

        let claims = verify(bearer.token(), &app_state.config.jwt_access_secret)
            .map_err(|_| unauthorized())?;

        Ok(AuthUser {
            user_id: claims.sub,
            email: claims.email,
        })
    }
}

fn unauthorized() -> axum::response::Response {
    crate::http_error::respond(
        StatusCode::UNAUTHORIZED,
        "Tu sesión ha caducado. Vuelve a iniciar sesión",
    )
}
