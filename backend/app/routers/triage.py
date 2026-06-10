"""
Router for daily triage recommendations.
"""

from fastapi import APIRouter, HTTPException, Depends
from typing import Any

from app.agents.triage_agent import generate_triage_recommendation
from app.services.farmer_service import get_farmer_profile
from app.services.climate_service import get_climate_trend
from app.services.threat_service import get_regional_threats
from app.external_apis.open_meteo import get_forecast

router = APIRouter(prefix="/triage", tags=["Daily Triage"])

@router.get("/{user_id}")
async def get_triage_recommendation(user_id: str):
    """
    Get the single most important action for the day based on weather, profile, and threats.
    """
    try:
        profile = await get_farmer_profile(user_id)
        if not profile:
            raise HTTPException(status_code=404, detail="Farmer not found")
            
        location = profile.get("location", "Tekirdağ")
        region = profile.get("region", "Marmara")
        
        # We need coordinates for forecast. Usually geocode handles this, or it's in the profile.
        # Simple lookup fallback if needed, but get_forecast needs lat/lon.
        # Let's use geocode.
        from app.external_apis.geocoding import geocode
        lat, lon, _ = await geocode(location)
        
        # Get 16-day forecast to extract today/tomorrow
        forecast = await get_forecast(lat, lon)
        
        # Get threats
        threats = await get_regional_threats(region)
        
        # Run triage agent
        recommendation = await generate_triage_recommendation(
            location=location,
            forecast=forecast.dict() if hasattr(forecast, "dict") else str(forecast),
            farmer_profile=profile,
            recent_threats=threats
        )
        
        return recommendation
    except Exception as e:
        logger = logging.getLogger(__name__)
        logger.exception("Error in triage recommendation")
        raise HTTPException(status_code=500, detail=str(e))

import logging
