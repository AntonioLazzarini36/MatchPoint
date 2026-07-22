//! Direct port of chats/crypto.ts.
//!
//! Wire format is identical: `v1:{iv_b64}:{tag_b64}:{ciphertext_b64}`,
//! AES-256-GCM, 12-byte IV, key from MESSAGE_KEY_BASE64 (must decode to
//! exactly 32 bytes — same check as Node's `getKey()`).
//!
//! The one real difference is API shape, not bytes: Node's
//! `cipher.update()`/`cipher.final()` gives you the ciphertext, and
//! `cipher.getAuthTag()` gives you the 16-byte tag *separately*. The
//! `aes-gcm` crate instead returns them concatenated as a single buffer
//! (ciphertext, then the 16-byte tag appended at the end) — same
//! standard AES-GCM bytes, just packaged differently. So encrypting here
//! means slicing that combined buffer apart before writing our
//! `v1:iv:tag:ct` format, and decrypting means gluing tag+ciphertext
//! back together before handing it to the crate.

use aes_gcm::aead::{Aead, AeadCore, KeyInit, OsRng};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::{engine::general_purpose::STANDARD, Engine as _};

const VERSION: &str = "v1";
const TAG_LEN: usize = 16;

#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("MESSAGE_KEY_BASE64 must decode to 32 bytes")]
    BadKeyLength,
    #[error("invalid ciphertext format")]
    InvalidFormat,
    #[error("base64 decode error: {0}")]
    Base64(#[from] base64::DecodeError),
    #[error("encryption failed")]
    Encrypt,
    #[error("decryption failed (wrong key or corrupted data)")]
    Decrypt,
}

fn cipher(key_base64: &str) -> Result<Aes256Gcm, CryptoError> {
    let key_bytes = STANDARD.decode(key_base64)?;
    if key_bytes.len() != 32 {
        return Err(CryptoError::BadKeyLength);
    }
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    Ok(Aes256Gcm::new(key))
}

pub fn encrypt_text(plain: &str, key_base64: &str) -> Result<String, CryptoError> {
    let cipher = cipher(key_base64)?;
    let nonce = Aes256Gcm::generate_nonce(&mut OsRng); // 12 random bytes, same as Node's crypto.randomBytes(12)

    let combined = cipher
        .encrypt(&nonce, plain.as_bytes())
        .map_err(|_| CryptoError::Encrypt)?;

    // aes-gcm appends the 16-byte tag at the end of the ciphertext;
    // split it back apart to match crypto.ts's separate iv/tag/ciphertext fields.
    let (ciphertext, tag) = combined.split_at(combined.len() - TAG_LEN);

    Ok(format!(
        "{VERSION}:{}:{}:{}",
        STANDARD.encode(nonce),
        STANDARD.encode(tag),
        STANDARD.encode(ciphertext),
    ))
}

pub fn decrypt_text(payload: &str, key_base64: &str) -> Result<String, CryptoError> {
    let parts: Vec<&str> = payload.split(':').collect();
    if parts.len() != 4 || parts[0] != VERSION {
        return Err(CryptoError::InvalidFormat);
    }

    let cipher = cipher(key_base64)?;
    let iv = STANDARD.decode(parts[1])?;
    let tag = STANDARD.decode(parts[2])?;
    let ciphertext = STANDARD.decode(parts[3])?;

    let nonce = Nonce::from_slice(&iv);

    // Glue ciphertext + tag back into the single buffer aes-gcm expects.
    let mut combined = ciphertext;
    combined.extend_from_slice(&tag);

    let plain = cipher
        .decrypt(nonce, combined.as_slice())
        .map_err(|_| CryptoError::Decrypt)?;

    String::from_utf8(plain).map_err(|_| CryptoError::Decrypt)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips() {
        // Same key format as .env's MESSAGE_KEY_BASE64 (any valid 32-byte b64 key).
        let key = "1mKQdNgaRWyt/45tyC5TKw9ogvCE45Kq5p+wciokGtg=";
        let encrypted = encrypt_text("hola desde rust", key).unwrap();
        assert!(encrypted.starts_with("v1:"));
        let decrypted = decrypt_text(&encrypted, key).unwrap();
        assert_eq!(decrypted, "hola desde rust");
    }
}
