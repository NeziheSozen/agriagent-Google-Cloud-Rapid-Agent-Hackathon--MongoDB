import json


import logging
import uuid
from pydantic import BaseModel, Field
from app.models.climate import ClimateTrend
from app.models.threat import RegionalThreats
from app.agents.llm_utils import get_genai_client, generate_json_response

logger = logging.getLogger(__name__)

class BiologicalCropOption(BaseModel):
    crop: str = Field(description="Name of the biologically suitable crop")
    expected_yield_tons_per_hectare: float = Field(description="Expected yield in tons per hectare")
    biological_risk_score: float = Field(description="Risk score from 0-10 based purely on weather and pest risks")
    risk_factors: list[str] = Field(description="Specific biological/weather risk factors")
    rotation_benefit: str = Field(description="Benefit of this crop for soil health and rotation")
    notes: str = Field(description="Agronomist's specific advice on planting this crop")

class AgronomistOutput(BaseModel):
    farm_summary: str = Field(description="Short summary of farm's biological state")
    rotation_analysis: str = Field(description="Analysis of 5-year crop rotation history")
    climate_assessment: str = Field(description="Assessment of climate and weather risks")
    threat_assessment: str = Field(description="Assessment of pest and disease threats")
    top_3_crops: list[BiologicalCropOption] = Field(description="Top 3 biologically suitable crops")

async def analyze_biology(
    farmer_data: dict,
    climate: ClimateTrend | None,
    threats: RegionalThreats | None,
    satellite: dict | None
) -> AgronomistOutput:
    """
    Agronomist Agent: Analyzes biology, soil, weather, and rotation using ADK.
    """
    from google.adk.agents.llm_agent import LlmAgent
    from google.adk import Runner
    from google.adk.sessions.in_memory_session_service import InMemorySessionService
    
    logger.info("🌿 Agronomist Agent (ADK) starting biological analysis...")
    
    # 1. Prepare Context
    lang = farmer_data.get('language', 'tr')
    plots_json = json.dumps(farmer_data.get('plots', []), ensure_ascii=False, default=str)
    farmer_context = f"""
    Name: {farmer_data.get('name', 'Unknown')}
    Location: {farmer_data.get('location', 'Unknown')}, {farmer_data.get('region', 'Unknown')}
    Fields and Lands (including planting history and soil analysis): {plots_json}
    """

    climate_context = "None"
    if climate:
        climate_context = f"Expected Rainfall: {climate.forecast.predicted_rainfall_mm}mm, Temperature: {climate.forecast.predicted_avg_temp_celsius}°C, Risk: {climate.forecast.drought_risk}, Notes: {climate.analysis_notes}"

    threat_context = "None"
    if threats:
        threat_list = [f"{t.threat_name_tr} (Severity: {t.severity}, Target: {', '.join(t.affected_crops)})" for t in threats.active_threats]
        threat_context = f"Overall Risk: {threats.overall_risk_level}. Threats: " + "; ".join(threat_list)

    # 2. Build Instruction — dynamically pull allowed crop names from the catalog
    from app.external_apis.market_data import _BASELINE_PRICES
    allowed_crop_names = list(_BASELINE_PRICES.keys())
    
    # Build a compact crop catalog with key characteristics for smarter recommendations
    crop_catalog_lines = []
    for name, info in _BASELINE_PRICES.items():
        crop_catalog_lines.append(f"{name} (Volatility: {info['volatility']}, Demand: {info['global_demand']})")
    crop_catalog = "\n".join(crop_catalog_lines)
    
    instruction = f"""You are an expert Agronomist Agent.
Analyze the farmer's raw data and output the required JSON strictly.
CRITICAL REQUIREMENT: You MUST write the ENTIRE report and all text fields in the language with code '{lang}' (e.g. if 'tr' then Turkish, if 'en' then English).

CRITICAL CROP NAMING RULE: You MUST use ONLY the EXACT crop names from the catalog below in the 'crop' field of top_3_crops. Do NOT invent names, do NOT add parenthetical alternatives, do NOT use localized names.

IMPORTANT: Always prefer SPECIFIC VARIETIES over generic parent crops when applicable. For example:
- Instead of "Tomato" → recommend "Cherry Tomato", "Roma Tomato", or "Beefsteak Tomato" based on the farmer's conditions
- Instead of "Pepper" → recommend "Bell Pepper", "Capia Pepper", or "Hot Pepper"
- Instead of "Grape" → recommend "Table Grape", "Wine Grape", or "Sultana Grape"
- Instead of "Olive" → recommend "Table Olive" or "Oil Olive"
- Instead of "Lentil" → recommend "Red Lentil" or "Green Lentil"

--- AVAILABLE CROP CATALOG ---
{crop_catalog}

Your task is to identify the 3 most suitable crops for the farmer's field based solely on BIOLOGICAL data (soil, rotation, climate, pests).
Do NOT consider costs or selling prices — that is the Economist Agent's job. You should only analyze soil, water, diseases, and rotation needs (e.g., recommending legumes if the soil needs nitrogen fixation).

DATA:
--- FARMER AND FIELD ---
{farmer_context}

--- CLIMATE FORECAST ---
{climate_context}

--- ACTIVE REGIONAL PESTS ---
{threat_context}

## Intercropping Analysis
- If the field has young trees (tree_age < 5 years) and canopy_coverage < 60%:
  - Recommend shade-tolerant intercrops for the spaces between trees
  - Suitable intercrops: Strawberry (high shade tolerance), Green Bean (nitrogen-fixing), Zucchini, Clover (cover crop)
  - In walnut/hazelnut nurseries, intercropping is critically important for cash flow during the first 4-5 unprofitable years
  - Prefer shallow-rooted plants that won't compete with the main tree's root depth when selecting intercrops

## Topography and Slope Analysis
- If the terrain slope (slope_percent) is greater than 20%:
  - Standard tractor/combine use is NOT SUITABLE — there is a machine rollover risk
  - Recommend terracing
  - Recommend erosion-preventing cover crops: clover, vetch, grass pea
  - Highlight alternatives such as backpack motorized trimmers or drone spraying
- If slope is between 10-20%:
  - Careful machinery use is possible, recommend contour farming
- If slope is less than 10%:
  - Standard mechanization is suitable
"""

    # 3. Create ADK LlmAgent
    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="AgronomistAgent",
        instruction=instruction,
        output_schema=AgronomistOutput
    )

    # 4. Run the Agent
    session_service = InMemorySessionService()
    session_id = f"agronomist_{uuid.uuid4().hex[:8]}"
    await session_service.create_session(app_name="AgriAgent", user_id="system", session_id=session_id)
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    final_text = ""
    from google.genai import types
    msg = types.Content(role='user', parts=[types.Part.from_text(text="Please generate the analysis in JSON format.")])
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
            final_output = AgronomistOutput(**data_dict)
            logger.info("🌿 Agronomist Agent (ADK) completed analysis successfully.")
            return final_output
        except Exception as e:
            logger.error(f"🌿 Agronomist Agent JSON parse error: {e}")
        
    logger.error("🌿 Agronomist Agent (ADK) failed to produce structured output.")
    return AgronomistOutput(
        farm_summary="Data could not be retrieved.",
        rotation_analysis="Data could not be retrieved.",
        climate_assessment="Data could not be retrieved.",
        threat_assessment="Data could not be retrieved.",
        top_3_crops=[]
    )
