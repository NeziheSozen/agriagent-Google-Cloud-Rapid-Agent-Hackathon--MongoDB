"""
Agromonitoring (AgroAPI) client — satellite imagery, NDVI, and soil data.

Provides real-time field monitoring via Sentinel-2 satellite data:
  - NDVI (Normalized Difference Vegetation Index) — crop health
  - Soil moisture and surface temperature
  - Satellite imagery URLs (true color, false color, NDVI)

Requires an API key from https://agromonitoring.com/dashboard
Free tier: 60 requests/minute, polygon area ≤ 25 ha.

API Docs: https://agromonitoring.com/api
"""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(connect=10.0, read=30.0, write=10.0, pool=10.0)


# ── Polygon Management ──────────────────────────────────────────────────


async def create_polygon(
    name: str,
    coordinates: list[list[float]],
) -> dict:
    """
    Create a polygon (field boundary) in Agromonitoring.

    Parameters
    ----------
    name : str
        Human-readable field name (e.g. "Ana Tarla").
    coordinates : list[list[float]]
        GeoJSON polygon coordinates [[lon, lat], ...].
        Must be a closed ring (first == last point).

    Returns
    -------
    dict
        Agromonitoring polygon object with ``id`` field.
    """
    settings = get_settings()
    url = f"{settings.agromonitoring_base_url}/polygons"

    # Ensure the ring is closed
    if coordinates[0] != coordinates[-1]:
        coordinates = coordinates + [coordinates[0]]

    body = {
        "name": name,
        "geo_json": {
            "type": "Feature",
            "properties": {},
            "geometry": {
                "type": "Polygon",
                "coordinates": [coordinates],
            },
        },
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.post(
            url,
            json=body,
            params={"appid": settings.agromonitoring_api_key},
        )
        resp.raise_for_status()
        result = resp.json()

    logger.info("Created Agromonitoring polygon: %s (id=%s)", name, result.get("id"))
    return result


async def list_polygons() -> list[dict]:
    """List all registered polygons."""
    settings = get_settings()
    url = f"{settings.agromonitoring_base_url}/polygons"

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params={"appid": settings.agromonitoring_api_key})
        resp.raise_for_status()
        return resp.json()


async def delete_polygon(polygon_id: str) -> None:
    """Delete a polygon by its Agromonitoring ID."""
    settings = get_settings()
    url = f"{settings.agromonitoring_base_url}/polygons/{polygon_id}"

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.delete(url, params={"appid": settings.agromonitoring_api_key})
        resp.raise_for_status()

    logger.info("Deleted Agromonitoring polygon: %s", polygon_id)


# ── NDVI Data ────────────────────────────────────────────────────────────


async def get_ndvi(polygon_id: str) -> list[dict]:
    """
    Get NDVI (vegetation index) statistics for a polygon.

    Returns the latest available NDVI data from Sentinel-2 imagery.
    NDVI ranges from -1 to 1:
      - > 0.6  = Healthy vegetation
      - 0.3–0.6 = Moderate stress
      - < 0.3  = Severe stress / bare soil

    Returns
    -------
    list[dict]
        Each entry has ``dt`` (unix timestamp), ``data`` with
        ``min``, ``max``, ``mean``, ``median``, ``p75``, ``p25``.
    """
    settings = get_settings()
    url = f"{settings.agromonitoring_base_url}/ndvi"

    # Request last 14 days of data
    end_ts = int(time.time())
    start_ts = end_ts - (14 * 86400)

    params = {
        "polyid": polygon_id,
        "start": start_ts,
        "end": end_ts,
        "appid": settings.agromonitoring_api_key,
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    logger.info("Got %d NDVI entries for polygon %s", len(data), polygon_id)
    return data


# ── Soil Data ────────────────────────────────────────────────────────────


async def get_soil(polygon_id: str) -> dict:
    """
    Get current soil conditions for a polygon.

    Returns surface moisture (m³/m³), temperature at 10cm depth,
    and surface temperature.

    Returns
    -------
    dict
        Keys: ``dt``, ``moisture``, ``t0`` (surface temp), ``t10`` (10cm temp).
    """
    settings = get_settings()
    url = f"{settings.agromonitoring_base_url}/soil"

    params = {
        "polyid": polygon_id,
        "appid": settings.agromonitoring_api_key,
        "units": "metric",  # Celsius, not Kelvin
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    logger.info("Got soil data for polygon %s", polygon_id)
    return data


# ── Satellite Imagery ────────────────────────────────────────────────────


async def get_satellite_images(polygon_id: str) -> list[dict]:
    """
    Search for available satellite imagery for a polygon.

    Returns metadata including image URLs for different band
    combinations (true color, false color, NDVI, EVI).

    Returns
    -------
    list[dict]
        Each entry has ``dt``, ``type``, ``dc`` (data coverage %),
        ``cl`` (cloud coverage %), and ``image`` dict with URLs.
    """
    settings = get_settings()
    url = f"{settings.agromonitoring_base_url}/image/search"

    end_ts = int(time.time())
    start_ts = end_ts - (30 * 86400)  # Last 30 days

    params = {
        "polyid": polygon_id,
        "start": start_ts,
        "end": end_ts,
        "appid": settings.agromonitoring_api_key,
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    # Filter to low cloud coverage images
    clear_images = [img for img in data if img.get("cl", 100) < 30]

    logger.info(
        "Found %d satellite images (%d clear) for polygon %s",
        len(data), len(clear_images), polygon_id,
    )
    return clear_images if clear_images else data[:3]


# ── Weather for Polygon ─────────────────────────────────────────────────


async def get_weather(polygon_id: str) -> dict:
    """
    Get current weather conditions for a polygon's location.

    Returns
    -------
    dict
        Standard weather data: temp, humidity, wind, description, etc.
    """
    settings = get_settings()
    url = f"{settings.agromonitoring_base_url}/weather"

    params = {
        "polyid": polygon_id,
        "appid": settings.agromonitoring_api_key,
        "units": "metric",  # Celsius + m/s, not Kelvin
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        return resp.json()
