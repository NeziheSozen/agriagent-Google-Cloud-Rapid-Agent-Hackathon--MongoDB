import requests
from bs4 import BeautifulSoup

url = "https://eislem.izmir.bel.tr/tr/HalFiyatlari/20"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
}
response = requests.get(url, headers=headers)
print(response.text[:2000])
