import asyncio
from pymongo import AsyncMongoClient
from app.config import get_settings
from app.external_apis.market_data import update_market_prices_in_db
import logging

logging.basicConfig(level=logging.INFO)

async def main():
    settings = get_settings()
    client = AsyncMongoClient(settings.mongodb_url)
    db = client[settings.database_name]
    await update_market_prices_in_db(db)

if __name__ == "__main__":
    asyncio.run(main())
