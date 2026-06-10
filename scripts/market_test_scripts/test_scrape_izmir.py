import requests
from bs4 import BeautifulSoup

def test_scrape_izmir():
    url = "https://eislem.izmir.bel.tr/tr/HalFiyatlari/20"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    response = requests.get(url, headers=headers)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    tables = soup.find_all('table')
    if not tables:
        print("No tables found")
        return
        
    print(f"Found {len(tables)} tables")
    table = tables[0]
    rows = table.find_all('tr')
    
    results = []
    for row in rows[1:]:
        cols = row.find_all('td')
        if len(cols) >= 4:
            name = cols[0].text.strip()
            unit = cols[1].text.strip()
            min_price = cols[2].text.strip()
            max_price = cols[3].text.strip()
            results.append({
                "name": name,
                "unit": unit,
                "min": min_price,
                "max": max_price
            })
            
    print(f"Parsed {len(results)} items")
    for r in results[:10]:
        print(r)

test_scrape_izmir()
