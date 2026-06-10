import asyncio
import httpx
from bs4 import BeautifulSoup

async def fetch_hal_gov_price(crop_name: str):
    url = "https://www.hal.gov.tr/Sayfalar/FiyatDetaylari.aspx"
    crop_mapping = {
        "Tomato": "DOMATES",
        "Pepper": "BİBER",
        "Potato": "PATATES",
        "Onion": "SOĞAN"
    }
    if crop_name not in crop_mapping: return None
    search_name = crop_mapping[crop_name]

    async with httpx.AsyncClient(timeout=15.0, verify=False) as client:
        resp = await client.get(url)
        soup = BeautifulSoup(resp.text, 'html.parser')
        table = soup.find('table', class_='gridView')
        if not table:
            print("Table not found!")
            return None
            
        rows = table.find_all('tr')
        found_names = []
        for row in rows[1:]:
            cols = row.find_all('td')
            if len(cols) >= 4:
                item_name = cols[0].text.strip().upper()
                found_names.append(item_name)
                if search_name in item_name:
                    price_text = cols[3].text.strip().replace(',', '.')
                    print(f"Found {item_name}: {price_text}")
                    return float(price_text)
                    
        print(f"Crop {search_name} not found! First 20 items: {found_names[:20]}")
        return None

async def test():
    await fetch_hal_gov_price("Tomato")
    await fetch_hal_gov_price("Potato")

if __name__ == "__main__":
    asyncio.run(test())
