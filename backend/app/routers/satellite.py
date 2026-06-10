"""
Satellite monitoring router — field analysis via Agromonitoring.

Endpoints for registering field polygons and retrieving NDVI,
soil moisture, and combined satellite analysis data.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from pymongo.asynchronous.database import AsyncDatabase

from app.database import get_db
from app.models.satellite import (
    CreatePolygonRequest,
    FieldPolygon,
    NDVIData,
    SatelliteAnalysis,
    SoilMoisture,
)
from app.services import satellite_service

router = APIRouter(tags=["Satellite Monitoring"])


@router.post(
    "/satellite/polygon",
    response_model=FieldPolygon,
    status_code=201,
    summary="Register a field polygon",
    description=(
        "Creates a field boundary polygon in Agromonitoring and stores it "
        "in MongoDB. Required before fetching NDVI or soil data."
    ),
)
async def create_polygon(
    request: CreatePolygonRequest,
    db: AsyncDatabase = Depends(get_db),
) -> FieldPolygon:
    return await satellite_service.register_polygon(db, request)


@router.get(
    "/satellite/ndvi/{user_id}",
    response_model=NDVIData | None,
    summary="Get NDVI vegetation health",
    description="Returns the latest NDVI reading and health classification for the user's field.",
)
async def get_ndvi(
    user_id: str,
    db: AsyncDatabase = Depends(get_db),
) -> NDVIData | None:
    return await satellite_service.get_ndvi_analysis(db, user_id)


@router.get(
    "/satellite/soil/{user_id}",
    response_model=SoilMoisture | None,
    summary="Get soil moisture and temperature",
    description="Returns current soil moisture, surface and underground temperature for the user's field.",
)
async def get_soil(
    user_id: str,
    db: AsyncDatabase = Depends(get_db),
) -> SoilMoisture | None:
    return await satellite_service.get_soil_analysis(db, user_id)


@router.get(
    "/satellite/analysis/{user_id}",
    response_model=SatelliteAnalysis,
    summary="Get full satellite analysis",
    description=(
        "Combines NDVI, soil moisture, and satellite imagery into a "
        "comprehensive field analysis with Turkish-language summary."
    ),
)
async def get_analysis(
    user_id: str,
    db: AsyncDatabase = Depends(get_db),
) -> SatelliteAnalysis:
    return await satellite_service.get_full_analysis(db, user_id)
