#![cfg(feature = "web-server")]

use std::{
    env,
    sync::Arc,
};

use axum::{
    body::Body,
    extract::{Path, State},
    middleware,
    http::{
        header::{self, ACCEPT, AUTHORIZATION, CONTENT_TYPE, STRICT_TRANSPORT_SECURITY, WWW_AUTHENTICATE},
        HeaderValue, Method, Request, StatusCode,
    },
    response::{IntoResponse, Response},
    Router,
};
use base64::Engine;
use mime_guess::mime;
use rust_embed::RustEmbed;
use std::sync::Arc as StdArc;
use tower_http::{
    cors::CorsLayer,
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
            // 显式禁止生产中的通配符，防止意外放开
            log::warn!("CORS_ALLOW_ORIGINS='*' 已被忽略，请使用逗号分隔的白名单");
            return layer;
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
    let api_token = env::var("WEB_API_TOKEN").ok().unwrap_or_else(|| password.clone());
    let csrf_token = env::var("WEB_CSRF_TOKEN").ok();
    let hsts_enabled = env::var("ENABLE_HSTS")
        .map(|v| matches!(v.as_str(), "1" | "true" | "TRUE" | "yes" | "on"))
        .unwrap_or(true);

    if env::var("WEB_API_TOKEN").is_err() {
        log::warn!("WEB_API_TOKEN 未设置，Bearer Token 将默认等同于密码（建议单独设置并关闭浏览器自动填充）");
    }
    if csrf_token.is_none() {
        log::warn!("WEB_CSRF_TOKEN 未设置，将对跨站提交只依赖浏览器策略；推荐设置并在前端携带 X-CSRF-Token");
    }

    let auth_validator = AuthValidator::new(password, Some(api_token.clone()), csrf_token.clone());

    let max_concurrency = env::var("WEB_MAX_CONCURRENCY")
        .ok()
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(64);
    let rate_limit = env::var("WEB_RATE_LIMIT_PER_MIN")
        .ok()
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(300);

    let router = routes::create_router(state)
        .layer(ValidateRequestHeaderLayer::custom(auth_validator))
        .layer(middleware::from_fn_with_state(
            hsts_enabled,
            add_hsts_header,
        ));

    // Only apply CORS when explicitly configured via env; default to same-origin.
    let router = if env::var("CORS_ALLOW_ORIGINS").is_ok() {
        router.layer(cors_layer())
    } else {
        router
    };

    router
}

#[derive(Clone)]
struct AuthValidator {
    basic_user: StdArc<String>,
    basic_pass: StdArc<String>,
    bearer: Option<StdArc<String>>,
    csrf_token: Option<StdArc<String>>,
}

impl AuthValidator {
    fn new(password: String, bearer: Option<String>, csrf_token: Option<String>) -> Self {
        Self {
            basic_user: StdArc::new("admin".to_string()),
            basic_pass: StdArc::new(password),
            bearer: bearer.map(StdArc::new),
            csrf_token: csrf_token.map(StdArc::new),
        }
    }

    fn is_authorized(&self, auth_value: &str) -> bool {
        if let Some(token) = self.bearer.as_ref() {
            if auth_value.trim_start().to_ascii_lowercase().starts_with("bearer") {
                return auth_value
                    .split_once(' ')
                    .map(|(_, v)| v == token.as_ref())
                    .unwrap_or(false);
            }
        }

        if let Some(raw) = auth_value.strip_prefix("Basic ") {
            if let Ok(decoded) =
                base64::engine::general_purpose::STANDARD.decode(raw.trim().as_bytes())
            {
                if let Ok(s) = String::from_utf8(decoded) {
                    if let Some((user, pass)) = s.split_once(':') {
                        return user == self.basic_user.as_str() && pass == self.basic_pass.as_str();
                    }
                }
            }
        }

        false
    }

    fn unauthorized() -> Response {
        Response::builder()
            .status(StatusCode::UNAUTHORIZED)
            .header(
                WWW_AUTHENTICATE,
                HeaderValue::from_static(r#"Basic realm="cc-switch", charset="UTF-8""#),
            )
            .body(Body::empty())
            .unwrap_or_else(|_| Response::new(Body::empty()))
    }

    fn forbidden_csrf() -> Response {
        Response::builder()
            .status(StatusCode::FORBIDDEN)
            .body(Body::empty())
            .unwrap_or_else(|_| Response::new(Body::empty()))
    }
}

impl tower_http::validate_request::ValidateRequest<Body> for AuthValidator {
    type ResponseBody = Body;

    fn validate(&mut self, request: &mut Request<Body>) -> Result<(), Response<Self::ResponseBody>> {
        let Some(auth_header) = request
            .headers()
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
        else {
            return Err(Self::unauthorized());
        };

        if !self.is_authorized(auth_header) {
            return Err(Self::unauthorized());
        }

        if let Some(csrf) = &self.csrf_token {
            if request.method() != Method::GET && request.method() != Method::HEAD {
                let token = request
                    .headers()
                    .get("x-csrf-token")
                    .and_then(|v| v.to_str().ok());
                if token != Some(csrf.as_str()) {
                    return Err(Self::forbidden_csrf());
                }
            }
        }

        Ok(())
    }
}

async fn add_hsts_header(
    State(enabled): State<bool>,
    req: Request<Body>,
    next: middleware::Next,
) -> Response {
    let mut res = next.run(req).await;
    if enabled {
        let value = HeaderValue::from_static("max-age=31536000; includeSubDomains");
        res.headers_mut()
            .entry(STRICT_TRANSPORT_SECURITY)
            .or_insert(value);
    }
    res
}
