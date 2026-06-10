"""
GBIF (Global Biodiversity Information Facility) client for pest occurrence data.

Free, open-access API with no authentication required.
Provides scientifically verified species occurrence records worldwide.

API Docs: https://www.gbif.org/developer/summary
Base URL: https://api.gbif.org/v1
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import httpx

logger = logging.getLogger(__name__)

GBIF_BASE = "https://api.gbif.org/v1"
_TIMEOUT = httpx.Timeout(connect=5.0, read=15.0, write=5.0, pool=5.0)


# ── Crop → Known pest species mapping ───────────────────────────────────
# Scientific names of common agricultural pests per crop
_CROP_PESTS: dict[str, list[dict]] = {
    "Tomato": [
        {"name": "Tuta absoluta", "tr": "Domates güvesi", "type": "Pest"},
        {"name": "Tetranychus urticae", "tr": "Kırmızı örümcek", "type": "Pest"},
        {"name": "Bemisia tabaci", "tr": "Tütün beyazsineği", "type": "Pest"},
        {"name": "Frankliniella occidentalis", "tr": "Trips", "type": "Pest"},
        {"name": "Phytophthora infestans", "tr": "Geç yanıklık", "type": "Disease"},
        {"name": "Fusarium oxysporum", "tr": "Fusaryum solgunluğu", "type": "Disease"},
        {"name": "Liriomyza trifolii", "tr": "Yaprak galeri sineği", "type": "Pest"},
        {"name": "Myzus persicae", "tr": "Yaprak biti", "type": "Pest"},
    ],
    "Wheat": [
        {"name": "Eurygaster integriceps", "tr": "Süne", "type": "Pest"},
        {"name": "Cephus pygmeus", "tr": "Buğday sap arısı", "type": "Pest"},
        {"name": "Puccinia recondita", "tr": "Buğday pası", "type": "Disease"},
        {"name": "Sitobion avenae", "tr": "Buğday yaprak biti", "type": "Pest"},
        {"name": "Fusarium graminearum", "tr": "Fusaryum başak yanıklığı", "type": "Disease"},
    ],
    "Cotton": [
        {"name": "Helicoverpa armigera", "tr": "Yeşilkurt", "type": "Pest"},
        {"name": "Bemisia tabaci", "tr": "Tütün beyazsineği", "type": "Pest"},
        {"name": "Tetranychus urticae", "tr": "Kırmızı örümcek", "type": "Pest"},
        {"name": "Spodoptera frugiperda", "tr": "Sonbahar tırtılı", "type": "Invasive"},
        {"name": "Frankliniella occidentalis", "tr": "Trips", "type": "Pest"},
    ],
    "Pepper": [
        {"name": "Myzus persicae", "tr": "Yaprak biti", "type": "Pest"},
        {"name": "Tetranychus urticae", "tr": "Kırmızı örümcek", "type": "Pest"},
        {"name": "Frankliniella occidentalis", "tr": "Trips", "type": "Pest"},
        {"name": "Bemisia tabaci", "tr": "Tütün beyazsineği", "type": "Pest"},
        {"name": "Phytophthora capsici", "tr": "Biber kök çürüklüğü", "type": "Disease"},
    ],
    "Grape": [
        {"name": "Plasmopara viticola", "tr": "Mildiyö", "type": "Disease"},
        {"name": "Lobesia botrana", "tr": "Salkım güvesi", "type": "Pest"},
        {"name": "Tetranychus urticae", "tr": "Kırmızı örümcek", "type": "Pest"},
        {"name": "Ceratitis capitata", "tr": "Akdeniz meyve sineği", "type": "Pest"},
        {"name": "Uncinula necator", "tr": "Külleme", "type": "Disease"},
    ],
    "Olive": [
        {"name": "Bactrocera oleae", "tr": "Zeytin sineği", "type": "Pest"},
        {"name": "Prays oleae", "tr": "Zeytin güvesi", "type": "Pest"},
        {"name": "Saissetia oleae", "tr": "Zeytin koşnili", "type": "Pest"},
    ],
    "Corn": [
        {"name": "Spodoptera frugiperda", "tr": "Sonbahar tırtılı", "type": "Invasive"},
        {"name": "Helicoverpa armigera", "tr": "Yeşilkurt", "type": "Pest"},
        {"name": "Ostrinia nubilalis", "tr": "Mısır koçan kurdu", "type": "Pest"},
    ],
    "Sunflower": [
        {"name": "Plasmopara viticola", "tr": "Mildiyö", "type": "Disease"},
        {"name": "Helicoverpa armigera", "tr": "Yeşilkurt", "type": "Pest"},
        {"name": "Sclerotinia sclerotiorum", "tr": "Beyaz çürüklük", "type": "Disease"},
    ],
    "Potato": [
        {"name": "Phytophthora infestans", "tr": "Mildiyö / Geç yanıklık", "type": "Disease"},
        {"name": "Leptinotarsa decemlineata", "tr": "Patates böceği", "type": "Pest"},
        {"name": "Myzus persicae", "tr": "Yaprak biti", "type": "Pest"},
    ],
    "Strawberry": [
        {"name": "Tetranychus urticae", "tr": "Kırmızı örümcek", "type": "Pest"},
        {"name": "Frankliniella occidentalis", "tr": "Trips", "type": "Pest"},
        {"name": "Botrytis cinerea", "tr": "Kurşuni küf", "type": "Disease"},
    ],
    "Cucumber": [
        {"name": "Bemisia tabaci", "tr": "Tütün beyazsineği", "type": "Pest"},
        {"name": "Tetranychus urticae", "tr": "Kırmızı örümcek", "type": "Pest"},
        {"name": "Frankliniella occidentalis", "tr": "Trips", "type": "Pest"},
        {"name": "Pseudoperonospora cubensis", "tr": "Hıyar mildiyösü", "type": "Disease"},
    ],
}

# Default pests to check when no crop info is available
_DEFAULT_PESTS = [
    {"name": "Tetranychus urticae", "tr": "Kırmızı örümcek", "type": "Pest"},
    {"name": "Frankliniella occidentalis", "tr": "Trips", "type": "Pest"},
    {"name": "Myzus persicae", "tr": "Yaprak biti", "type": "Pest"},
    {"name": "Bemisia tabaci", "tr": "Tütün beyazsineği", "type": "Pest"},
    {"name": "Tuta absoluta", "tr": "Domates güvesi", "type": "Pest"},
    {"name": "Helicoverpa armigera", "tr": "Yeşilkurt", "type": "Pest"},
    {"name": "Fusarium oxysporum", "tr": "Fusaryum solgunluğu", "type": "Disease"},
    {"name": "Phytophthora infestans", "tr": "Geç yanıklık", "type": "Disease"},
]


async def get_species_key(client: httpx.AsyncClient, scientific_name: str) -> int | None:
    """Get GBIF taxon key for a species by scientific name."""
    try:
        r = await client.get(f"{GBIF_BASE}/species/match", params={"name": scientific_name})
        if r.status_code == 200:
            data = r.json()
            if data.get("matchType") != "NONE":
                return data.get("usageKey")
    except Exception:
        logger.debug("GBIF species match failed for %s", scientific_name)
    return None


async def get_occurrence_count(client: httpx.AsyncClient, taxon_key: int, country_code: str) -> int:
    """Get number of occurrence records for a species in a country."""
    try:
        r = await client.get(f"{GBIF_BASE}/occurrence/search", params={
            "taxonKey": taxon_key,
            "country": country_code,
            "limit": 0,
        })
        if r.status_code == 200:
            return r.json().get("count", 0)
    except Exception:
        pass
    return 0


def _severity_from_count(count: int, threat_type: str) -> str:
    """Estimate severity based on occurrence records and threat type."""
    if threat_type == "Invasive":
        return "High" if count > 0 else "Medium"
    if count >= 100:
        return "High"
    if count >= 10:
        return "Medium"
    if count > 0:
        return "Low"
    return "Low"


def _spread_risk(threat_type: str) -> float:
    return {"Pest": 0.65, "Disease": 0.45, "Invasive": 0.80}.get(threat_type, 0.5)


async def discover_pests_for_region(
    country_code: str,
    crops: list[str] | None = None,
    region: str = "",
) -> list[dict]:
    """
    Discover pests/diseases relevant to given crops in a country using GBIF.

    1. Build pest candidate list from crop → pest mapping
    2. Verify each pest's presence via GBIF occurrence records
    3. Return verified threats sorted by occurrence count

    Parameters
    ----------
    country_code : str
        ISO 3166-1 alpha-2 country code (e.g., "TR", "ES", "BR")
    crops : list[str] | None
        Crops the farmer grows. If None, uses default pest list.
    region : str
        Region name for context.
    """
    # Build candidate pest list from crops
    candidates: list[dict] = []
    seen_names: set[str] = set()

    if crops:
        for crop in crops:
            pests = _CROP_PESTS.get(crop, [])
            for pest in pests:
                if pest["name"] not in seen_names:
                    candidates.append(pest)
                    seen_names.add(pest["name"])

    # Add defaults if we don't have enough
    if len(candidates) < 5:
        for pest in _DEFAULT_PESTS:
            if pest["name"] not in seen_names:
                candidates.append(pest)
                seen_names.add(pest["name"])

    # Verify via GBIF
    threats: list[dict] = []
    async with httpx.AsyncClient(timeout=_TIMEOUT, headers={"User-Agent": "AgriAgent/1.0"}) as client:
        for pest in candidates:
            taxon_key = await get_species_key(client, pest["name"])
            if taxon_key is None:
                continue

            count = await get_occurrence_count(client, taxon_key, country_code)

            severity = _severity_from_count(count, pest["type"])

            threat = {
                "threat_name": f"{pest['tr'].split('(')[0].strip()} ({pest['name']})",
                "threat_name_tr": f"{pest['tr']} ({pest['name']})",
                "threat_type": pest["type"],
                "affected_crops": [c for c, pests in _CROP_PESTS.items() if any(p["name"] == pest["name"] for p in pests)],
                "severity": severity,
                "source_location": region or country_code,
                "reported_date": datetime.now(timezone.utc),
                "spread_risk_to_neighbors": _spread_risk(pest["type"]),
                "description": f"Verified by GBIF: {count} occurrence records in {country_code}.",
                "description_tr": f"Verified in GBIF database: {count} observation records in {country_code}.",
                "gbif_taxon_key": taxon_key,
                "gbif_occurrence_count": count,
            }
            threats.append(threat)

    # Sort by occurrence count (most prevalent first)
    threats.sort(key=lambda t: t.get("gbif_occurrence_count", 0), reverse=True)

    logger.info("🌍 GBIF: Discovered %d verified pests for %s (%s)", len(threats), region, country_code)
    return threats
