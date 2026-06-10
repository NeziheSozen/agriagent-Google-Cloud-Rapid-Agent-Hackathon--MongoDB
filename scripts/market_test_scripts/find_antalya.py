import requests
import re
import json

def fetch_antalya():
    url = "https://www.antalya.bel.tr/tr/halden-gunluk-fiyatlar"
    headers = {'User-Agent': 'Mozilla/5.0'}
    res = requests.get(url, headers=headers)
    # Search for json data
    matches = re.findall(r'var\s+data\s*=\s*(\[.*?\]);', res.text, re.DOTALL)
    if matches:
        print("Found data array!")
        print(matches[0][:500])
    else:
        # Search for any JSON-like array containing "urun_adi"
        matches2 = re.findall(r'(\[\s*\{.*?urun_adi.*?\}\s*\])', res.text, re.DOTALL)
        if matches2:
            print("Found urun_adi array!")
            print(matches2[0][:500])
        else:
            print("No data found in antalya")

fetch_antalya()
