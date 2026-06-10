"""
Service for calculating Growing Degree Days (GDD), VPD, and harvest estimation.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone, timedelta

from app.external_apis.open_meteo import get_hourly_historical
from app.external_apis.geocoding import geocode
from app.models.climate import GDDReport

logger = logging.getLogger(__name__)

# Base temperature and target GDD for crops
CROP_GDD_REQUIREMENTS = {
    "wheat": {"tbase": 0.0, "target": 2000},
    "buğday": {"tbase": 0.0, "target": 2000},
    "corn": {"tbase": 10.0, "target": 2700},
    "mısır": {"tbase": 10.0, "target": 2700},
    "sunflower": {"tbase": 6.0, "target": 1800},
    "ayçiçeği": {"tbase": 6.0, "target": 1800},
    "tomato": {"tbase": 10.0, "target": 1200},
    "domates": {"tbase": 10.0, "target": 1200},
    "canola": {"tbase": 5.0, "target": 1400},
    "kanola": {"tbase": 5.0, "target": 1400},
    "soybean": {"tbase": 10.0, "target": 1500},
    "soya": {"tbase": 10.0, "target": 1500},
}


def _calculate_vpd(temp_c: float, rh_pct: float) -> float:
    """
    Calculate Vapor Pressure Deficit (VPD) in kPa.
    temp_c: Temperature in Celsius
    rh_pct: Relative Humidity in percentage
    """
    # Saturation Vapor Pressure (es) using Tetens equation
    es = 0.61078 * (17.27 * temp_c) / (temp_c + 237.3)
    # Actual Vapor Pressure (ea)
    ea = es * (rh_pct / 100.0)
    # VPD
    return es - ea


async def generate_gdd_report(location: str, crop: str, planting_date: str) -> GDDReport:
    """
    Generate a Growing Degree Days (GDD) report.
    """
    lat, lon, region = await geocode(location)
    
    # Define Tbase and Target GDD
    crop_req = CROP_GDD_REQUIREMENTS.get(crop.lower(), {"tbase": 10.0, "target": 1500})
    tbase = crop_req["tbase"]
    target_gdd = crop_req["target"]
    
    now = datetime.now(timezone.utc)
    yesterday = (now - timedelta(days=1)).strftime("%Y-%m-%d")
    
    end_date = yesterday
    if planting_date > end_date:
        # If planting date is in the future, we have no GDD yet.
        return GDDReport(
            location=location,
            crop=crop,
            planting_date=planting_date,
            accumulated_gdd=0.0,
            target_gdd=target_gdd,
            progress_pct=0.0,
            estimated_harvest_date=None,
            days_to_harvest=None,
            vpd_current=None,
            brix_estimate=None,
            recommendation="Planting date has not arrived yet, GDD accumulation has not started."
        )

    # We fetch hourly data to get daily min, max, and also current RH for VPD
    hourly_data = await get_hourly_historical(lat, lon, planting_date, end_date)
    
    times = hourly_data.get("time", [])
    temps = hourly_data.get("temperature_2m", [])
    humidities = hourly_data.get("relative_humidity_2m", [])
    
    # Aggregate daily
    daily_temps = {}
    last_temp = None
    last_rh = None
    
    for t_str, temp, rh in zip(times, temps, humidities):
        if temp is None:
            continue
        date_only = t_str.split("T")[0]
        if date_only not in daily_temps:
            daily_temps[date_only] = []
        daily_temps[date_only].append(temp)
        last_temp = temp
        if rh is not None:
            last_rh = rh
            
    accumulated_gdd = 0.0
    recent_daily_gdd = []
    
    for d, d_temps in sorted(daily_temps.items()):
        tmax = max(d_temps)
        tmin = min(d_temps)
        gdd = max(0.0, (tmax + tmin) / 2.0 - tbase)
        accumulated_gdd += gdd
        recent_daily_gdd.append(gdd)
        
    progress_pct = (accumulated_gdd / target_gdd) * 100
    
    # Estimate harvest date
    estimated_harvest_date = None
    days_to_harvest = None
    
    if progress_pct >= 100:
        days_to_harvest = 0
        estimated_harvest_date = now.strftime("%Y-%m-%d")
    else:
        # Average GDD per day over the last 7 days
        avg_gdd_rate = sum(recent_daily_gdd[-7:]) / 7.0 if len(recent_daily_gdd) >= 7 else sum(recent_daily_gdd) / max(len(recent_daily_gdd), 1)
        if avg_gdd_rate > 0:
            remaining_gdd = target_gdd - accumulated_gdd
            days_to_harvest = int(remaining_gdd / avg_gdd_rate)
            estimated_harvest_date = (now + timedelta(days=days_to_harvest)).strftime("%Y-%m-%d")

    # Current VPD
    vpd_current = None
    if last_temp is not None and last_rh is not None:
        vpd_current = round(_calculate_vpd(last_temp, last_rh), 2)
    # Calculate average DTV (Diurnal Temperature Variation) for recent days
    dtv = 0.0
    if len(daily_temps) > 0:
        recent = list(daily_temps.values())[-14:] if len(daily_temps) >= 14 else list(daily_temps.values())
        dtv = sum((max(t) - min(t)) for t in recent) / len(recent)

    # Real-world Brix estimate based on progress and Diurnal Temperature Variation (DTV)
    # Agronomic model: Higher day/night temp amplitude (DTV) strongly increases sugar accumulation.
    brix_estimate = None
    if progress_pct > 50:
        base_brix = 8.0 + (progress_pct - 50) * 0.1
        # DTV bonus: cold nights & warm days increase sugars (e.g. DTV > 10C gives a bonus)
        dtv_bonus = min(max((dtv - 10) * 0.3, 0), 2.5)
        brix_estimate = round(base_brix + dtv_bonus, 1)

    recommendation = []
    if progress_pct >= 100:
        recommendation.append(f"Target GDD ({target_gdd}) for {crop.capitalize()} has been reached. Ready for harvest.")
    else:
        recommendation.append(f"{round(accumulated_gdd, 1)} GDD accumulated so far (Target: {target_gdd}, {round(progress_pct, 1)}%).")
        if days_to_harvest is not None:
            recommendation.append(f"Based on the current warming trend, estimated {days_to_harvest} days until harvest ({estimated_harvest_date}).")
            
    if vpd_current is not None:
        if vpd_current > 1.5:
            recommendation.append(f"⚠️ Current VPD {vpd_current} kPa: High water stress risk. Increase irrigation.")
        elif vpd_current < 0.5:
            recommendation.append(f"Current VPD {vpd_current} kPa: Low transpiration, fungal risk possible.")
        else:
            recommendation.append(f"Current VPD {vpd_current} kPa: Within optimal range for plant transpiration.")

    if brix_estimate is not None:
        recommendation.append(f"Estimated sugar (Brix) content: {brix_estimate}%")

    return GDDReport(
        location=location,
        crop=crop,
        planting_date=planting_date,
        accumulated_gdd=round(accumulated_gdd, 1),
        target_gdd=target_gdd,
        progress_pct=round(progress_pct, 1),
        estimated_harvest_date=estimated_harvest_date,
        days_to_harvest=days_to_harvest,
        vpd_current=vpd_current,
        brix_estimate=brix_estimate,
        recommendation=" ".join(recommendation)
    )
