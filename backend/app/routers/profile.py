"""
Profile router — farmer profile retrieval.

Exposes ``GET /profile/{user_id}`` which returns the full
``FarmerProfile`` including soil analysis and crop history.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from pymongo.asynchronous.database import AsyncDatabase

from app.database import get_db
from app.models.farmer import FarmerProfile
from app.services.farmer_service import get_farmer_profile

router = APIRouter(tags=["Profile"])


@router.get(
    "/profile/{user_id}",
    response_model=FarmerProfile,
    summary="Get farmer profile",
    description="Retrieve a complete farmer profile by user ID, including "
    "embedded soil analysis and 5-year crop rotation history.",
)
async def read_profile(
    user_id: str,
    db: AsyncDatabase = Depends(get_db),
) -> FarmerProfile:
    """Return the farmer profile for the given ``user_id``."""
    return await get_farmer_profile(db, user_id)

from pydantic import BaseModel

class LoginRequest(BaseModel):
    email: str

@router.post(
    "/profile/login",
    response_model=FarmerProfile,
    summary="Demo Login",
    description="Creates or returns a farmer profile for the given email.",
)
async def demo_login(
    req: LoginRequest,
    db: AsyncDatabase = Depends(get_db),
) -> FarmerProfile:
    from fastapi import HTTPException
    
    # Search by email field first
    existing = await db.farmers.find_one({"email": req.email.strip().lower()})
    if existing:
        return FarmerProfile(**existing)
    
    # Fallback: search by name derived from email (legacy profiles)
    raw_name = req.email.split('@')[0]
    name = raw_name.replace('.', ' ').replace('_', ' ').title()
    existing = await db.farmers.find_one({"name": name})
    if existing:
        return FarmerProfile(**existing)
    
    # If not found, they must go through onboarding
    raise HTTPException(status_code=404, detail="Profile not found. Please complete onboarding.")

class OnboardingRequest(BaseModel):
    name: str
    email: str = ""
    location: str
    region: str
    size_hectares: float
    irrigation_level: str
    crops: list[str] = []
    tenure_type: str = "Owned"
    age: int = 45

@router.post(
    "/profile/onboarding",
    response_model=FarmerProfile,
    summary="Create Onboarding Profile",
    description="Creates a new farmer profile with simulated history based on onboarding input.",
)
async def create_onboarding_profile(
    req: OnboardingRequest,
    db: AsyncDatabase = Depends(get_db),
) -> FarmerProfile:
    import uuid
    import random
    from datetime import datetime, timezone
    
    # Check if a profile with this email already exists
    email = req.email.strip().lower() if req.email else ""
    if email:
        existing = await db.farmers.find_one({"email": email})
        if existing:
            return FarmerProfile(**existing)
    
    # Fallback: check by name
    existing = await db.farmers.find_one({"name": req.name})
    if existing:
        return FarmerProfile(**existing)

    user_id = f"farmer_{uuid.uuid4().hex[:8]}"
    
    from app.models.farmer import FarmPlot

    plot = FarmPlot(
        name="Ana Tarla" if req.size_hectares >= 1.0 else "Sera",
        size_hectares=req.size_hectares,
        irrigation_level=req.irrigation_level,
        tenure_type=req.tenure_type,
        soil_analysis=None,
        crop_history=[]
    )

    profile = FarmerProfile(
        user_id=user_id,
        name=req.name,
        email=email,
        location=req.location,
        region=req.region,
        age=req.age,
        crops=req.crops,
        plots=[plot]
    )
    
    await db.farmers.insert_one(profile.model_dump())
    return profile

class ProfileUpdateRequest(BaseModel):
    name: str | None = None
    location: str | None = None
    region: str | None = None
    age: int | None = None
    gender: str | None = None
    crops: list[str] | None = None

@router.put(
    "/profile/{user_id}",
    response_model=FarmerProfile,
    summary="Update farmer profile",
    description="Update editable fields of a farmer profile.",
)
async def update_profile(
    user_id: str,
    req: ProfileUpdateRequest,
    db: AsyncDatabase = Depends(get_db),
) -> FarmerProfile:
    from fastapi import HTTPException
    
    update_data = {k: v for k, v in req.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    result = await db.farmers.update_one(
        {"user_id": user_id},
        {"$set": update_data}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Farmer not found")
        
    return await get_farmer_profile(db, user_id)

class PlotUpdateRequest(BaseModel):
    size_hectares: float | None = None
    irrigation_level: str | None = None

@router.put(
    "/profile/{user_id}/plot/{plot_index}",
    response_model=FarmerProfile,
    summary="Update farm plot",
    description="Update editable fields of a specific farm plot.",
)
async def update_plot(
    user_id: str,
    plot_index: int,
    req: PlotUpdateRequest,
    db: AsyncDatabase = Depends(get_db),
) -> FarmerProfile:
    from fastapi import HTTPException
    
    update_data = {f"plots.{plot_index}.{k}": v for k, v in req.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    result = await db.farmers.update_one(
        {"user_id": user_id},
        {"$set": update_data}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Farmer or plot not found")
        
    return await get_farmer_profile(db, user_id)

class CropHistoryRequest(BaseModel):
    year: int
    crop: str
    yield_tons_per_hectare: float = 0.0
    profit: float = 0.0
    notes: str | None = None

@router.post(
    "/profile/{user_id}/plot/{plot_index}/crop",
    response_model=FarmerProfile,
    summary="Add crop history entry",
    description="Add a new crop history entry to a specific farm plot.",
)
async def add_crop_history(
    user_id: str,
    plot_index: int,
    req: CropHistoryRequest,
    db: AsyncDatabase = Depends(get_db),
) -> FarmerProfile:
    from fastapi import HTTPException
    
    entry = {k: v for k, v in req.model_dump().items() if v is not None}
    
    result = await db.farmers.update_one(
        {"user_id": user_id},
        {"$push": {f"plots.{plot_index}.crop_history": entry}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Farmer or plot not found")
        
    return await get_farmer_profile(db, user_id)

from fastapi import UploadFile, File

@router.post(
    "/profile/{user_id}/plot/{plot_index}/upload-soil",
    response_model=FarmerProfile,
    summary="Upload Soil Analysis Report",
    description="Uploads an image of a lab soil report. Extracts data using Gemini Vision OCR and updates the profile.",
)
async def upload_soil_report(
    user_id: str,
    plot_index: int,
    file: UploadFile = File(...),
    db: AsyncDatabase = Depends(get_db),
) -> FarmerProfile:
    from app.services.soil_service import scan_and_save_soil_report
    
    # Read the image bytes
    image_bytes = await file.read()
    mime_type = file.content_type or "image/jpeg"
    
    return await scan_and_save_soil_report(
        db=db,
        user_id=user_id,
        plot_index=plot_index,
        image_bytes=image_bytes,
        mime_type=mime_type
    )
