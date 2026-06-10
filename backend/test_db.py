import asyncio
from app.database import _client
async def main():
    db = _client["agri_agent"]
    farmers = await db.farmers.find().to_list(10)
    for f in farmers:
        print(f["user_id"], f["name"])
    print("Done")
asyncio.run(main())
