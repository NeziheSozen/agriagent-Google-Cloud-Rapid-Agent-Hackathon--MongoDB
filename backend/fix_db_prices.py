import asyncio
from pymongo import AsyncMongoClient
from app.config import get_settings

async def fix():
    settings = get_settings()
    client = AsyncMongoClient(str(settings.mongodb_url))
    db = client[settings.database_name]
    
    docs = await db.market_data.find({}).to_list(None)
    for doc in docs:
        cur = doc.get("current_price_tl_per_ton", 0)
        trend = doc.get("price_trend")
        pred = doc.get("predicted_harvest_price_tl_per_ton", 0)
        
        if trend == "up" and pred > cur:
            new_pred = cur * 0.85
            await db.market_data.update_one({"_id": doc["_id"]}, {"$set": {"predicted_harvest_price_tl_per_ton": new_pred}})
            print(f"Fixed {doc.get('crop')} UP: {pred} -> {new_pred}")
        elif trend == "down" and pred < cur:
            new_pred = cur * 1.15
            await db.market_data.update_one({"_id": doc["_id"]}, {"$set": {"predicted_harvest_price_tl_per_ton": new_pred}})
            print(f"Fixed {doc.get('crop')} DOWN: {pred} -> {new_pred}")
        
    print("Done")

asyncio.run(fix())
