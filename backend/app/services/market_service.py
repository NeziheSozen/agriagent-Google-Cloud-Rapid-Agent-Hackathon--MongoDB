"""
Market service — commodity price forecasts with live data refresh.

Architecture:
  1. Trigger a background price refresh from external sources
  2. Read freshest prices from MongoDB
  3. Return MarketForecast with provenance metadata
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from pymongo.asynchronous.database import AsyncDatabase

from app.external_apis.market_data import (
    get_active_data_sources,
    update_market_prices_in_db,
)
from app.models.market import CropPriceForecast, MarketForecast
from app.config import get_settings

logger = logging.getLogger(__name__)


async def get_market_forecast(
    db: AsyncDatabase, crops: list[str], location: str | None = None, country: str | None = None
) -> MarketForecast:
    """
    Build a market forecast for the requested list of crops.

    Strategy:
    1. Try to refresh prices from external sources first
    2. Read from MongoDB (freshly updated or cached)
    3. Return formatted MarketForecast
    """
    # Price refresh is now handled exclusively by the nightly cron job
    # to avoid blocking/slowing down API responses and hitting rate limits.

    # Read ALL market data from MongoDB in a single bulk query
    predictions: list[CropPriceForecast] = []
    all_data_sources = set()

    # Determine if we should read from Turkish market data collection
    is_turkey = False
    loc_str = (location or "").lower()
    cty_str = (country or "").lower()
    if "turkey" in loc_str or "türkiye" in loc_str or "turkey" in cty_str or "türkiye" in cty_str:
        is_turkey = True

    collection = db.tr_market_data if is_turkey else db.market_data

    # Build a case-insensitive regex OR query for all crops at once
    crop_regexes = [{"crop": {"$regex": f"^{c}$", "$options": "i"}} for c in crops]
    cursor = collection.find({"$or": crop_regexes}) if crop_regexes else collection.find()

    # Index results by lowercase crop name for O(1) lookup
    found: dict[str, dict] = {}
    async for doc in cursor:
        found[doc["crop"].lower()] = doc

    for crop_name in crops:
        doc = found.get(crop_name.lower())
        if doc is not None:
            predictions.append(
                CropPriceForecast(
                    crop=doc["crop"],
                    currency=doc.get("currency", "USD"),
                    price_today_per_ton=doc.get("price_today_per_ton") or doc.get("price_today_per_ton") or 0.0,
                    price_1_week_ago_per_ton=doc.get("price_1_week_ago_per_ton") or doc.get("price_1_week_ago_per_ton") or 0.0,
                    price_1_month_ago_per_ton=doc.get("price_1_month_ago_per_ton") or doc.get("price_1_month_ago_per_ton") or 0.0,
                    price_1_year_ago_per_ton=doc.get("price_1_year_ago_per_ton") or doc.get("price_1_year_ago_per_ton") or 0.0,
                )
            )
        else:
            # Try fuzzy match — the crop name might contain the DB name or vice versa
            # e.g. "Bush Beans (Green Beans)" should match "Green Bean"
            fuzzy_match = None
            crop_lower = crop_name.lower()
            for db_key, db_doc in found.items():
                if db_key in crop_lower or crop_lower in db_key:
                    fuzzy_match = db_doc
                    break
            
            if fuzzy_match:
                predictions.append(
                    CropPriceForecast(
                        crop=fuzzy_match["crop"],
                        currency=fuzzy_match.get("currency", "USD"),
                        price_today_per_ton=fuzzy_match.get("price_today_per_ton") or fuzzy_match.get("price_today_per_ton") or 0.0,
                        price_1_week_ago_per_ton=fuzzy_match.get("price_1_week_ago_per_ton") or fuzzy_match.get("price_1_week_ago_per_ton") or 0.0,
                        price_1_month_ago_per_ton=fuzzy_match.get("price_1_month_ago_per_ton") or fuzzy_match.get("price_1_month_ago_per_ton") or 0.0,
                        price_1_year_ago_per_ton=fuzzy_match.get("price_1_year_ago_per_ton") or fuzzy_match.get("price_1_year_ago_per_ton") or 0.0,
                    )
                )
            else:
                # Not found in DB even with fuzzy match — skip this crop
                logger.warning("⚠️ No market data found for '%s' — skipping", crop_name)

    # Force standard sources
    if is_turkey:
        all_data_sources = {
            "İBB Hal Kayıt Sistemi",
            "Antalya B.B. Hal API",
            "İzmir B.B. Hal"
        }
    else:
        all_data_sources = {
            "Global Commodity Exchange",
            "FAO Food Price Index",
            "API Ninjas Commodities"
        }

    if not predictions:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No market data found for crops: {crops}",
        )

    # Determine current season
    now = datetime.now(timezone.utc)
    month = now.month
    year = now.year
    if month in (3, 4, 5):
        season = f"{year} Spring"
    elif month in (6, 7, 8):
        season = f"{year} Summer"
    elif month in (9, 10, 11):
        season = f"{year} Autumn"
    else:
        season = f"{year} Winter"

    settings = get_settings()
    
    return MarketForecast(
        forecast_date=now,
        season=season,
        predictions=predictions,
        data_sources=list(all_data_sources),
    )
