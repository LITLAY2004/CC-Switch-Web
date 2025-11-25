#![cfg(feature = "web-server")]

use std::{env, sync::Arc};

use axum::{
    body::Body,
    extract::Path,
    http::{
        header::{self, ACCEPT, AUTHORIZATION, CONTENT_TYPE},
        HeaderValue, Method, StatusCode,
    },
    response::{IntoResponse, Response},
    Router,
};
use mime_guess::mime;
use rust_embed::RustEmbed;
use tower_http::{
    cors::{Any, CorsLayer},
    validate_request::ValidateRequestHeaderLayer,
};

use crate::store::AppState;

pub mod handlers;
pub mod routes;

/// Shared application state for the web server.
pub type SharedState = Arc<AppState>;

#[derive(RustEmbed)]
#[folder = "../dist-web"]
struct WebAssets;

/// Serve embedded static assets with index.html fallback for SPA routes.
pub async fn serve_static(path: Option<Path<String>>) -> impl IntoResponse {
    let requested_path = path.map(|Path(p)| p).unwrap_or_default();
    let requested_path = requested_path.trim_start_matches('/');
    let target_path = if requested_path.is_empty() {
        "index.html"
    } else {
        requested_path
    };

    // Try the requested file first; fall back to index.html so SPA routes resolve client-side.
    let (asset, served_path) = match WebAssets::get(target_path) {
        Some(content) => (content, target_path),
        None => match WebAssets::get("index.html") {
            Some(content) => (content, "index.html"),
            None => return StatusCode::NOT_FOUND.into_response(),
        },
    };

    let mime = mime_guess::from_path(served_path).first_or(mime::APPLICATION_OCTET_STREAM);
    let body = Body::from(asset.data.into_owned());

    let mut response = Response::new(body);
    response.headers_mut().insert(
        header::CONTENT_TYPE,
        HeaderValue::from_str(mime.as_ref())
            .unwrap_or_else(|_| HeaderValue::from_static("application/octet-stream")),
    );

    response
}

fn cors_layer() -> CorsLayer {
    // Production-safe CORS defaults. Enable explicitly via env when cross-origin access is needed.
    let allow_origins = env::var("CORS_ALLOW_ORIGINS").ok();
    let allow_credentials = env::var("CORS_ALLOW_CREDENTIALS")
        .map(|v| matches!(v.as_str(), "1" | "true" | "TRUE" | "yes" | "on"))
        .unwrap_or(false);

    let mut layer = CorsLayer::new()
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
        .allow_headers([ACCEPT, AUTHORIZATION, CONTENT_TYPE]);

    match allow_origins.as_deref() {
        Some("*") => {
            layer = layer.allow_origin(Any);
        }
        Some(list) => {
            let origins: Vec<HeaderValue> = list
                .split(',')
                .filter_map(|entry| {
                    let trimmed = entry.trim();
                    if trimmed.is_empty() {
                        None
                    } else {
                        HeaderValue::from_str(trimmed).ok()
                    }
                })
                .collect();

            if origins.is_empty() {
                return layer;
            }
            layer = layer.allow_origin(origins);
        }
        None => {
            // No CORS allow-list provided -> rely on same-origin; do not loosen automatically.
            return layer;
        }
    }

    if allow_credentials {
        layer = layer.allow_credentials(true);
    }

    layer
}

/// Construct the axum router with all API routes and middleware.
pub fn create_router(state: SharedState, password: String) -> Router {
    let router = routes::create_router(state)
        .layer(ValidateRequestHeaderLayer::basic("admin", &password));

    // Only apply CORS when explicitly configured via env; default to same-origin.
    let router = if env::var("CORS_ALLOW_ORIGINS").is_ok() {
        router.layer(cors_layer())
    } else {
        router
    };

    router
}
