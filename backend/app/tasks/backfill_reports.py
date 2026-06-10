"""
Backfill task: Fills missing sustainability_analysis and insurance_recommendations
fields in existing strategy reports by calling the sustainability and insurance agents.

This runs:
- On application startup (for any reports that have empty fields)
- Via the /internal/agents/backfill-reports endpoint (manual trigger)
"""

import logging
from pymongo.asynchronous.database import AsyncDatabase

logger = logging.getLogger(__name__)


async def backfill_empty_report_fields(db: AsyncDatabase) -> dict:
    """
    Finds all strategy reports with empty sustainability or insurance fields
    and fills them using the sustainability + insurance agents with real data.

    Returns a summary of what was updated.
    """
    from app.agents.sustainability_agent import analyze_sustainability
    from app.agents.policy_agent import get_insurance_recommendations
    from app.services import farmer_service, climate_service
    from app.config import get_settings
    import os

    # Ensure GCP Vertex AI credentials are available for the agents
    settings = get_settings()
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
    os.environ["GOOGLE_CLOUD_PROJECT"] = settings.gcp_project_id
    os.environ["GOOGLE_CLOUD_LOCATION"] = settings.gcp_location

    logger.info("🔄 Backfill task starting — scanning reports for empty fields...")

    # Find reports with empty/null sustainability or insurance
    query = {
        "$or": [
            {"sustainability_analysis": {"$in": [None, ""]}},
            {"insurance_recommendations": {"$in": [None, ""]}},
            {"sustainability_analysis": {"$regex": "^Sustainability analysis was not available"}},
            {"insurance_recommendations": {"$regex": "^Insurance recommendations were not available"}},
        ]
    }

    reports = []
    async for doc in db.strategy_reports.find(query):
        reports.append(doc)

    if not reports:
        logger.info("✅ Backfill: All reports already have sustainability & insurance data.")
        return {"status": "nothing_to_do", "updated": 0}

    logger.info(f"🔄 Found {len(reports)} reports needing backfill.")

    updated_count = 0

    for report_doc in reports:
        user_id = report_doc.get("user_id", "unknown")
        report_id = report_doc.get("_id")

        try:
            # Fetch farmer profile for context
            farmer = await farmer_service.get_farmer_profile(db, user_id)
            farmer_data = farmer.model_dump()

            updates = {}

            # ── Sustainability ──
            needs_sustainability = not report_doc.get("sustainability_analysis") or \
                report_doc.get("sustainability_analysis", "").startswith("Sustainability analysis was not available")

            if needs_sustainability:
                climate = None
                try:
                    climate = await climate_service.get_climate_trend(db, farmer.location)
                except Exception:
                    pass

                sustainability_output = await analyze_sustainability(
                    farmer_data=farmer_data,
                    climate_trend=climate.model_dump() if climate else None
                )

                eco_plan = "\n".join(f"• {a}" for a in sustainability_output.eco_action_plan)
                updates["sustainability_analysis"] = (
                    f"Toprak Sağlığı Skoru: {sustainability_output.soil_health_score}/100\n"
                    f"Karbon Azaltma Potansiyeli: %{sustainability_output.carbon_reduction_potential_pct}\n\n"
                    f"{eco_plan}\n\n"
                    f"{sustainability_output.rotation_science_notes}"
                )
                logger.info(f"🌿 Backfill: Generated sustainability for report {report_id}")

            # ── Insurance ──
            needs_insurance = not report_doc.get("insurance_recommendations") or \
                report_doc.get("insurance_recommendations", "").startswith("Insurance recommendations were not available")

            if needs_insurance:
                crops = [h.get("crop", "") for h in report_doc.get("recommendations", []) if h.get("crop")]
                if not crops:
                    crops = [h.crop for h in farmer.crop_history] if farmer.crop_history else ["Wheat"]

                has_greenhouse = any(
                    "sera" in (p.name or "").lower() or "greenhouse" in (p.name or "").lower()
                    for p in farmer.plots
                )
                has_frost_risk = any((p.elevation_m or 0) > 1000 for p in farmer.plots)

                insurance_data = await get_insurance_recommendations(
                    region=farmer.region,
                    crops=crops,
                    has_greenhouse=has_greenhouse,
                    has_frost_risk=has_frost_risk
                )
                updates["insurance_recommendations"] = insurance_data
                logger.info(f"🛡️ Backfill: Generated insurance for report {report_id}")

            # ── Update MongoDB ──
            if updates:
                await db.strategy_reports.update_one(
                    {"_id": report_id},
                    {"$set": updates}
                )
                updated_count += 1
                logger.info(f"✅ Backfill: Updated report {report_id} for user {user_id}")

        except Exception as e:
            logger.error(f"❌ Backfill failed for report {report_id}: {e}", exc_info=True)
            continue

    logger.info(f"🔄 Backfill complete. Updated {updated_count}/{len(reports)} reports.")
    return {"status": "completed", "scanned": len(reports), "updated": updated_count}
