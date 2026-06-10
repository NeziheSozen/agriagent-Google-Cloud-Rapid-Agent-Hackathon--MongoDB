import json
import time
import urllib.request
from urllib.parse import quote
import re

with open("app/external_apis/eppo_client.py", "r") as f:
    content = f.read()

blocks = content.split("eppo_code")
out_content = blocks[0]

for block in blocks[1:]:
    match = re.search(r'"threat_name":\s*"[^"]+\(([^)]+)\)"', block)
    if match:
        sci_name = match.group(1)
        if "wikipedia.org" in block or sci_name == "Fusarium oxysporum":
            out_content += "eppo_code" + block
            continue
            
        print(f"Fetching {sci_name}...")
        url = f"https://en.wikipedia.org/w/api.php?action=query&titles={quote(sci_name)}&prop=pageimages&format=json&pithumbsize=500"
        req = urllib.request.Request(url, headers={'User-Agent': f'AgriAgentBot/1.1 ({sci_name})'})
        try:
            resp = urllib.request.urlopen(req)
            data = json.loads(resp.read())
            pages = data['query']['pages']
            page = list(pages.values())[0]
            img = page.get('thumbnail', {}).get('source')
            if img:
                print(f"Found image: {img}")
                block = re.sub(r'"image_url":\s*"[^"]+"', f'"image_url": "{img}"', block)
        except Exception as e:
            print(f"Error {sci_name}: {e}")
        time.sleep(2)
    
    out_content += "eppo_code" + block

with open("app/external_apis/eppo_client.py", "w") as f:
    f.write(out_content)

print("Done updating eppo_client.py")
