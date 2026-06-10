import asyncio
from pymongo import AsyncMongoClient
import datetime
import os

async def check():
    client = AsyncMongoClient(os.getenv("MONGODB_URI"))
    db = client["agriagent_db"]
    policies = db["policies"]
    
    docs = await policies.find().sort("_id", -1).to_list(length=100)
    print(f"Total documents in policies: {len(docs)}")
    if docs:
        for d in docs[:10]:
            print(f"ID: {d.get('_id')}")
            print(f"Generation Time: {d.get('_id').generation_time}")
            print(f"Title: {d.get('title')}")
            print(f"Country: {d.get('country')}")
            print(f"Published Date: {d.get('published_date')}")
            print("---")

asyncio.run(check())
