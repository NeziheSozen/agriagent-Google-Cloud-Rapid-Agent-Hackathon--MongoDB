"""
Farmer service — profile retrieval and management.

Queries the ``farmers`` collection and maps raw BSON documents
to ``FarmerProfile`` Pydantic models.
"""

from __future__ import annotations

from fastapi import HTTPException, status
from pymongo.asynchronous.database import AsyncDatabase

from app.models.farmer import FarmerProfile


async def get_farmer_profile(db: AsyncDatabase, user_id: str) -> FarmerProfile:
    """
    Retrieve a farmer profile by ``user_id``.

    Parameters
    ----------
    db:
        Async database handle (injected via ``Depends(get_db)``).
    user_id:
        Unique farmer identifier, e.g. ``"farmer_001"``.

    Returns
    -------
    FarmerProfile
        Fully hydrated profile including embedded crop history.

    Raises
    ------
    HTTPException 404
        If no farmer with the given ``user_id`` exists.
    """
    doc = await db.farmers.find_one({"user_id": user_id})

    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Farmer profile not found for user_id='{user_id}'",
        )

    return FarmerProfile(**doc)
