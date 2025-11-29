#![cfg(feature = "web-server")]

use axum::{http::StatusCode, Json};
use serde_json::Value;

use super::{ApiError, ApiResult};

const RELAY_PULSE_STATUS_URL: &str = "https://relaypulse.top/api/status";

/// Proxy Relay-Pulse health status to avoid frontend CORS issues.
pub async fn proxy_status() -> ApiResult<Value> {
    let client = reqwest::Client::builder()
        .user_agent("cc-switch/health-proxy")
        .build()
        .map_err(|err| ApiError::new(StatusCode::INTERNAL_SERVER_ERROR, err.to_string()))?;

    let response = client
        .get(RELAY_PULSE_STATUS_URL)
        .header(reqwest::header::ACCEPT, "application/json")
        .send()
        .await
        .map_err(|err| {
            let status = if err.is_timeout() {
                StatusCode::GATEWAY_TIMEOUT
            } else {
                StatusCode::BAD_GATEWAY
            };
            ApiError::new(status, format!("Failed to reach Relay-Pulse API: {err}"))
        })?;

    if !response.status().is_success() {
        return Err(ApiError::new(
            StatusCode::BAD_GATEWAY,
            format!("Relay-Pulse API responded with {}", response.status()),
        ));
    }

    let body = response.json::<Value>().await.map_err(|err| {
        ApiError::new(
            StatusCode::BAD_GATEWAY,
            format!("Failed to parse Relay-Pulse response: {err}"),
        )
    })?;

    Ok(Json(body))
}
