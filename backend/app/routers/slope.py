"""
Router for topography and slope analysis.
"""

from fastapi import APIRouter, HTTPException

from app.services.slope_service import analyze_slope

router = APIRouter(prefix="/slope", tags=["Topography & Slope"])

@router.get("/{location}")
async def get_slope_analysis(location: str):
    """
    Get slope and elevation analysis for a location.
    """
    try:
        return await analyze_slope(location)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
