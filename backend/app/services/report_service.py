"""
Report service — persist and retrieve AI-generated strategy reports.

Handles the write path (save) and the read path (list by user)
for the ``strategy_reports`` collection.
"""

from __future__ import annotations

from datetime import datetime

from pymongo.asynchronous.database import AsyncDatabase

from app.models.report import StrategyReport


async def save_strategy_report(
    db: AsyncDatabase, report: StrategyReport
) -> dict:
    """
    Persist a strategy report and return its new ``_id``.

    Parameters
    ----------
    db:
        Async database handle.
    report:
        Fully populated ``StrategyReport`` from the orchestrator.

    Returns
    -------
    dict
        ``{"id": "<inserted_id>", "message": "..."}``
    """
    doc = report.model_dump()
    doc["created_at"] = doc.get("created_at") or datetime.utcnow()

    result = await db.strategy_reports.insert_one(doc)

    return {
        "id": str(result.inserted_id),
        "message": "Strategy report saved successfully",
        "user_id": report.user_id,
        "season": report.season,
    }


async def get_reports_by_user(
    db: AsyncDatabase, user_id: str
) -> list[StrategyReport]:
    """
    Retrieve all strategy reports for a user, newest first.

    Parameters
    ----------
    db:
        Async database handle.
    user_id:
        Farmer identifier, e.g. ``"farmer_001"``.

    Returns
    -------
    list[StrategyReport]
        Chronologically descending list (may be empty).
    """
    cursor = db.strategy_reports.find({"user_id": user_id}).sort("created_at", -1)
    reports: list[StrategyReport] = []

    async for doc in cursor:
        reports.append(StrategyReport(**doc))

    return reports
