"""
Market / commodity price models.

Provides current and predicted crop prices to inform
profitability estimates in the strategy report.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class CropForecastRequest(BaseModel):
    """Inbound request body for ``POST /market-forecast``."""

    crops: list[str] = Field(
        ..., min_length=1, description="List of crop names to forecast"
    )
    location: str | None = Field(default=None, description="Farmer's location")
    country: str | None = Field(default=None, description="Farmer's country")


class CropPriceForecast(BaseModel):
    """Historical price data for a single commodity."""

    crop: str
    currency: str
    price_today_per_ton: float = Field(..., ge=0)
    price_1_week_ago_per_ton: float = Field(..., ge=0)
    price_1_month_ago_per_ton: float = Field(..., ge=0)
    price_1_year_ago_per_ton: float = Field(..., ge=0)


class MarketForecast(BaseModel):
    """
    Aggregated market outlook returned by the market endpoint.

    Contains per-crop forecasts plus metadata about data provenance.
    """

    forecast_date: datetime = Field(default_factory=datetime.utcnow)
    season: str = Field(..., description="Target season, e.g. '2026 Summer'")
    predictions: list[CropPriceForecast] = Field(default_factory=list)
    data_sources: list[str] = Field(
        default_factory=list,
        description="Provenance — exchanges, agencies, models used",
    )
