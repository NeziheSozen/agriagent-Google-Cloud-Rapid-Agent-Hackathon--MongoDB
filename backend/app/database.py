"""
Database connectivity and lifecycle management.

Uses **PyMongo 4.13+ AsyncMongoClient** (motor is deprecated as of 2026).
The ``lifespan`` context manager handles connection setup / teardown,
and ``get_db`` provides a FastAPI dependency for per-request DB access.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI, Request
from pymongo import AsyncMongoClient
from pymongo.asynchronous.database import AsyncDatabase

from app.config import get_settings

# Module-level reference populated during lifespan
_client: AsyncMongoClient | None = None


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """
    FastAPI lifespan: open the Mongo connection on startup, close on shutdown.

    Also creates required indexes so queries stay fast at scale.
    """
    global _client
    settings = get_settings()

    # ── Startup ──────────────────────────────────────────────────────────
    _client = AsyncMongoClient(settings.mongodb_url)
    db = _client[settings.database_name]

    # Verify the connection is alive
    await db.command("ping")

    await create_indexes(db)
    print("🌾 AgriAgent DB connected & indexes ready")
    
    # Start the Change Stream Watcher in the background
    import asyncio
    watcher_task = asyncio.create_task(watch_policies(db))

    # One-time backfill on startup for any reports with missing data
    from app.tasks.backfill_reports import backfill_empty_report_fields
    backfill_task = asyncio.create_task(backfill_empty_report_fields(db))

    # Start the nightly scheduler (03:00 every day)
    scheduler_task = asyncio.create_task(_nightly_scheduler(db))

    yield  # ← app runs here

    # ── Shutdown ─────────────────────────────────────────────────────────
    watcher_task.cancel()
    backfill_task.cancel()
    scheduler_task.cancel()

    try:
        await _client.close()
    except TypeError:
        _client.close()
    _client = None
    print("🔌 AgriAgent DB connection closed")


async def _nightly_scheduler(db: AsyncDatabase) -> None:
    """
    Runs every night at 03:00 local time:
    1. Scout Agent  → scrapes official gov sites for fresh policy/grant data
    2. Backfill     → fills empty sustainability/insurance fields in old reports
    3. Market Data  → updates global and regional market prices
    """
    import asyncio
    from datetime import datetime, timedelta
    import logging

    logger = logging.getLogger(__name__)
    SCHEDULE_HOUR = 3  # 03:00 local time

    while True:
        try:
            # Calculate seconds until next 03:00
            now = datetime.now()
            target = now.replace(hour=SCHEDULE_HOUR, minute=0, second=0, microsecond=0)
            if target <= now:
                target += timedelta(days=1)

            wait_seconds = (target - now).total_seconds()
            print(
                f"⏰ Nightly scheduler: next run at {target.strftime('%Y-%m-%d %H:%M')} "
                f"(in {wait_seconds / 60:.0f} minutes)"
            )
            await asyncio.sleep(wait_seconds)

            # ── 1. Scout Agent: fetch fresh policies from gov sites ──
            logger.info("🕵️ Nightly job [1/2]: Running Scout Agent...")
            try:
                from app.agents.scout_agent import run_nightly_scout
                scout_result = await run_nightly_scout(db)
                logger.info("🕵️ Scout Agent done: %s", scout_result)
            except Exception as e:
                logger.error("🕵️ Scout Agent failed: %s", e, exc_info=True)

            # ── 2. Backfill: fill missing sustainability/insurance ──
            logger.info("🔄 Nightly job [2/2]: Running Report Backfill...")
            try:
                from app.tasks.backfill_reports import backfill_empty_report_fields
                backfill_result = await backfill_empty_report_fields(db)
                logger.info("🔄 Backfill done: %s", backfill_result)
            except Exception as e:
                logger.error("🔄 Backfill failed: %s", e, exc_info=True)

            # ── 3. Market Prices: update MongoDB cache ──
            logger.info("📈 Nightly job [3/3]: Running Market Price Update...")
            try:
                from app.external_apis.market_data import update_market_prices_in_db
                market_result = await update_market_prices_in_db(db)
                logger.info("📈 Market Prices updated: %s crops", market_result)
            except Exception as e:
                logger.error("📈 Market Price Update failed: %s", e, exc_info=True)

            logger.info("✅ Nightly scheduler cycle complete.")

        except asyncio.CancelledError:
            logger.info("⏰ Nightly scheduler cancelled.")
            break
        except Exception as e:
            logger.error("⏰ Nightly scheduler error: %s", e, exc_info=True)
            # Wait 1 hour before retrying on unexpected errors
            await asyncio.sleep(3600)


async def get_db(request: Request) -> AsyncDatabase:
    """
    FastAPI dependency — returns the database handle for the current request.

    Usage::

        @router.get("/example")
        async def example(db = Depends(get_db)):
            ...
    """
    settings = get_settings()
    if _client is None:
        raise RuntimeError("Database client is not initialised — is lifespan configured?")
    return _client[settings.database_name]


async def get_async_db() -> AsyncDatabase:
    """
    Get database handle outside of FastAPI request context.

    Used by background scheduler jobs and other non-request code.
    """
    settings = get_settings()
    if _client is None:
        raise RuntimeError("Database client is not initialised — is lifespan configured?")
    return _client[settings.database_name]


async def create_indexes(db: AsyncDatabase) -> None:
    """
    Create MongoDB indexes for optimal query performance.

    Called once during application startup inside the lifespan handler.
    """
    # Farmers — look up by user_id (unique) and region
    await db.farmers.create_index("user_id", unique=True)
    await db.farmers.create_index("region")
    await db.farmers.create_index([("location_geo", "2dsphere")])

    # Climate trends — one document per location
    await db.climate_trends.create_index("location", unique=True)
    await db.climate_trends.create_index("region")

    # Regional threats — query by region + recency
    await db.regional_threats.create_index("region")
    await db.regional_threats.create_index("active_threats.reported_date")

    # Market data — look up by crop name
    await db.market_data.create_index("crop", unique=True)

    # Strategy reports — per-user, sorted by creation time
    await db.strategy_reports.create_index([("user_id", 1), ("created_at", -1)])

    # Field polygons — satellite monitoring
    await db.field_polygons.create_index("user_id")
    await db.field_polygons.create_index("agro_polygon_id", sparse=True)

    # Cooperatives — look up by coop_id (unique), join_code (unique), and region
    await db.cooperatives.create_index("coop_id", unique=True)
    await db.cooperatives.create_index("join_code", unique=True)
    await db.cooperatives.create_index("region")
    await db.cooperatives.create_index([("location_geo", "2dsphere")])

    # Fleet bookings — one booking per machine per date
    await db.fleet_bookings.create_index([("machine_id", 1), ("date", 1)], unique=True)
    
    # Initialize Time Series Collection for sensor data
    try:
        await db.create_collection("sensor_data", timeseries={"timeField": "timestamp", "metaField": "plot_id"})
        import logging
        logging.getLogger(__name__).info("Created Time Series collection: sensor_data")
    except Exception as e:
        # Collection might already exist
        if "already exists" not in str(e).lower():
            pass

async def watch_policies(db: AsyncDatabase):
    """
    MongoDB Change Stream listener.
    Autonomously detects new policies and triggers push notifications to relevant farmers.
    """
    import asyncio
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        logger.info("👀 Change Stream Watcher started on 'policies' collection.")
        # Watch only for insert operations
        pipeline = [{"$match": {"operationType": "insert"}}]
        
        async with await db.policies.watch(pipeline) as stream:
            async for change in stream:
                doc = change["fullDocument"]
                title = doc.get("title", "New Incentive")
                
                # Fetch all farmers to notify them. In a real app, match by region/crop.
                # For hackathon demo, we notify everyone or log generically.
                farmers_cursor = db.farmers.find({})
                async for farmer in farmers_cursor:
                    logger.info(
                        f"\n======================================================\n"
                        f"🔔 AUTONOMOUS PUSH NOTIFICATION (CHANGE STREAM)\n"
                        f"To: {farmer.get('name')} (Region: {farmer.get('region')})\n"
                        f"Message: A new support package has been published for your land!\n"
                        f"Title: {title}\n"
                        f"Please open the app and ask the 'Agriculture Assistant' for details.\n"
                        f"======================================================\n"
                    )
    except asyncio.CancelledError:
        logger.info("Change Stream Watcher cancelled.")
    except Exception as e:
        logger.error(f"Change Stream Watcher failed: {e}")
