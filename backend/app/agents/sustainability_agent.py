import json
import uuid
import logging
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

class SustainabilityOutput(BaseModel):
    soil_health_score: float = Field(description="Topsoil health score from 1-100 based on organic matter and rotation history")
    carbon_reduction_potential_pct: float = Field(description="Estimated percentage reduction in carbon emissions (e.g. 15.5) under sustainable rotation")
    eco_action_plan: list[str] = Field(description="Actionable, global-minded recommendations for carbon reduction and sustainable soil rejuvenation")
    rotation_science_notes: str = Field(description="Comprehensive explanation of the benefits of biological diversity and rotation for long-term farming sustainability")

async def analyze_sustainability(
    farmer_data: dict,
    climate_trend: dict | None = None
) -> SustainabilityOutput:
    """
    Sustainability Agent: Analyzes organic matter, historical rotations, and climate trends to guide
    sustainable farming and reduce carbon footprints.
    """
    from google.adk.agents.llm_agent import LlmAgent
    from google.adk import Runner
    from google.adk.sessions.in_memory_session_service import InMemorySessionService
    
    logger.info("🌿 Sustainability Agent starting eco-analysis...")
    
    lang = farmer_data.get('language', 'tr')
    plots_json = json.dumps(farmer_data.get('plots', []), ensure_ascii=False, default=str)
    farmer_context = f"""
    Name: {farmer_data.get('name', 'Unknown')}
    Location: {farmer_data.get('location', 'Unknown')}, {farmer_data.get('region', 'Unknown')}
    Plots and Soil analysis details: {plots_json}
    """
    
    climate_context = "None"
    if climate_trend:
        forecast = climate_trend.get('forecast', {})
        climate_context = f"Forecast Rainfall: {forecast.get('predicted_rainfall_mm')}mm, Temp: {forecast.get('predicted_avg_temp_celsius')}°C, Drought Risk: {forecast.get('drought_risk')}"

    instruction = f"""You are the Expert Sustainability & Ekoloji Agent (EcoAgent) for our advanced farming platform.
Your task is to analyze the chosen primary crop and evaluate its long-term ecological impact and carbon footprint potential.
CRITICAL REQUIREMENT: You MUST write the ENTIRE report and all text fields in the language with code '{lang}' (e.g. if 'tr' then Turkish, if 'en' then English).

FARM PROFILE:
Do NOT talk about financial profits or costs. Focus entirely on organic soil health, reducing synthetic fertilizer footprints, carbon sequestration, and bio-diverse crop rotation.

DATA CONTEXT:
--- Farmer and Plot Records ---
{farmer_context}

--- Regional Climate Forecasts ---
{climate_context}

Your output must follow the specified schema. Keep all reasoning fully global, scientifically rigorous, and highly actionable.
"""

    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="SustainabilityAgent",
        instruction=instruction,
        output_schema=SustainabilityOutput
    )

    session_service = InMemorySessionService()
    session_id = f"sustainability_{uuid.uuid4().hex[:8]}"
    await session_service.create_session(app_name="AgriAgent", user_id="system", session_id=session_id)
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    final_text = ""
    from google.genai import types
    msg = types.Content(role='user', parts=[types.Part.from_text(text="Please generate the sustainability analysis in structured JSON format.")])
    
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
            final_output = SustainabilityOutput(**data_dict)
            logger.info("🌿 Sustainability Agent successfully completed the eco-analysis.")
            return final_output
        except Exception as e:
            logger.error(f"🌿 Sustainability Agent JSON parse error: {e}")
            
    logger.error("🌿 Sustainability Agent failed to produce structured output. Using fallback.")
    return SustainabilityOutput(
        soil_health_score=70.0,
        carbon_reduction_potential_pct=10.0,
        eco_action_plan=["Incorporate green manure crops to build organic matter.", "Minimize tillage on steep slopes to protect soil structure."],
        rotation_science_notes="Diversifying rotations reduces pest pressure and builds robust soil microbial communities."
    )
