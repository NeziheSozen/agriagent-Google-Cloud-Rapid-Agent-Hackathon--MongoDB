"""
Irrigation assessment router — auto-detects irrigation need from satellite data.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.services.irrigation_service import assess_irrigation

router = APIRouter(prefix="/irrigation", tags=["Irrigation Assessment"])


@router.get("/assess/{location}")
async def get_irrigation_assessment(
    location: str,
    crop: str = "default",
):
    """
    Assess irrigation need for a location using real-time Open-Meteo data:
    soil moisture, precipitation, and ET0 evapotranspiration.

    Returns irrigation level (None/Low/Medium/High) with detailed reasoning.
    """
    try:
        result = await assess_irrigation(location, crop)
        return result.to_dict()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Irrigation assessment failed: {str(e)}")
