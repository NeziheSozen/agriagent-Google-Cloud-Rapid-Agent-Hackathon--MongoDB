import asyncio
import logging
from pymongo import AsyncMongoClient
from app.config import get_settings
from app.agents.scout_agent import run_nightly_scout
from app.agents.policy_agent import get_policy_grants

logging.basicConfig(level=logging.INFO)

async def main():
    settings = get_settings()
    client = AsyncMongoClient(settings.mongodb_url)
    db = client.get_database("agriagent")
    
    # 1. Clear old policies
    await db.policies.delete_many({})
    print("🧹 Cleared old policies.")
    
    # 2. Run Scout Agent to embed the mock PDF
    print("🏃 Running Scout Agent to embed the real text...")
    result = await run_nightly_scout(db)
    print(f"Scout Result: {result}")
    
    # 3. Test Policy Agent
    print("\n🔍 Testing Policy Agent querying for 'Domates' in 'Antalya'...")
    grants = await get_policy_grants(db, region="Antalya", crops=["Domates", "Narenciye"])
    print(f"\n--- POLICY AGENT OUTPUT ---\n{grants}\n---------------------------\n")
    
if __name__ == "__main__":
    asyncio.run(main())
