#![cfg(feature = "web-server")]

use axum::{http::StatusCode, Json};
use serde::Deserialize;

use super::{ApiError, ApiResult};

/// Stub handler for tray updates in web mode.
pub async fn update_tray() -> ApiResult<bool> {
    Ok(Json(true))
}

#[derive(Deserialize)]
pub struct OpenExternalPayload {
    pub url: String,
}

/// Validate and acknowledge external URL open request in web mode.
/// 实际浏览器打开操作应由前端完成，这里仅作校验避免 404。
pub async fn open_external(Json(payload): Json<OpenExternalPayload>) -> ApiResult<bool> {
    let parsed = url::Url::parse(&payload.url)
        .map_err(|e| ApiError::new(StatusCode::BAD_REQUEST, e.to_string()))?;
    let scheme = parsed.scheme().to_ascii_lowercase();
    if scheme != "http" && scheme != "https" {
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "Unsupported URL scheme",
        ));
    }
    Ok(Json(true))
}
