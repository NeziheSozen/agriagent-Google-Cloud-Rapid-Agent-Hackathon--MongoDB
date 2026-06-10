"""
Farmer domain models.

Captures everything about a farm: identity, soil lab results,
and five-year crop rotation history used by the recommendation engine.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal
import uuid

from pydantic import BaseModel, Field


class CropHistoryEntry(BaseModel):
    """Single year of crop performance on a farm plot."""

    year: int = Field(..., ge=2000, le=2100, description="Harvest year")
    crop: str = Field(..., min_length=1, description="Crop cultivated that year")
    yield_tons_per_hectare: float = Field(..., ge=0, description="Harvested yield (t/ha)")
    profit: float = Field(..., description="Net profit in USD")
    notes: str | None = Field(default=None, description="Optional observations")


class SoilAnalysis(BaseModel):
    """Lab-grade soil test results for a farm parcel."""

    ph: float = Field(..., ge=0, le=14, description="Soil pH value")
    nitrogen_ppm: float = Field(..., ge=0, description="Nitrogen concentration (ppm)")
    phosphorus_ppm: float = Field(..., ge=0, description="Phosphorus concentration (ppm)")
    potassium_ppm: float = Field(..., ge=0, description="Potassium concentration (ppm)")
    organic_matter_percent: float = Field(..., ge=0, le=100, description="Organic matter (%)")
    salinity_ds_m: float = Field(..., ge=0, description="Electrical conductivity (dS/m)")
    texture: Literal["Loamy", "Clay", "Sandy", "Silty", "Peaty"] = Field(
        ..., description="USDA texture class"
    )
    test_date: datetime = Field(..., description="Date the soil sample was analysed")


class FarmPlot(BaseModel):
    """An individual farm plot, field, or greenhouse."""

    plot_id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8], description="Unique plot identifier")
    name: str = Field(..., description="Name of the plot (e.g., Sera 1, Ana Tarla)")
    size_hectares: float = Field(..., gt=0, description="Plot size (ha)")
    irrigation_level: Literal["None", "Low", "Medium", "High"] = Field(
        ..., description="Available irrigation capacity"
    )
    tenure_type: Literal["Owned", "Rented"] = Field(
        default="Owned", description="Whether the plot is owned or rented (impacts ROI strategy)"
    )
    slope_percent: float | None = Field(default=None, description="Terrain slope percentage")
    elevation_m: float | None = Field(default=None, description="Elevation in meters")
    tree_age: int | None = Field(default=None, description="Age of trees in years, for orchards")
    canopy_coverage_pct: float | None = Field(default=None, ge=0, le=100, description="Tree canopy coverage percentage")
    tree_type: str | None = Field(default=None, description="Type of tree crop, e.g. walnut, cherry")
    lease_end_date: str | None = Field(default=None, description="Lease expiry date for rented plots, ISO format")
    rental_cost: float | None = Field(default=None, ge=0, description="Annual rental cost in USD")
    soil_analysis: SoilAnalysis | None = Field(
        default=None, description="Most recent soil lab report for this plot"
    )
    crop_history: list[CropHistoryEntry] = Field(
        default_factory=list, description="Last 5 years of crop data for this plot"
    )
    location_geo: dict | None = Field(default=None, description="GeoJSON Point: {'type': 'Point', 'coordinates': [longitude, latitude]}")


class FarmerProfile(BaseModel):
    """
    Complete farmer profile stored in the ``farmers`` collection.

    A farmer can have multiple farm plots (FarmPlot).
    """

    user_id: str = Field(..., min_length=1, description="Unique farmer identifier")
    name: str = Field(..., min_length=1, description="Farmer's full name")
    email: str = Field(default="", description="Farmer's email address")
    location: str = Field(..., description="Province / city")
    region: str = Field(..., description="Agricultural region")
    location_geo: dict | None = Field(default=None, description="GeoJSON Point for $geoNear queries")
    age: int = Field(default=45, ge=18, le=100, description="Farmer's age for grant filtering")
    gender: Literal["Male", "Female", "Other", "Prefer not to say"] = Field(
        default="Prefer not to say", description="Gender of the farmer for specific grant filtering"
    )
    crops: list[str] = Field(
        default_factory=list, description="List of crops the farmer currently grows"
    )
    plots: list[FarmPlot] = Field(
        default_factory=list, description="List of all plots, greenhouses, or fields owned by the farmer"
    )
    created_at: datetime = Field(
        default_factory=datetime.utcnow, description="Profile creation timestamp"
    )
    cooperative_id: str | None = Field(
        default=None, description="ID of the cooperative the farmer belongs to"
    )
    cooperative_name: str | None = Field(
        default=None, description="Name of the cooperative the farmer belongs to"
    )
