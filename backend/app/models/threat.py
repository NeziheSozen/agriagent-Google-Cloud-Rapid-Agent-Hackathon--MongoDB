"""
Threat / pest / disease alert models.

Tracks active agricultural threats per region with severity scoring
and spread-risk probabilities used by the advisory engine.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ThreatAlert(BaseModel):
    """A single confirmed or emerging agricultural threat."""

    threat_name: str = Field(..., description="English threat name")
    threat_name_tr: str | None = Field(default=None, description="Turkish threat name")
    local_threat_name: str | None = Field(default=None, description="Threat name in the requested local language")
    threat_type: Literal["Disease", "Pest", "Invasive"] = Field(
        ..., description="Classification category"
    )
    affected_crops: list[str] = Field(..., min_length=1, description="Crops at risk")
    severity: Literal["Low", "Medium", "High", "Critical"]
    source_location: str = Field(..., description="First reported location")
    reported_date: datetime
    spread_risk_to_neighbors: float = Field(
        ..., ge=0.0, le=1.0, description="Probability of regional spread (0–1)"
    )
    description: str = Field(..., description="Advisory text for farmers")
    description_tr: str | None = Field(default=None, description="Turkish advisory text")
    local_description: str | None = Field(default=None, description="Advisory text in the requested local language")
    image_url: str | None = Field(default=None, description="URL of the threat image")


class RegionalThreats(BaseModel):
    """
    Aggregated threat overview for an agricultural region.

    Returned by ``GET /regional-threats/{region}`` with threats
    filtered to the last 30 days and an overall risk score.
    """

    region: str
    query_date: datetime = Field(default_factory=datetime.utcnow)
    active_threats: list[ThreatAlert] = Field(default_factory=list)
    overall_risk_level: Literal["Low", "Medium", "High", "Critical"]
    advisory: str = Field(..., description="Region-wide advisory summary")
