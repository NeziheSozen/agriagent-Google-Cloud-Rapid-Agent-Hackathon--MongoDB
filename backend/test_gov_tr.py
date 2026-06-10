import asyncio
import httpx
from bs4 import BeautifulSoup

async def test_scrape():
    url = "https://www.tarimorman.gov.tr/"
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers, timeout=10.0)
            print("Status code:", response.status_code)
            soup = BeautifulSoup(response.text, "html.parser")
            text = soup.get_text(separator=' ', strip=True)
            print("Extracted text snippet:", text[:200])
        except Exception as e:
            print("Failed:", e)

asyncio.run(test_scrape())
