"""
Open-Meteo API client — historical climate data and weather forecasts.

Open-Meteo is a **free, open-source** weather API that requires **no API key**.
It provides:
  - Historical daily weather data going back decades (Archive API)
  - 16-day weather forecasts (Forecast API)

This module fetches raw data and transforms it into AgriAgent domain models
(``YearlyClimateSummary``, ``FutureForecast``, ``ClimateTrend``).

API Docs: https://open-meteo.com/en/docs
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import date, datetime, timezone

import httpx

from app.config import get_settings
from app.models.climate import (
    ClimateTrend,
    FutureForecast,
    YearlyClimateSummary,
)

logger = logging.getLogger(__name__)

# ── Constants ────────────────────────────────────────────────────────────

# Spring months for rainfall averaging (March-May)
_SPRING_MONTHS = {3, 4, 5}
# Summer months for temperature averaging (June-August)
_SUMMER_MONTHS = {6, 7, 8}

_TIMEOUT = httpx.Timeout(connect=10.0, read=30.0, write=10.0, pool=10.0)


# ── Public API ───────────────────────────────────────────────────────────


async def get_hourly_historical(
    latitude: float,
    longitude: float,
    start_date: str,
    end_date: str,
) -> dict:
    """
    Fetch historical hourly weather data from Open-Meteo Archive API.

    Parameters
    ----------
    latitude, longitude : float
        GPS coordinates.
    start_date, end_date : str
        Date range in 'YYYY-MM-DD' format.

    Returns
    -------
    dict
        Hourly data containing 'time' and 'temperature_2m' lists.
    """
    settings = get_settings()
    url = f"{settings.open_meteo_archive_url}/v1/archive"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": start_date,
        "end_date": end_date,
        "hourly": "temperature_2m,relative_humidity_2m",
        "timezone": "Europe/Istanbul",
        "temperature_unit": "celsius",
    }

    logger.info(
        "Fetching Open-Meteo HOURLY historical data: (%.2f, %.2f) %s to %s",
        latitude, longitude, start_date, end_date,
    )

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    return data.get("hourly", {})


async def get_historical_climate(
    latitude: float,
    longitude: float,
    start_year: int | None = None,
    end_year: int | None = None,
) -> list[YearlyClimateSummary]:
    """
    Fetch historical daily weather data from Open-Meteo Archive API and
    aggregate it into yearly summaries matching our ``YearlyClimateSummary`` model.

    Parameters
    ----------
    latitude, longitude : float
        GPS coordinates of the location.
    start_year : int, optional
        First year of data (defaults to 10 years ago).
    end_year : int, optional
        Last year of data (defaults to last complete year).

    Returns
    -------
    list[YearlyClimateSummary]
        One entry per year with spring rainfall, summer temp, drought/frost days.
    """
    settings = get_settings()
    now = datetime.now(timezone.utc)

    if end_year is None:
        end_year = now.year - 1  # last complete year
    if start_year is None:
        start_year = end_year - 9  # 10 years of data

    start_date = f"{start_year}-01-01"
    end_date = f"{end_year}-12-31"

    url = f"{settings.open_meteo_archive_url}/v1/archive"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": start_date,
        "end_date": end_date,
        "daily": ",".join([
            "temperature_2m_mean",
            "temperature_2m_min",
            "temperature_2m_max",
            "precipitation_sum",
        ]),
        "timezone": "Europe/Istanbul",
        "temperature_unit": "celsius",
        "precipitation_unit": "mm",
    }

    logger.info(
        "Fetching Open-Meteo historical data: (%.2f, %.2f) %s to %s",
        latitude, longitude, start_date, end_date,
    )

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    daily = data.get("daily", {})
    dates = daily.get("time", [])
    temps_mean = daily.get("temperature_2m_mean", [])
    temps_min = daily.get("temperature_2m_min", [])
    precip = daily.get("precipitation_sum", [])

    if not dates:
        logger.warning("Open-Meteo returned empty historical data")
        return []

    # ── Aggregate by year ────────────────────────────────────────────
    yearly_data: dict[int, dict] = defaultdict(lambda: {
        "spring_rain": [],
        "summer_temp": [],
        "drought_days": 0,
        "frost_days": 0,
    })

    for i, date_str in enumerate(dates):
        try:
            d = date.fromisoformat(date_str)
        except (ValueError, TypeError):
            continue

        year = d.year
        month = d.month
        entry = yearly_data[year]

        # Spring rainfall (March-May)
        if month in _SPRING_MONTHS and i < len(precip) and precip[i] is not None:
            entry["spring_rain"].append(precip[i])

        # Summer temperature (June-August)
        if month in _SUMMER_MONTHS and i < len(temps_mean) and temps_mean[i] is not None:
            entry["summer_temp"].append(temps_mean[i])

        # Drought days: precipitation < 1mm
        if i < len(precip) and precip[i] is not None and precip[i] < 1.0:
            entry["drought_days"] += 1

        # Frost days: min temp ≤ 0°C
        if i < len(temps_min) and temps_min[i] is not None and temps_min[i] <= 0.0:
            entry["frost_days"] += 1

    # ── Build YearlyClimateSummary objects ────────────────────────────
    summaries: list[YearlyClimateSummary] = []
    for year in sorted(yearly_data.keys()):
        d = yearly_data[year]
        spring_rain = d["spring_rain"]
        summer_temp = d["summer_temp"]

        summaries.append(YearlyClimateSummary(
            year=year,
            avg_spring_rainfall_mm=round(sum(spring_rain), 1) if spring_rain else 0.0,
            avg_summer_temp_celsius=round(sum(summer_temp) / len(summer_temp), 1) if summer_temp else 0.0,
            drought_days=d["drought_days"],
            frost_days=d["frost_days"],
        ))

    # Keep last 5 years for the frontend (matching existing model expectations)
    if len(summaries) > 5:
        summaries = summaries[-5:]

    logger.info("Built %d yearly climate summaries from Open-Meteo", len(summaries))
    return summaries


async def get_forecast(
    latitude: float,
    longitude: float,
    lang: str = "en",
) -> FutureForecast:
    """
    Fetch a **6-month seasonal forecast** from Open-Meteo Seasonal API
    (ECMWF SEAS5 model) and derive a ``FutureForecast`` with drought-risk
    assessment suitable for agricultural planning.

    Unlike the 16-day weather forecast, this uses climate models that
    project temperature and precipitation trends months ahead — essential
    for crop planning and harvest forecasting.

    Parameters
    ----------
    latitude, longitude : float
        GPS coordinates of the location.

    Returns
    -------
    FutureForecast
        Aggregated seasonal forecast for the upcoming growing period.
    """
    # ── Seasonal API endpoint (ECMWF SEAS5, 51 ensemble members) ─────
    url = "https://seasonal-api.open-meteo.com/v1/seasonal"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "daily": ",".join([
            "temperature_2m_mean",
            "precipitation_sum",
        ]),
        "forecast_days": 183,  # 6 months
        "timezone": "Europe/Istanbul",
        "temperature_unit": "celsius",
        "precipitation_unit": "mm",
    }

    logger.info(
        "Fetching Open-Meteo 6-month SEASONAL forecast: (%.2f, %.2f)",
        latitude, longitude,
    )

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    daily = data.get("daily", {})
    dates = daily.get("time", [])
    temps_mean = daily.get("temperature_2m_mean", [])
    precip = daily.get("precipitation_sum", [])

    if not dates:
        # Fallback: return a generic forecast if seasonal API fails
        now = datetime.now(timezone.utc)
        return FutureForecast(
            season=_get_season_label(now),
            predicted_rainfall_mm=0.0,
            predicted_avg_temp_celsius=0.0,
            drought_risk="Medium",
            trend_summary="Seasonal forecast data could not be retrieved.",
        )

    # ── Aggregate by upcoming season (hemisphere-aware) ────────────
    now = datetime.now(timezone.utc)
    current_month = now.month
    is_southern = latitude < 0  # Southern hemisphere has reversed seasons

    # Determine the target agricultural season
    # Northern: Spring=Mar-May, Summer=Jun-Aug, Autumn=Sep-Nov, Winter=Dec-Feb
    # Southern: Spring=Sep-Nov, Summer=Dec-Feb, Autumn=Mar-May, Winter=Jun-Aug
    if is_southern:
        if current_month <= 2:
            # Southern summer → forecast for autumn (Mar-May)
            target_months = {3, 4, 5}
            season_label = f"{now.year} Autumn"
        elif current_month <= 5:
            # Southern autumn → forecast for winter (Jun-Aug)
            target_months = {6, 7, 8}
            season_label = f"{now.year} Winter"
        elif current_month <= 8:
            # Southern winter → forecast for spring (Sep-Nov)
            target_months = {9, 10, 11}
            season_label = f"{now.year} Spring"
        else:
            # Southern spring → forecast for summer (Dec-Feb)
            target_months = {12, 1, 2}
            season_label = f"{now.year}/{now.year + 1} Summer"
    else:
        if current_month <= 5:
            # Northern spring → forecast for summer
            target_months = {6, 7, 8}
            season_label = f"{now.year} Summer"
        elif current_month <= 8:
            # Northern summer → forecast for autumn
            target_months = {9, 10, 11}
            season_label = f"{now.year} Autumn"
        elif current_month <= 11:
            # Northern autumn → forecast for winter
            target_months = {12, 1, 2}
            season_label = f"{now.year}/{now.year + 1} Winter"
        else:
            # Northern winter → forecast for spring
            target_months = {3, 4, 5}
            season_label = f"{now.year + 1} Spring"

    # Collect data for the target season
    season_temps: list[float] = []
    season_precip: list[float] = []
    all_temps: list[float] = []
    all_precip_days: list[float] = []

    for i, date_str in enumerate(dates):
        try:
            d = date.fromisoformat(date_str)
        except (ValueError, TypeError):
            continue

        # Track overall stats
        if i < len(temps_mean) and temps_mean[i] is not None:
            all_temps.append(temps_mean[i])
        if i < len(precip) and precip[i] is not None:
            all_precip_days.append(precip[i])

        # Track target season stats
        if d.month in target_months:
            if i < len(temps_mean) and temps_mean[i] is not None:
                season_temps.append(temps_mean[i])
            if i < len(precip) and precip[i] is not None:
                season_precip.append(precip[i])

    # Calculate seasonal aggregates
    avg_temp = round(sum(season_temps) / len(season_temps), 1) if season_temps else 0.0
    total_precip = round(sum(season_precip), 1)
    dry_days = sum(1 for p in season_precip if p < 1.0)
    total_season_days = len(season_precip) if season_precip else 1

    # Determine drought risk
    drought_risk = _assess_drought_risk(
        total_precip_mm=total_precip,
        dry_day_ratio=dry_days / max(total_season_days, 1),
        avg_temp=avg_temp,
    )

    # Build seasonal trend summary
    trend_summary = _build_seasonal_summary(
        season_label=season_label,
        avg_temp=avg_temp,
        total_precip=total_precip,
        dry_days=dry_days,
        total_days=total_season_days,
        drought_risk=drought_risk,
        lang=lang,
    )

    return FutureForecast(
        season=season_label,
        predicted_rainfall_mm=total_precip,
        predicted_avg_temp_celsius=avg_temp,
        drought_risk=drought_risk,
        trend_summary=trend_summary,
    )


async def get_full_climate_trend(
    latitude: float,
    longitude: float,
    city: str,
    region: str,
    lang: str = "en",
) -> ClimateTrend:
    """
    Combine historical data and forecast into a complete ``ClimateTrend``.

    This is the main entry point that the climate service calls.
    """
    # Fetch both in parallel would be nice, but sequential is simpler
    historical = await get_historical_climate(latitude, longitude)
    forecast = await get_forecast(latitude, longitude, lang=lang)

    # Generate analysis notes from the data
    analysis_notes = _generate_analysis_notes(historical, forecast, city, lang=lang)

    return ClimateTrend(
        location=city,
        region=region,
        historical=historical,
        forecast=forecast,
        analysis_notes=analysis_notes,
    )


# ── Private helpers ──────────────────────────────────────────────────────


def _assess_drought_risk(
    total_precip_mm: float,
    dry_day_ratio: float,
    avg_temp: float,
) -> str:
    """Categorize drought risk based on forecast indicators."""
    score = 0

    # Very little precipitation — thresholds for a full season (~90 days)
    if total_precip_mm < 30:
        score += 3
    elif total_precip_mm < 60:
        score += 2
    elif total_precip_mm < 100:
        score += 1

    # High ratio of dry days
    if dry_day_ratio > 0.85:
        score += 3
    elif dry_day_ratio > 0.65:
        score += 2
    elif dry_day_ratio > 0.5:
        score += 1

    # High temperatures compound drought stress
    if avg_temp > 35:
        score += 2
    elif avg_temp > 30:
        score += 1

    if score >= 6:
        return "Critical"
    elif score >= 4:
        return "High"
    elif score >= 2:
        return "Medium"
    return "Low"


def _get_season_label(dt: datetime) -> str:
    """Return a human-readable season label like '2026 Summer'."""
    month = dt.month
    year = dt.year
    if month in (3, 4, 5):
        return f"{year} Spring"
    elif month in (6, 7, 8):
        return f"{year} Summer"
    elif month in (9, 10, 11):
        return f"{year} Autumn"
    else:
        return f"{year} Winter"


def _build_trend_summary(
    avg_temp: float,
    total_precip: float,
    dry_days: int,
    forecast_days: int,
    drought_risk: str,
) -> str:
    """Build a human-readable trend narrative."""
    parts: list[str] = []

    # Temperature assessment
    if avg_temp > 35:
        parts.append(f"Average temperature will be extremely hot at {avg_temp}°C over the next {forecast_days} days.")
    elif avg_temp > 28:
        parts.append(f"Average temperature is expected to be above seasonal norms at {avg_temp}°C.")
    elif avg_temp > 20:
        parts.append(f"Temperatures will remain mild with an average of {avg_temp}°C.")
    else:
        parts.append(f"Temperatures will stay cool with an average of {avg_temp}°C.")

    # Precipitation assessment
    if total_precip < 5:
        parts.append(f"Total precipitation is only {total_precip} mm — a very dry period is expected.")
    elif total_precip < 20:
        parts.append(f"Total precipitation of {total_precip} mm is expected; irrigation may be needed.")
    elif total_precip < 50:
        parts.append(f"Total precipitation of {total_precip} mm is expected, sufficient for agricultural activities.")
    else:
        parts.append(f"Total precipitation of {total_precip} mm — a rainy period is expected.")

    # Drought warning
    if drought_risk in ("High", "Critical"):
        parts.append(f"⚠️ Drought risk is at {drought_risk} level! {dry_days}/{forecast_days} days will be dry.")

    return " ".join(parts)


def _build_seasonal_summary(
    season_label: str,
    avg_temp: float,
    total_precip: float,
    dry_days: int,
    total_days: int,
    drought_risk: str,
    lang: str = "en",
) -> str:
    """Build a human-readable seasonal trend narrative in the given language."""
    parts: list[str] = []

    if lang == 'tr':
        parts.append(f"🌾 {season_label} Mevsimsel Tahmin (ECMWF SEAS5):")
        if avg_temp > 35:
            parts.append(f"Sıcaklıklar ortalama {avg_temp}°C ile aşırı sıcak bir sezon bekleniyor — sıcaklık stresi riski çok yüksek.")
        elif avg_temp > 28:
            parts.append(f"Sıcaklıklar {avg_temp}°C ortalamayla ılıman seyredecek.")
        elif avg_temp > 20:
            parts.append(f"Sıcaklıklar {avg_temp}°C ortalamayla ılıman seyredecek.")
        else:
            parts.append(f"Sıcaklıklar {avg_temp}°C ortalamayla serin kalacak.")
        if total_precip < 30:
            parts.append(f"Toplam {total_precip} mm yağış bekleniyor — çok kurak bir sezon; acil sulama planı gerekli.")
        elif total_precip < 80:
            parts.append(f"Toplam {total_precip} mm yağış bekleniyor — düzenli sulama ihtiyacı olacak.")
        elif total_precip < 150:
            parts.append(f"Toplam {total_precip} mm yağış — tarım için yeterli, ancak dağılımı takip edilmeli.")
        else:
            parts.append(f"Toplam {total_precip} mm yağış — yağışlı bir sezon bekleniyor.")
        dry_pct = round(100 * dry_days / max(total_days, 1))
        if drought_risk in ("High", "Critical"):
            parts.append(f"⚠ Kuraklık riski {drought_risk}! Sezonun %{dry_pct}'i kurak geçecek ({dry_days}/{total_days} gün).")
        elif drought_risk == "Medium":
            parts.append(f"Sezonun %{dry_pct}'inde yağış beklenmiyor.")
    else:
        # English (default)
        parts.append(f"🌾 {season_label} Seasonal Forecast (ECMWF SEAS5):")
        if avg_temp > 35:
            parts.append(f"An extremely hot season is expected with an average temperature of {avg_temp}°C — heat stress risk is very high.")
        elif avg_temp > 28:
            parts.append(f"A warm season is forecasted with an average temperature of {avg_temp}°C.")
        elif avg_temp > 20:
            parts.append(f"Temperatures will remain mild with an average of {avg_temp}°C.")
        else:
            parts.append(f"Temperatures will stay cool with an average of {avg_temp}°C.")
        if total_precip < 30:
            parts.append(f"Total precipitation is only {total_precip} mm — a very dry season is forecasted; an urgent irrigation plan is needed.")
        elif total_precip < 80:
            parts.append(f"Total precipitation of {total_precip} mm is expected — regular irrigation will be needed.")
        elif total_precip < 150:
            parts.append(f"Total precipitation of {total_precip} mm — sufficient for agriculture, but distribution should be monitored.")
        else:
            parts.append(f"Total precipitation of {total_precip} mm — a rainy season is expected.")
        dry_pct = round(100 * dry_days / max(total_days, 1))
        if drought_risk in ("High", "Critical"):
            parts.append(f"⚠️ Drought risk is {drought_risk}! {dry_pct}% of the season will be dry ({dry_days}/{total_days} days).")
        elif drought_risk == "Medium":
            parts.append(f"No precipitation is expected for {dry_pct}% of the season.")

    return " ".join(parts)


def _generate_analysis_notes(
    historical: list[YearlyClimateSummary],
    forecast: FutureForecast,
    city: str,
    lang: str = "en",
) -> str:
    """Generate expert analysis notes from the combined climate data in the given language."""
    if not historical:
        if lang == 'tr':
            return f"{city} için yeterli geçmiş veri bulunamadı."
        return f"Insufficient historical data found for {city}."

    notes_parts: list[str] = []
    first = historical[0]
    last = historical[-1]
    years_span = last.year - first.year

    if years_span > 0:
        temp_change = last.avg_summer_temp_celsius - first.avg_summer_temp_celsius
        if abs(temp_change) > 0.5:
            if lang == 'tr':
                yön = "artış" if temp_change > 0 else "düşüş"
                notes_parts.append(f"Son {years_span} yılda yaz sıcaklıklarında {abs(temp_change):.1f}°C {yön} gözlemlendi.")
            else:
                direction = "increase" if temp_change > 0 else "decrease"
                notes_parts.append(f"A {abs(temp_change):.1f}°C {direction} in summer temperatures has been observed over the last {years_span} years.")

        rain_change = last.avg_spring_rainfall_mm - first.avg_spring_rainfall_mm
        if abs(rain_change) > 5:
            if lang == 'tr':
                yön = "artıyor" if rain_change > 0 else "azalıyor"
                notes_parts.append(f"Bahar yağışları son {years_span} yılda {yön} (fark: {abs(rain_change):.1f} mm).")
            else:
                direction = "increasing" if rain_change > 0 else "decreasing"
                notes_parts.append(f"Spring rainfall is {direction} over the last {years_span} years (difference: {abs(rain_change):.1f} mm).")

        drought_change = last.drought_days - first.drought_days
        if abs(drought_change) > 10:
            if lang == 'tr':
                yön = "artıyor" if drought_change > 0 else "azalıyor"
                notes_parts.append(f"Kurak gün sayısı {yön} (fark: {abs(drought_change)} gün).")
            else:
                direction = "increasing" if drought_change > 0 else "decreasing"
                notes_parts.append(f"Number of drought days is {direction} (difference: {abs(drought_change)} days).")

    avg_summer_temp = sum(h.avg_summer_temp_celsius for h in historical) / len(historical)
    avg_spring_rain = sum(h.avg_spring_rainfall_mm for h in historical) / len(historical)

    if lang == 'tr':
        notes_parts.append(
            f"{city} uzun dönem ortalamaları: Yaz sıcaklığı {avg_summer_temp:.1f}°C, "
            f"Bahar yağışı {avg_spring_rain:.1f} mm."
        )
        if forecast.predicted_avg_temp_celsius > avg_summer_temp + 1:
            notes_parts.append("📈 Tahmin ortalamanın üstünde sıcaklıklar gösteriyor — sıcaklık stresine dikkat.")
        elif forecast.predicted_avg_temp_celsius < avg_summer_temp - 1:
            notes_parts.append("📉 Tahmin ortalamanın altında — serin bir sezon bekleniyor.")
    else:
        notes_parts.append(
            f"{city} long-term averages: Summer temperature {avg_summer_temp:.1f}°C, "
            f"Spring rainfall {avg_spring_rain:.1f} mm."
        )
        if forecast.predicted_avg_temp_celsius > avg_summer_temp + 1:
            notes_parts.append("📈 Forecast shows above-average temperatures — watch for heat stress.")
        elif forecast.predicted_avg_temp_celsius < avg_summer_temp - 1:
            notes_parts.append("📉 Forecast is below average — a cool season is expected.")

    if lang == 'tr':
        return " ".join(notes_parts) if notes_parts else f"{city} iklim verileri analiz edildi."
    return " ".join(notes_parts) if notes_parts else f"Climate data for {city} has been analyzed."
