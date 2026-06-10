"""
Satellite monitoring domain models.

Data structures for field polygons, NDVI vegetation analysis,
soil moisture readings, and combined satellite analysis results.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

from app.models.common import MongoBaseModel


class FieldPolygon(MongoBaseModel):
    """
    A farmer's field boundary registered with Agromonitoring.

    The ``agro_polygon_id`` is the remote ID returned by the
    Agromonitoring API after polygon creation.
    """

    user_id: str = Field(..., description="Owner farmer ID")
    name: str = Field(..., description="Human-readable field name")
    coordinates: list[list[float]] = Field(
        ..., description="GeoJSON ring [[lon, lat], ...]"
    )
    agro_polygon_id: str = Field(
        default="", description="Agromonitoring polygon ID"
    )
    area_hectares: float = Field(default=0.0, ge=0, description="Field area in hectares")
    created_at: str = Field(default="", description="ISO 8601 creation timestamp")


class NDVIData(BaseModel):
    """
    Normalized Difference Vegetation Index reading from satellite.

    NDVI ranges:
      - > 0.6  → Healthy, dense vegetation
      - 0.3–0.6 → Moderate stress or sparse vegetation
      - < 0.3  → Severe stress, bare soil, or water
    """

    date: str = Field(..., description="ISO 8601 date of satellite pass")
    ndvi_min: float = Field(..., ge=-1, le=1)
    ndvi_max: float = Field(..., ge=-1, le=1)
    ndvi_mean: float = Field(..., ge=-1, le=1)
    health_status: Literal["Healthy", "Moderate Stress", "Severe Stress"] = Field(
        ..., description="Derived crop health classification"
    )
    health_status_tr: str = Field(
        default="", description="Turkish translation of health status"
    )


class SoilMoisture(BaseModel):
    """Soil moisture and temperature from satellite/model data."""

    date: str = Field(..., description="ISO 8601 date")
    surface_moisture: float = Field(
        ..., ge=0, le=1, description="Volumetric water content (m³/m³)"
    )
    surface_temp_celsius: float = Field(..., description="Surface temperature")
    underground_temp_celsius: float = Field(
        default=0.0, description="Temperature at 10cm depth"
    )
    moisture_status: Literal["Adequate", "Dry", "Waterlogged"] = Field(
        ..., description="Derived moisture classification"
    )
    moisture_status_tr: str = Field(
        default="", description="Turkish translation of moisture status"
    )


class SatelliteImage(BaseModel):
    """Satellite image metadata and URLs."""

    date: str = Field(..., description="ISO 8601 date of capture")
    cloud_coverage_percent: float = Field(default=0, ge=0, le=100)
    data_coverage_percent: float = Field(default=0, ge=0, le=100)
    true_color_url: str = Field(default="", description="RGB true-color image URL")
    false_color_url: str = Field(default="", description="False-color composite URL")
    ndvi_url: str = Field(default="", description="NDVI heatmap image URL")
    evi_url: str = Field(default="", description="EVI heatmap image URL")


class SatelliteAnalysis(BaseModel):
    """
    Combined satellite analysis for a farmer's field.

    Aggregates NDVI, soil, and imagery into a single response
    with human-readable Turkish summary.
    """

    user_id: str
    field_name: str
    ndvi: NDVIData | None = None
    soil: SoilMoisture | None = None
    latest_image: SatelliteImage | None = None
    analysis_summary: str = Field(
        default="", description="AI-generated Turkish analysis"
    )
    data_source: str = Field(
        default="Agromonitoring (Sentinel-2)",
        description="Satellite data provider"
    )
    analyzed_at: str = Field(default="", description="ISO 8601 analysis timestamp")


class CreatePolygonRequest(BaseModel):
    """Request body for creating a field polygon."""

    user_id: str = Field(..., description="Owner farmer ID")
    name: str = Field(..., description="Field name")
    coordinates: list[list[float]] = Field(
        ...,
        description="Polygon coordinates [[lon, lat], ...]. Must have ≥ 4 points (closed ring).",
    )
