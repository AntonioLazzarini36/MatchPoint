//! File storage for profile photos. Pure I/O, no DB access — mirrors how
//! `chats::crypto` isolates encryption from `chats::service`. The DB side
//! (appending/removing a URL on `profiles.photos`) lives in `me::service`.

use std::path::Path;

pub const MAX_PHOTOS: usize = 6;
const MAX_PHOTO_BYTES: usize = 5 * 1024 * 1024;

#[derive(Debug, thiserror::Error)]
pub enum PhotoError {
    #[error("No se ha recibido ninguna foto")]
    MissingField,
    #[error("El archivo no es una imagen JPEG, PNG o WebP")]
    NotAnImage,
    #[error("La foto supera el límite de 5 MB")]
    TooLarge,
    // Se responde con 400, asi que este texto llega al movil: ni en ingles
    // ni con el detalle de la libreria dentro.
    #[error("No hemos podido leer la foto. Vuelve a intentarlo")]
    Multipart(#[from] axum::extract::multipart::MultipartError),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

/// Extensión real del archivo mirando sus primeros bytes.
///
/// Antes esto se decía por el `Content-Type` que manda el cliente, sin
/// mirar el contenido nunca: cualquiera podía subir un ejecutable, un zip
/// o un HTML etiquetado como `image/png` y quedábamos sirviéndolo desde
/// nuestro dominio. La cabecera la escribe quien sube, así que no es una
/// comprobación, es una declaración de intenciones.
///
/// Ahora la cabecera se ignora por completo y manda el contenido. Sin
/// crate nueva: son tres firmas de bytes muy cortas y estables.
fn sniff_extension(bytes: &[u8]) -> Option<&'static str> {
    // JPEG: SOI (FF D8) seguido de un marcador.
    if bytes.starts_with(&[0xFF, 0xD8, 0xFF]) {
        return Some("jpg");
    }
    // PNG: firma de 8 bytes fija.
    if bytes.starts_with(&[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
        return Some("png");
    }
    // WebP: contenedor RIFF con "WEBP" en el byte 8.
    if bytes.len() >= 12 && bytes.starts_with(b"RIFF") && &bytes[8..12] == b"WEBP" {
        return Some("webp");
    }
    None
}

/// Reads the `photo` field off a multipart body, validates the **real**
/// file type and its size, and writes it under `photos_dir` with a
/// generated name. Returns
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

        let bytes = field.bytes().await?;
        // Tamaño antes que tipo: no tiene sentido inspeccionar 50MB para
        // luego rechazarlos igual.
        if bytes.len() > MAX_PHOTO_BYTES {
            return Err(PhotoError::TooLarge);
        }

        // La extensión sale de los bytes, no de lo que diga el cliente.
        let ext = sniff_extension(&bytes).ok_or(PhotoError::NotAnImage)?;

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

#[cfg(test)]
mod tests {
    use super::*;

    /// El caso que motivó el cambio: un archivo que no es una imagen pero
    /// que el cliente etiquetaría como `image/png`. Antes pasaba, porque
    /// sólo se miraba la cabecera.
    #[test]
    fn rejects_non_images() {
        assert_eq!(sniff_extension(b"<html><script>alert(1)</script>"), None);
        assert_eq!(sniff_extension(b"MZ\x90\x00"), None); // .exe
        assert_eq!(sniff_extension(b"PK\x03\x04"), None); // .zip
        assert_eq!(sniff_extension(b""), None);
    }

    #[test]
    fn recognises_supported_formats() {
        assert_eq!(sniff_extension(&[0xFF, 0xD8, 0xFF, 0xE0]), Some("jpg"));
        assert_eq!(
            sniff_extension(&[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
            Some("png")
        );
        assert_eq!(
            sniff_extension(b"RIFF\x00\x00\x00\x00WEBPVP8 "),
            Some("webp")
        );
    }

    /// Un RIFF que no es WebP (un .wav, por ejemplo) no debe colarse sólo
    /// por empezar igual.
    #[test]
    fn rejects_riff_that_is_not_webp() {
        assert_eq!(sniff_extension(b"RIFF\x00\x00\x00\x00WAVEfmt "), None);
    }

    /// Menos bytes de los que hace falta para decidir: no debe entrar en
    /// pánico por indexar fuera de rango.
    #[test]
    fn handles_truncated_input() {
        assert_eq!(sniff_extension(b"RIFF"), None);
        assert_eq!(sniff_extension(&[0xFF, 0xD8]), None);
        assert_eq!(sniff_extension(&[0x89, 0x50]), None);
    }
}
