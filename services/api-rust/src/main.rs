//! Thin entrypoint. All real logic lives in `lib.rs` so it's compiled as
//! part of the library target (see comment there re: clippy dead_code).

#[tokio::main]
async fn main() {
    matchpoint_api::run().await;
}