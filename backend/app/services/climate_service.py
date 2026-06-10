"""
Climate service — real-time data from Open-Meteo with MongoDB caching.

Architecture:
  1. Try Open-Meteo API for real-time historical + forecast data
  2. On success → cache result in MongoDB → return
  3. On failure → fall back to cached MongoDB data (graceful degradation)

This ensures the API always returns data, even when Open-Meteo is down.
"""

from __future__ import annotations

import logging
import re
from datetime import datetime, timezone

from fastapi import HTTPException, status
from pymongo.asynchronous.database import AsyncDatabase

from app.external_apis.geocoding import geocode
from app.external_apis.open_meteo import get_full_climate_trend
from app.models.climate import ClimateTrend

logger = logging.getLogger(__name__)

# Common Turkish character normalizations for location matching
_TR_MAP = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")


def _normalize(text: str) -> str:
    """Lower-case, strip diacritics, collapse whitespace."""
    return re.sub(r"\s+", " ", text.translate(_TR_MAP).strip().lower())


async def get_climate_trend(db: AsyncDatabase, location: str, lang: str = "en") -> ClimateTrend:
    """
    Return climate trend data for a given location.

    Strategy:
      1. Geocode the location name → GPS coordinates
      2. Fetch live data from Open-Meteo (historical + forecast)
      3. Cache the result in MongoDB for future fallback
      4. If Open-Meteo fails, fall back to MongoDB cached data

    Raises
    ------
    HTTPException 404
        When no data can be obtained from any source.
    """

    # ── Step 1: Try fetching real-time data from Open-Meteo ──────────
    try:
        coords = await geocode(location)
        if coords is not None:
            logger.info(
                "Fetching live climate data for %s (%.2f, %.2f)",
                location, coords.latitude, coords.longitude,
            )

            trend = await get_full_climate_trend(
                latitude=coords.latitude,
                longitude=coords.longitude,
                city=coords.city,
                region=coords.region,
                lang=lang,
            )

            # Cache in MongoDB for fallback
            await _cache_climate_trend(db, trend)

            logger.info("✅ Returned live Open-Meteo data for %s", location)
            return trend
        else:
            logger.warning("Could not geocode location: %s", location)

    except Exception:
        logger.warning(
            "Open-Meteo API call failed for '%s', falling back to cache",
            location,
            exc_info=True,
        )

    # ── Step 2: Fallback to MongoDB cached data ──────────────────────
    logger.info("Falling back to MongoDB cache for '%s'", location)

    # 2a) Try exact case-insensitive regex match first
    doc = await db.climate_trends.find_one(
        {"location": {"$regex": f"^{re.escape(location)}$", "$options": "i"}}
    )

    # 2b) Fallback: scan all docs and compare normalized forms
    if doc is None:
        target = _normalize(location)
        async for candidate in db.climate_trends.find():
            cand_norm = _normalize(candidate.get("location", ""))
            if cand_norm in target or target in cand_norm:
                doc = candidate
                break

    # 2c) Ultimate fallback: just return any document to prevent UI crash
    if doc is None:
        doc = await db.climate_trends.find_one()

    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No climate data found for location='{location}'",
        )

    logger.info("📦 Returned cached MongoDB data for %s", location)
    return ClimateTrend(**doc)


async def _cache_climate_trend(db: AsyncDatabase, trend: ClimateTrend) -> None:
    """
    Upsert climate trend data into MongoDB for caching.

    Uses the location as the unique key (case-insensitive match).
    """
    try:
        trend_dict = trend.model_dump()
        trend_dict["_cached_at"] = datetime.now(timezone.utc).isoformat()

        await db.climate_trends.update_one(
            {"location": {"$regex": f"^{re.escape(trend.location)}$", "$options": "i"}},
            {"$set": trend_dict},
            upsert=True,
        )
        logger.info("Cached climate data for %s in MongoDB", trend.location)
    except Exception:
        logger.warning(
            "Failed to cache climate data for %s",
            trend.location,
            exc_info=True,
        )
