import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from app.external_apis.market_data import update_market_prices_in_db
from app.config import get_settings

async def main():
    settings = get_settings()
    client = AsyncIOMotorClient(settings.mongo_uri)
    db = client[settings.mongo_db_name]
    updated = await update_market_prices_in_db(db)
    print(f"Updated {updated} global prices and upserted Turkish data")

asyncio.run(main())
