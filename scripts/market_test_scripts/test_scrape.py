import requests
import json

urls = [
    "https://tarim.ibb.istanbul/avrupa-yakasi-hal-mudurlugu/hal-fiyatlari.html",
    "https://www.antalya.bel.tr/tr/halden-gunluk-fiyatlar",
    "https://eislem.izmir.bel.tr/tr/HalFiyatlari/20"
]

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

for url in urls:
    try:
        response = requests.get(url, headers=headers, timeout=10)
        print(f"URL: {url} - Status: {response.status_code} - Length: {len(response.text)}")
        if response.status_code == 200:
            print(f"Preview:\n{response.text[:200]}")
    except Exception as e:
        print(f"URL: {url} - Error: {e}")
    print("-" * 50)
