"""
Satellite monitoring service — field analysis via Agromonitoring.

Orchestrates polygon management, NDVI health checks, and soil
moisture readings, translating raw API data into domain models
with English-language summaries.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from pymongo.asynchronous.database import AsyncDatabase

from app.config import get_settings
from app.external_apis import agromonitoring as agro_api
from app.models.satellite import (
    CreatePolygonRequest,
    FieldPolygon,
    NDVIData,
    SatelliteAnalysis,
    SatelliteImage,
    SoilMoisture,
)

logger = logging.getLogger(__name__)

# ── Health status thresholds ─────────────────────────────────────────────

_NDVI_HEALTHY = 0.6
_NDVI_MODERATE = 0.3

_MOISTURE_DRY = 0.15      # Below this = "Dry"
_MOISTURE_WET = 0.45      # Above this = "Waterlogged"

# Translated labels
_HEALTH_TR = {
    "Healthy": "Healthy",
    "Moderate Stress": "Moderate Stress",
    "Severe Stress": "Severe Stress",
}
_MOISTURE_TR = {
    "Adequate": "Adequate",
    "Dry": "Dry",
    "Waterlogged": "Waterlogged",
}


# ── Polygon Management ──────────────────────────────────────────────────


async def register_polygon(
    db: AsyncDatabase, request: CreatePolygonRequest,
) -> FieldPolygon:
    """
    Register a field polygon with Agromonitoring and save to MongoDB.
    """
    settings = get_settings()

    if not settings.agromonitoring_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Agromonitoring API key not configured",
        )

    # Create polygon in Agromonitoring
    try:
        result = await agro_api.create_polygon(
            name=request.name,
            coordinates=request.coordinates,
        )
    except Exception as exc:
        logger.error("Agromonitoring polygon creation failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to create polygon in Agromonitoring: {exc}",
        )

    now = datetime.now(timezone.utc).isoformat()

    polygon = FieldPolygon(
        user_id=request.user_id,
        name=request.name,
        coordinates=request.coordinates,
        agro_polygon_id=result.get("id", ""),
        area_hectares=result.get("area", 0) / 10_000,  # m² → ha
        created_at=now,
    )

    # Save to MongoDB
    poly_dict = polygon.model_dump(exclude={"id"})
    insert_result = await db.field_polygons.insert_one(poly_dict)
    logger.info(
        "Registered polygon '%s' for user %s (agro_id=%s, mongo_id=%s)",
        request.name, request.user_id,
        polygon.agro_polygon_id, insert_result.inserted_id,
    )

    return polygon


async def get_user_polygon(db: AsyncDatabase, user_id: str) -> FieldPolygon | None:
    """Get the first registered polygon for a user."""
    doc = await db.field_polygons.find_one({"user_id": user_id})
    if doc is None:
        return None
    return FieldPolygon(**doc)


# ── NDVI Analysis ────────────────────────────────────────────────────────


async def get_ndvi_analysis(
    db: AsyncDatabase, user_id: str,
) -> NDVIData | None:
    """
    Get NDVI vegetation health data for a user's field.

    Returns None if the user has no registered polygon.
    """
    polygon = await get_user_polygon(db, user_id)
    if polygon is None or not polygon.agro_polygon_id:
        return None

    try:
        ndvi_entries = await agro_api.get_ndvi(polygon.agro_polygon_id)
    except Exception as exc:
        logger.warning("NDVI fetch failed for %s: %s", user_id, exc)
        return None

    if not ndvi_entries:
        return None

    # Use the most recent entry
    latest = ndvi_entries[-1]
    data = latest.get("data", {})

    ndvi_mean = data.get("mean", 0.0)
    health = _classify_ndvi(ndvi_mean)

    return NDVIData(
        date=datetime.fromtimestamp(latest["dt"], tz=timezone.utc).isoformat(),
        ndvi_min=round(data.get("min", 0.0), 3),
        ndvi_max=round(data.get("max", 0.0), 3),
        ndvi_mean=round(ndvi_mean, 3),
        health_status=health,
        health_status_tr=_HEALTH_TR[health],
    )


# ── Soil Moisture Analysis ───────────────────────────────────────────────


async def get_soil_analysis(
    db: AsyncDatabase, user_id: str,
) -> SoilMoisture | None:
    """
    Get soil moisture and temperature for a user's field.

    Returns None if the user has no registered polygon.
    """
    polygon = await get_user_polygon(db, user_id)
    if polygon is None or not polygon.agro_polygon_id:
        return None

    try:
        soil_data = await agro_api.get_soil(polygon.agro_polygon_id)
    except Exception as exc:
        logger.warning("Soil data fetch failed for %s: %s", user_id, exc)
        return None

    moisture = soil_data.get("moisture", 0.0)
    moisture_status = _classify_moisture(moisture)

    return SoilMoisture(
        date=datetime.fromtimestamp(soil_data.get("dt", 0), tz=timezone.utc).isoformat(),
        surface_moisture=round(moisture, 3),
        surface_temp_celsius=round(soil_data.get("t0", 0.0) - 273.15, 1),  # Kelvin → Celsius
        underground_temp_celsius=round(soil_data.get("t10", 0.0) - 273.15, 1),
        moisture_status=moisture_status,
        moisture_status_tr=_MOISTURE_TR[moisture_status],
    )


# ── Full Satellite Analysis ─────────────────────────────────────────────


async def get_full_analysis(
    db: AsyncDatabase, user_id: str,
) -> SatelliteAnalysis:
    """
    Get a complete satellite analysis combining NDVI, soil, and imagery.

    Raises
    ------
    HTTPException 404
        If the user has no registered field polygon.
    """
    polygon = await get_user_polygon(db, user_id)
    if polygon is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No field polygon registered for user '{user_id}'. "
                   f"Register one via POST /satellite/polygon first.",
        )

    # Fetch all data (tolerating individual failures)
    ndvi = await get_ndvi_analysis(db, user_id)
    soil = await get_soil_analysis(db, user_id)
    latest_image = await _get_latest_image(polygon.agro_polygon_id)

    # Build summary
    summary = _build_analysis_summary(polygon.name, ndvi, soil)

    return SatelliteAnalysis(
        user_id=user_id,
        field_name=polygon.name,
        ndvi=ndvi,
        soil=soil,
        latest_image=latest_image,
        analysis_summary=summary,
        analyzed_at=datetime.now(timezone.utc).isoformat(),
    )


# ── Private Helpers ──────────────────────────────────────────────────────


def _classify_ndvi(ndvi_mean: float) -> str:
    """Classify NDVI into health categories."""
    if ndvi_mean >= _NDVI_HEALTHY:
        return "Healthy"
    elif ndvi_mean >= _NDVI_MODERATE:
        return "Moderate Stress"
    return "Severe Stress"


def _classify_moisture(moisture: float) -> str:
    """Classify soil moisture into categories."""
    if moisture < _MOISTURE_DRY:
        return "Dry"
    elif moisture > _MOISTURE_WET:
        return "Waterlogged"
    return "Adequate"


async def _get_latest_image(agro_polygon_id: str) -> SatelliteImage | None:
    """Get the most recent satellite image for a polygon."""
    if not agro_polygon_id:
        return None

    try:
        images = await agro_api.get_satellite_images(agro_polygon_id)
    except Exception as exc:
        logger.warning("Satellite image fetch failed: %s", exc)
        return None

    if not images:
        return None

    latest = images[-1]
    image_urls = latest.get("image", {})

    return SatelliteImage(
        date=datetime.fromtimestamp(latest["dt"], tz=timezone.utc).isoformat(),
        cloud_coverage_percent=latest.get("cl", 0),
        data_coverage_percent=latest.get("dc", 0),
        true_color_url=image_urls.get("truecolor", ""),
        false_color_url=image_urls.get("falsecolor", ""),
        ndvi_url=image_urls.get("ndvi", ""),
        evi_url=image_urls.get("evi", ""),
    )


def _build_analysis_summary(
    field_name: str,
    ndvi: NDVIData | None,
    soil: SoilMoisture | None,
) -> str:
    """Build an English-language summary of the satellite analysis."""
    parts: list[str] = [f"📡 Satellite analysis results for field '{field_name}':"]

    if ndvi:
        if ndvi.health_status == "Healthy":
            parts.append(
                f"🌿 Vegetation is healthy (NDVI: {ndvi.ndvi_mean:.2f}). "
                f"Greenness intensity is in good condition."
            )
        elif ndvi.health_status == "Moderate Stress":
            parts.append(
                f"⚠️ Moderate stress detected in vegetation (NDVI: {ndvi.ndvi_mean:.2f}). "
                f"Irrigation or fertilization check is recommended."
            )
        else:
            parts.append(
                f"🔴 Severe stress in vegetation! (NDVI: {ndvi.ndvi_mean:.2f}). "
                f"Urgent intervention may be needed — check for disease, drought, or pests."
            )
    else:
        parts.append("NDVI data is not currently available.")

    if soil:
        if soil.moisture_status == "Dry":
            parts.append(
                f"💧 Soil moisture is low ({soil.surface_moisture:.1%}). "
                f"Irrigation is needed. Surface temperature: {soil.surface_temp_celsius}°C."
            )
        elif soil.moisture_status == "Waterlogged":
            parts.append(
                f"🌊 Soil is waterlogged ({soil.surface_moisture:.1%}). "
                f"Drainage check should be performed. Surface temperature: {soil.surface_temp_celsius}°C."
            )
        else:
            parts.append(
                f"✅ Soil moisture is adequate ({soil.surface_moisture:.1%}). "
                f"Surface temperature: {soil.surface_temp_celsius}°C."
            )
    else:
        parts.append("Soil moisture data is not currently available.")

    return " ".join(parts)
