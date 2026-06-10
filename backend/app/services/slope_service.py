"""
Service for calculating topography, slope, and erosion risks.
"""

from __future__ import annotations

import logging

from app.external_apis.elevation import get_elevation, calculate_slope
from app.external_apis.geocoding import geocode

logger = logging.getLogger(__name__)

async def analyze_slope(location: str) -> dict:
    """
    Analyze the slope and elevation of a location.
    Returns slope analysis with erosion risk and machinery recommendations.
    """
    lat, lon, region = await geocode(location)
    
    elevation_m = await get_elevation(lat, lon)
    slope_pct = await calculate_slope(lat, lon)
    
    # Determine erosion risk
    if slope_pct < 10:
        erosion_risk = "Low"
    elif slope_pct <= 20:
        erosion_risk = "Medium"
    elif slope_pct <= 35:
        erosion_risk = "High"
    else:
        erosion_risk = "Critical"
        
    machinery_suitable = slope_pct < 20
    
    recommended_equipment = []
    cover_crop_recommendation = None
    
    if slope_pct < 10:
        recommended_equipment = ["Standard Tractor", "Combine Harvester", "Seeder"]
    elif slope_pct <= 20:
        recommended_equipment = ["Slope-Adapted Tractor", "Compact Seeder"]
        cover_crop_recommendation = "Slope is above 10%. Planting cover crops such as clover or vetch is recommended during winter months to prevent erosion."
    else:
        recommended_equipment = ["Backpack Motorized Trimmer", "Drone Spraying", "Small Cultivator"]
        cover_crop_recommendation = "WARNING: Slope is above 20%. Standard mechanization carries rollover risk. Terracing should be performed and permanent deep-rooted cover crops should be used."

    return {
        "location": location,
        "elevation_m": round(elevation_m, 1),
        "slope_percent": round(slope_pct, 1),
        "erosion_risk": erosion_risk,
        "machinery_suitable": machinery_suitable,
        "recommended_equipment": recommended_equipment,
        "cover_crop_recommendation": cover_crop_recommendation,
    }
