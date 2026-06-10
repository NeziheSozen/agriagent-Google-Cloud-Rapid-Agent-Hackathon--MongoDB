import logging
from datetime import datetime, timezone
from fastapi import HTTPException
from pymongo.asynchronous.database import AsyncDatabase
from app.models.farmer import FarmerProfile, SoilAnalysis
from app.agents.llm_utils import get_genai_client, generate_json_with_image

logger = logging.getLogger(__name__)

async def scan_and_save_soil_report(
    db: AsyncDatabase,
    user_id: str,
    plot_index: int,
    image_bytes: bytes,
    mime_type: str
) -> FarmerProfile:
    """
    Extracts SoilAnalysis data from an image using Gemini Vision,
    and updates the specific plot in the farmer's profile.
    """
    logger.info(f"Scanning soil report for {user_id} plot index {plot_index}")
    
    # 1. Fetch farmer to ensure plot exists
    profile_data = await db.farmers.find_one({"user_id": user_id})
    if not profile_data:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
        
    farmer = FarmerProfile(**profile_data)
    if plot_index < 0 or plot_index >= len(farmer.plots):
        raise HTTPException(status_code=400, detail="Invalid plot index")

    # 2. Use Gemini Vision to parse the document
    client = get_genai_client()
    
    prompt = (
        "You are an expert Agricultural Engineer and Laboratory Data Analyst. "
        "The attached photo is a soil analysis laboratory report (may be in Turkish or English). "
        "Please read the data in the report and convert it completely into the requested JSON schema. "
        "If values are not explicitly stated in the report, you may make reasonable agricultural estimates (average local values), "
        "but your priority should be to EXTRACT THE DATA FROM THE IMAGE. "
        "Organic matter should be entered as a percentage (%) (e.g., if 2.5% then 2.5). "
        "pH should be between 0-14. "
        "For texture, select only one of these words: Loamy, Clay, Sandy, Silty, Peaty. "
        "If uncertain, use 'Loamy'. "
        "Provide the test date in ISO format (e.g., 2026-05-26T00:00:00Z), if no date is in the report use today's date."
    )
    
    try:
        soil_analysis: SoilAnalysis = generate_json_with_image(
            client=client,
            prompt=prompt,
            image_bytes=image_bytes,
            mime_type=mime_type,
            response_schema=SoilAnalysis,
            model_name="gemini-2.5-flash",
            temperature=0.1 # Low temperature provides more reliable OCR
        )
    except Exception as e:
        logger.error(f"Gemini Vision failed to parse soil report: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to analyze image: {str(e)}")

    # 3. Update the specific plot in MongoDB
    plot = farmer.plots[plot_index]
    plot.soil_analysis = soil_analysis
    
    update_result = await db.farmers.update_one(
        {"user_id": user_id},
        {"$set": {
            f"plots.{plot_index}.soil_analysis": soil_analysis.model_dump(mode="json")
        }}
    )
    
    if update_result.modified_count == 0:
        logger.warning(f"Failed to update database for {user_id}")
    
    return farmer
