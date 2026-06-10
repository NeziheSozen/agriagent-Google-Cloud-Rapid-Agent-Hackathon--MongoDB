import asyncio
import os
from dotenv import load_dotenv

# load settings from .env
load_dotenv()

from app.external_apis.market_data import fetch_izmir_hal_price

async def test():
    for crop in ["Tomato", "Potato"]:
        res = await fetch_izmir_hal_price(crop)
        print(f"Price for {crop}: {res}")

if __name__ == "__main__":
    asyncio.run(test())
