"""
Market router — commodity price forecasts.

Exposes ``POST /market-forecast`` accepting a list of crop names
and returning aggregated price predictions.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from app.database import AsyncDatabase, get_db
from app.models.market import CropForecastRequest, MarketForecast
from app.services.market_service import get_market_forecast
from app.external_apis.market_data import update_market_prices_in_db

router = APIRouter(tags=["Market"])

@router.get("/trigger-scraper")
async def trigger_scraper(db: AsyncDatabase = Depends(get_db)):
    try:
        updated = await update_market_prices_in_db(db)
        return {"status": "success", "updated": updated}
    except Exception as e:
        import traceback
        return {"status": "error", "error": str(e), "traceback": traceback.format_exc()}

@router.get("/debug-db")
async def debug_db(db: AsyncDatabase = Depends(get_db)):
    tr_count = await db.tr_market_data.count_documents({})
    global_count = await db.market_data.count_documents({})
    sample = await db.tr_market_data.find_one({}) if tr_count > 0 else None
    if sample and "_id" in sample:
        sample["_id"] = str(sample["_id"])
    return {"tr_count": tr_count, "global_count": global_count, "tr_sample": sample}


@router.post(
    "/market-forecast",
    response_model=MarketForecast,
    summary="Get 1-year commodity price forecast",
    description="Predicts prices using SARIMA and real-time wholesale data.",
)
async def market_forecast_endpoint(
    req: CropForecastRequest,
    db: AsyncDatabase = Depends(get_db)
):
    return await get_market_forecast(db, req.crops, req.location, req.country)
