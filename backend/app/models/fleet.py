"""
Models for Fleet Management and Cooperative Sharing.
"""

from __future__ import annotations

from typing import Literal
import uuid
from pydantic import BaseModel, Field

class FleetMachine(BaseModel):
    """A machine available for cooperative sharing."""
    machine_id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8])
    name: str = Field(..., description="e.g. John Deere 6155M")
    type: Literal["seeder", "harvester", "sprayer", "tractor"]
    region: str
    owner: str = Field(..., description="Cooperative or farmer name owning the machine")

class FleetBooking(BaseModel):
    """A booking for a machine."""
    booking_id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8])
    machine_id: str
    farmer_name: str
    date: str = Field(..., description="ISO date format YYYY-MM-DD")
    status: Literal["confirmed", "pending", "weather_blocked", "maintenance"]
    reason: str = Field(..., description="e.g. 'Wheat Harvest', 'Corn Planting'")

class FleetScheduleItem(BaseModel):
    """A single day in the machine's schedule."""
    date: str
    status: str
    assignee: str
    reason: str
    is_current_user: bool = False

class FleetSchedule(BaseModel):
    """Full schedule representation for the frontend."""
    machine: str
    region: str
    synergy_discount_percent: float
    schedule: list[FleetScheduleItem]
