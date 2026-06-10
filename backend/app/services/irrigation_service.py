"""
Irrigation assessment service — determines irrigation need from real-time
soil moisture, precipitation, and evapotranspiration data via Open-Meteo.

Replaces manual "None/Low/Medium/High" input with data-driven classification.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

import httpx

from app.external_apis.geocoding import geocode

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(connect=10.0, read=30.0, write=10.0, pool=10.0)

# Crop-specific water demand coefficients (mm/day during peak growth)
_CROP_WATER_DEMAND = {
    "wheat": 4.5,
    "barley": 4.0,
    "corn": 6.5,
    "sunflower": 5.5,
    "tomato": 6.0,
    "cotton": 7.0,
    "canola": 4.0,
    "soybean": 5.5,
    "chickpea": 3.5,
    "lentil": 3.0,
    "pepper": 5.0,
    "lettuce": 4.0,
    "green_bean": 4.5,
    "default": 5.0,
}


class IrrigationAssessment:
    """Data class for irrigation assessment results."""

    def __init__(
        self,
        level: str,
        soil_moisture_percent: float,
        precipitation_last_7days_mm: float,
        et0_daily_mm: float,
        water_deficit_mm: float,
        recommendation: str,
        details: dict,
    ):
        self.level = level
        self.soil_moisture_percent = soil_moisture_percent
        self.precipitation_last_7days_mm = precipitation_last_7days_mm
        self.et0_daily_mm = et0_daily_mm
        self.water_deficit_mm = water_deficit_mm
        self.recommendation = recommendation
        self.details = details

    def to_dict(self) -> dict:
        return {
            "level": self.level,
            "soil_moisture_percent": self.soil_moisture_percent,
            "precipitation_last_7days_mm": self.precipitation_last_7days_mm,
            "et0_daily_mm": self.et0_daily_mm,
            "water_deficit_mm": self.water_deficit_mm,
            "recommendation": self.recommendation,
            "details": self.details,
        }


async def assess_irrigation(
    location: str,
    crop: str = "default",
) -> IrrigationAssessment:
    """
    Assess irrigation need for a location using Open-Meteo soil moisture,
    precipitation history, and ET0 evapotranspiration data.

    Parameters
    ----------
    location : str
        City/region name (geocoded to lat/lon).
    crop : str
        Crop type for water demand calculation.

    Returns
    -------
    IrrigationAssessment
        Data-driven irrigation classification (None/Low/Medium/High).
    """
    lat, lon, resolved_name = await geocode(location)

    now = datetime.now(timezone.utc)
    today = now.strftime("%Y-%m-%d")
    week_ago = (now - timedelta(days=7)).strftime("%Y-%m-%d")

    # ── Fetch current soil moisture + recent weather from Open-Meteo ──
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "hourly": ",".join([
            "soil_moisture_0_to_7cm",
            "soil_moisture_7_to_28cm",
            "soil_moisture_28_to_100cm",
        ]),
        "daily": ",".join([
            "precipitation_sum",
            "et0_fao_evapotranspiration",
            "temperature_2m_max",
            "temperature_2m_min",
        ]),
        "past_days": 7,
        "forecast_days": 7,
        "timezone": "auto",
        "temperature_unit": "celsius",
        "precipitation_unit": "mm",
    }

    logger.info(
        "Fetching soil moisture + ET0 for irrigation assessment: %s (%.2f, %.2f)",
        location, lat, lon,
    )

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    hourly = data.get("hourly", {})
    daily = data.get("daily", {})

    # ── Parse soil moisture (latest reading) ─────────────────────────
    sm_shallow = hourly.get("soil_moisture_0_to_7cm", [])
    sm_mid = hourly.get("soil_moisture_7_to_28cm", [])
    sm_deep = hourly.get("soil_moisture_28_to_100cm", [])

    # Get last valid reading (most recent non-null value)
    def _last_valid(arr: list) -> float:
        for v in reversed(arr):
            if v is not None:
                return v
        return 0.0

    current_sm_shallow = _last_valid(sm_shallow)
    current_sm_mid = _last_valid(sm_mid)
    current_sm_deep = _last_valid(sm_deep)

    # Weighted average: shallow (30%), mid (50%), deep (20%)
    # Open-Meteo returns volumetric water content (m³/m³), convert to %
    avg_soil_moisture = (
        current_sm_shallow * 0.3 +
        current_sm_mid * 0.5 +
        current_sm_deep * 0.2
    ) * 100  # Convert to percentage

    # ── Parse precipitation (last 7 days) ────────────────────────────
    precip_values = daily.get("precipitation_sum", [])
    dates = daily.get("time", [])

    # Split into past and future
    past_precip = []
    future_precip = []
    for i, d in enumerate(dates):
        if i < len(precip_values) and precip_values[i] is not None:
            if d <= today:
                past_precip.append(precip_values[i])
            else:
                future_precip.append(precip_values[i])

    total_past_precip = sum(past_precip)
    total_future_precip = sum(future_precip)

    # ── Parse ET0 (evapotranspiration) ───────────────────────────────
    et0_values = daily.get("et0_fao_evapotranspiration", [])
    recent_et0 = [v for v in et0_values if v is not None]
    avg_et0 = sum(recent_et0) / len(recent_et0) if recent_et0 else 4.0

    # ── Calculate water deficit ──────────────────────────────────────
    crop_demand = _CROP_WATER_DEMAND.get(crop.lower(), _CROP_WATER_DEMAND["default"])

    # Water balance: demand vs supply over 7 days
    weekly_demand = crop_demand * 7
    weekly_supply = total_past_precip
    water_deficit = max(0, weekly_demand - weekly_supply)

    # ── Classify irrigation level ────────────────────────────────────
    level, recommendation = _classify_irrigation(
        soil_moisture_pct=avg_soil_moisture,
        water_deficit_mm=water_deficit,
        avg_et0=avg_et0,
        future_precip=total_future_precip,
        crop=crop,
    )

    return IrrigationAssessment(
        level=level,
        soil_moisture_percent=round(avg_soil_moisture, 1),
        precipitation_last_7days_mm=round(total_past_precip, 1),
        et0_daily_mm=round(avg_et0, 1),
        water_deficit_mm=round(water_deficit, 1),
        recommendation=recommendation,
        details={
            "location": resolved_name,
            "crop": crop,
            "soil_moisture_shallow_pct": round(current_sm_shallow * 100, 1),
            "soil_moisture_mid_pct": round(current_sm_mid * 100, 1),
            "soil_moisture_deep_pct": round(current_sm_deep * 100, 1),
            "forecast_precip_next_7days_mm": round(total_future_precip, 1),
            "crop_water_demand_mm_per_day": crop_demand,
            "assessment_date": today,
        },
    )


def _classify_irrigation(
    soil_moisture_pct: float,
    water_deficit_mm: float,
    avg_et0: float,
    future_precip: float,
    crop: str,
) -> tuple[str, str]:
    """
    Classify irrigation need into None/Low/Medium/High based on
    soil moisture, water deficit, ET0, and upcoming precipitation.

    Returns (level, recommendation).
    """
    # Score system: higher = more irrigation needed
    score = 0

    # Soil moisture assessment
    # Field capacity typically ~30-35%, wilting point ~10-15%
    if soil_moisture_pct < 12:
        score += 4  # Critical - near wilting point
    elif soil_moisture_pct < 18:
        score += 3  # Low moisture
    elif soil_moisture_pct < 25:
        score += 2  # Below optimal
    elif soil_moisture_pct < 32:
        score += 1  # Adequate
    # else: >= 32% → saturated, no irrigation needed

    # Water deficit assessment (7-day)
    if water_deficit_mm > 30:
        score += 3
    elif water_deficit_mm > 20:
        score += 2
    elif water_deficit_mm > 10:
        score += 1

    # ET0 assessment (high evapotranspiration = more water loss)
    if avg_et0 > 6.0:
        score += 2
    elif avg_et0 > 4.0:
        score += 1

    # Future precipitation offset (rain coming = less irrigation needed)
    if future_precip > 20:
        score -= 2
    elif future_precip > 10:
        score -= 1

    score = max(0, score)

    # Classify
    if score <= 1:
        level = "None"
        recommendation = (
            f"Soil moisture is adequate ({soil_moisture_pct:.0f}%). "
            f"{future_precip:.0f}mm of precipitation expected in the next 7 days. "
            "No irrigation is needed at this time."
        )
    elif score <= 3:
        level = "Low"
        recommendation = (
            f"Soil moisture is at a reasonable level ({soil_moisture_pct:.0f}%). "
            f"Daily evaporation is {avg_et0:.1f}mm. "
            "Light weekly irrigation will be sufficient."
        )
    elif score <= 5:
        level = "Medium"
        recommendation = (
            f"Soil moisture is declining ({soil_moisture_pct:.0f}%). "
            f"Water deficit: {water_deficit_mm:.0f}mm/week. "
            "A regular irrigation schedule should be applied (2-3 times per week)."
        )
    else:
        level = "High"
        recommendation = (
            f"⚠️ Soil moisture is at a critical level ({soil_moisture_pct:.0f}%)! "
            f"Water deficit: {water_deficit_mm:.0f}mm/week, evaporation: {avg_et0:.1f}mm/day. "
            "Urgent and intensive irrigation required (daily drip or sprinkler)."
        )

    return level, recommendation
