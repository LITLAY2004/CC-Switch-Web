#![cfg(feature = "web-server")]

use std::sync::Arc;

use axum::{extract::State, Json};

use crate::{settings, settings::AppSettings, store::AppState};

use super::{ApiError, ApiResult};

pub async fn get_settings(State(_state): State<Arc<AppState>>) -> ApiResult<AppSettings> {
    Ok(Json(settings::get_settings()))
}

pub async fn save_settings(
    State(_state): State<Arc<AppState>>,
    Json(settings): Json<AppSettings>,
) -> ApiResult<bool> {
    settings::update_settings(settings).map_err(ApiError::from)?;
    Ok(Json(true))
}
