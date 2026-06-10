import asyncio
import httpx
from bs4 import BeautifulSoup

async def fetch_ibb_hal():
    url = "https://hal.ibb.istanbul/Fiyatlar"
    async with httpx.AsyncClient(verify=False) as client:
        try:
            resp = await client.get(url, timeout=10)
            soup = BeautifulSoup(resp.text, 'html.parser')
            rows = soup.select('table tr')
            print(f"Found {len(rows)} rows")
            for r in rows[:10]:
                cols = [c.text.strip() for c in r.find_all(['th', 'td'])]
                print(cols)
        except Exception as e:
            print("Error:", e)

asyncio.run(fetch_ibb_hal())
