import asyncio
from pymongo import AsyncMongoClient

import os

async def dump_policies():
    client = AsyncMongoClient(os.getenv("MONGODB_URL", "mongodb://localhost:27017"))
    db = client["agriagent_db"]
    policies = await db["policies"].find().sort("_id", -1).to_list(length=100)
    
    with open("all_policies.md", "w") as f:
        f.write("# Tüm Tarım Teşvikleri ve Destekleri\n\n")
        for p in policies:
            title = p.get('title')
            country = p.get('country', 'Belirtilmemiş')
            published_date = p.get('published_date', 'Bilinmiyor')
            crops = ", ".join(p.get('crops', []))
            content = p.get('content', '').strip()
            
            f.write(f"## {title}\n")
            f.write(f"**Ülke:** {country}\n\n")
            if published_date:
                f.write(f"**Yayın Tarihi:** {published_date}\n\n")
            f.write(f"**Ürünler:** {crops}\n\n")
            f.write(f"**İçerik:**\n{content}\n\n")
            f.write("---\n\n")

asyncio.run(dump_policies())
