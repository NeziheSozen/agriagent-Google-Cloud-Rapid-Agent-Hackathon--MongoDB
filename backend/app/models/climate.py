"""
Climate domain models.

Historical summaries and seasonal forecasts that drive drought-risk
and temperature-trend assessments in the recommendation engine.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class YearlyClimateSummary(BaseModel):
    """Aggregated climate metrics for a single calendar year."""

    year: int = Field(..., ge=2000, le=2100)
    avg_spring_rainfall_mm: float = Field(..., ge=0, description="March–May mean rainfall")
    avg_summer_temp_celsius: float = Field(..., description="June–August mean temperature")
    drought_days: int = Field(..., ge=0, description="Days with < 1 mm precipitation")
    frost_days: int = Field(..., ge=0, description="Days with min temp ≤ 0 °C")


class FutureForecast(BaseModel):
    """Model-based seasonal forecast for the upcoming growing period."""

    season: str = Field(..., description="Target season, e.g. '2026 Summer'")
    predicted_rainfall_mm: float = Field(..., ge=0)
    predicted_avg_temp_celsius: float
    drought_risk: Literal["Low", "Medium", "High", "Critical"]
    trend_summary: str = Field(..., description="Human-readable trend narrative")


class ClimateTrend(BaseModel):
    """
    Per-location climate dossier stored in ``climate_trends``.

    Contains a multi-year historical array and a single forward-looking
    forecast to support planning decisions.
    """

    location: str = Field(..., description="Province or city name")
    region: str = Field(..., description="Agricultural macro-region")
    historical: list[YearlyClimateSummary] = Field(
        default_factory=list, description="5-year rolling history"
    )
    forecast: FutureForecast
    analysis_notes: str = Field(..., description="Expert commentary on the data")


class ChillingReport(BaseModel):
    """Report on accumulated chilling hours and frost risk for a specific crop."""

    location: str
    crop: str
    season: str = Field(..., description="E.g. '2025/2026 Winter'")
    accumulated_hours: int
    target_hours: int
    fulfillment_pct: float
    status: Literal["Insufficient", "Marginal", "Sufficient", "Optimal"]
    frost_risk_dates: list[str] = Field(default_factory=list)
    recommendation: str


class GDDReport(BaseModel):
    """Report on Growing Degree Days and Harvest/Brix Estimation."""

    location: str
    crop: str
    planting_date: str
    accumulated_gdd: float
    target_gdd: float
    progress_pct: float
    estimated_harvest_date: str | None = None
    days_to_harvest: int | None = None
    vpd_current: float | None = None
    brix_estimate: float | None = None
    recommendation: str
