import logging
import asyncio
from typing import Optional
from bs4 import BeautifulSoup
import httpx
from pymongo.asynchronous.database import AsyncDatabase
from app.config import get_settings

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(10.0)

async def scrape_selina_wamucii_price(crop_name: str) -> Optional[float]:
    """
    Attempt to scrape the global wholesale price for a specific crop 
    from Selina Wamucii's US market insights as a proxy for global price.
    Returns price in USD per ton.
    """
    # Transform crop name to URL slug format (e.g., "Cherry Tomato" -> "cherry-tomatoes")
    slug = crop_name.lower().replace(" ", "-")
    # Pluralize for common URL structure if it doesn't end with 's' or 'es'
    if not slug.endswith("s") and not slug.endswith("corn") and not slug.endswith("wheat") and not slug.endswith("rice"):
        if slug.endswith("y"):
            slug = slug[:-1] + "ies"
        elif slug.endswith("to") or slug.endswith("tato"):
            slug = slug + "es"
        else:
            slug = slug + "s"
            
    url = f"https://www.selinawamucii.com/insights/prices/united-states-of-america/{slug}/"
    
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT, follow_redirects=True) as client:
            resp = await client.get(
                url,
                headers={
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                    "Accept": "text/html,application/xhtml+xml,application/xml"
                }
            )
            if resp.status_code == 200:
                # Naive text parsing to find the price to avoid heavy BS4 logic if format changes
                text = resp.text.lower()
                
                # "wholesale price range for us tomatoes is between us$ 1.97 and us$ 3.94 per kilogram"
                if "wholesale price range for us" in text and "per kilogram" in text:
                    # Extract the first USD value using basic string matching
                    # This is a hackathon-level quick parse.
                    import re
                    matches = re.findall(r"us\$\s*([0-9.]+)", text)
                    if len(matches) >= 2:
                        low = float(matches[0])
                        high = float(matches[1])
                        avg_price_kg = (low + high) / 2.0
                        return avg_price_kg * 1000  # Convert to per Ton
                        
                logger.debug(f"Could not parse price from Selina Wamucii for {crop_name}")
            else:
                logger.debug(f"Selina Wamucii HTTP {resp.status_code} for {crop_name}")
    except Exception as e:
        logger.debug(f"Scraping failed for {crop_name}: {str(e)}")
        
    return None

async def get_baseline_from_db(db: AsyncDatabase, crop_name: str, is_turkey: bool = False) -> dict:
    """
    Reads the baseline parameters from MongoDB instead of hardcoded python dictionary.
    """
    collection = db.tr_market_data_cache if is_turkey else db.market_data_cache
    
    # Try exact match
    doc = await collection.find_one({"crop": crop_name})
    if doc:
        return doc
        
    # Try case-insensitive
    doc = await collection.find_one({"crop": {"$regex": f"^{crop_name}$", "$options": "i"}})
    if doc:
        return doc
        
    # Default fallback if DB hasn't been seeded properly for this crop
    if is_turkey:
        return {"base": 20000, "vol": 0.15}
    else:
        return {"base_price": 500, "volatility": "Medium"}
