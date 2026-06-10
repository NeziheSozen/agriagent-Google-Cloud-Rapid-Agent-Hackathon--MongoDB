import json
import uuid

import logging
from pydantic import BaseModel, Field
from pymongo.asynchronous.database import AsyncDatabase
from app.agents.agronomist_agent import AgronomistOutput
from app.services.coop_service import calculate_coop_synergy

logger = logging.getLogger(__name__)

class CoopOutput(BaseModel):
    synergy_analysis: str = Field(description="Analysis of the regional cooperative power and fleet sharing potential.")
    negotiated_discount_percent: float = Field(description="The B2B discount percentage negotiated by the agent.")
    coop_notes: str = Field(description="Actionable notes for the farmer to join the co-op or share machines.")

async def analyze_synergy(
    db: AsyncDatabase,
    farmer_data: dict,
    agronomist_data: AgronomistOutput
) -> CoopOutput:
    """
    Cooperative (Synergy) Agent: The 5th Agent in the MAS.
    Analyzes regional data, calculates total land power, and negotiates a discount.
    """
    from google.adk.agents.llm_agent import LlmAgent
    from google.adk import Runner
    from google.adk.sessions.in_memory_session_service import InMemorySessionService
    
    logger.info("🤝 Coop Agent starting synergy analysis...")
    
    lang = farmer_data.get('language', 'tr')
    region = farmer_data.get('region', 'Unknown')
    crops_to_evaluate = [c.crop for c in agronomist_data.top_3_crops]
    
    coop_context = "Regional cooperative data not found."
    discount_percent = 0.0
    
    if crops_to_evaluate:
        # Check the top crop for synergy
        top_crop = crops_to_evaluate[0]
        coop_report = await calculate_coop_synergy(db, region, top_crop)
        if coop_report:
            coop_context = coop_report.synergy_message
            discount_percent = coop_report.potential_discount_percent

    instruction = f"""You are the "Cooperative and Synergy Agent" (CoopAgent) of the AgriAgent system.
Your job is to look at the user's intended primary crop and region, and calculate how much they could save by joining a local cooperative.
CRITICAL REQUIREMENT: You MUST write the ENTIRE report and all text fields in the language with code '{lang}' (e.g. if 'tr' then Turkish, if 'en' then English).

USER INTENDED CROP: {crops_to_evaluate[0] if crops_to_evaluate else 'Unknown'}

DATA:
Farmer's Region: {region}
Main Crop Under Consideration: {crops_to_evaluate[0] if crops_to_evaluate else 'Unknown'}
Cooperative Engine Result: {coop_context}

TASKS:
1. Interpret the "Cooperative Engine Result" and write a "Synergy Analysis" for the farmer. (Explain how strong they are collectively in this region).
2. Provide recommendations for machine rental and shared use (Fleet Sharing).
3. Record the potential discount rate (if available, %{discount_percent}) as an integer or decimal so the Economist Agent can deduct it from costs.
"""

    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="CoopAgent",
        instruction=instruction,
        output_schema=CoopOutput
    )

    session_service = InMemorySessionService()
    session_id = f"coop_{uuid.uuid4().hex[:8]}"
    await session_service.create_session(app_name="AgriAgent", user_id="system", session_id=session_id)
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    final_text = ""
    from google.genai import types
    msg = types.Content(role='user', parts=[types.Part.from_text(text="Please generate the cooperative synergy analysis in JSON format.")])
    async for event in runner.run_async(user_id="system", session_id=session_id, new_message=msg):
        if hasattr(event, "content") and event.content:
            for p in event.content.parts:
                if hasattr(p, "text") and p.text:
                    final_text += p.text
            
    if final_text:

        try:
            clean_text = final_text.strip()
            if clean_text.startswith("```json"):
                clean_text = clean_text[7:]
            if clean_text.endswith("```"):
                clean_text = clean_text[:-3]
            
            data_dict = json.loads(clean_text.strip())
            final_output = CoopOutput(**data_dict)
            final_output.negotiated_discount_percent = discount_percent
            logger.info("🤝 Coop Agent (ADK) completed analysis successfully.")
            return final_output
        except Exception as e:
            logger.error(f"🤝 Coop Agent JSON parse error: {e}")
        
    logger.error("🤝 Coop Agent (ADK) failed to produce structured output.")
    return CoopOutput(
        synergy_analysis="Regional data could not be analyzed.",
        negotiated_discount_percent=discount_percent,
        coop_notes="Synergy could not be calculated."
    )
