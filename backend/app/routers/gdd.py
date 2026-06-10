"""
Router for Growing Degree Days (GDD) and harvest estimation.
"""

from fastapi import APIRouter, HTTPException

from app.services.gdd_service import generate_gdd_report
from app.models.climate import GDDReport

router = APIRouter(prefix="/gdd", tags=["Growing Degree Days"])

@router.get("/{location}", response_model=GDDReport)
async def get_gdd_report(location: str, crop: str = "wheat", planting_date: str = "2026-03-15"):
    """
    Get GDD accumulation and harvest estimation for a location and crop.
    """
    try:
        return await generate_gdd_report(location, crop, planting_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
