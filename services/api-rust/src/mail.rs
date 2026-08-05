//! Envío de correo. Hoy sólo manda el código de verificación de email.
//!
//! Dos transportes a propósito:
//!
//! - **Resend**, cuando hay `RESEND_API_KEY`. Es el envío de verdad.
//! - **Log**, cuando no la hay. Imprime el correo por consola en vez de
//!   mandarlo. Así el flujo entero (registrar → pedir código → verificar)
//!   se puede desarrollar y probar sin credenciales, sin cuenta y sin
//!   gastar cuota — y sin que nadie tenga que comentar código para que
//!   compile.
//!
//! `AppConfig::validate` avisa (y en producción aborta) si falta la API
//! key, para que nadie despliegue creyendo que manda correos cuando en
//! realidad los está escribiendo en un log.

use crate::config::AppConfig;

#[derive(Debug, thiserror::Error)]
pub enum MailError {
    #[error("no se pudo contactar con el proveedor de email: {0}")]
    Transport(String),
    #[error("el proveedor de email rechazó el envío ({status}): {body}")]
    Rejected { status: u16, body: String },
}

#[derive(Clone)]
pub enum Mailer {
    /// Sin credenciales: el correo va al log, no a nadie.
    Log,
    Resend {
        api_key: String,
        from: String,
        client: reqwest::Client,
    },
}

impl Mailer {
    pub fn from_config(cfg: &AppConfig) -> Self {
        match &cfg.resend_api_key {
            Some(api_key) => {
                tracing::info!("email: usando Resend, remitente {}", cfg.email_from);
                Mailer::Resend {
                    api_key: api_key.clone(),
                    from: cfg.email_from.clone(),
                    client: reqwest::Client::new(),
                }
            }
            None => {
                tracing::warn!(
                    "email: sin RESEND_API_KEY — los correos se escriben en el log, no se envían"
                );
                Mailer::Log
            }
        }
    }

    pub async fn send_verification_code(&self, to: &str, code: &str) -> Result<(), MailError> {
        let subject = "Tu código de MatchPoint";
        let html = verification_html(code);

        match self {
            Mailer::Log => {
                // A nivel `warn` y con el código bien visible: en dev esto
                // es la única forma de continuar el flujo, así que tiene
                // que verse entre el resto de trazas.
                tracing::warn!("[EMAIL NO ENVIADO] para {to} — asunto: {subject} — CÓDIGO: {code}");
                Ok(())
            }
            Mailer::Resend {
                api_key,
                from,
                client,
            } => {
                let res = client
                    .post("https://api.resend.com/emails")
                    .bearer_auth(api_key)
                    .json(&serde_json::json!({
                        "from": from,
                        "to": [to],
                        "subject": subject,
                        "html": html,
                    }))
                    .send()
                    .await
                    .map_err(|e| MailError::Transport(e.to_string()))?;

                let status = res.status();
                if status.is_success() {
                    return Ok(());
                }

                // El cuerpo del error de Resend explica el motivo real
                // (dominio sin verificar, destinatario no permitido en la
                // cuenta gratuita, key sin permisos...). Sin él, depurar
                // esto es adivinar.
                let body = res.text().await.unwrap_or_default();
                Err(MailError::Rejected {
                    status: status.as_u16(),
                    body,
                })
            }
        }
    }
}

fn verification_html(code: &str) -> String {
    // HTML a mano y muy simple: los clientes de correo tienen soporte CSS
    // impredecible, y esto sólo tiene que enseñar seis dígitos.
    format!(
        r#"<div style="font-family:system-ui,-apple-system,sans-serif;max-width:480px;margin:0 auto;padding:24px">
  <h1 style="color:#0E7A57;font-size:22px;margin:0 0 8px">Confirma tu email</h1>
  <p style="color:#444;font-size:15px;line-height:1.5;margin:0 0 20px">
    Escribe este código en MatchPoint para terminar de crear tu cuenta:
  </p>
  <div style="font-size:34px;font-weight:700;letter-spacing:8px;color:#0E7A57;background:#F0F7F4;border-radius:12px;padding:18px;text-align:center">{code}</div>
  <p style="color:#888;font-size:13px;line-height:1.5;margin:20px 0 0">
    Caduca en 15 minutos. Si no has sido tú, puedes ignorar este correo.
  </p>
</div>"#
    )
}
