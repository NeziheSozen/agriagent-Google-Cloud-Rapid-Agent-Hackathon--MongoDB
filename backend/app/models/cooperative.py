"""
Cooperative / Collective sharing network models.

Supports both official cooperatives and voluntary
sharing networks where farmers pool machines.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal

import random
import string
import uuid

from pydantic import BaseModel, Field


def _generate_join_code() -> str:
    """Generate a 6-char join code like 'TKR-482'."""
    letters = "".join(random.choices(string.ascii_uppercase, k=3))
    digits = "".join(random.choices(string.digits, k=3))
    return f"{letters}-{digits}"


class CoopMachine(BaseModel):
    """A machine owned by a farmer and optionally shared with the cooperative."""

    machine_id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8])
    name: str  # "Pneumatic Seeder", "Combine Harvester"
    type: str  # seeder | harvester | sprayer | tractor | trailer
    owner_id: str  # user_id of the farmer who owns it
    owner_name: str  # Display name
    shared: bool = False  # Whether owner wants to share with coop
    daily_rental_cost: float = 0.0  # Daily rental price (0 = free for coop members)
    status: str = "active"  # active | maintenance | retired
    ownership_type: str = "individual"  # "individual" | "cooperative" | "ai_managed"


class Cooperative(BaseModel):
    """A cooperative or voluntary collective sharing network."""

    coop_id: str = Field(default_factory=lambda: str(uuid.uuid4())[:12])
    name: str
    region: str
    location_geo: dict | None = None  # GeoJSON Point: {"type": "Point", "coordinates": [longitude, latitude]}
    description: str = ""
    coop_type: Literal["official", "collective"] = "collective"
    member_ids: list[str] = Field(default_factory=list)
    machines: list[CoopMachine] = Field(default_factory=list)
    admin_id: str  # Founder/president user_id
    join_code: str = Field(default_factory=_generate_join_code)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
