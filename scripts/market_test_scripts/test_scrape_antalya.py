import requests
import re

def find_api():
    url = "https://www.antalya.bel.tr/tr/halden-gunluk-fiyatlar"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    response = requests.get(url, headers=headers)
    
    # Look for API endpoints
    apis = re.findall(r'(https?://[^\s"\']+/api/[^\s"\']+)', response.text)
    if apis:
        print("Found API URLs:")
        for api in set(apis):
            print(api)
            
    # Look for any JSON data inside scripts
    scripts = re.findall(r'<script>(.*?)</script>', response.text, re.DOTALL)
    for s in scripts:
        if 'api' in s.lower() or 'fetch' in s.lower() or 'axios' in s.lower() or '$.ajax' in s.lower() or '$.get' in s.lower():
            print("Found script with network call:")
            print(s[:500])

find_api()
