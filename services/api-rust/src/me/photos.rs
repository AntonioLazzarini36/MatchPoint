//! File storage for profile photos. Pure I/O, no DB access — mirrors how
//! `chats::crypto` isolates encryption from `chats::service`. The DB side
//! (appending/removing a URL on `profiles.photos`) lives in `me::service`.

use std::path::Path;

pub const MAX_PHOTOS: usize = 6;
const MAX_PHOTO_BYTES: usize = 5 * 1024 * 1024;

#[derive(Debug, thiserror::Error)]
pub enum PhotoError {
    #[error("falta el campo 'photo' en el multipart")]
    MissingField,
    #[error("tipo de imagen no soportado: {0}")]
    UnsupportedContentType(String),
    #[error("la foto supera el límite de 5MB")]
    TooLarge,
    #[error("multipart error: {0}")]
    Multipart(#[from] axum::extract::multipart::MultipartError),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

fn extension_for(content_type: &str) -> Result<&'static str, PhotoError> {
    match content_type {
        "image/jpeg" => Ok("jpg"),
        "image/png" => Ok("png"),
        "image/webp" => Ok("webp"),
        other => Err(PhotoError::UnsupportedContentType(other.to_string())),
    }
}

/// Reads the `photo` field off a multipart body, validates content-type and
/// size, and writes it under `photos_dir` with a generated name. Returns
/// the absolute public URL (`{public_base_url}/uploads/{file}`) — this is
/// the exact string that ends up in `profiles.photos` and, unchanged, in
/// what Flutter's `Image.network(url)` calls already expect.
pub async fn save_uploaded_photo(
    mut multipart: axum::extract::Multipart,
    photos_dir: &str,
    public_base_url: &str,
) -> Result<String, PhotoError> {
    while let Some(field) = multipart.next_field().await? {
        if field.name() != Some("photo") {
            continue;
        }

        let content_type = field.content_type().unwrap_or_default().to_string();
        let ext = extension_for(&content_type)?;

        let bytes = field.bytes().await?;
        if bytes.len() > MAX_PHOTO_BYTES {
            return Err(PhotoError::TooLarge);
        }

        let filename = format!("{}.{ext}", uuid::Uuid::new_v4());
        tokio::fs::write(Path::new(photos_dir).join(&filename), &bytes).await?;

        return Ok(format!("{public_base_url}/uploads/{filename}"));
    }

    Err(PhotoError::MissingField)
}

/// Best-effort delete of the file backing `url`, if it lives under
/// `photos_dir` — silently no-ops on urls it doesn't recognize (manually
/// set photo URLs, seed data), same "don't fail the request over cleanup"
/// spirit as `auth::service::logout`'s best-effort token revoke.
pub async fn delete_photo_file(url: &str, photos_dir: &str, public_base_url: &str) {
    let prefix = format!("{public_base_url}/uploads/");
    if let Some(filename) = url.strip_prefix(&prefix) {
        let _ = tokio::fs::remove_file(Path::new(photos_dir).join(filename)).await;
    }
}
