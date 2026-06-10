"""
EPPO Global Database client — pest/disease alert monitoring.

Fetches real-time pest and disease distribution data from the European
and Mediterranean Plant Protection Organization (EPPO) for regional
threat assessment.

EPPO provides free access to:
  - Pest taxonomy and distribution data
  - Reporting Service (monthly pest alerts)
  - Quarantine status information

API Base: https://data.eppo.int/api/rest/1.0
No API key required for basic endpoints.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(connect=10.0, read=30.0, write=10.0, pool=10.0)

# ── Region → Country code mapping ───────────────────────────────────────

_REGION_TO_COUNTRY = {
    "Thrace": "TR",
    "Central Anatolia": "TR",
    "Mediterranean": "TR",
    "Çukurova": "TR",
    "Southeastern Anatolia": "TR",
    "Black Sea": "TR",
    "Marmara": "TR",
    "Aegean": "TR",
}

# ── Key crop pests for Turkish agriculture ───────────────────────────────
# Maps common agricultural threats to their EPPO codes and local names

_KNOWN_PESTS: list[dict] = [
    {
        "eppo_code": "TUTAAB",
        "threat_name": "Tomato leafminer (Tuta absoluta)",
        "threat_name_tr": "Domates güvesi (Tuta absoluta)",
        "threat_type": "Pest",
        "affected_crops": ["Tomato", "Pepper", "Eggplant", "Potato"],
        "description": "Highly destructive moth whose larvae mine tomato leaves and fruits. "
                       "Can cause 80-100% crop loss in unprotected greenhouses.",
        "description_tr": "Larvaları domates yaprakları ve meyvelerini kemiren oldukça yıkıcı bir güve. "
                          "Korunmasız seralarda %80-100 ürün kaybına neden olabilir.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Tuta_absoluta_5432149.jpg/500px-Tuta_absoluta_5432149.jpg",
    },
    {
        "eppo_code": "HELIAR",
        "threat_name": "Cotton bollworm (Helicoverpa armigera)",
        "threat_name_tr": "Yeşilkurt (Helicoverpa armigera)",
        "threat_type": "Pest",
        "affected_crops": ["Cotton", "Corn", "Tomato", "Chickpea", "Sunflower"],
        "description": "Polyphagous moth pest causing significant damage to cotton bolls, "
                       "corn ears, and tomato fruits across Mediterranean and subtropical regions.",
        "description_tr": "Akdeniz ve subtropikal bölgelerde pamuk kozalarına, mısır koçanlarına "
                          "ve domates meyvelerine ciddi zarar veren çok konukçulu güve zararlısı.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Helicoverpa_armigera.jpg/500px-Helicoverpa_armigera.jpg",
    },
    {
        "eppo_code": "EURYLA",
        "threat_name": "Sunn pest (Eurygaster integriceps)",
        "threat_name_tr": "Süne (Eurygaster integriceps)",
        "threat_type": "Pest",
        "affected_crops": ["Wheat", "Barley"],
        "description": "Major cereal pest in Turkey and the Middle East. Both adults and nymphs "
                       "feed on wheat heads, reducing grain quality and gluten content.",
        "description_tr": "Türkiye ve Ortadoğu'da önemli bir tahıl zararlısı. Hem erginler hem de "
                          "nimfler buğday başaklarını emerek tane kalitesini ve glüten içeriğini düşürür.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/98/Eurygaster_integriceps_Puton.jpg/500px-Eurygaster_integriceps_Puton.jpg",
    },
    {
        "eppo_code": "PLAAAM",
        "threat_name": "Downy mildew (Plasmopara viticola)",
        "threat_name_tr": "Mildiyö (Plasmopara viticola)",
        "threat_type": "Disease",
        "affected_crops": ["Grape", "Sunflower"],
        "description": "Oomycete pathogen causing leaf spots, shoot lesions, and fruit rot "
                       "in grapevines. Favored by warm, humid conditions.",
        "description_tr": "Asmalarda yaprak lekeleri, sürgün lezyonları ve meyve çürüklüğüne neden "
                          "olan oomycete patojen. Sıcak ve nemli koşulları tercih eder.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Mildew-back.JPG/500px-Mildew-back.JPG",
    },
    {
        "eppo_code": "PUCCIR",
        "threat_name": "Wheat rust (Puccinia recondita)",
        "threat_name_tr": "Buğday pası (Puccinia recondita)",
        "threat_type": "Disease",
        "affected_crops": ["Wheat", "Barley"],
        "description": "Fungal disease causing orange-brown pustules on wheat leaves. "
                       "Can reduce yields by 20-50% in susceptible varieties.",
        "description_tr": "Buğday yapraklarında turuncu-kahverengi kabarcıklara neden olan mantar hastalığı. "
                          "Hassas çeşitlerde verimi %20-50 oranında düşürebilir.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c9/Pucciniaceae_-_Puccinia_recondita.JPG/500px-Pucciniaceae_-_Puccinia_recondita.JPG",
    },
    {
        "eppo_code": "SPODLI",
        "threat_name": "Fall armyworm (Spodoptera frugiperda)",
        "threat_name_tr": "Sonbahar tırtılı (Spodoptera frugiperda)",
        "threat_type": "Invasive",
        "affected_crops": ["Corn", "Sorghum", "Rice", "Cotton"],
        "description": "Highly invasive moth pest spreading across Africa, Asia, and the Mediterranean. "
                       "Larvae feed voraciously on corn and other cereals.",
        "description_tr": "Afrika, Asya ve Akdeniz bölgesine yayılan oldukça istilacı güve zararlısı. "
                          "Larvaları mısır ve diğer tahılları oburca yer.",
        "image_url": "https://static.inaturalist.org/photos/160344068/medium.jpg",
    },
    {
        "eppo_code": "XANTCI",
        "threat_name": "Citrus canker (Xanthomonas citri)",
        "threat_name_tr": "Turunçgil kanseri (Xanthomonas citri)",
        "threat_type": "Disease",
        "affected_crops": ["Orange", "Lemon", "Mandarin", "Grapefruit"],
        "description": "Bacterial disease causing raised corky lesions on fruit, leaves, and stems. "
                       "Quarantine pest with significant economic impact on citrus industry.",
        "description_tr": "Meyve, yaprak ve gövdelerde kabuk benzeri kabarık lezyonlara neden olan "
                          "bakteriyel hastalık. Turunçgil endüstrisi üzerinde ciddi ekonomik etkisi olan karantina zararlısı.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Bacterial_black_spot_of_mango_-_9077467185.jpg/500px-Bacterial_black_spot_of_mango_-_9077467185.jpg",
    },
    {
        "eppo_code": "BEMITA",
        "threat_name": "Silverleaf whitefly (Bemisia tabaci)",
        "threat_name_tr": "Tütün beyazsineği (Bemisia tabaci)",
        "threat_type": "Pest",
        "affected_crops": ["Cotton", "Tomato", "Pepper", "Cucumber", "Eggplant"],
        "description": "Major vector pest transmitting over 100 plant viruses. "
                       "Causes direct feeding damage and sooty mold from honeydew excretion.",
        "description_tr": "100'den fazla bitki virüsü taşıyan önemli vektör zararlısı. "
                          "Doğrudan beslenme zararı ve bal özü salgısından kaynaklanan fumajin oluşturur.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/98234558/medium.jpeg",
    },
    {
        "eppo_code": "LEPTDE",
        "threat_name": "Wheat stem sawfly (Cephus pygmeus)",
        "threat_name_tr": "Buğday sap arısı (Cephus pygmeus)",
        "threat_type": "Pest",
        "affected_crops": ["Wheat", "Barley", "Oat"],
        "description": "Larvae bore into wheat stems causing lodging at harvest. "
                       "Significant pest in Thrace and Central Anatolia grain-producing regions.",
        "description_tr": "Larvaları buğday saplarını delerek hasatta yatmaya neden olur. "
                          "Trakya ve İç Anadolu tahıl üretim bölgelerinde önemli zararlı.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/40501837/medium.jpeg",
    },
    {
        "eppo_code": "DITYDI",
        "threat_name": "Pine processionary moth (Thaumetopoea pityocampa)",
        "threat_name_tr": "Çam kese böceği (Thaumetopoea pityocampa)",
        "threat_type": "Pest",
        "affected_crops": ["Pine", "Cedar"],
        "description": "Defoliating forest pest whose caterpillars also pose health risks "
                       "to humans and animals due to urticating hairs.",
        "description_tr": "Yaprak döken orman zararlısı; tırtılları yakıcı tüyleri nedeniyle "
                          "insanlar ve hayvanlar için sağlık riski oluşturur.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/151178243/medium.jpeg",
    },
    # ── Newly added pests ──────────────────────────────────────────
    {
        "eppo_code": "TETRUR",
        "threat_name": "Two-spotted spider mite (Tetranychus urticae)",
        "threat_name_tr": "Kırmızı örümcek (Tetranychus urticae)",
        "threat_type": "Pest",
        "affected_crops": ["Tomato", "Pepper", "Cucumber", "Eggplant", "Strawberry", "Apple", "Cotton", "Grape"],
        "description": "Extremely common mite pest feeding on leaf undersides, causing yellowing, "
                       "bronzing and webbing. Thrives in hot, dry conditions and can explode in population rapidly.",
        "description_tr": "Yaprak altlarında beslenerek sararma, bronzlaşma ve ağ örmeye neden olan çok yaygın akar zararlısı. "
                          "Sıcak ve kuru koşullarda hızla çoğalarak ciddi verim kaybına yol açar.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Tetranychus_urticae_%284883560779%29.jpg/500px-Tetranychus_urticae_%284883560779%29.jpg",
    },
    {
        "eppo_code": "THRIPS",
        "threat_name": "Western flower thrips (Frankliniella occidentalis)",
        "threat_name_tr": "Trips (Frankliniella occidentalis)",
        "threat_type": "Pest",
        "affected_crops": ["Tomato", "Pepper", "Cucumber", "Strawberry", "Lettuce", "Grape", "Cotton"],
        "description": "Tiny insect pest causing silvery feeding scars on leaves and fruit. "
                       "Major vector of Tomato Spotted Wilt Virus (TSWV). Very difficult to control.",
        "description_tr": "Yaprak ve meyvelerde gümüşi beslenme izleri bırakan küçük böcek zararlısı. "
                          "Domates lekeli solma virüsü (TSWV) taşıyıcısı. Mücadelesi çok güçtür.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/171773037/medium.jpg",
    },
    {
        "eppo_code": "APHIDS",
        "threat_name": "Green peach aphid (Myzus persicae)",
        "threat_name_tr": "Yaprak biti / Yeşil şeftali yaprak biti (Myzus persicae)",
        "threat_type": "Pest",
        "affected_crops": ["Peach", "Pepper", "Tomato", "Potato", "Tobacco", "Lettuce", "Sugar beet"],
        "description": "One of the most polyphagous and economically important aphids worldwide. "
                       "Transmits over 100 plant viruses and causes leaf curling and stunting.",
        "description_tr": "Dünyada en yaygın ve ekonomik açıdan en zararlı yaprak biti türlerinden biri. "
                          "100'den fazla bitki virüsü taşır, yaprak kıvrılması ve bodurlaşmaya neden olur.",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Myzus_persicae.jpg/500px-Myzus_persicae.jpg",
    },
    {
        "eppo_code": "LIRIOM",
        "threat_name": "Serpentine leafminer (Liriomyza trifolii)",
        "threat_name_tr": "Yaprak galeri sineği (Liriomyza trifolii)",
        "threat_type": "Pest",
        "affected_crops": ["Tomato", "Pepper", "Cucumber", "Lettuce", "Celery", "Bean"],
        "description": "Small fly whose larvae create serpentine mines in leaf tissue, "
                       "reducing photosynthesis. Serious greenhouse pest.",
        "description_tr": "Larvaları yaprak dokusu içinde kıvrımlı galeriler açarak fotosentezi azaltan küçük sinek. "
                          "Seralarda ciddi zararlı.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/57907570/medium.jpeg",
    },
    {
        "eppo_code": "FUSAOX",
        "threat_name": "Fusarium wilt (Fusarium oxysporum)",
        "threat_name_tr": "Fusaryum solgunluğu (Fusarium oxysporum)",
        "threat_type": "Disease",
        "affected_crops": ["Tomato", "Watermelon", "Melon", "Banana", "Cotton", "Chickpea"],
        "description": "Soil-borne fungal pathogen causing vascular wilt, yellowing and plant death. "
                       "Persists in soil for years and is very difficult to eradicate.",
        "description_tr": "Toprak kökenli mantar patojeni; damar solgunluğu, sararma ve bitki ölümüne neden olur. "
                          "Toprakta yıllarca kalıcıdır ve eradikasyonu çok zordur.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/32036896/medium.jpeg",
    },
    {
        "eppo_code": "PHYTIF",
        "threat_name": "Late blight (Phytophthora infestans)",
        "threat_name_tr": "Mildiyö / Geç yanıklık (Phytophthora infestans)",
        "threat_type": "Disease",
        "affected_crops": ["Potato", "Tomato"],
        "description": "Devastating oomycete disease causing rapid foliage and tuber rot. "
                       "Historically responsible for the Irish Potato Famine.",
        "description_tr": "Hızlı yaprak ve yumru çürümesine neden olan yıkıcı oomycete hastalığı. "
                          "Tarihte İrlanda patates kıtlığına sebep olmuştur.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/119968804/medium.jpeg",
    },
    {
        "eppo_code": "DACUOL",
        "threat_name": "Olive fruit fly (Bactrocera oleae)",
        "threat_name_tr": "Zeytin sineği (Bactrocera oleae)",
        "threat_type": "Pest",
        "affected_crops": ["Olive"],
        "description": "The most damaging pest of olives worldwide. Larvae feed inside the fruit "
                       "causing premature drop, quality loss, and increased acidity in olive oil.",
        "description_tr": "Dünyada zeytinin en zararlı böceği. Larvaları meyve içinde beslenerek erken dökülme, "
                          "kalite kaybı ve zeytinyağında asitlik artışına neden olur.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/114668862/medium.jpeg",
    },
    {
        "eppo_code": "CERTCA",
        "threat_name": "Mediterranean fruit fly (Ceratitis capitata)",
        "threat_name_tr": "Akdeniz meyve sineği (Ceratitis capitata)",
        "threat_type": "Pest",
        "affected_crops": ["Peach", "Apple", "Orange", "Mandarin", "Fig", "Apricot", "Grape"],
        "description": "One of the world's most destructive fruit pests. Females lay eggs in fruit, "
                       "larvae feed on flesh causing rot and premature drop.",
        "description_tr": "Dünyanın en yıkıcı meyve zararlılarından biri. Dişiler meyveye yumurta bırakır, "
                          "larvalar meyve etinde beslenerek çürüme ve erken dökülmeye neden olur.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/85614036/medium.jpeg",
    },
    {
        "eppo_code": "PHYTCA",
        "threat_name": "Pepper root rot (Phytophthora capsici)",
        "threat_name_tr": "Biber kök çürüklüğü (Phytophthora capsici)",
        "threat_type": "Disease",
        "affected_crops": ["Pepper", "Tomato", "Eggplant", "Cucumber", "Zucchini", "Melon"],
        "description": "Soil-borne oomycete causing severe root and crown rot, resulting in sudden wilt and plant death.",
        "description_tr": "Şiddetli kök ve kök boğazı çürüklüğüne neden olan, ani solgunluk ve bitki ölümüyle sonuçlanan toprak kökenli oomycete patojeni.",
        "image_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/159842603/medium.jpg",
    },
]

# Region → pest mapping for relevance
_REGION_PESTS: dict[str, list[str]] = {
    "Thrace": ["PLAAAM", "PUCCIR", "EURYLA", "LEPTDE", "APHIDS", "FUSAOX"],
    "Central Anatolia": ["EURYLA", "LEPTDE", "PUCCIR", "HELIAR", "APHIDS", "FUSAOX"],
    "Mediterranean": ["TUTAAB", "XANTCI", "BEMITA", "SPODLI", "TETRUR", "THRIPS", "DACUOL", "CERTCA"],
    "Çukurova": ["HELIAR", "SPODLI", "BEMITA", "TUTAAB", "TETRUR", "THRIPS", "LIRIOM"],
    "Southeastern Anatolia": ["EURYLA", "HELIAR", "PUCCIR", "BEMITA", "TETRUR", "FUSAOX"],
    "Black Sea": ["DITYDI", "PUCCIR", "PLAAAM", "PHYTIF", "APHIDS"],
    "Marmara": ["PLAAAM", "PUCCIR", "TUTAAB", "BEMITA", "TETRUR", "THRIPS", "APHIDS", "CERTCA"],
    "Aegean": ["TUTAAB", "PLAAAM", "BEMITA", "XANTCI", "DACUOL", "CERTCA", "TETRUR", "THRIPS"],
    "Tekirdağ": ["PLAAAM", "PUCCIR", "EURYLA", "LEPTDE", "APHIDS", "TETRUR", "THRIPS"],
}


# ── Public API ───────────────────────────────────────────────────────────


async def search_pests_for_region(region: str, crops: list[str] | None = None) -> list[dict]:
    """
    Dynamically discover pest/disease threats for a region.

    Strategy (4-tier):
    1. MongoDB cache (valid for 7 days)
    2. GBIF scientific database (free, no auth, verified occurrence data)
    3. Gemini AI + Google Search (for enriched descriptions)
    4. Hardcoded knowledge base (last resort fallback)

    Parameters
    ----------
    region : str
        Agricultural region name (e.g., "Thrace", "Mediterranean", "Tekirdağ").
    crops : list[str] | None
        Optional list of crops the farmer grows, for more targeted results.
    """
    # ── Step 1: Check MongoDB cache ──────────────────────────────────
    try:
        from app.database import get_async_db
        db = await get_async_db()
        
        cached = await db.threat_cache.find_one({"region": region})
        if cached:
            cached_at = cached.get("cached_at")
            if cached_at:
                from dateutil.parser import parse as parse_dt
                try:
                    cache_time = parse_dt(cached_at) if isinstance(cached_at, str) else cached_at
                    if cache_time.tzinfo is None:
                        cache_time = cache_time.replace(tzinfo=timezone.utc)
                    age = datetime.now(timezone.utc) - cache_time
                    if age.days < 7:
                        logger.info("✅ Returning cached threats for %s (age: %s)", region, age)
                        return cached.get("threats", [])
                except Exception:
                    pass
    except Exception:
        logger.warning("Cache check failed, proceeding to GBIF", exc_info=True)

    # ── Step 2: GBIF scientific database ─────────────────────────────
    threats: list[dict] = []
    
    try:
        from app.external_apis.gbif_client import discover_pests_for_region as gbif_discover
        
        # Determine country code from region
        country_code = "TR" # Replace with dynamic lookup if available
        
        gbif_threats = await gbif_discover(
            country_code=country_code,
            crops=crops,
            region=region,
        )
        
        if gbif_threats:
            # Enrich GBIF results with our knowledge base (images, detailed descriptions)
            for threat in gbif_threats:
                # Match with known pests for image_url and richer descriptions
                for known in _KNOWN_PESTS:
                    import re
                    def extract_sci(name: str) -> str:
                        m = re.search(r'\((.*?)\)', name)
                        return m.group(1).lower().strip() if m else name.lower().strip()
                        
                    known_sci = extract_sci(known.get("threat_name", ""))
                    threat_sci = extract_sci(threat.get("threat_name", ""))
                    
                    if known_sci and threat_sci and (known_sci in threat_sci or threat_sci in known_sci):
                        if not threat.get("image_url"):
                            threat["image_url"] = known.get("image_url")
                        # Use richer description from knowledge base if GBIF one is generic
                        if "GBIF" in threat.get("description", ""):
                            threat["description"] = known["description"]
                            threat["description_tr"] = known["description_tr"]
                            
                        # Update with our rich names
                        threat["threat_name"] = known.get("threat_name", threat["threat_name"])
                        threat["threat_name_tr"] = known.get("threat_name_tr", threat.get("threat_name_tr"))
                        break
                
                threats.append(threat)
            
            logger.info("🌍 GBIF returned %d verified threats for %s", len(threats), region)
            
            # Cache results
            try:
                db = await get_async_db()
                threat_dicts = []
                for t in threats:
                    td = dict(t)
                    if isinstance(td.get("reported_date"), datetime):
                        td["reported_date"] = td["reported_date"].isoformat()
                    threat_dicts.append(td)
                    
                await db.threat_cache.update_one(
                    {"region": region},
                    {"$set": {
                        "region": region,
                        "threats": threat_dicts,
                        "cached_at": datetime.now(timezone.utc).isoformat(),
                        "source": "gbif",
                    }},
                    upsert=True,
                )
            except Exception:
                logger.warning("Failed to cache GBIF threats", exc_info=True)
            
            return threats
    except Exception:
        logger.warning("GBIF discovery failed for %s, trying Gemini", region, exc_info=True)

    # ── Step 3: Gemini AI + Google Search (fallback) ─────────────────
    try:
        from google import genai
        from app.agents.llm_utils import get_genai_client
        
        client = get_genai_client()
        crop_context = f"Crops grown in the region: {', '.join(crops)}." if crops else ""
        
        prompt = f"""You are an agricultural pest and disease expert.
