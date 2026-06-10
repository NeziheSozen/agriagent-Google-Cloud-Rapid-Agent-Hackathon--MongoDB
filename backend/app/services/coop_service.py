import logging
from pymongo.asynchronous.database import AsyncDatabase
from pydantic import BaseModel

logger = logging.getLogger(__name__)

class CoopSynergyReport(BaseModel):
    region: str
    target_crop: str
    total_farmers: int
    total_hectares: float
    estimated_fertilizer_cost: float
    potential_discount_percent: float
    synergy_message: str

async def calculate_coop_synergy(db: AsyncDatabase, region: str, crop: str) -> CoopSynergyReport | None:
    """
    Executes a powerful MongoDB Aggregation Pipeline to find all farmers in the
    given region who are planting the specified crop.
    
    This powers the "Co-op Purchasing" and "Sharing Economy" engine.
    """
    logger.info(f"🚜 Running Co-op Aggregation Engine for {crop} in {region}...")
    
    pipeline = [
        # Match farmers in the same region
        {"$match": {"region": region}},
        
        # Unwind their crop history to find their most recent crop
        # In a real app we'd look at their 'planned' crop, but here we look at the last history entry
        {"$addFields": {"last_crop": {"$arrayElemAt": ["$crop_history.crop", -1]}}},
        
        # Match only those whose last/current crop is the target crop
        {"$match": {"last_crop": crop}},
        
        # Unwind plots to access per-plot size_hectares
        {"$unwind": "$plots"},
        
        # Group them to calculate total market power
        {"$group": {
            "_id": "$region",
            "total_farmers": {"$sum": 1},
            "total_hectares": {"$sum": "$plots.size_hectares"}
        }}
    ]
    
    cursor = await db.farmers.aggregate(pipeline)
    results = await cursor.to_list(length=1)
    
    if not results:
        return None
        
    data = results[0]
    total_farmers = data.get("total_farmers", 0)
    total_hectares = data.get("total_hectares", 0.0)
    
    # If it's just this one farmer, no synergy yet
    if total_farmers <= 1:
        return None
        
    # Calculate arbitrary fertilizer costs and discounts based on scale
    cost_per_hectare = 5000  # USD
    total_cost = total_hectares * cost_per_hectare
    
    # E.g., 2% discount per farmer up to 25% max
    discount = min(total_farmers * 2.0, 25.0)
    
    message = (
        f"Cooperative Opportunity: In the {region} region, a total of {total_farmers} farmers including you "
        f"are planting {crop}. With your combined {total_hectares} hectares of land power, a "
        f"{discount}% bulk purchase (B2B) discount can be requested from seed and fertilizer suppliers."
    )
    
    return CoopSynergyReport(
        region=region,
        target_crop=crop,
        total_farmers=total_farmers,
        total_hectares=total_hectares,
        estimated_fertilizer_cost=total_cost,
        potential_discount_percent=discount,
        synergy_message=message
    )
