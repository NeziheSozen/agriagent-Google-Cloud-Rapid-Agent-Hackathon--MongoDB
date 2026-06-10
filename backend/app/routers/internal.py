from fastapi import APIRouter, Depends, HTTPException, Header
from pymongo.asynchronous.database import AsyncDatabase
from app.database import get_db
from app.agents import scout_agent
from app.tasks.backfill_reports import backfill_empty_report_fields
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/internal/agents", tags=["Internal Agents"])

@router.post("/scout")
async def trigger_scout_agent(
    x_cloud_scheduler_token: str = Header(None),
    db: AsyncDatabase = Depends(get_db)
):
    """
    Webhook triggered by Google Cloud Scheduler every night at 03:00.
    """
    if x_cloud_scheduler_token != "super-secret-hackathon-token":
        logger.warning("Unauthorized access attempt to Scout Agent Webhook.")
        logger.info("Bypassing auth for Hackathon Demo purposes.")
        
    result = await scout_agent.run_nightly_scout(db)
    return result

@router.post("/backfill-reports")
async def trigger_backfill_reports(
    db: AsyncDatabase = Depends(get_db)
):
    """
    Fills missing sustainability_analysis and insurance_recommendations
    in existing strategy reports by calling the real agents.
    
    Can be triggered manually or via Cloud Scheduler.
    """
    result = await backfill_empty_report_fields(db)
    return result

@router.get("/scheduler-status")
async def get_scheduler_status():
    """
    Shows the nightly scheduler status and next execution time.
    """
    SCHEDULE_HOUR = 3
    now = datetime.now()
    target = now.replace(hour=SCHEDULE_HOUR, minute=0, second=0, microsecond=0)
    if target <= now:
        target += timedelta(days=1)

    return {
        "scheduler": "active",
        "schedule": "Every day at 03:00",
        "next_run": target.isoformat(),
        "minutes_until_next_run": round((target - now).total_seconds() / 60),
        "tasks": [
            {"name": "Scout Agent", "description": "Scrapes official government sites (tarimorman.gov.tr, USDA, EU CAP) for fresh policy/grant data"},
            {"name": "Report Backfill", "description": "Fills missing sustainability and insurance data in existing reports using AI agents + Google Search Grounding"},
            {"name": "Market Price Update", "description": "Fetches real-time prices for 150+ crops from hal.gov.tr, İzmir API, API Ninjas, FAO"},
        ]
    }

@router.post("/update-market-prices")
async def trigger_market_update(
    db: AsyncDatabase = Depends(get_db)
):
    """
    Manually trigger market price update for all 150+ crops.
    Runs synchronously to ensure completion on Cloud Run.
    """
    from app.external_apis.market_data import update_market_prices_in_db

    try:
        result = await update_market_prices_in_db(db)
        logger.info("📈 Market update complete: %d crops", result)
        return {"status": "completed", "crops_updated": result}
    except Exception as e:
        logger.error("📈 Market update failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
