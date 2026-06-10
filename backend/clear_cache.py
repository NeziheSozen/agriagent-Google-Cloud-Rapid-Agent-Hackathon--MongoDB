import asyncio
from app.config import get_settings
from motor.motor_asyncio import AsyncIOMotorClient

async def clear():
    settings = get_settings()
    client = AsyncIOMotorClient(settings.mongodb_url)
    db = client.get_database(settings.mongodb_db_name)
    await db.threat_cache.drop()
    print('Cache cleared')

asyncio.run(clear())
