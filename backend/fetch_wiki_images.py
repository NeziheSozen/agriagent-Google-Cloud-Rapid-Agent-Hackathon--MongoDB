import json
import urllib.request
from urllib.parse import quote

pests = [
    "Tuta absoluta", "Helicoverpa armigera", "Eurygaster integriceps",
    "Plasmopara viticola", "Puccinia recondita", "Spodoptera frugiperda",
    "Xanthomonas citri", "Bemisia tabaci", "Cephus pygmeus",
    "Thaumetopoea pityocampa", "Tetranychus urticae", "Frankliniella occidentalis",
    "Myzus persicae", "Liriomyza trifolii", "Phytophthora infestans",
    "Bactrocera oleae", "Ceratitis capitata"
]

results = {}
for p in pests:
    url = f"https://en.wikipedia.org/w/api.php?action=query&titles={quote(p)}&prop=pageimages&format=json&pithumbsize=500"
    req = urllib.request.Request(url, headers={'User-Agent': 'AgriAgent/1.0 (test)'})
    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read())
        pages = data['query']['pages']
        page = list(pages.values())[0]
        img = page.get('thumbnail', {}).get('source')
        if img:
            results[p] = img
    except Exception as e:
        print(f"Error for {p}: {e}")
print(json.dumps(results, indent=2))
