import os
import urllib.request
import urllib.error

pests = {
    "TUTAAB": "Tuta_absoluta_1.jpg",
    "HELIAR": "Helicoverpa_armigera.jpg",
    "EURYLA": "Eurygaster_integriceps.jpg",
    "PLAAAM": "Plasmopara_viticola_1.jpg",
    "PUCCIR": "Puccinia_recondita_2.jpg",
    "SPODLI": "Spodoptera_frugiperda_larva.jpg",
    "XANTCI": "Citrus_canker.jpg",
    "BEMITA": "Bemisia_tabaci_02.jpg",
    "LEPTDE": "Cephus_pygmeus_1.jpg",
    "DITYDI": "Thaumetopoea_pityocampa_01.jpg"
}

os.makedirs("app/static/pests", exist_ok=True)

for code, filename in pests.items():
    url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{filename}?width=400"
    out_path = f"app/static/pests/{code}.jpg"
    print(f"Downloading {filename}...")
    req = urllib.request.Request(
        url, 
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    )
    try:
        with urllib.request.urlopen(req) as response, open(out_path, 'wb') as out_file:
            data = response.read()
            out_file.write(data)
        print(f"  -> Saved {out_path}")
    except urllib.error.URLError as e:
        print(f"  -> Failed: {e}")
