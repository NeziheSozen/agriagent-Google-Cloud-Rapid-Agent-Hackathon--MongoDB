"""
Reports router — save and retrieve AI-generated strategy reports.

Exposes:
- ``POST /save-strategy-report`` — persist a new report
- ``GET  /reports/{user_id}``    — list reports for a farmer
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from pymongo.asynchronous.database import AsyncDatabase

from app.database import get_db
from app.models.report import StrategyReport
from app.services.report_service import get_reports_by_user, save_strategy_report

router = APIRouter(tags=["Reports"])


@router.post(
    "/save-strategy-report",
    summary="Save a strategy report",
    description="Persist an AI-generated strategy report for a farmer. "
    "Returns the inserted document ID.",
    status_code=201,
)
async def create_report(
    report: StrategyReport,
    db: AsyncDatabase = Depends(get_db),
) -> dict:
    """Save a new strategy report and return its ID."""
    return await save_strategy_report(db, report)


@router.get(
    "/reports/{user_id}",
    response_model=list[StrategyReport],
    summary="List reports for a farmer",
    description="Retrieve all saved strategy reports for a farmer, "
    "ordered newest first.",
)
async def list_reports(
    user_id: str,
    db: AsyncDatabase = Depends(get_db),
) -> list[StrategyReport]:
    """Return all strategy reports for the given ``user_id``."""
    return await get_reports_by_user(db, user_id)
