"""
Strategy report models.

The ``StrategyReport`` is the crown-jewel output of AgriAgent: a
personalized, multi-factor crop-planning document that synthesises
farmer profile, climate, threats, and market data into ranked
actionable recommendations.
"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class CropOption(BaseModel):
    """A single ranked crop recommendation within a strategy report."""

    rank: int = Field(..., ge=1, description="1 = best option")
    crop: str
    expected_yield_tons_per_hectare: float = Field(..., ge=0)
    estimated_revenue: float = Field(..., ge=0)
    estimated_cost: float = Field(..., ge=0)
    estimated_profit: float = Field(..., description="Revenue minus cost")
    risk_score: float = Field(
        ..., ge=0.0, le=10.0, description="Composite risk (0 = safe, 10 = very risky)"
    )
    risk_factors: list[str] = Field(
        default_factory=list, description="Key risk drivers for this option"
    )
    rotation_benefit: str = Field(
        ..., description="Soil / rotation advantage of choosing this crop"
    )


class StrategyReport(BaseModel):
    """
    Complete AI-generated strategy report persisted in
    ``strategy_reports`` collection.

    Created by the orchestrator after merging outputs from all
    sub-agents (climate, threat, market).
    """

    user_id: str = Field(..., min_length=1)
    currency_symbol: str = Field(default="$", description="Currency symbol for localized financial data")
    season: str = Field(..., description="Planning horizon, e.g. '2026 Summer'")
    farm_summary: str
    rotation_analysis: str
    climate_assessment: str
    threat_assessment: str
    market_outlook: str
    recommendations: list[CropOption] = Field(
        ..., min_length=1, description="Ranked crop options (typically 3)"
    )
    sustainability_analysis: str = Field(
        default="", description="Carbon reduction and ecological soil management guidance"
    )
    insurance_recommendations: str = Field(
        default="", description="Matched agricultural, greenhouse, or frost insurance options"
    )
    final_recommendation: str = Field(
        ..., description="Executive summary / recommended action"
    )
    created_at: datetime = Field(default_factory=datetime.utcnow)


