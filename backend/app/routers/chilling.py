"""
Router for chilling hours and frost alerts.
"""

from fastapi import APIRouter, HTTPException

from app.services.chilling_service import generate_chilling_report
from app.models.climate import ChillingReport

router = APIRouter(prefix="/chilling", tags=["Chilling Hours"])

@router.get("/{location}", response_model=ChillingReport)
async def get_chilling_report(location: str, crop: str = "walnut"):
    """
    Get chilling hours accumulation and frost risk for a location and crop.
    """
    try:
        return await generate_chilling_report(location, crop)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
