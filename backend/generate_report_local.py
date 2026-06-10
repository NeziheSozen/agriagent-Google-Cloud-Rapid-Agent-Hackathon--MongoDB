import asyncio
import os
import sys

# Add backend dir to python path
sys.path.append("/Users/nezihes/Desktop/agrticulture agent/backend")

from motor.motor_asyncio import AsyncIOMotorClient
from app.services.agent_service import generate_full_report

async def main():
    os.environ["MONGODB_URL"] = "mongodb+srv://<user>:<password>@<cluster>.mongodb.net/"
    os.environ["DATABASE_NAME"] = "agriagent_db"
    
    # Must use specific keys from .env
    os.environ["GCP_PROJECT_ID"] = "devpost-gemini-agent-hackhaton"
    os.environ["GOOGLE_CLOUD_PROJECT"] = "devpost-gemini-agent-hackhaton"
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
    
    client = AsyncIOMotorClient(os.environ["MONGODB_URL"])
    db = client[os.environ["DATABASE_NAME"]]
    
    try:
        report = await generate_full_report(db, "farmer_001", "tr")
        print(f"Success! Report ID: {report.id}")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        
if __name__ == "__main__":
    asyncio.run(main())
