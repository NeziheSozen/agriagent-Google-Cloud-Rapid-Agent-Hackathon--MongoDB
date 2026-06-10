"""
Climate router — historical trends and seasonal forecasts.

Exposes ``GET /climate-trend/{location}`` for per-location
climate intelligence.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from pymongo.asynchronous.database import AsyncDatabase

from app.database import get_db
from app.models.climate import ClimateTrend
from app.services.climate_service import get_climate_trend

router = APIRouter(tags=["Climate"])


@router.get(
    "/climate-trend/{location}",
    response_model=ClimateTrend,
    summary="Get climate trend for a location",
    description="Returns 5-year historical climate data and a seasonal "
    "forecast for the specified location. Handles Turkish character "
    "aliases (e.g. Tekirdağ / Tekirdag).",
)
async def read_climate_trend(
    location: str,
    lang: str = "en",
    db: AsyncDatabase = Depends(get_db),
) -> ClimateTrend:
    """Return climate trend data for the given location."""
    return await get_climate_trend(db, location, lang=lang)


@router.delete(
    "/climate-cache",
    summary="Clear climate cache",
    description="Deletes all cached climate data from MongoDB, forcing fresh Open-Meteo fetches.",
)
async def clear_climate_cache(
    db: AsyncDatabase = Depends(get_db),
) -> dict:
    """Admin endpoint to invalidate stale climate cache."""
    result = await db.climate_trends.delete_many({})
    return {"deleted": result.deleted_count, "message": "Climate cache cleared"}

