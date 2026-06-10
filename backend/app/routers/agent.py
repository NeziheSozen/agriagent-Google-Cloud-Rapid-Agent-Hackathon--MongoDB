"""
Agent router — AI-powered report generation endpoints.

Provides endpoints for triggering AI strategy report generation
that orchestrates all data sources (climate, threats, market, satellite)
through Google Gemini.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, UploadFile, File
from fastapi.responses import StreamingResponse
from pymongo.asynchronous.database import AsyncDatabase

from app.database import get_db
from app.models.report import StrategyReport
from app.services import agent_service

router = APIRouter(prefix="/agent", tags=["AI Agent"])


from pydantic import BaseModel

class ChatRequest(BaseModel):
    message: str

@router.post(
    "/generate-report/{user_id}",
    response_model=StrategyReport,
    summary="Generate AI strategy report",
    description=(
        "Orchestrates all data sources (farmer profile, Open-Meteo climate, "
        "EPPO threats, market prices, Agromonitoring satellite) and feeds them "
        "to Google Gemini to generate a comprehensive crop rotation strategy report. "
        "The report is automatically saved to MongoDB."
    ),
)
async def generate_report(
    user_id: str,
    lang: str = "tr",
    db: AsyncDatabase = Depends(get_db),
) -> StrategyReport:
    return await agent_service.generate_full_report(db, user_id, lang)

@router.post(
    "/chat/{user_id}",
    summary="Chat with the Master Agent",
    description="Conversational endpoint acting as the Agent Builder bridge.",
)
async def chat_with_agent(
    user_id: str,
    req: ChatRequest,
    db: AsyncDatabase = Depends(get_db),
) -> dict:
    reply = await agent_service.chat_with_agent(db, user_id, req.message)
    return {"reply": reply}

@router.post(
    "/chat/stream/{user_id}",
    summary="Stream Chat with the Master Agent",
    description="Conversational endpoint acting as the Agent Builder bridge with Server-Sent Events (SSE).",
)
async def stream_chat_with_agent(
    user_id: str,
    req: ChatRequest,
    db: AsyncDatabase = Depends(get_db),
) -> StreamingResponse:
    return StreamingResponse(
        agent_service.stream_chat_with_agent(db, user_id, req.message),
        media_type="text/event-stream"
    )

@router.post(
    "/voice-chat/{user_id}",
    summary="Voice Chat with the Master Agent",
    description="Conversational endpoint for voice input.",
)
async def voice_chat_with_agent(
    user_id: str,
    file: UploadFile = File(...),
    db: AsyncDatabase = Depends(get_db),
) -> dict:
    audio_bytes = await file.read()
    reply = await agent_service.voice_chat_with_agent(db, user_id, audio_bytes, file.content_type)
    return {"reply": reply}

from app.agents.llm_utils import get_genai_client, generate_json_with_image
from app.models.threat import ThreatAlert
import base64
from datetime import datetime, timezone

@router.post(
    "/scan-pest/{user_id}",
    response_model=ThreatAlert,
    summary="Scan pest via image",
    description="Analyzes an uploaded image to identify pests or diseases.",
)
async def scan_pest(
    user_id: str,
    lang: str = "en",
    file: UploadFile = File(...),
    db: AsyncDatabase = Depends(get_db),
) -> ThreatAlert:
    image_bytes = await file.read()
    client = get_genai_client()
    
    prompt = (
        "You are an expert agricultural agent. Analyze this image and identify the agricultural pest or disease. "
        f"Provide its name (in English as threat_name, and in the language code '{lang}' as local_threat_name), "
        "classification (Pest, Disease, or Invasive), "
        "severity (Low, Medium, High, or Critical), affected crops, and a brief description with recommendations "
        f"(in English as description, and in the language code '{lang}' as local_description). "
        "For source_location, use 'AI Scanner'. For spread_risk_to_neighbors, estimate a value between 0.0 and 1.0. "
        f"For reported_date, use '{datetime.now(timezone.utc).isoformat()}'"
    )
    
    alert = generate_json_with_image(
        client=client,
        prompt=prompt,
        image_bytes=image_bytes,
        mime_type=file.content_type or "image/jpeg",
        response_schema=ThreatAlert
    )
    
    # Save the scanned threat to the database (optional for demo, but good practice)
    # We can fetch the user's region and append it to their RegionalThreats document.
    farmer = await db.farmers.find_one({"_id": user_id})
    if farmer:
        region = farmer.get("region", "Unknown")
        alert.source_location = f"{region} (AI Scan)"
        
        await db.regional_threats.update_one(
            {"region": {"$regex": f"^{region}$", "$options": "i"}},
            {"$push": {"active_threats": alert.model_dump()}},
            upsert=True
        )
        
        
    return alert

@router.get(
    "/urgency/{user_id}",
    summary="Get Real-time AI Urgency Radar",
    description="Calculates operational urgency for each plot using Gemini based on real weather and threats.",
)
async def get_urgency_radar(
    user_id: str,
    db: AsyncDatabase = Depends(get_db),
) -> list[dict]:
    return await agent_service.calculate_urgency_radar(db, user_id)

@router.get(
    "/logistics-advice/{crop}",
    summary="Get AI Logistics Advice",
    description="Uses Gemini to analyze logistics needs for a specific crop.",
)
async def get_logistics_advice(
    crop: str,
) -> dict:
    from app.agents.llm_utils import get_genai_client
    
    prompt = f"""
    You are an agricultural logistics consultant. The user wants to transport the crop '{crop}'.
    Considering general logistics options (e.g., Cold Chain Logistics, Standard Truck, Open Bed Truck, etc.), please:
    1. Explain which logistics method is the most advantageous for '{crop}'.
    2. Briefly justify your recommendation based on cost, spoilage risk, and speed balance.
    
    IMPORTANT: You MUST write your response entirely in Turkish. Keep it concise (2-3 sentences), clear, and professional.
    """
    
    client = get_genai_client()
    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt,
    )
    return {"advice": response.text.strip()}
