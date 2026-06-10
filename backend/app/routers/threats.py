"""
Threats router — regional pest / disease / invasive alerts.

Exposes ``GET /regional-threats/{region}`` with automatic 30-day
filtering and aggregate risk scoring.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from pymongo.asynchronous.database import AsyncDatabase

from app.database import get_db
from app.models.threat import RegionalThreats
from app.services.threat_service import get_regional_threats

router = APIRouter(tags=["Threats"])


@router.get(
    "/regional-threats/{region}",
    response_model=RegionalThreats,
    summary="Get regional threat alerts",
    description="Returns active agricultural threats for the specified region, "
    "filtered to the last 30 days. Includes an overall risk level "
    "and a human-readable advisory.",
)
async def read_regional_threats(
    region: str,
    db: AsyncDatabase = Depends(get_db),
) -> RegionalThreats:
    """Return active threats and advisory for the given region."""
    return await get_regional_threats(db, region)
