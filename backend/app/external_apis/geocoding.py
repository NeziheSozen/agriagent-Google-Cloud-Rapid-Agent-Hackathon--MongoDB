"""
Geocoding utilities for Turkish agricultural locations.

Provides coordinate lookups for Turkish cities/provinces used in the
AgriAgent platform. Falls back to the Open-Meteo Geocoding API for
locations not in the static map.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

logger = logging.getLogger(__name__)

# ── Data structure ───────────────────────────────────────────────────────

@dataclass(frozen=True)
class Coordinates:
    """GPS coordinates with metadata."""
    latitude: float
    longitude: float
    city: str
    region: str


# ── Static lookup table — major Turkish agricultural provinces ───────────

_TURKEY_LOCATIONS: dict[str, Coordinates] = {
    "tekirdağ": Coordinates(41.17, 27.51, "Tekirdağ", "Thrace"),
    "tekirdag": Coordinates(41.17, 27.51, "Tekirdağ", "Thrace"),
    "edirne": Coordinates(41.67, 26.55, "Edirne", "Thrace"),
    "kırklareli": Coordinates(41.74, 27.23, "Kırklareli", "Thrace"),
    "konya": Coordinates(37.87, 32.48, "Konya", "Central Anatolia"),
    "ankara": Coordinates(39.93, 32.86, "Ankara", "Central Anatolia"),
    "eskişehir": Coordinates(39.78, 30.52, "Eskişehir", "Central Anatolia"),
    "antalya": Coordinates(36.89, 30.71, "Antalya", "Mediterranean"),
    "mersin": Coordinates(36.80, 34.64, "Mersin", "Mediterranean"),
    "adana": Coordinates(37.00, 35.32, "Adana", "Çukurova"),
    "hatay": Coordinates(36.20, 36.16, "Hatay", "Çukurova"),
    "gaziantep": Coordinates(37.06, 37.38, "Gaziantep", "Southeastern Anatolia"),
    "şanlıurfa": Coordinates(37.16, 38.79, "Şanlıurfa", "Southeastern Anatolia"),
    "diyarbakır": Coordinates(37.91, 40.24, "Diyarbakır", "Southeastern Anatolia"),
    "samsun": Coordinates(41.29, 36.33, "Samsun", "Black Sea"),
    "trabzon": Coordinates(41.00, 39.72, "Trabzon", "Black Sea"),
    "bursa": Coordinates(40.19, 29.06, "Bursa", "Marmara"),
    "balıkesir": Coordinates(39.65, 27.88, "Balıkesir", "Marmara"),
    "izmir": Coordinates(38.42, 27.14, "İzmir", "Aegean"),
    "aydın": Coordinates(37.85, 27.85, "Aydın", "Aegean"),
    "denizli": Coordinates(37.77, 29.09, "Denizli", "Aegean"),
    "afyon": Coordinates(38.75, 30.54, "Afyon", "Central Anatolia"),
    "kayseri": Coordinates(38.73, 35.48, "Kayseri", "Central Anatolia"),
    "sivas": Coordinates(39.75, 37.02, "Sivas", "Central Anatolia"),
    "tokat": Coordinates(40.31, 36.55, "Tokat", "Black Sea"),
    "çorum": Coordinates(40.55, 34.95, "Çorum", "Central Anatolia"),
    "amasya": Coordinates(40.65, 35.83, "Amasya", "Black Sea"),
    "manisa": Coordinates(38.61, 27.43, "Manisa", "Aegean"),
    "uşak": Coordinates(38.67, 29.41, "Uşak", "Aegean"),
}

# Turkish diacritic normalization
_TR_MAP = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")


def _normalize_key(name: str) -> str:
    """Normalize a location name for lookup."""
    return name.strip().lower()


async def geocode(location: str) -> Coordinates | None:
    """
    Resolve a Turkish location name to GPS coordinates.

    Checks the static lookup table first (fast). If not found, queries
    the Open-Meteo Geocoding API as a fallback.

    Parameters
    ----------
    location : str
        City or province name (Turkish or ASCII).

    Returns
    -------
    Coordinates or None
        Resolved coordinates, or ``None`` if the location cannot be found.
    """
    # 1) Try static lookup (exact key)
    key = _normalize_key(location)
    if key in _TURKEY_LOCATIONS:
        return _TURKEY_LOCATIONS[key]

    # 2) Try ASCII-normalized key
    ascii_key = key.translate(_TR_MAP)
    if ascii_key in _TURKEY_LOCATIONS:
        return _TURKEY_LOCATIONS[ascii_key]

    # 3) Try matching against normalized versions of all keys
    for stored_key, coords in _TURKEY_LOCATIONS.items():
        if stored_key.translate(_TR_MAP) == ascii_key:
            return coords

    # 4) Fallback: Open-Meteo Geocoding API
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                "https://geocoding-api.open-meteo.com/v1/search",
                params={
                    "name": location,
                    "count": 1,
                    "language": "tr",
                    "format": "json",
                },
            )
            resp.raise_for_status()
            data = resp.json()

            results = data.get("results", [])
            if results:
                r = results[0]
                logger.info(
                    "Geocoded '%s' via Open-Meteo: (%.2f, %.2f)",
                    location, r["latitude"], r["longitude"],
                )
                return Coordinates(
                    latitude=r["latitude"],
                    longitude=r["longitude"],
                    city=r.get("name", location),
                    region=r.get("admin1", "Unknown"),
                )
    except Exception:
        logger.warning("Open-Meteo geocoding failed for '%s'", location, exc_info=True)

    return None
