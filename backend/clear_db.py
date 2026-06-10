import asyncio
from pymongo import AsyncMongoClient
from app.config import get_settings

async def clear_all_users():
    settings = get_settings()
    client = AsyncMongoClient(settings.mongodb_url)
    db = client[settings.database_name]
    
    print("Clearing farmers collection...")
    await db.farmers.delete_many({})
    
    print("Clearing strategy_reports collection...")
    await db.strategy_reports.delete_many({})
    
    print("Clearing field_polygons collection...")
    await db.field_polygons.delete_many({})
    
    print("Database cleared successfully!")
    client.close()

if __name__ == "__main__":
    asyncio.run(clear_all_users())
