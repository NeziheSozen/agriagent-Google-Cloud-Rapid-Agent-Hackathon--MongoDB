import asyncio
import httpx
from google import genai
from google.genai import types
from app.agents.llm_utils import get_genai_client

client = get_genai_client()

pests = [
    ("Tuta absoluta", "https://inaturalist-open-data.s3.amazonaws.com/photos/588846203/medium.jpg"),
    ("Helicoverpa armigera", "https://inaturalist-open-data.s3.amazonaws.com/photos/12166109/medium.jpg"),
    ("Eurygaster integriceps", "https://static.inaturalist.org/photos/59697176/medium.jpg"),
    ("Plasmopara viticola", "https://inaturalist-open-data.s3.amazonaws.com/photos/303947166/medium.jpeg"),
    ("Puccinia recondita", "https://inaturalist-open-data.s3.amazonaws.com/photos/384216149/medium.jpg"),
    ("Spodoptera frugiperda", "https://static.inaturalist.org/photos/160344068/medium.jpg"),
    ("Xanthomonas citri", "https://static.inaturalist.org/photos/138986/medium.jpg"),
    ("Bemisia tabaci", "https://inaturalist-open-data.s3.amazonaws.com/photos/98234558/medium.jpeg"),
    ("Cephus pygmeus", "https://inaturalist-open-data.s3.amazonaws.com/photos/40501837/medium.jpeg"),
    ("Thaumetopoea pityocampa", "https://inaturalist-open-data.s3.amazonaws.com/photos/151178243/medium.jpeg"),
    ("Tetranychus urticae", "https://inaturalist-open-data.s3.amazonaws.com/photos/27710588/medium.jpg"),
    ("Frankliniella occidentalis", "https://inaturalist-open-data.s3.amazonaws.com/photos/171773037/medium.jpg"),
    ("Myzus persicae", "https://inaturalist-open-data.s3.amazonaws.com/photos/1428990/medium.jpg"),
    ("Liriomyza trifolii", "https://inaturalist-open-data.s3.amazonaws.com/photos/57907570/medium.jpeg"),
    ("Phytophthora infestans", "https://inaturalist-open-data.s3.amazonaws.com/photos/119968804/medium.jpeg"),
    ("Bactrocera oleae", "https://inaturalist-open-data.s3.amazonaws.com/photos/114668862/medium.jpeg"),
    ("Ceratitis capitata", "https://inaturalist-open-data.s3.amazonaws.com/photos/85614036/medium.jpeg"),
]

async def check_image(name, url):
    try:
        async with httpx.AsyncClient() as http_client:
            resp = await http_client.get(url)
            if resp.status_code != 200:
                print(f"{name}: Failed to fetch image (HTTP {resp.status_code})")
                return

        image_part = types.Part.from_bytes(data=resp.content, mime_type='image/jpeg')
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=['Does this image show the agricultural pest/disease: ' + name + '? Answer YES or NO. Then describe what is actually in the image in 5 words.', image_part]
        )
        print(f"{name}: {response.text.strip()}")
    except Exception as e:
        print(f"{name}: Error - {e}")

async def main():
    tasks = [check_image(name, url) for name, url in pests]
    await asyncio.gather(*tasks)

if __name__ == '__main__':
    asyncio.run(main())
