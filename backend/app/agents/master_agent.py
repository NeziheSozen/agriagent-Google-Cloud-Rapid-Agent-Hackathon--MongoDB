import json
import uuid

import logging
from datetime import datetime, timezone
from app.models.report import StrategyReport, CropOption
from app.agents.agronomist_agent import AgronomistOutput
from app.agents.economist_agent import EconomistOutput
from app.agents.sustainability_agent import SustainabilityOutput
from app.agents.llm_utils import get_genai_client, generate_json_response
from pydantic import BaseModel

logger = logging.getLogger(__name__)

class MasterAgentReport(BaseModel):
    season: str
    farm_summary: str
    rotation_analysis: str
    climate_assessment: str
    threat_assessment: str
    market_outlook: str
    sustainability_analysis: str
    insurance_recommendations: str
    final_recommendation: str

async def synthesize_report(
    farmer_data: dict,
    agronomist_data: AgronomistOutput,
    economist_data: EconomistOutput,
    sustainability_data: SustainabilityOutput,
    insurance_data: str,
    past_report_context: str | None = None
) -> StrategyReport:
    """
    Master Agent: The Orchestrator.
    Takes biological analysis, financial analysis, sustainability details, and insurance findings,
    synthesizes them into a cohesive, user-friendly final report,
    and returns the StrategyReport object required by the UI.
    """
    logger.info("🧠 Master Agent synthesizing final report...")

    lang = farmer_data.get('language', 'tr')
    # We will build the final crop list directly by merging Agronomist and Economist data
    final_crops = []
    
    # Create a mapping for easy lookup
    bio_map = {c.crop: c for c in agronomist_data.top_3_crops}
    
    # The economist returns them ranked by profitability
    for rank_idx, fin_crop in enumerate(economist_data.financial_ranking):
        bio_crop = bio_map.get(fin_crop.crop)
        if not bio_crop:
            continue
            
        combined_risk = (bio_crop.biological_risk_score + fin_crop.financial_risk_score) / 2.0
        
        final_crops.append(
            CropOption(
                rank=rank_idx + 1,
                crop=fin_crop.crop,
                expected_yield_tons_per_hectare=fin_crop.expected_yield_tons_per_hectare,
                estimated_revenue=fin_crop.estimated_revenue,
                estimated_cost=fin_crop.estimated_cost,
                estimated_profit=fin_crop.estimated_profit,
                risk_score=combined_risk,
                risk_factors=bio_crop.risk_factors + [fin_crop.financial_notes],
                rotation_benefit=bio_crop.rotation_benefit
            )
        )

    # 1. Prepare Context for Master Agent to write the text fields
    memory_context = ""
    if past_report_context:
        memory_context = f"\n--- PAST MEMORY (UNIFIED MEMORY) ---\nYou gave the farmer the following recommendation last season: {past_report_context}\nDraw a consistent new strategy using this recommendation as reference.\n"

    instruction = f"""You are the 'Master Agent' (Main Coordinator) of the Agriculture Platform.
The Agronomist Agent (Biology), Economist Agent (Finance), Sustainability Agent (Ecology/Carbon), and Insurance Agent have completed their analyses.
Your task is to write the text (summary) sections of the final strategy report for the farmer using the raw data they produced.
Please create a visionary summary considering the following strategies (Cooperative purchasing, Intercropping, Tractor/Machine sharing).
CRITICAL REQUIREMENT: You MUST write the ENTIRE report in the language with code '{lang}' (e.g. if 'tr' then Turkish, if 'en' then English).
{memory_context}

DATA:
--- AGRONOMIST AGENT SUMMARY ---
Rotation: {agronomist_data.rotation_analysis}
Climate: {agronomist_data.climate_assessment}
Threat: {agronomist_data.threat_assessment}

--- ECONOMIST AGENT SUMMARY ---
Market & Grants/Subsidies: {economist_data.market_outlook}

--- SUSTAINABILITY (ECO) AGENT SUMMARY ---
Soil Health Score: {sustainability_data.soil_health_score}/100
Carbon Reduction Potential: %{sustainability_data.carbon_reduction_potential_pct}
Eco Action Plan: {", ".join(sustainability_data.eco_action_plan)}
Ecological Science Notes: {sustainability_data.rotation_science_notes}

--- INSURANCE RECOMMENDATIONS ---
Recommended Agricultural Insurance: {insurance_data}

TASK: Combine all this data to create the final assessments for the farmer.
"""

    from google.adk.agents.llm_agent import LlmAgent
    from google.adk import Runner
    from google.adk.sessions.in_memory_session_service import InMemorySessionService

    # 2. Create ADK LlmAgent
    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="MasterAgent",
        instruction=instruction,
        output_schema=MasterAgentReport
    )

    # 3. Run the Agent
    session_service = InMemorySessionService()
    session_id = f"master_{uuid.uuid4().hex[:8]}"
    await session_service.create_session(app_name="AgriAgent", user_id="system", session_id=session_id)
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    final_text = ""
    from google.genai import types
    msg = types.Content(role='user', parts=[types.Part.from_text(text="Please generate the synthesis in JSON format.")])
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
            final_output = MasterAgentReport(**data_dict)
        except Exception as e:
            logger.error(f"🧠 Master Agent JSON parse error: {e}")
            final_output = None
            
    if not (final_output and isinstance(final_output, MasterAgentReport)):
        logger.error("🧠 Master Agent (ADK) failed to produce structured output.")
        final_output = MasterAgentReport(
            season="Unknown",
            farm_summary="Could not be fully synthesized due to system load.",
            rotation_analysis="Could not be synthesized.",
            climate_assessment="Could not be synthesized.",
            threat_assessment="Could not be synthesized.",
            market_outlook="Could not be synthesized.",
            sustainability_analysis="Could not be synthesized.",
            insurance_recommendations="Could not be synthesized.",
            final_recommendation="Could not be synthesized."
        )

    if not final_crops:
        final_crops.append(
            CropOption(
                rank=1,
                crop="Analysis Error (Please Retry)",
                expected_yield_tons_per_hectare=0.0,
                estimated_revenue=0.0,
                estimated_cost=0.0,
                estimated_profit=0.0,
                risk_score=10.0,
                risk_factors=["The Agronomist or Economist agent failed to return structured data."],
                rotation_benefit="None"
            )
        )

    location = farmer_data.get("location", "").lower()
    if "turkey" in location or "türkiye" in location:
        currency_symbol = "₺"
    elif any(c in location for c in ["germany", "france", "italy", "spain", "netherlands"]):
        currency_symbol = "€"
    elif "uk" in location or "united kingdom" in location or "england" in location:
        currency_symbol = "£"
    elif "korea" in location:
        currency_symbol = "₩"
    elif "japan" in location:
        currency_symbol = "¥"
    elif "india" in location:
        currency_symbol = "₹"
    elif "china" in location:
        currency_symbol = "¥"
    elif "russia" in location:
        currency_symbol = "₽"
    elif "brazil" in location:
        currency_symbol = "R$"
    else:
        currency_symbol = "$"

    # 4. Build final Pydantic model for the DB/UI
    report = StrategyReport(
        user_id=farmer_data.get("user_id", "unknown"),
        currency_symbol=currency_symbol,
        season=final_output.season,
        farm_summary=final_output.farm_summary,
        rotation_analysis=final_output.rotation_analysis,
        climate_assessment=final_output.climate_assessment,
        threat_assessment=final_output.threat_assessment,
        market_outlook=final_output.market_outlook,
        sustainability_analysis=final_output.sustainability_analysis,
        insurance_recommendations=final_output.insurance_recommendations,
        recommendations=final_crops,
        final_recommendation=final_output.final_recommendation,
        created_at=datetime.now(timezone.utc)
    )

    logger.info("🧠 Master Agent (ADK) synthesis complete.")
    return report

