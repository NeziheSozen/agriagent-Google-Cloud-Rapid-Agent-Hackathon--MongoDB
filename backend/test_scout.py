import asyncio
from pymongo import AsyncMongoClient
from app.agents.scout_agent import run_nightly_scout
from app.config import get_settings

async def main():
    settings = get_settings()
    client = AsyncMongoClient(settings.mongodb_url)
    db = client[settings.database_name]
    
    result = await run_nightly_scout(db)
    print("Result:", result)

if __name__ == "__main__":
    asyncio.run(main())
