import asyncio
import logging
from datetime import datetime, timezone
from pymongo import AsyncMongoClient

from app.config import get_settings

logger = logging.getLogger(__name__)

# Moving hardcoded data out of the application code into the database seed.
GLOBAL_SEED_DATA = {
    # Cereals
    "Wheat": {"base_price": 270, "volatility": "Medium"},
    "Durum Wheat": {"base_price": 320, "volatility": "Medium"},
    "Barley": {"base_price": 240, "volatility": "Low"},
    "Corn": {"base_price": 250, "volatility": "Medium"},
    "Silage Corn": {"base_price": 100, "volatility": "Low"},
    "Popcorn": {"base_price": 340, "volatility": "Medium"},
    "Rice": {"base_price": 520, "volatility": "Medium"},
    "Paddy Rice": {"base_price": 340, "volatility": "Medium"},
    "Oat": {"base_price": 220, "volatility": "Low"},
    "Rye": {"base_price": 200, "volatility": "Low"},
    "Millet": {"base_price": 240, "volatility": "Low"},
    "Sorghum": {"base_price": 210, "volatility": "Low"},
    "Triticale": {"base_price": 220, "volatility": "Low"},
    "Buckwheat": {"base_price": 430, "volatility": "Medium"},
    # Oilseeds
    "Sunflower": {"base_price": 530, "volatility": "High"},
    "Sunflower (Confectionery)": {"base_price": 630, "volatility": "High"},
    "Canola": {"base_price": 540, "volatility": "High"},
    "Soybean": {"base_price": 430, "volatility": "Medium"},
    "Sesame": {"base_price": 1290, "volatility": "High"},
    "Flaxseed": {"base_price": 720, "volatility": "Medium"},
    "Safflower": {"base_price": 460, "volatility": "Medium"},
    "Peanut": {"base_price": 860, "volatility": "Medium"},
    # Industrial
    "Cotton": {"base_price": 1200, "volatility": "High"},
    "Sugar Beet": {"base_price": 35, "volatility": "Low"},
    "Tobacco": {"base_price": 1570, "volatility": "Medium"},
    "Tea": {"base_price": 340, "volatility": "Low"},
    "Hemp": {"base_price": 570, "volatility": "High"},
    "Lavender": {"base_price": 2290, "volatility": "High"},
    "Rose": {"base_price": 2720, "volatility": "High"},
    # Legumes
    "Chickpea": {"base_price": 800, "volatility": "Medium"},
    "Lentil": {"base_price": 920, "volatility": "Medium"},
    "Red Lentil": {"base_price": 970, "volatility": "Medium"},
    "Green Lentil": {"base_price": 860, "volatility": "Medium"},
    "Dry Bean": {"base_price": 720, "volatility": "Medium"},
    "Kidney Bean": {"base_price": 800, "volatility": "Medium"},
    "Broad Bean": {"base_price": 430, "volatility": "Medium"},
    "Pea": {"base_price": 340, "volatility": "Low"},
    "Cowpea": {"base_price": 570, "volatility": "Medium"},
    # Tomatoes
    "Tomato": {"base_price": 230, "volatility": "Very High"},
    "Cherry Tomato": {"base_price": 520, "volatility": "Very High"},
    "Roma Tomato": {"base_price": 220, "volatility": "Very High"},
    "Beefsteak Tomato": {"base_price": 290, "volatility": "Very High"},
    "Cluster Tomato": {"base_price": 340, "volatility": "Very High"},
    "Pink Tomato": {"base_price": 270, "volatility": "Very High"},
    "Dried Tomato": {"base_price": 1860, "volatility": "High"},
    # Peppers
    "Pepper": {"base_price": 400, "volatility": "Very High"},
    "Bell Pepper": {"base_price": 460, "volatility": "Very High"},
    "Hot Pepper": {"base_price": 340, "volatility": "High"},
    "Capia Pepper": {"base_price": 320, "volatility": "High"},
    "Banana Pepper": {"base_price": 290, "volatility": "High"},
    "Isot Pepper": {"base_price": 2430, "volatility": "Medium"},
    "Dried Red Pepper": {"base_price": 1570, "volatility": "Medium"},
    # Cucurbits
    "Cucumber": {"base_price": 170, "volatility": "Medium"},
    "Cornichon": {"base_price": 340, "volatility": "Medium"},
    "Zucchini": {"base_price": 240, "volatility": "Medium"},
    "Pumpkin": {"base_price": 120, "volatility": "Low"},
    "Pumpkin Seed": {"base_price": 1720, "volatility": "High"},
    "Watermelon": {"base_price": 72, "volatility": "High"},
    "Seedless Watermelon": {"base_price": 100, "volatility": "High"},
    "Melon": {"base_price": 100, "volatility": "High"},
    "Cantaloupe": {"base_price": 130, "volatility": "High"},
    "Honeydew Melon": {"base_price": 120, "volatility": "High"},
    # Leafy Greens
    "Lettuce": {"base_price": 190, "volatility": "High"},
    "Iceberg Lettuce": {"base_price": 160, "volatility": "High"},
    "Romaine Lettuce": {"base_price": 220, "volatility": "High"},
    "Spinach": {"base_price": 200, "volatility": "Medium"},
    "Cabbage": {"base_price": 100, "volatility": "Low"},
    "Red Cabbage": {"base_price": 130, "volatility": "Low"},
    "Kale": {"base_price": 260, "volatility": "Medium"},
    "Arugula": {"base_price": 340, "volatility": "High"},
    "Chard": {"base_price": 170, "volatility": "Medium"},
    "Purslane": {"base_price": 230, "volatility": "Medium"},
    # Root
    "Potato": {"base_price": 140, "volatility": "High"},
    "Sweet Potato": {"base_price": 340, "volatility": "Medium"},
    "Carrot": {"base_price": 140, "volatility": "Low"},
    "Onion": {"base_price": 120, "volatility": "High"},
    "Red Onion": {"base_price": 140, "volatility": "High"},
    "Shallot": {"base_price": 430, "volatility": "Medium"},
    "Garlic": {"base_price": 720, "volatility": "High"},
    "Radish": {"base_price": 140, "volatility": "Medium"},
    "Turnip": {"base_price": 100, "volatility": "Low"},
    "Beet": {"base_price": 120, "volatility": "Low"},
    "Celery": {"base_price": 200, "volatility": "Medium"},
    "Celeriac": {"base_price": 170, "volatility": "Low"},
    "Leek": {"base_price": 160, "volatility": "Medium"},
    # Other Veg
    "Eggplant": {"base_price": 290, "volatility": "Medium"},
    "Green Bean": {"base_price": 520, "volatility": "Medium"},
    "Broad Green Bean": {"base_price": 400, "volatility": "Medium"},
    "Okra": {"base_price": 630, "volatility": "High"},
    "Artichoke": {"base_price": 430, "volatility": "Medium"},
    "Asparagus": {"base_price": 1090, "volatility": "High"},
    "Broccoli": {"base_price": 290, "volatility": "Medium"},
    "Cauliflower": {"base_price": 170, "volatility": "Medium"},
    "Brussels Sprouts": {"base_price": 340, "volatility": "Medium"},
    "Fennel": {"base_price": 230, "volatility": "Medium"},
    "Mushroom": {"base_price": 1000, "volatility": "Medium"},
    "Oyster Mushroom": {"base_price": 1290, "volatility": "High"},
    "Shiitake Mushroom": {"base_price": 2290, "volatility": "High"},
    # Herbs & Spices
    "Parsley": {"base_price": 290, "volatility": "Medium"},
    "Dill": {"base_price": 340, "volatility": "Medium"},
    "Mint": {"base_price": 430, "volatility": "Medium"},
    "Basil": {"base_price": 570, "volatility": "High"},
    "Thyme": {"base_price": 1000, "volatility": "Medium"},
    "Oregano": {"base_price": 1140, "volatility": "Medium"},
    "Cumin": {"base_price": 1860, "volatility": "High"},
    "Anise": {"base_price": 1570, "volatility": "Medium"},
    "Black Cumin": {"base_price": 2000, "volatility": "High"},
    "Sumac": {"base_price": 1430, "volatility": "Medium"},
    "Saffron": {"base_price": 7140, "volatility": "High"},
    "Bay Leaf": {"base_price": 1290, "volatility": "Low"},
    "Rosemary": {"base_price": 720, "volatility": "Medium"},
    # Stone Fruits
    "Cherry": {"base_price": 1140, "volatility": "High"},
    "Sour Cherry": {"base_price": 720, "volatility": "High"},
    "Peach": {"base_price": 430, "volatility": "Medium"},
    "Nectarine": {"base_price": 460, "volatility": "Medium"},
    "Plum": {"base_price": 340, "volatility": "Medium"},
    "Apricot": {"base_price": 570, "volatility": "Medium"},
    "Dried Apricot": {"base_price": 2140, "volatility": "Medium"},
    # Pome Fruits
    "Apple": {"base_price": 230, "volatility": "Low"},
    "Green Apple": {"base_price": 260, "volatility": "Low"},
    "Red Apple": {"base_price": 240, "volatility": "Low"},
    "Pear": {"base_price": 320, "volatility": "Low"},
    "Quince": {"base_price": 290, "volatility": "Low"},
    "Medlar": {"base_price": 520, "volatility": "Medium"},
    # Citrus
    "Orange": {"base_price": 220, "volatility": "Low"},
    "Blood Orange": {"base_price": 290, "volatility": "Medium"},
    "Mandarin": {"base_price": 190, "volatility": "Low"},
    "Lemon": {"base_price": 260, "volatility": "Medium"},
    "Grapefruit": {"base_price": 200, "volatility": "Low"},
    "Bergamot": {"base_price": 430, "volatility": "Medium"},
    # Berries
    "Strawberry": {"base_price": 920, "volatility": "High"},
    "Raspberry": {"base_price": 1290, "volatility": "High"},
    "Blackberry": {"base_price": 1140, "volatility": "High"},
    "Blueberry": {"base_price": 2290, "volatility": "High"},
    "Mulberry": {"base_price": 570, "volatility": "Medium"},
    "Cranberry": {"base_price": 1570, "volatility": "High"},
    # Subtropical
    "Banana": {"base_price": 630, "volatility": "Low"},
    "Kiwi": {"base_price": 430, "volatility": "Medium"},
    "Avocado": {"base_price": 1000, "volatility": "High"},
    "Mango": {"base_price": 1430, "volatility": "High"},
    "Pineapple": {"base_price": 520, "volatility": "Medium"},
    "Passion Fruit": {"base_price": 2000, "volatility": "High"},
    "Dragon Fruit": {"base_price": 2570, "volatility": "High"},
    "Persimmon": {"base_price": 340, "volatility": "Medium"},
    "Loquat": {"base_price": 570, "volatility": "High"},
    # Grapes
    "Grape": {"base_price": 340, "volatility": "Medium"},
    "Table Grape": {"base_price": 400, "volatility": "Medium"},
    "Wine Grape": {"base_price": 230, "volatility": "Medium"},
    "Sultana Grape": {"base_price": 1000, "volatility": "Medium"},
    "Raisin": {"base_price": 1430, "volatility": "Medium"},
    # Olives
    "Olive": {"base_price": 1290, "volatility": "Medium"},
    "Table Olive": {"base_price": 1140, "volatility": "Medium"},
    "Oil Olive": {"base_price": 1430, "volatility": "Medium"},
    "Olive Oil": {"base_price": 5720, "volatility": "High"},
    # Nuts
    "Walnut": {"base_price": 2430, "volatility": "Low"},
    "Hazelnut": {"base_price": 3430, "volatility": "Medium"},
    "Almond": {"base_price": 2860, "volatility": "Medium"},
    "Pistachio": {"base_price": 5140, "volatility": "High"},
    "Chestnut": {"base_price": 860, "volatility": "Medium"},
    "Pine Nut": {"base_price": 10000, "volatility": "High"},
    # Other Fruits
    "Fig": {"base_price": 1000, "volatility": "High"},
    "Dried Fig": {"base_price": 2000, "volatility": "Medium"},
    "Pomegranate": {"base_price": 460, "volatility": "Medium"},
    "Cornelian Cherry": {"base_price": 720, "volatility": "High"},
    "Jujube": {"base_price": 860, "volatility": "High"},
    "Carob": {"base_price": 430, "volatility": "Low"},
    # Coffee & Cocoa
    "Coffee": {"base_price": 5140, "volatility": "High"},
    "Cocoa": {"base_price": 3430, "volatility": "High"},
}

