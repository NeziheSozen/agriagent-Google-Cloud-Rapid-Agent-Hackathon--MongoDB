import os
from pymongo import MongoClient
from dotenv import load_dotenv

def main():
    load_dotenv()
    mongo_url = os.getenv("MONGODB_URL")
    if not mongo_url:
        print("MONGODB_URL not found in environment!")
        return
    client = MongoClient(mongo_url)
    db = client.get_database("agriagent_db")
    
    # Delete the threat cache so it re-fetches from GBIF and maps images correctly
    result = db.threat_cache.delete_many({})
    print(f"Deleted {result.deleted_count} cached threat documents.")
    
    # Also delete regional_threats to be completely sure
    result2 = db.regional_threats.delete_many({})
    print(f"Deleted {result2.deleted_count} regional_threats documents.")

if __name__ == "__main__":
    main()
