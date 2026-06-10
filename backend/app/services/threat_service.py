"""
Threat service — real-time pest/disease monitoring via EPPO + MongoDB.

Architecture:
  1. Try EPPO API for real distribution and alert data
  2. Cache results in MongoDB
  3. Fall back to MongoDB seed data if EPPO is unavailable
  4. Compute overall risk level and generate advisory
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from pymongo.asynchronous.database import AsyncDatabase

from app.external_apis import eppo_client
from app.models.threat import RegionalThreats, ThreatAlert

logger = logging.getLogger(__name__)

# Severity ordinal for computing the aggregate risk level
_SEVERITY_ORDER = {"Low": 0, "Medium": 1, "High": 2, "Critical": 3}
_SEVERITY_LABELS = ["Low", "Medium", "High", "Critical"]


def _compute_overall_risk(threats: list[ThreatAlert]) -> str:
    """
    Derive the region-wide risk level from individual threat severities.

    Rules:
    - Any **Critical** threat → region is Critical
    - ≥ 2 High threats → Critical
    - Any High → High
    - ≥ 2 Medium → High
    - Any Medium → Medium
    - Otherwise → Low
    """
    if not threats:
        return "Low"

    severity_counts = {"Low": 0, "Medium": 0, "High": 0, "Critical": 0}
    for t in threats:
        severity_counts[t.severity] += 1

    if severity_counts["Critical"] > 0:
        return "Critical"
    if severity_counts["High"] >= 2:
        return "Critical"
    if severity_counts["High"] > 0:
        return "High"
    if severity_counts["Medium"] >= 2:
        return "High"
    if severity_counts["Medium"] > 0:
        return "Medium"
    return "Low"


def _build_advisory(region: str, risk: str, threats: list[ThreatAlert]) -> str:
    """Generate a human-readable advisory string for the region."""
    if risk == "Critical":
        return (
            f"⚠️ CRITICAL: Serious agricultural threats exist in the {region} region. "
            f"{len(threats)} active alerts. Immediate protective measures are recommended. "
            "Contact your local agricultural directorate."
        )
    if risk == "High":
        return (
            f"🔴 HIGH RISK: {len(threats)} active threats found in the {region} region. "
            "Monitor fields closely and prepare preventive measures."
        )
    if risk == "Medium":
        return (
            f"🟡 MEDIUM RISK: {len(threats)} threats reported in the {region} region. "
            "Routine observation is recommended — early intervention prevents spreading."
        )
    return (
        f"🟢 LOW RISK: The {region} region is currently stable. {len(threats)} "
        "minor alerts present. Continue standard crop protection practices."
    )


async def get_regional_threats(db: AsyncDatabase, region: str) -> RegionalThreats:
    """
    Fetch active threats for a region — uses Gemini-powered dynamic discovery,
    falls back to hardcoded knowledge base, then MongoDB cache.
    """
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=30)

    # ── Step 1: Try dynamic pest discovery (Gemini + fallback) ────────
    try:
        # Optionally get farmer's crops for more targeted results
        crops = None
        try:
            farmer_doc = await db.farmers.find_one({"region": {"$regex": f".*{region}.*", "$options": "i"}})
            if farmer_doc:
                crops = farmer_doc.get("crops", [])
        except Exception:
            pass
        
        discovered_threats = await eppo_client.search_pests_for_region(region, crops=crops)

        if discovered_threats:
            active = []
            from app.external_apis.eppo_client import _KNOWN_PESTS
            import re
            
            def extract_sci(name: str) -> str:
                m = re.search(r'\((.*?)\)', name)
                return m.group(1).lower().strip() if m else name.lower().strip()

            for t in discovered_threats:
                # Match with known pests for image_url and richer descriptions
                for known in _KNOWN_PESTS:
                    known_sci = extract_sci(known.get("threat_name", ""))
                    threat_sci = extract_sci(t.get("threat_name", ""))
                    
                    if known_sci and threat_sci and (known_sci in threat_sci or threat_sci in known_sci):
                        if not t.get("image_url"):
                            t["image_url"] = known.get("image_url")
                        # Use richer description from knowledge base if GBIF one is generic
                        if "GBIF" in t.get("description", ""):
                            t["description"] = known["description"]
                            t["description_tr"] = known["description_tr"]
                            
                        # GBIF often only provides the scientific name, so we use our rich name
                        t["threat_name"] = known.get("threat_name", t["threat_name"])
                        t["threat_name_tr"] = known.get("threat_name_tr", t.get("threat_name_tr"))
                        break

                try:
                    # Handle both datetime objects and ISO strings for reported_date
                    if isinstance(t.get("reported_date"), str):
                        from dateutil.parser import parse as parse_dt
                        t["reported_date"] = parse_dt(t["reported_date"])
                    elif t.get("reported_date") is None:
                        t["reported_date"] = now
                    active.append(ThreatAlert(**t))
                except Exception as e:
                    logger.warning("Skipping malformed threat: %s", e)
                    continue

            # Preserve manually scanned threats (AI Scans)
            existing_doc = await db.regional_threats.find_one({"region": {"$regex": f"^{region}$", "$options": "i"}})
            if existing_doc and "active_threats" in existing_doc:
                for st in existing_doc["active_threats"]:
                    if st.get("source_location") and "(AI Scan)" in st.get("source_location"):
                        try:
                            if isinstance(st.get("reported_date"), str):
                                from dateutil.parser import parse as parse_dt
                                st["reported_date"] = parse_dt(st["reported_date"])
                            # Add back the manually scanned threat so it isn't erased
                            active.append(ThreatAlert(**st))
                        except Exception:
                            pass

            # Cache to MongoDB
            await _cache_threats(db, region, active)

            overall = _compute_overall_risk(active)
            advisory = _build_advisory(region, overall, active)

            logger.info("✅ Returned %d threats for %s", len(active), region)
            return RegionalThreats(
                region=region,
                query_date=now,
                active_threats=active,
                overall_risk_level=overall,
                advisory=advisory,
            )
    except Exception:
        logger.warning(
            "Dynamic threat fetch failed for '%s', falling back to cache",
            region,
            exc_info=True,
        )

    # ── Step 2: Fallback to MongoDB cached/seed data ─────────────────
    logger.info("Falling back to MongoDB for threats in '%s'", region)

    doc = await db.regional_threats.find_one(
        {"region": {"$regex": f"^{region}$", "$options": "i"}}
    )

    # 2b) Ultimate fallback: just return any document to prevent UI crash
    if doc is None:
        doc = await db.regional_threats.find_one()

    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No threat data found for region='{region}'",
        )

    # Filter embedded alerts to recent ones
    raw_threats = doc.get("active_threats", [])
    active = []
    
    from app.external_apis.eppo_client import _KNOWN_PESTS
    
    for t in raw_threats:
        alert = ThreatAlert(**t)
        if alert.reported_date >= cutoff:
            # Re-enrich image_url if missing from cache
            if not alert.image_url:
                for pest in _KNOWN_PESTS:
                    if pest["threat_name"] == alert.threat_name:
                        alert.image_url = pest.get("image_url")
                        break
            active.append(alert)

    overall = _compute_overall_risk(active)
    advisory = _build_advisory(region, overall, active)

    logger.info("📦 Returned %d cached threats for %s", len(active), region)
    return RegionalThreats(
        region=doc["region"],
        query_date=now,
        active_threats=active,
        overall_risk_level=overall,
        advisory=advisory,
    )


async def _cache_threats(
    db: AsyncDatabase,
    region: str,
    threats: list[ThreatAlert],
) -> None:
    """Cache EPPO threat data to MongoDB for fallback."""
    try:
        threat_dicts = [t.model_dump() for t in threats]
        # Convert datetime objects to ISO strings for MongoDB
        for td in threat_dicts:
            if isinstance(td.get("reported_date"), datetime):
                td["reported_date"] = td["reported_date"].isoformat()

        await db.regional_threats.update_one(
            {"region": {"$regex": f"^{region}$", "$options": "i"}},
            {
                "$set": {
                    "region": region,
                    "active_threats": threat_dicts,
                    "cached_at": datetime.now(timezone.utc).isoformat(),
                }
            },
            upsert=True,
        )
        logger.info("Cached %d threats for %s in MongoDB", len(threats), region)
    except Exception:
        logger.warning("Failed to cache threats for %s", region, exc_info=True)
