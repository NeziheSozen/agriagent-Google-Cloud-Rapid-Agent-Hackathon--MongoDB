"""
Service for calculating chilling hours and late frost risks.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone, timedelta

from app.external_apis.open_meteo import get_hourly_historical
from app.external_apis.geocoding import geocode
from app.models.climate import ChillingReport

logger = logging.getLogger(__name__)

# Typical chilling hour requirements (0 - 7.2 °C)
CHILLING_REQUIREMENTS = {
    "ceviz": 800,
    "walnut": 800,
    "kiraz": 700,
    "cherry": 700,
    "elma": 1000,
    "apple": 1000,
    "şeftali": 650,
    "peach": 650,
    "kayısı": 500,
    "apricot": 500,
    "erik": 600,
    "plum": 600,
    "armut": 900,
    "pear": 900,
    "incir": 100,
    "fig": 100,
    "zeytin": 200,
    "olive": 200,
    "kivi": 600,
    "kiwi": 600,
}


async def generate_chilling_report(location: str, crop: str) -> ChillingReport:
    """
    Generate a chilling hours report for a given location and crop.
    
    It checks hourly temperatures between Nov 1 and Mar 31,
    and identifies late frost risks after March 15.
    """
    lat, lon, region = await geocode(location)
    
    now = datetime.now(timezone.utc)
    # Determine the season bounds. If we are before Nov, we check the previous winter.
    if now.month < 11:
        start_year = now.year - 1
        end_year = now.year
    else:
        start_year = now.year
        end_year = now.year + 1

    start_date = f"{start_year}-11-01"
    end_date = f"{end_year}-03-31"
    
    # We shouldn't request future dates in the archive API. Cap end_date to yesterday if needed.
    # Note: open_meteo handles historical data, we might need forecast for future dates if current date is before Mar 31.
    # For hackathon purposes, assuming we can get data up to now.
    yesterday = (now - timedelta(days=1)).strftime("%Y-%m-%d")
    if end_date > yesterday:
        end_date = yesterday

    hourly_data = await get_hourly_historical(lat, lon, start_date, end_date)
    
    times = hourly_data.get("time", [])
    temps = hourly_data.get("temperature_2m", [])
    
    accumulated_hours = 0
    frost_risk_dates = []
    
    for t_str, temp in zip(times, temps):
        if temp is None:
            continue
            
        # Count chilling hours (0 to 7.2 C)
        if 0.0 <= temp <= 7.2:
            accumulated_hours += 1
            
        # Check frost risk after March 15
        dt = datetime.fromisoformat(t_str)
        if dt.month == 3 and dt.day >= 15 and temp < 0.0:
            date_only = dt.strftime("%Y-%m-%d")
            if date_only not in frost_risk_dates:
                frost_risk_dates.append(date_only)
    
    target_hours = CHILLING_REQUIREMENTS.get(crop.lower(), 500)  # default 500
    fulfillment_pct = (accumulated_hours / target_hours) * 100 if target_hours > 0 else 100.0
    
    if fulfillment_pct >= 100:
        status = "Optimal"
    elif fulfillment_pct >= 80:
        status = "Sufficient"
    elif fulfillment_pct >= 50:
        status = "Marginal"
    else:
        status = "Insufficient"
        
    recommendation = []
    if status == "Optimal" or status == "Sufficient":
        recommendation.append(f"Chilling requirement for {crop.capitalize()} ({target_hours} hours) has been sufficiently met.")
    else:
        recommendation.append(f"WARNING: Chilling hours for {crop.capitalize()} are insufficient ({accumulated_hours}/{target_hours}). Delayed flowering and reduced yield may occur.")
        
    if frost_risk_dates:
        recommendation.append("⚠️ SPRING LATE FROST RISK: Sub-zero temperatures were observed after March 15. Buds may be damaged — keep frost protection/misting systems ready.")
    else:
        recommendation.append("No late frost risk observed.")

    return ChillingReport(
        location=location,
        crop=crop,
        season=f"{start_year}/{end_year} Winter",
        accumulated_hours=accumulated_hours,
        target_hours=target_hours,
        fulfillment_pct=round(fulfillment_pct, 1),
        status=status,
        frost_risk_dates=frost_risk_dates,
        recommendation=" ".join(recommendation)
    )
