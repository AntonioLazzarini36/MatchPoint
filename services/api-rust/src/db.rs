//! Equivalent of `prisma/prisma.module.ts` + `prisma/prisma.service.ts`.
//! Prisma gave you a single lazily-connected client; here we build a
//! connection pool once at startup and hand out connections from it.
//! Every `*.service.ts` that did `private prisma: PrismaService` becomes
//! a service function that takes `&DbPool` (or pulls it off `AppState`).

use diesel_async::pooled_connection::bb8::Pool;
use diesel_async::pooled_connection::AsyncDieselConnectionManager;
use diesel_async::AsyncPgConnection;

pub type DbPool = Pool<AsyncPgConnection>;

/// Builds the connection pool. Panics on startup if the DB is unreachable,
/// same fail-fast behavior you'd get from Nest/Prisma refusing to boot.
pub async fn build_pool(database_url: &str) -> DbPool {
    let manager = AsyncDieselConnectionManager::<AsyncPgConnection>::new(database_url);

    Pool::builder()
        .max_size(10)
        .build(manager)
        .await
        .expect("failed to build the Postgres connection pool")
}
