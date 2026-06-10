import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from app.config import get_settings

async def main():
    settings = get_settings()
    client = AsyncIOMotorClient(settings.mongo_uri)
    db = client[settings.mongo_db_name]
    count = await db.tr_market_data.count_documents({})
    print(f"Total documents in tr_market_data: {count}")
    if count > 0:
        doc = await db.tr_market_data.find_one()
        print(f"Sample: {doc['crop']} - {doc['price_today_per_ton']} {doc['currency']}")

asyncio.run(main())
