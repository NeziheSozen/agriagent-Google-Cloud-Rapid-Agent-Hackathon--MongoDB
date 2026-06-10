import asyncio
import logging
from google import genai
from pymongo import AsyncMongoClient
import os
import sys

# Add the backend directory to the path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from app.config import get_settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def seed_policies():
    settings = get_settings()
    client = AsyncMongoClient(settings.mongodb_url)
    db = client[settings.database_name]
    
    # 1. Prepare initial seed policies
    policies = [
        {
            "title": "IPARD III Greenhouse and Protected Agriculture Grant",
            "content": "Under the EU-supported IPARD III program, grant support of 25% to 50% is provided for new greenhouse investments (Tomato, Pepper, Cucumber) in the Marmara, Aegean, and Mediterranean regions. For rented lands, the lease period must be at least 5 years.",
            "crops": ["Tomato", "Pepper", "Cucumber", "Domates", "Biber"]
        },
        {
            "title": "Ministry of Agriculture Oilseed Support Premium",
            "content": "Farmers planting Canola (Rapeseed), Sunflower, and Soybean in the Thrace and Central Anatolia regions will receive a 15% premium payment on the sale price, in addition to 150 USD per decare fuel and fertilizer support. Ziraat Bank offers zero-interest operating loans.",
            "crops": ["Canola", "Sunflower", "Soybean", "Kanola", "Ayçiçeği"]
        },
        {
            "title": "Climate Change Adaptation and Drought Support",
            "content": "In regions with high drought risk (Central Anatolia), 75% of seed costs will be covered by the government for farmers planting low water-consumption crops such as Lentil, Chickpea, and Barley.",
            "crops": ["Lentil", "Chickpea", "Barley", "Mercimek", "Nohut", "Arpa"]
        }
    ]
    
    # 2. Initialize Gemini Client for Embeddings
    genai_client = genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
    )
    
    # 3. Generate embeddings and insert
    logger.info("Dropping existing policies collection...")
    await db.policies.drop()
    
    logger.info("Generating embeddings and inserting policies...")
    for policy in policies:
        text_to_embed = f"{policy['title']}\n{policy['content']}"
        
        try:
            response = genai_client.models.embed_content(
                model="text-embedding-004",
                contents=text_to_embed
            )
            embedding = response.embeddings[0].values
            policy["embedding"] = embedding
            
            await db.policies.insert_one(policy)
            logger.info(f"Inserted: {policy['title']}")
        except Exception as e:
            logger.error(f"Failed to embed/insert {policy['title']}: {e}")
            
    logger.info("Policy seeding complete!")
    client.close()

if __name__ == "__main__":
    asyncio.run(seed_policies())