TR_SEED_DATA = {
    # Cereals
    "Wheat": {"base": 9500, "vol": 0.05},
    "Barley": {"base": 8200, "vol": 0.04},
    "Corn": {"base": 8500, "vol": 0.06},
    "Rice": {"base": 24000, "vol": 0.08},
    "Oat": {"base": 7800, "vol": 0.05},
    # Vegetables
    "Tomato": {"base": 25000, "vol": 0.20},  
    "Pepper": {"base": 35000, "vol": 0.25},  
    "Cucumber": {"base": 18000, "vol": 0.22}, 
    "Eggplant": {"base": 22000, "vol": 0.18}, 
    "Onion": {"base": 12000, "vol": 0.30},    
    "Potato": {"base": 14000, "vol": 0.25},   
    "Garlic": {"base": 85000, "vol": 0.15},   
    "Cabbage": {"base": 9000, "vol": 0.12},
    "Spinach": {"base": 15000, "vol": 0.20},
    "Lettuce": {"base": 12000, "vol": 0.20},
    "Carrot": {"base": 13000, "vol": 0.15},
    # Fruits
    "Apple": {"base": 22000, "vol": 0.15},
    "Orange": {"base": 16000, "vol": 0.18},
    "Lemon": {"base": 18000, "vol": 0.20},
    "Grape": {"base": 30000, "vol": 0.15},
    "Cherry": {"base": 80000, "vol": 0.25},
    "Peach": {"base": 35000, "vol": 0.20},
    "Plum": {"base": 28000, "vol": 0.18},
    "Watermelon": {"base": 8000, "vol": 0.30},
    "Melon": {"base": 12000, "vol": 0.25},
    "Strawberry": {"base": 65000, "vol": 0.22},
    # Oilseeds & Industrial
    "Sunflower": {"base": 18000, "vol": 0.10},
    "Cotton": {"base": 28000, "vol": 0.12},
    "Soybean": {"base": 15000, "vol": 0.08},
    "Canola": {"base": 16000, "vol": 0.09},
    "Sugar Beet": {"base": 2500, "vol": 0.02},
    # Nuts & Olives
    "Hazelnut": {"base": 120000, "vol": 0.15},
    "Walnut": {"base": 95000, "vol": 0.12},
    "Almond": {"base": 110000, "vol": 0.10},
    "Pistachio": {"base": 350000, "vol": 0.20},
    "Olive": {"base": 75000, "vol": 0.15},
    "Olive Oil": {"base": 250000, "vol": 0.18},
    # Legumes
    "Chickpea": {"base": 42000, "vol": 0.10},
    "Lentil": {"base": 38000, "vol": 0.12},
    "Green Bean": {"base": 45000, "vol": 0.25},
    "Pea": {"base": 32000, "vol": 0.20},
}