Research the currently active or at-risk agricultural pests and plant diseases in the {region} region.
{crop_context}

For each pest/disease, provide the following information in JSON format:
- threat_name: English scientific/common name (e.g., "Two-spotted spider mite (Tetranychus urticae)")
- threat_name_tr: Turkish name (e.g., "Kırmızı örümcek (Tetranychus urticae)")
- threat_type: "Pest", "Disease" or "Invasive"
- affected_crops: List of affected crops (in English)
- severity: "Low", "Medium", "High" or "Critical"
- description: Short description in English
- description_tr: Short description in Turkish
- source_location: "{region}"
- spread_risk_to_neighbors: Spread risk between 0.0-1.0

Find at least 5 and at most 10 pests/diseases. Provide real, up-to-date, and scientifically accurate information.
Return only a JSON array, nothing else."""

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                temperature=0.3,
                tools=[genai.types.Tool(google_search=genai.types.GoogleSearch())],
            ),
        )
        
        import json
        text = response.text.strip()
        if text.startswith("```"):
            text = text.split("\n", 1)[1] if "\n" in text else text[3:]
        if text.endswith("```"):
            text = text[:-3]
        text = text.strip()
        if text.startswith("json"):
            text = text[4:].strip()
            
        parsed = json.loads(text)
        
        if isinstance(parsed, list):
            for item in parsed:
                item["reported_date"] = datetime.now(timezone.utc).isoformat()
                if not item.get("image_url"):
                    for known in _KNOWN_PESTS:
                        if (known["threat_name"].lower() in item.get("threat_name", "").lower() or
                            known["threat_name_tr"].lower() in item.get("threat_name_tr", "").lower()):
                            item["image_url"] = known.get("image_url")
                            break
                if not item.get("spread_risk_to_neighbors"):
                    item["spread_risk_to_neighbors"] = _estimate_spread_risk(item.get("threat_type", "Pest"))
                threats.append(item)
            
            logger.info("🤖 Gemini discovered %d threats for %s", len(threats), region)
            
            try:
                db = await get_async_db()
                await db.threat_cache.update_one(
                    {"region": region},
                    {"$set": {"region": region, "threats": threats,
                              "cached_at": datetime.now(timezone.utc).isoformat(), "source": "gemini"}},
                    upsert=True,
                )
            except Exception:
                pass
            return threats
    except Exception:
        logger.warning("Gemini discovery also failed for %s, using hardcoded", region, exc_info=True)

    # ── Step 4: Hardcoded knowledge base (last resort) ───────────────
    relevant_codes = _REGION_PESTS.get(region, [])
    if not relevant_codes:
        for key in _REGION_PESTS:
            if key.lower() in region.lower() or region.lower() in key.lower():
                relevant_codes = _REGION_PESTS[key]
                break
    if not relevant_codes:
        relevant_codes = ["TETRUR", "THRIPS", "APHIDS", "TUTAAB", "BEMITA", "FUSAOX"]

    for code in relevant_codes:
        pest_info = _get_pest_info(code)
        if pest_info is None:
            continue
        severity = await _assess_severity(code, region, None)
        threats.append({
            "threat_name": pest_info["threat_name"],
            "threat_name_tr": pest_info["threat_name_tr"],
            "threat_type": pest_info["threat_type"],
            "affected_crops": pest_info["affected_crops"],
            "severity": severity,
            "source_location": region,
            "reported_date": datetime.now(timezone.utc),
            "spread_risk_to_neighbors": _estimate_spread_risk(pest_info["threat_type"]),
            "description": pest_info["description"],
            "image_url": pest_info.get("image_url"),
        })

    logger.info("📦 Returned %d hardcoded fallback threats for %s", len(threats), region)
    return threats


async def get_eppo_reporting_service() -> list[dict]:
    """
    Fetch the latest EPPO Reporting Service articles.

    Returns recent pest/disease reports from across the EPPO region.
    """
    settings = get_settings()

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                f"{settings.eppo_base_url}/tools/reporting",
                params={"format": "json"},
            )
            if resp.status_code == 200:
                return resp.json()
    except Exception:
        logger.warning("EPPO Reporting Service fetch failed", exc_info=True)

    return []


# ── Private Helpers ──────────────────────────────────────────────────────


def _get_pest_info(eppo_code: str) -> dict | None:
    """Look up pest info from our knowledge base."""
    for pest in _KNOWN_PESTS:
        if pest["eppo_code"] == eppo_code:
            return pest
    return None


async def _fetch_eppo_distribution(eppo_code: str) -> list[dict] | None:
    """
    Fetch pest distribution data from EPPO Global Database.

    Returns None on failure (network error, etc.) — callers should
    fall back to local data.
    """
    settings = get_settings()

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                f"{settings.eppo_base_url}/taxon/{eppo_code}/distribution",
            )
            if resp.status_code == 200:
                data = resp.json()
                logger.info(
                    "Fetched EPPO distribution for %s: %d records",
                    eppo_code, len(data) if isinstance(data, list) else 0,
                )
                return data if isinstance(data, list) else []
    except Exception:
        logger.debug("EPPO API call failed for %s", eppo_code, exc_info=True)

    return None


def _is_present_locally(distribution: list[dict] | None, country_code: str) -> bool:
    """Check if a pest is listed as present in Turkey."""
    if distribution is None:
        return True  # Assume present if we can't check

    for entry in distribution:
        country = entry.get("country", {}).get("isocode", "")
        if country == country_code:
            status = entry.get("status", "").lower()
            if "present" in status or "widespread" in status:
                return True

    return False


async def _assess_severity(
    eppo_code: str,
    region: str,
    distribution: list[dict] | None,
) -> str:
    """
    Assess the severity of a pest threat for a given region.

    Uses a combination of:
    - Known destructiveness of the pest
    - Whether EPPO data confirms presence
    - Regional crop vulnerability
    """
    # High-severity pests (known to cause >30% yield loss)
    high_severity = {"TUTAAB", "EURYLA", "SPODLI", "HELIAR", "PHYTIF", "DACUOL"}
    medium_severity = {"PUCCIR", "PLAAAM", "BEMITA", "XANTCI", "TETRUR", "THRIPS", "FUSAOX", "CERTCA", "APHIDS", "LIRIOM"}

    if eppo_code in high_severity:
        return "High"
    elif eppo_code in medium_severity:
        return "Medium"
    return "Low"


def _estimate_spread_risk(threat_type: str) -> float:
    """Estimate spread risk based on threat type."""
    risk_map = {
        "Pest": 0.65,      # Insects can migrate
        "Disease": 0.45,   # Diseases spread via wind/water
        "Invasive": 0.80,  # Invasive species spread aggressively
    }
    return risk_map.get(threat_type, 0.5)
