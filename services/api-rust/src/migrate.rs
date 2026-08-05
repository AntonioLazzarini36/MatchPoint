//! Migraciones al arrancar.
//!
//! En local se corren a mano con `diesel migration run`, pero en un
//! despliegue no hay terminal donde hacerlo: el contenedor arranca y ya.
//! Olvidarlas deja el servicio en pie contra un esquema viejo, que falla
//! de formas raras (columna que no existe) en vez de fallar claro.
//!
//! Los `.sql` se compilan **dentro del binario** (`embed_migrations!`), así
//! que la imagen no necesita llevar la carpeta `migrations/` ni el CLI de
//! Diesel.
//!
//! Ojo con varias instancias a la vez: dos arrancando en paralelo
//! intentarían migrar las dos. Diesel toma un lock en la tabla de
//! migraciones, así que la segunda espera y ve el trabajo hecho, pero si
//! algún día esto escala a varias réplicas conviene mover las migraciones
//! a un paso propio del despliegue.

use diesel::Connection;
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};

pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("migrations");

/// Aplica lo que falte. Aborta el arranque si falla: un servicio corriendo
/// contra un esquema a medias hace más daño que uno que no arranca.
pub fn run(database_url: &str) {
    let mut conn = diesel::PgConnection::establish(database_url)
        .unwrap_or_else(|e| panic!("migraciones: no se pudo conectar a la base de datos: {e}"));

    let applied = conn
        .run_pending_migrations(MIGRATIONS)
        .unwrap_or_else(|e| panic!("migraciones: fallo al aplicarlas: {e}"));

    if applied.is_empty() {
        tracing::info!("migraciones: la base de datos ya estaba al día");
    } else {
        for name in &applied {
            tracing::info!("migraciones: aplicada {name}");
        }
    }
}
