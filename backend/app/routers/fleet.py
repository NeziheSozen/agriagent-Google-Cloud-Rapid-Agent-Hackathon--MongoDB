"""
Fleet management router — schedule, book, and cancel machine usage.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from pymongo.asynchronous.database import AsyncDatabase

from app.database import get_db
from app.services.fleet_service import (
    generate_fleet_schedule,
    book_machine,
    cancel_booking,
)

router = APIRouter(prefix="/fleet", tags=["Fleet Management"])


class BookMachineRequest(BaseModel):
    machine_id: str
    farmer_name: str
    date: str  # YYYY-MM-DD
    coop_id: str
    reason: str = "Machine Usage"


@router.get("/schedule")
async def get_fleet_schedule(
    region: str = "Tekirdağ",
    farmer_name: str = "You",
    machine_type: str | None = None,
    coop_id: str | None = None,
    db: AsyncDatabase = Depends(get_db),
):
    """
    Returns the autonomous fleet sharing schedule.

    If ``coop_id`` is provided, queries real cooperative machines.
    Otherwise returns a prompt to join a cooperative.
    """
    schedule = await generate_fleet_schedule(
        db, region, farmer_name, machine_type, coop_id
    )
    return schedule


@router.post("/book")
async def book_machine_endpoint(
    body: BookMachineRequest,
    db: AsyncDatabase = Depends(get_db),
):
    """Book a shared machine for a specific date."""
    try:
        result = await book_machine(
            db,
            machine_id=body.machine_id,
            farmer_name=body.farmer_name,
            date=body.date,
            coop_id=body.coop_id,
            reason=body.reason,
        )
        return {"status": "booked", "booking": result}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/cancel/{booking_id}")
async def cancel_booking_endpoint(
    booking_id: str,
    db: AsyncDatabase = Depends(get_db),
):
    """Cancel an existing machine booking."""
    try:
        result = await cancel_booking(db, booking_id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