async def run_seed():
    settings = get_settings()
    client = AsyncMongoClient(settings.mongodb_url)
    db = client[settings.database_name]
    
    # Check if seeds already exist to not overwrite live data accidentally
    global_count = await db.market_data_cache.count_documents({})
    if global_count == 0:
        logger.info("Seeding global market cache...")
        docs = []
        now = datetime.now(timezone.utc).isoformat()
        for crop, data in GLOBAL_SEED_DATA.items():
            docs.append({
                "crop": crop,
                "base_price": data["base_price"],
                "volatility": data["volatility"],
                "last_scraped": None,
                "created_at": now
            })
        if docs:
            await db.market_data_cache.insert_many(docs)
            logger.info(f"Inserted {len(docs)} global crop baselines.")

    tr_count = await db.tr_market_data_cache.count_documents({})
    if tr_count == 0:
        logger.info("Seeding TR market cache...")
        docs = []
        now = datetime.now(timezone.utc).isoformat()
        for crop, data in TR_SEED_DATA.items():
            docs.append({
                "crop": crop,
                "base": data["base"],
                "vol": data["vol"],
                "last_scraped": None,
                "created_at": now
            })
        if docs:
            await db.tr_market_data_cache.insert_many(docs)
            logger.info(f"Inserted {len(docs)} TR crop baselines.")
            
    print("Market database successfully seeded with initial baseline caches!")

if __name__ == "__main__":
    asyncio.run(run_seed())
