"""
Open-Meteo Elevation API client.
"""

from __future__ import annotations

import logging
import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(connect=10.0, read=10.0, write=10.0, pool=10.0)


async def get_elevation(latitude: float, longitude: float) -> float:
    """
    Get the elevation in meters for a given coordinate.
    """
    url = "https://api.open-meteo.com/v1/elevation"
    params = {
        "latitude": latitude,
        "longitude": longitude,
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    elevations = data.get("elevation", [])
    if elevations and elevations[0] is not None:
        return float(elevations[0])
    return 0.0


async def calculate_slope(latitude: float, longitude: float) -> float:
    """
    Calculate the slope percentage for a given coordinate by sampling 
    surrounding points (±0.001 degrees, approx 111 meters).
    
    Formula: max elevation difference / distance * 100
    """
    offset = 0.001
    
    points = [
        (latitude, longitude), # Center
        (latitude + offset, longitude), # North
        (latitude - offset, longitude), # South
        (latitude, longitude + offset), # East
        (latitude, longitude - offset), # West
    ]
    
    lats = ",".join([str(p[0]) for p in points])
    lons = ",".join([str(p[1]) for p in points])
    
    url = "https://api.open-meteo.com/v1/elevation"
    params = {
        "latitude": lats,
        "longitude": lons,
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    elevations = data.get("elevation", [])
    if not elevations or len(elevations) < 5 or any(e is None for e in elevations):
        return 0.0
        
    center_el = elevations[0]
    north_el = elevations[1]
    south_el = elevations[2]
    east_el = elevations[3]
    west_el = elevations[4]
    
    # Distance for 0.001 deg is approx 111 meters
    dist = 111.0
    
    # Max slope in N-S or E-W direction
    slope_ns = abs(north_el - south_el) / (2 * dist) * 100
    slope_ew = abs(east_el - west_el) / (2 * dist) * 100
    
    return float(max(slope_ns, slope_ew))
